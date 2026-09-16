import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:stacflow/src/generated/error_codes.dart';
import 'package:stacflow/src/generated/sse_events.dart';
import 'package:stacflow/src/providers/provider.dart';
import 'package:stacflow/src/providers/turn_runner.dart';
import 'package:stacflow/src/transport/sse_parser.dart';
import 'package:stacflow/src/transport/turn_ids.dart';
import 'package:stacflow/src/transport/turn_request.dart';

/// OpenAI's Chat Completions API, called directly with an API key. Point
/// [baseUrl] at any compatible server: Ollama, Groq, OpenRouter, LM Studio,
/// vLLM, or a proxy of your own that holds the key.
final class OpenAIProvider implements StacFlowProvider {
  new({
    required this._apiKey,
    this.model = defaultModel,
    this.baseUrl = 'https://api.openai.com/v1',
    this.headers = const {},
    http.Client? httpClient,
    List<ModelOption>? models,
    this.includeUsage = true,
    this.firstByteTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 90),
  }) : _client = httpClient,
       models = models ?? [ModelOption(id: model, label: model)];

  /// The model used when none is given.
  static const String defaultModel = 'gpt-5-mini';

  @override
  final String model;

  /// The API origin, including the version path.
  final String baseUrl;

  /// Extra request headers, sent before the SDK's own.
  final Map<String, String> headers;

  @override
  final List<ModelOption> models;

  /// Asks for token counts in the final chunk; turn off for compatible
  /// servers that reject `stream_options`.
  final bool includeUsage;

  /// How long to wait for the response headers.
  final Duration firstByteTimeout;

  /// How long to wait between chunks of the reply.
  final Duration idleTimeout;

  final String _apiKey;
  final http.Client? _client;

  @override
  String get id => 'openai';

  @override
  StacFlowProvider withModel(String model) => OpenAIProvider(
    apiKey: _apiKey,
    model: model,
    baseUrl: baseUrl,
    headers: headers,
    httpClient: _client,
    models: models,
    includeUsage: includeUsage,
    firstByteTimeout: firstByteTimeout,
    idleTimeout: idleTimeout,
  );

  @override
  Stream<SseEvent> run(TurnRequest request) => runTurn(
    turn: _OpenAITurn(this, request, _apiKey),
    request: request,
    providerId: id,
    model: model,
    apiKey: _apiKey,
    client: _client,
    firstByteTimeout: firstByteTimeout,
    idleTimeout: idleTimeout,
  );

  @override
  String toString() => 'OpenAIProvider(model: $model)';
}

final class _OpenAITurn extends ProviderTurn {
  new(this.provider, this.request, this._apiKey);

  final OpenAIProvider provider;
  final TurnRequest request;
  final String _apiKey;

  static const Set<String> _imageTypes = {
    'image/png',
    'image/jpeg',
    'image/gif',
    'image/webp',
  };

  static const Set<String> _finalCodes = {
    'insufficient_quota',
    'billing_hard_limit_reached',
    'credit_balance_exhausted',
  };

  static const Set<String> _schemaMeta = {r'$schema', r'$id', r'$comment'};

  String? _finishReason;
  final Map<int, String> _callIds = {};
  final Map<int, StringBuffer> _held = {};
  final Set<int> _closed = {};
  int? _openIndex;
  int _nextIndex = 0;

  @override
  Uri get url {
    final base = provider.baseUrl.endsWith('/')
        ? provider.baseUrl.substring(0, provider.baseUrl.length - 1)
        : provider.baseUrl;
    return Uri.parse('$base/chat/completions');
  }

  @override
  Map<String, String> get headers => {
    ...provider.headers,
    'content-type': 'application/json',
    'accept': 'text/event-stream',
    'authorization': 'Bearer $_apiKey',
  };

  @override
  Uint8List get body {
    final agent = request.agent;
    final json = <String, Object?>{
      'model': provider.model,
      'stream': true,
      if (provider.includeUsage) 'stream_options': {'include_usage': true},
      if (request.tools.isNotEmpty)
        'tools': [
          for (final tool in request.tools)
            {
              'type': 'function',
              'function': {
                'name': tool.name,
                'description': tool.description,
                'parameters': {
                  for (final entry in tool.parameters.entries)
                    if (!_schemaMeta.contains(entry.key))
                      entry.key: entry.value,
                  'type': 'object',
                },
              },
            },
        ],
      'messages': [
        if (agent.instructions case final instructions?
            when instructions.isNotEmpty)
          {'role': 'system', 'content': instructions},
        for (final message in withToolResults(request.history))
          ..._messages(message),
      ],
      if (agent.temperature != null) 'temperature': agent.temperature,
      if (agent.maxOutputTokens != null)
        'max_completion_tokens': agent.maxOutputTokens,
    };
    return utf8.encode(jsonEncode(json));
  }

  List<Map<String, Object?>> _messages(WireMessage message) {
    if (message.role == WireRole.assistant) {
      final calls = message.parts.whereType<WireToolCallPart>().toList();
      if (calls.isEmpty) return [_message(message)];
      final text = [
        for (final part in message.parts)
          if (part is WireTextPart) part.text,
      ].join('\n');
      return [
        {
          'role': 'assistant',
          'content': text.isEmpty ? null : text,
          'tool_calls': [
            for (final call in calls)
              {
                'id': providerCallIdOf(call.id) ?? call.id,
                'type': 'function',
                'function': {
                  'name': call.name,
                  'arguments': jsonEncode(call.args),
                },
              },
          ],
        },
      ];
    }
    final results = message.parts.whereType<WireToolResultPart>().toList();
    final rest = [
      for (final part in message.parts)
        if (part is! WireToolResultPart) part,
    ];
    return [
      for (final result in results)
        {
          'role': 'tool',
          'tool_call_id': providerCallIdOf(result.id) ?? result.id,
          'content': resultText(result),
        },
      if (rest.isNotEmpty)
        _message(WireMessage(role: WireRole.user, parts: rest)),
    ];
  }

