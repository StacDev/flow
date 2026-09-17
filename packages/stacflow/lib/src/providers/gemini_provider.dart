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

/// Google's Gemini API, called directly with an API key from AI Studio.
final class GeminiProvider implements StacFlowProvider {
  GeminiProvider({
    required this._apiKey,
    this.model = defaultModel,
    this.baseUrl = 'https://generativelanguage.googleapis.com',
    this.headers = const {},
    http.Client? httpClient,
    List<ModelOption>? models,
    this.firstByteTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 90),
  }) : _client = httpClient,
       models = models ?? [ModelOption(id: model, label: model)];

  /// The model used when none is given.
  static const String defaultModel = 'gemini-3.6-flash';

  @override
  final String model;

  /// The API origin; point it at a proxy that holds the key in production.
  final String baseUrl;

  /// Extra request headers, sent before the SDK's own.
  final Map<String, String> headers;

  @override
  final List<ModelOption> models;

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
  String get id => 'gemini';

  @override
  StacFlowProvider withModel(String model) => GeminiProvider(
    apiKey: _apiKey,
    model: model,
    baseUrl: baseUrl,
    headers: headers,
    httpClient: _client,
    models: models,
    firstByteTimeout: firstByteTimeout,
    idleTimeout: idleTimeout,
  );

  @override
  Stream<SseEvent> run(TurnRequest request) => runTurn(
    turn: _GeminiTurn(this, request, _apiKey, _replayFor(request)),
    request: request,
    providerId: id,
    model: model,
    apiKey: _apiKey,
    client: _client,
    firstByteTimeout: firstByteTimeout,
    idleTimeout: idleTimeout,
  );

  @override
  String toString() => 'GeminiProvider(model: $model)';
}

final class _GeminiTurn extends ProviderTurn {
  _GeminiTurn(this.provider, this.request, this._apiKey, this._replay);

  final GeminiProvider provider;
  final TurnRequest request;
  final String _apiKey;
  final Map<String, List<Map<String, dynamic>>> _replay;

  static const Set<String> _imageTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static const Set<String> _schemaKeywords = {
    'type',
    'format',
    'title',
    'description',
    'nullable',
    'enum',
    'properties',
    'required',
    'items',
    'minItems',
    'maxItems',
    'minimum',
    'maximum',
    'minLength',
    'maxLength',
    'pattern',
    'anyOf',
    'default',
  };

  bool _sawFrame = false;
  final List<Map<String, dynamic>> _parts = [];
  final List<String> _callIds = [];

  @override
  Uri get url {
    final base = provider.baseUrl.endsWith('/')
        ? provider.baseUrl.substring(0, provider.baseUrl.length - 1)
        : provider.baseUrl;
    return Uri.parse(
      '$base/v1beta/models/${provider.model}:streamGenerateContent?alt=sse',
    );
  }

  @override
  Map<String, String> get headers => {
    ...provider.headers,
    'content-type': 'application/json',
    'accept': 'text/event-stream',
    'x-goog-api-key': _apiKey,
  };

