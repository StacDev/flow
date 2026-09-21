import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:stacflow/src/providers/provider.dart';
import 'package:stacflow/src/providers/turn_runner.dart';
import 'package:stacflow/src/transport/error_codes.dart';
import 'package:stacflow/src/transport/sse_events.dart';
import 'package:stacflow/src/transport/sse_parser.dart';
import 'package:stacflow/src/transport/turn_ids.dart';
import 'package:stacflow/src/transport/turn_request.dart';

/// Anthropic's Messages API, called directly with an API key. Browser
/// calls send the header Anthropic requires for that, so the key travels
/// to the browser; keep that for development builds.
final class AnthropicProvider implements StacFlowProvider {
  AnthropicProvider({
    required this._apiKey,
    this.model = defaultModel,
    this.baseUrl = 'https://api.anthropic.com',
    this.headers = const {},
    http.Client? httpClient,
    List<ModelOption>? models,
    this.maxTokens = 64000,
    this.firstByteTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 90),
  }) : _client = httpClient,
       models = models ?? [ModelOption(id: model, label: model)];

  /// The model used when none is given; `claude-sonnet-5` is the cheaper
  /// choice.
  static const String defaultModel = 'claude-opus-5';

  @override
  final String model;

  /// The API origin; point it at a proxy that holds the key in production.
  final String baseUrl;

  /// Extra request headers, sent before the SDK's own.
  final Map<String, String> headers;

  @override
  final List<ModelOption> models;

  /// The reply length limit the API requires, unless the agent sets one.
  final int maxTokens;

  /// How long to wait for the response headers.
  final Duration firstByteTimeout;

  /// How long to wait between chunks of the reply.
  final Duration idleTimeout;

  final String _apiKey;
  final http.Client? _client;
  final Map<String, Map<String, List<Map<String, dynamic>>>> _replay = {};

  static const int _maxCachedThreads = 8;

  Map<String, List<Map<String, dynamic>>> _replayFor(TurnRequest request) {
    final thread = request.ids.threadId;
    if (request.segment == 0) _replay.remove(thread);
    final cached = _replay[thread];
    if (cached != null) return cached;
    while (_replay.length >= _maxCachedThreads) {
      _replay.remove(_replay.keys.first);
    }
    return _replay[thread] = {};
  }

  @override
  String get id => 'anthropic';

  @override
  StacFlowProvider withModel(String model) => AnthropicProvider(
    apiKey: _apiKey,
    model: model,
    baseUrl: baseUrl,
    headers: headers,
    httpClient: _client,
    models: models,
    maxTokens: maxTokens,
    firstByteTimeout: firstByteTimeout,
    idleTimeout: idleTimeout,
  );

  @override
  Stream<SseEvent> run(TurnRequest request) => runTurn(
    turn: _AnthropicTurn(this, request, _apiKey, _replayFor(request)),
    request: request,
    providerId: id,
    model: model,
    apiKey: _apiKey,
    client: _client,
    firstByteTimeout: firstByteTimeout,
    idleTimeout: idleTimeout,
  );

  @override
  String toString() => 'AnthropicProvider(model: $model)';
}

final class _AnthropicTurn extends ProviderTurn {
  _AnthropicTurn(this.provider, this.request, this._apiKey, this._replay);

  final AnthropicProvider provider;
  final TurnRequest request;
  final String _apiKey;
  final Map<String, List<Map<String, dynamic>>> _replay;