  Map<String, Object?> _message(WireMessage message) {
    final role = message.role == WireRole.user ? 'user' : 'assistant';
    final textOnly = message.parts.every((part) => part is WireTextPart);
    if (textOnly) {
      return {
        'role': role,
        'content': [
          for (final part in message.parts)
            if (part is WireTextPart) part.text,
        ].join('\n'),
      };
    }
    return {
      'role': role,
      'content': [
        for (final part in message.parts)
          switch (part) {
            WireTextPart(:final text) => {'type': 'text', 'text': text},
            WireImagePart(:final bytes, :final mimeType)
                when message.role == WireRole.user &&
                    _imageTypes.contains(mimeType) =>
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,${base64Encode(bytes)}',
                },
              },
            WireImagePart() ||
            WireToolCallPart() ||
            WireToolResultPart() => null,
          },
      ].nonNulls.toList(),
    };
  }

  @override
  void onFrame(SseFrame frame, TurnEmitter out) {
    if (frame.data.trim() == '[DONE]') {
      _finishReason ??= 'stop';
      out.complete();
      return;
    }
    final json = decodeJsonObject(frame.data);
    if (json == null) return;
    if (objectAt(json, 'error') case final error?) {
      out.fail(_failure(200, error));
      return;
    }
    final choices = objectsAt(json, 'choices');
    if (choices.isNotEmpty) {
      final choice = choices.first;
      final delta = objectAt(choice, 'delta');
      if (delta != null) {
        final content = stringAt(delta, 'content');
        if (content != null) out.delta(content);
        for (final call in objectsAt(delta, 'tool_calls')) {
          _onToolCallChunk(call, out);
        }
      }
      final finish = stringAt(choice, 'finish_reason');
      if (finish != null) {
        _finishReason = finish;
        _closeOpen(out);
        if (finish == 'content_filter') {
          out.fail(
            const ProviderFailure(
              code: ErrorCodes.providerError,
              message: 'The reply was blocked by the content filter.',
              retryable: false,
              status: 200,
              upstreamCode: 'content_filter',
            ),
          );
        }
      }
    }
    if (objectAt(json, 'usage') case final usage?) {
      out.usage(
        inputTokens: intAt(usage, 'prompt_tokens'),
        outputTokens: intAt(usage, 'completion_tokens'),
      );
    }
  }

  void _onToolCallChunk(Map<String, dynamic> call, TurnEmitter out) {
    final function = objectAt(call, 'function');
    final name = function == null ? null : stringAt(function, 'name');
    final fragment = function == null ? null : stringAt(function, 'arguments');
    final named = name != null && name.isNotEmpty;
    final index =
        intAt(call, 'index') ??
        (!named && _openIndex != null ? _openIndex! : _nextIndex);
    if (_closed.contains(index)) {
      out.fail(
        const ProviderFailure(
          code: ErrorCodes.providerError,
          message: 'The provider interleaved chunks of different tool calls.',
          retryable: false,
          status: 200,
          upstreamCode: 'interleaved_tool_calls',
        ),
      );
      return;
    }
    var id = _callIds[index];
    if (id == null) {
      if (!named) {
        (_held[index] ??= StringBuffer()).write(fragment ?? '');
        return;
      }
      if (_openIndex case final open? when open != index) _closed.add(open);
      id = out.toolCallStart(name: name, providerCallId: stringAt(call, 'id'));
      _callIds[index] = id;
      _openIndex = index;
      _nextIndex = index + 1;
      final held = _held.remove(index);
      if (held != null && held.isNotEmpty) {
        out.toolCallDelta(id, held.toString());
      }
    }
    if (fragment != null && fragment.isNotEmpty) {
      out.toolCallDelta(id, fragment);
    }
  }

  void _closeOpen(TurnEmitter out) {
    final open = _openIndex;
    if (open == null) return;
    final id = _callIds[open];
    if (id != null) out.toolCallEnd(id);
    _closed.add(open);
    _openIndex = null;
  }

  @override
  void onEnd(TurnEmitter out) {
    if (_finishReason != null) {
      out.complete();
    } else {
      out.transportFailure(
        const ProviderTransportException(
          'The stream ended before the reply was complete.',
        ),
      );
    }
  }

  @override
  ProviderFailure mapHttpError(int status, String body) {
    final json = decodeJsonObject(body);
    return _failure(status, json == null ? null : objectAt(json, 'error'));
  }

  ProviderFailure _failure(int status, Map<String, dynamic>? error) {
    final message = error == null ? null : stringAt(error, 'message');
    final code = error == null ? null : stringAt(error, 'code');
    final type = error == null ? null : stringAt(error, 'type');
    final upstream = code ?? type;
    return httpFailure(
      status,
      provider: provider.id,
      detail: message == null ? null : scrub(message, apiKey: _apiKey),
      upstreamCode: upstream,
      retryable: status == 429 && upstream != null
          ? !(_finalCodes.contains(upstream) ||
                upstream.endsWith('spend_limit_exceeded'))
          : null,
    );
  }
}