  @override
  Uint8List get body {
    final agent = request.agent;
    final generationConfig = <String, Object?>{
      if (agent.temperature != null) 'temperature': agent.temperature,
      if (agent.maxOutputTokens != null)
        'maxOutputTokens': agent.maxOutputTokens,
    };
    final json = <String, Object?>{
      if (agent.instructions case final instructions?
          when instructions.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': instructions},
          ],
        },
      if (request.tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [
              for (final tool in request.tools)
                {
                  'name': tool.name,
                  'description': tool.description,
                  'parameters': providerSchema(
                    tool.parameters,
                    keywords: _schemaKeywords,
                  ),
                },
            ],
          },
        ],
      'contents': [
        for (final message in withSupportedImages(
          withToolResults(request.history),
          imageTypes: _imageTypes,
        ))
          _content(message),
      ],
      if (generationConfig.isNotEmpty) 'generationConfig': generationConfig,
    };
    return utf8.encode(jsonEncode(json));
  }

  Map<String, Object?> _content(WireMessage message) {
    final isUser = message.role == WireRole.user;
    if (!isUser) {
      final calls = message.parts.whereType<WireToolCallPart>();
      final cached = calls.isEmpty ? null : _replay[calls.first.id];
      if (cached != null) return {'role': 'model', 'parts': cached};
    }
    final results = <Map<String, Object?>>[];
    final others = <Map<String, Object?>>[];
    for (final part in message.parts) {
      switch (part) {
        case WireTextPart(:final text):
          others.add({'text': text});
        case WireImagePart(:final bytes, :final mimeType)
            when _imageTypes.contains(mimeType):
          others.add({
            'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
          });
        case WireToolCallPart(:final id, :final name, :final args) when !isUser:
          final providerId = providerCallIdOf(id);
          others.add({
            'functionCall': {'id': ?providerId, 'name': name, 'args': args},
          });
        case WireToolResultPart(:final id, :final name) when isUser:
          final providerId = providerCallIdOf(id);
          results.add({
            'functionResponse': {
              'id': ?providerId,
              'name': name,
              'response': _response(part),
            },
          });
        case WireImagePart():
        case WireToolCallPart():
        case WireToolResultPart():
          break;
      }
    }
    return {
      'role': isUser ? 'user' : 'model',
      'parts': [...results, ...others],
    };
  }

  Map<String, Object?> _response(WireToolResultPart part) =>
      switch (part.status) {
        WireToolResultStatus.ok => switch (part.result) {
          final Map<dynamic, dynamic> map => map.cast<String, Object?>(),
          final other => {'output': other},
        },
        WireToolResultStatus.declined => {'error': declinedSentence},
        WireToolResultStatus.error => {
          'error': part.error ?? 'The tool failed.',
        },
      };

  @override
  void onFrame(SseFrame frame, TurnEmitter out) {
    final json = decodeJsonObject(frame.data);
    if (json == null) return;
    _sawFrame = true;
    if (objectAt(json, 'error') case final error?) {
      out.fail(_failure(intAt(error, 'code') ?? 502, error));
      return;
    }
    final candidates = objectsAt(json, 'candidates');
    if (candidates.isEmpty) {
      final feedback = objectAt(json, 'promptFeedback');
      final reason = feedback == null
          ? null
          : stringAt(feedback, 'blockReason');
      if (reason != null) {
        out.fail(
          ProviderFailure(
            code: ErrorCodes.providerError,
            message: 'The request was blocked by the provider ($reason).',
            retryable: false,
            status: 200,
            upstreamCode: reason,
          ),
        );
      }
      return;
    }
    final candidate = candidates.first;
    final content = objectAt(candidate, 'content');
    if (content != null) {
      for (final part in objectsAt(content, 'parts')) {
        if (part['thought'] == true) continue;
        _parts.add(part);
        final text = stringAt(part, 'text');
        if (text != null) out.delta(text);
        final call = objectAt(part, 'functionCall');
        if (call != null) {
          final id = out.toolCallStart(
            name: stringAt(call, 'name') ?? '',
            providerCallId: stringAt(call, 'id'),
          );
          _callIds.add(id);
          out.toolCallEnd(
            id,
            args: objectAt(call, 'args') ?? <String, dynamic>{},
          );
        }
      }
    }
    if (objectAt(json, 'usageMetadata') case final usage?) {
      final output = intAt(usage, 'candidatesTokenCount');
      final thoughts = intAt(usage, 'thoughtsTokenCount') ?? 0;
      out.usage(
        inputTokens: intAt(usage, 'promptTokenCount'),
        outputTokens: output == null ? null : output + thoughts,
      );
    }
    final finish = stringAt(candidate, 'finishReason');
    if (finish == 'MALFORMED_FUNCTION_CALL') {
      out.fail(
        ProviderFailure(
          code: ErrorCodes.providerError,
          message:
              stringAt(candidate, 'finishMessage') ??
              'The model produced a malformed tool call.',
          retryable: true,
          status: 200,
          upstreamCode: finish,
        ),
      );
    } else if (finish != null && finish != 'STOP' && finish != 'MAX_TOKENS') {
      out.fail(
        ProviderFailure(
          code: ErrorCodes.providerError,
          message: 'The reply was cut short by the provider ($finish).',
          retryable: false,
          status: 200,
          upstreamCode: finish,
        ),
      );
    }
  }

  @override
  void onEnd(TurnEmitter out) {
    if (_sawFrame) {
      if (_callIds.isNotEmpty) {
        _replay[_callIds.first] = List.of(_parts);
      }
      out.complete();
    } else {
      out.transportFailure(
        const ProviderTransportException(
          'The stream ended before any data arrived.',
        ),
      );
    }
  }

  @override
  ProviderFailure mapHttpError(int status, String body) {
    final json = decodeJsonObject(body);
    final error = json == null ? null : objectAt(json, 'error');
    return _failure(status, error);
  }

  ProviderFailure _failure(int status, Map<String, dynamic>? error) {
    final message = error == null ? null : stringAt(error, 'message');
    final upstreamCode = error == null
        ? null
        : stringAt(error, 'status') ?? stringAt(error, 'code');
    final detail = message == null ? null : scrub(message, apiKey: _apiKey);
    final invalidKey =
        status == 400 &&
        (upstreamCode == 'INVALID_ARGUMENT' &&
                (message?.contains('API key') ?? false) ||
            _hasReason(error, 'API_KEY_INVALID'));
    return httpFailure(
      status,
      provider: provider.id,
      detail: detail,
      upstreamCode: upstreamCode,
      code: invalidKey ? ErrorCodes.providerAuthFailed : null,
      retryable: invalidKey ? false : null,
    );
  }

  static bool _hasReason(Map<String, dynamic>? error, String reason) {
    if (error == null) return false;
    for (final detail in objectsAt(error, 'details')) {
      if (stringAt(detail, 'reason') == reason) return true;
    }
    return false;
  }
}