  static const Set<String> _imageTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  };

  static const Set<String> _schemaMeta = {r'$schema', r'$id', r'$comment'};

  String? _stopReason;
  final Map<int, Map<String, dynamic>> _blocks = {};
  final Map<int, String> _callIds = {};
  final Map<int, StringBuffer> _partialJson = {};
  final Map<int, StringBuffer> _thinking = {};

  @override
  Uri get url => Uri.parse('${_trimSlash(provider.baseUrl)}/v1/messages');

  @override
  Map<String, String> get headers => {
    ...provider.headers,
    'content-type': 'application/json',
    'accept': 'text/event-stream',
    'anthropic-version': '2023-06-01',
    'anthropic-dangerous-direct-browser-access': 'true',
    'x-api-key': _apiKey,
  };

  @override
  Uint8List get body {
    final agent = request.agent;
    final json = <String, Object?>{
      'model': provider.model,
      'max_tokens': agent.maxOutputTokens ?? provider.maxTokens,
      'stream': true,
      if (agent.instructions case final instructions?
          when instructions.isNotEmpty)
        'system': instructions,
      if (agent.temperature != null) 'temperature': agent.temperature,
      if (request.tools.isNotEmpty)
        'tools': [
          for (final tool in request.tools)
            {
              'name': tool.name,
              'description': tool.description,
              'input_schema': {
                for (final entry in tool.parameters.entries)
                  if (!_schemaMeta.contains(entry.key)) entry.key: entry.value,
                'type': 'object',
              },
            },
        ],
      'messages': [
        for (final message in withSupportedImages(
          withToolResults(request.history),
          imageTypes: _imageTypes,
        ))
          _message(message),
      ],
    };
    return utf8.encode(jsonEncode(json));
  }

  Map<String, Object?> _message(WireMessage message) {
    final isUser = message.role == WireRole.user;
    if (!isUser) {
      final calls = message.parts.whereType<WireToolCallPart>();
      final cached = calls.isEmpty ? null : _replay[calls.first.id];
      if (cached != null) return {'role': 'assistant', 'content': cached};
    }
    final results = <Map<String, Object?>>[];
    final others = <Map<String, Object?>>[];
    for (final part in message.parts) {
      switch (part) {
        case WireTextPart(:final text) when text.trim().isNotEmpty:
          others.add({'type': 'text', 'text': text});
        case WireImagePart(:final bytes, :final mimeType)
            when isUser && _imageTypes.contains(mimeType):
          others.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mimeType,
              'data': base64Encode(bytes),
            },
          });
        case WireToolCallPart(:final id, :final name, :final args) when !isUser:
          others.add({
            'type': 'tool_use',
            'id': providerCallIdOf(id) ?? id,
            'name': name,
            'input': args,
          });
        case WireToolResultPart(:final id, :final status, :final result)
            when isUser:
          results.add({
            'type': 'tool_result',
            'tool_use_id': providerCallIdOf(id) ?? id,
            if (status != WireToolResultStatus.ok || result != null)
              'content': resultText(part),
            if (status != WireToolResultStatus.ok) 'is_error': true,
          });
        case WireTextPart():
        case WireImagePart():
        case WireToolCallPart():
        case WireToolResultPart():
          break;
      }
    }
    return {
      'role': isUser ? 'user' : 'assistant',
      'content': [...results, ...others],
    };
  }

  @override
  void onFrame(SseFrame frame, TurnEmitter out) {
    final json = decodeJsonObject(frame.data);
    if (json == null) return;
    final type = frame.event ?? stringAt(json, 'type');
    switch (type) {
      case 'message_start':
        final message = objectAt(json, 'message');
        final usage = message == null ? null : objectAt(message, 'usage');
        if (usage != null) {
          out.usage(inputTokens: intAt(usage, 'input_tokens'));
        }
      case 'content_block_start':
        _onBlockStart(json, out);
      case 'content_block_delta':
        _onBlockDelta(json, out);
      case 'content_block_stop':
        _onBlockStop(json, out);
      case 'message_delta':
        final delta = objectAt(json, 'delta');
        _stopReason = delta == null
            ? _stopReason
            : stringAt(delta, 'stop_reason') ?? _stopReason;
        final usage = objectAt(json, 'usage');
        if (usage != null) {
          out.usage(
            inputTokens: intAt(usage, 'input_tokens'),
            outputTokens: intAt(usage, 'output_tokens'),
          );
        }
      case 'message_stop':
        if (_stopReason == 'refusal') {
          out.fail(
            const ProviderFailure(
              code: ErrorCodes.providerError,
              message: 'The model declined this request.',
              retryable: false,
              status: 200,
              upstreamCode: 'refusal',
            ),
          );
        } else {
          _stopReason ??= 'end_turn';
          _cacheReplay();
          out.complete();
        }
      case 'error':
        out.fail(_failure(200, objectAt(json, 'error')));
    }
  }

  void _onBlockStart(Map<String, dynamic> json, TurnEmitter out) {
    final index = intAt(json, 'index') ?? _blocks.length;
    final block = objectAt(json, 'content_block');
    if (block == null) return;
    switch (stringAt(block, 'type')) {
      case 'text':
        _blocks[index] = {
          'type': 'text',
          'text': stringAt(block, 'text') ?? '',
        };
      case 'tool_use':
        final name = stringAt(block, 'name') ?? '';
        final providerId = stringAt(block, 'id');
        final id = out.toolCallStart(name: name, providerCallId: providerId);
        _callIds[index] = id;
        _partialJson[index] = StringBuffer();
        _blocks[index] = {
          'type': 'tool_use',
          'id': providerId ?? id,
          'name': name,
          'input': <String, dynamic>{},
        };
      case 'thinking':
        _thinking[index] = StringBuffer(stringAt(block, 'thinking') ?? '');
        _blocks[index] = {
          'type': 'thinking',
          'thinking': '',
          'signature': stringAt(block, 'signature') ?? '',
        };
      case 'redacted_thinking':
        _blocks[index] = {
          'type': 'redacted_thinking',
          'data': stringAt(block, 'data') ?? '',
        };
    }
  }

  void _onBlockDelta(Map<String, dynamic> json, TurnEmitter out) {
    final index = intAt(json, 'index') ?? -1;
    final delta = objectAt(json, 'delta');
    if (delta == null) return;
    switch (stringAt(delta, 'type')) {
      case 'text_delta':
        final text = stringAt(delta, 'text') ?? '';
        out.delta(text);
        final block = _blocks[index];
        if (block != null && block['type'] == 'text') {
          block['text'] = '${block['text']}$text';
        }
      case 'input_json_delta':
        final id = _callIds[index];
        final fragment = stringAt(delta, 'partial_json') ?? '';
        if (id != null) {
          out.toolCallDelta(id, fragment);
          _partialJson[index]?.write(fragment);
        }
      case 'thinking_delta':
        _thinking[index]?.write(stringAt(delta, 'thinking') ?? '');
      case 'signature_delta':
        final block = _blocks[index];
        if (block != null) {
          block['signature'] = stringAt(delta, 'signature') ?? '';
        }
    }
  }

  void _onBlockStop(Map<String, dynamic> json, TurnEmitter out) {
    final index = intAt(json, 'index') ?? -1;
    final thinking = _thinking[index];
    final block = _blocks[index];
    if (thinking != null && block != null) {
      block['thinking'] = thinking.toString();
    }
    final id = _callIds[index];
    if (id == null) return;
    final raw = (_partialJson[index]?.toString() ?? '').trim();
    final args = raw.isEmpty ? <String, dynamic>{} : decodeJsonObject(raw);
    if (args == null) {
      out.toolCallEnd(id);
      return;
    }
    block?['input'] = args;
    out.toolCallEnd(id, args: args);
  }

  void _cacheReplay() {
    if (_callIds.isEmpty) return;
    final indices = _blocks.keys.toList()..sort();
    final content = [
      for (final index in indices)
        if (_blocks[index] case final block?
            when block['type'] != 'text' ||
                (block['text'] as String).isNotEmpty)
          block,
    ];
    final firstCall = (_callIds.keys.toList()..sort()).first;
    _replay[_callIds[firstCall]!] = content;
  }

  @override
  void onEnd(TurnEmitter out) {
    if (_stopReason != null) {
      _cacheReplay();
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
    final type = error == null ? null : stringAt(error, 'type');
    final message = error == null ? null : stringAt(error, 'message');
    final (code, retryable) = switch (type) {
      'overloaded_error' || 'api_error' => (ErrorCodes.providerError, true),
      'rate_limit_error' => (ErrorCodes.providerRateLimited, true),
      'authentication_error' ||
      'permission_error' => (ErrorCodes.providerAuthFailed, false),
      'invalid_request_error' ||
      'request_too_large' => (ErrorCodes.validationFailed, false),
      _ => (null, null),
    };
    return httpFailure(
      status,
      provider: provider.id,
      detail: message == null ? null : scrub(message, apiKey: _apiKey),
      upstreamCode: type,
      code: code,
      retryable: retryable,
    );
  }
}

String _trimSlash(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;
