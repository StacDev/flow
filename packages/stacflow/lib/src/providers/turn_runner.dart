import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:stacflow/src/providers/provider.dart';
import 'package:stacflow/src/tools/tool.dart';
import 'package:stacflow/src/transport/error_codes.dart';
import 'package:stacflow/src/transport/sse_events.dart';
import 'package:stacflow/src/transport/sse_parser.dart';
import 'package:stacflow/src/transport/turn_ids.dart';
import 'package:stacflow/src/transport/turn_request.dart';

final class ProviderFailure {
  const ProviderFailure({
    required this.code,
    required this.message,
    this.retryable,
    this.status,
    this.upstreamCode,
  });

  final String code;
  final String message;
  final bool? retryable;
  final int? status;
  final String? upstreamCode;
}

abstract base class ProviderTurn {
  Uri get url;
  Map<String, String> get headers;
  Uint8List get body;
  void onFrame(SseFrame frame, TurnEmitter out);
  void onEnd(TurnEmitter out);
  ProviderFailure mapHttpError(int status, String body);
}

final class TurnEmitter {
  TurnEmitter({
    required this.ids,
    required this.segment,
    required this.model,
    required this.providerId,
    required List<Tool> tools,
    required this._sink,
    required this._errorSink,
    required this._onTerminal,
  }) : _tools = {for (final tool in tools) tool.name: tool};

  static final IdGenerator _minter = IdGenerator();

  final TurnIds ids;
  final int segment;
  final String model;
  final String providerId;
  final Map<String, Tool> _tools;
  final void Function(SseEvent event) _sink;
  final void Function(Object error) _errorSink;
  final void Function() _onTerminal;

  int _seq = 0;
  bool _done = false;
  int? _inputTokens;
  int? _outputTokens;
  _OpenCall? _open;
  final List<String> _callIds = [];
  final StringBuffer _heldText = StringBuffer();

  bool get isDone => _done;

  List<String> get toolCallIds => List.unmodifiable(_callIds);

  void start() {
    _sink(
      StartEvent(
        seq: _seq++,
        turnId: ids.turnId,
        segment: segment,
        messageId: ids.messageId,
        threadId: ids.threadId,
        model: model,
        agentVersionId: TurnIds.agentVersionId,
      ),
    );
  }

  void delta(String text) {
    if (_done || text.isEmpty) return;
    if (_open != null) {
      _heldText.write(text);
      return;
    }
    _sink(DeltaEvent(seq: _seq++, text: text));
  }

  String toolCallStart({required String name, String? providerCallId}) {
    final open = _open;
    if (open != null) {
      toolCallEnd(open.id);
      if (_done) return open.id;
    }
    if (_done) return '';
    final id = providerCallId == null || providerCallId.isEmpty
        ? _minter.toolCall()
        : toolCallIdFor(providerCallId);
    final permission = _tools[name]?.permission ?? ToolPermission.read;
    _open = _OpenCall(id, name);
    _callIds.add(id);
    _sink(
      ToolCallStartEvent(
        seq: _seq++,
        toolCallId: id,
        toolName: name,
        executor: ToolCallStartEventExecutor.client,
        permissionClass: switch (permission) {
          ToolPermission.read => ToolCallStartEventPermissionClass.read,
          ToolPermission.write => ToolCallStartEventPermissionClass.write,
          ToolPermission.destructive =>
            ToolCallStartEventPermissionClass.destructive,
        },
      ),
    );
    return id;
  }

  void toolCallDelta(String id, String fragment) {
    final open = _open;
    if (_done || open == null || open.id != id || fragment.isEmpty) return;
    open.buffer.write(fragment);
    _sink(ToolCallDeltaEvent(seq: _seq++, toolCallId: id, argsDelta: fragment));
  }

  void toolCallEnd(String id, {Map<String, dynamic>? args}) {
    final open = _open;
    if (_done || open == null || open.id != id) return;
    final raw = open.buffer.toString().trim();
    final parsed = args ?? decodeJsonObject(raw.isEmpty ? '{}' : raw);
    _open = null;
    if (parsed == null) {
      fail(
        ProviderFailure(
          code: ErrorCodes.providerError,
          message: 'The model sent malformed arguments for ${open.name}.',
          retryable: true,
          status: 200,
          upstreamCode: 'malformed_tool_args',
        ),
      );
      return;
    }
    _sink(ToolCallEndEvent(seq: _seq++, toolCallId: id, args: parsed));
    if (_heldText.isNotEmpty) {
      final text = _heldText.toString();
      _heldText.clear();
      _sink(DeltaEvent(seq: _seq++, text: text));
    }
  }

  void usage({int? inputTokens, int? outputTokens}) {
    if (inputTokens != null) _inputTokens = inputTokens;
    if (outputTokens != null) _outputTokens = outputTokens;
  }

  void complete() => _finish(DoneEventStatus.complete);

  void cancel() => _finish(DoneEventStatus.cancelled);

  void fail(ProviderFailure failure) {
    if (_done) return;
    _open = null;
    _flushUsage();
    final info = ErrorCodes.registry[failure.code];
    _sink(
      ErrorEvent(
        seq: _seq++,
        failureClass: info?.failureClass ?? FailureClass.provider,
        code: failure.code,
        message: failure.message,
        retryable: failure.retryable ?? info?.retryable ?? true,
        upstream: Upstream(
          provider: providerId,
          status: failure.status,
          code: failure.upstreamCode,
        ),
      ),
    );
    _finish(DoneEventStatus.error);
  }

  void close() => _done = true;

  void transportFailure(ProviderTransportException exception) {
    if (_done) return;
    _done = true;
    _errorSink(exception);
    _onTerminal();
  }

  void _finish(DoneEventStatus status) {
    if (_done) return;
    final open = _open;
    if (status == DoneEventStatus.complete && open != null) {
      toolCallEnd(open.id);
      if (_done) return;
    }
    if (status != DoneEventStatus.cancelled) _flushUsage();
    final awaiting = status == DoneEventStatus.complete && _callIds.isNotEmpty;
    _sink(
      DoneEvent(
        seq: _seq++,
        status: awaiting ? DoneEventStatus.awaitingClientTools : status,
        turnId: ids.turnId,
        pendingToolCallIds: awaiting ? List.unmodifiable(_callIds) : null,
      ),
    );
    _done = true;
    _onTerminal();
  }

  void _flushUsage() {
    if (_inputTokens == null && _outputTokens == null) return;
    _sink(
      UsageEvent(
        seq: _seq++,
        providerCall: segment,
        model: model,
        inputTokens: _inputTokens ?? 0,
        outputTokens: _outputTokens ?? 0,
      ),
    );
    _inputTokens = null;
    _outputTokens = null;
  }
}

final class _OpenCall {
  _OpenCall(this.id, this.name);

  final String id;
  final String name;
  final StringBuffer buffer = StringBuffer();
}

Stream<SseEvent> runTurn({
  required ProviderTurn turn,
  required TurnRequest request,
  required String providerId,
  required String model,
  required String apiKey,
  required http.Client? client,
  required Duration firstByteTimeout,
  required Duration idleTimeout,
}) {
  late final StreamController<SseEvent> controller;
  late final TurnEmitter emitter;
  StreamSubscription<SseFrame>? subscription;
  http.Client? owned;
  final abortSignal = Completer<void>();
  var finished = false;

  void finish() {
    if (finished) return;
    finished = true;
    emitter.close();
    unawaited(subscription?.cancel());
    if (!abortSignal.isCompleted) abortSignal.complete();
    owned?.close();
    unawaited(controller.close());
  }

  ProviderFailure timeoutFailure() => const ProviderFailure(
    code: ErrorCodes.segmentTimeout,
    message: 'The model did not answer in time.',
    retryable: true,
  );

  Future<void> run() async {
    emitter.start();
    if (apiKey.trim().isEmpty) {
      emitter.fail(
        ProviderFailure(
          code: ErrorCodes.providerAuthFailed,
          message: 'No API key was set for $providerId.',
          retryable: false,
        ),
      );
      return;
    }
    final effective = client ?? (owned = http.Client());
    final http.StreamedResponse response;
    try {
      final httpRequest =
          http.AbortableRequest(
              'POST',
              turn.url,
              abortTrigger: abortSignal.future,
            )
            ..headers.addAll(turn.headers)
            ..bodyBytes = turn.body;
      response = await effective.send(httpRequest).timeout(firstByteTimeout);
    } on TimeoutException {
      emitter.fail(timeoutFailure());
      return;
    } on http.RequestAbortedException {
      emitter.cancel();
      return;
    } on http.ClientException catch (error) {
      emitter.transportFailure(
        ProviderTransportException(
          'The connection to ${turn.url.host} failed before a response '
          'arrived.',
          cause: error,
        ),
      );
      return;
    }
    if (emitter.isDone) return;
    if (response.statusCode != 200) {
      var body = '';
      try {
        body = await _readCapped(response.stream).timeout(idleTimeout);
      } on Object {
        body = '';
      }
      emitter.fail(turn.mapHttpError(response.statusCode, body));
      return;
    }
    subscription = response.stream
        .timeout(idleTimeout)
        .transform(const SseDecoder())
        .listen(
          (frame) {
            if (!emitter.isDone) turn.onFrame(frame, emitter);
          },
          onError: (Object error) {
            if (emitter.isDone) return;
            if (error is TimeoutException) {
              emitter.fail(timeoutFailure());
            } else if (error is http.RequestAbortedException) {
              emitter.cancel();
            } else {
              emitter.transportFailure(
                ProviderTransportException(
                  'The connection to ${turn.url.host} was lost mid-stream.',
                  cause: error,
                ),
              );
            }
          },
          onDone: () {
            if (!emitter.isDone) turn.onEnd(emitter);
          },
          cancelOnError: true,
        );
  }

  controller = StreamController<SseEvent>(
    onListen: () {
      unawaited(
        request.abortTrigger.then((_) {
          if (emitter.isDone) return;
          if (!abortSignal.isCompleted) abortSignal.complete();
          emitter.cancel();
        }),
      );
      unawaited(run());
    },
    onCancel: finish,
  );
  emitter = TurnEmitter(
    ids: request.ids,
    segment: request.segment,
    model: model,
    providerId: providerId,
    tools: request.tools,
    sink: controller.add,
    errorSink: controller.addError,
    onTerminal: finish,
  );
  return controller.stream;
}

Future<String> _readCapped(Stream<List<int>> stream) async {
  final bytes = await stream.toList();
  final all = bytes.expand((chunk) => chunk).toList();
  final capped = all.sublist(0, min(all.length, 64 * 1024));
  return const Utf8Decoder(allowMalformed: true).convert(capped);
}

String scrub(String text, {required String apiKey, int maxLength = 300}) {
  var out = text.trim();
  if (apiKey.isNotEmpty) out = out.replaceAll(apiKey, '[redacted]');
  if (out.length > maxLength) out = '${out.substring(0, maxLength)}...';
  return out;
}

ProviderFailure httpFailure(
  int status, {
  required String provider,
  String? detail,
  String? upstreamCode,
  String? code,
  bool? retryable,
}) {
  final (defaultCode, defaultRetryable) = switch (status) {
    401 || 403 => (ErrorCodes.providerAuthFailed, false),
    429 => (ErrorCodes.providerRateLimited, true),
    400 || 404 || 413 || 422 => (ErrorCodes.validationFailed, false),
    408 || 500 || 502 || 503 || 504 || 529 => (ErrorCodes.providerError, true),
    _ => (ErrorCodes.providerError, status >= 500),
  };
  return ProviderFailure(
    code: code ?? defaultCode,
    message: detail == null || detail.isEmpty
        ? 'HTTP $status from $provider.'
        : detail,
    retryable: retryable ?? defaultRetryable,
    status: status,
    upstreamCode: upstreamCode,
  );
}

const String declinedSentence =
    'The user declined to run this tool call. Do not retry it or work '
    'around it; ask the user how they want to proceed.';

Map<String, dynamic> providerSchema(
  Map<String, dynamic> schema, {
  required Set<String> keywords,
}) {
  final out = <String, dynamic>{};
  for (final entry in schema.entries) {
    final key = entry.key;
    final value = entry.value;
    if (!keywords.contains(key)) continue;
    out[key] = switch (key) {
      'properties' when value is Map => {
        for (final property in value.entries)
          '${property.key}': property.value is Map
              ? providerSchema(
                  (property.value as Map).cast<String, dynamic>(),
                  keywords: keywords,
                )
              : property.value,
      },
      'items' when value is Map => providerSchema(
        value.cast<String, dynamic>(),
        keywords: keywords,
      ),
      'anyOf' || 'oneOf' || 'allOf' when value is List => [
        for (final option in value)
          if (option is Map)
            providerSchema(option.cast<String, dynamic>(), keywords: keywords),
      ],
      _ => value,
    };
  }
  return out;
}

String resultText(WireToolResultPart part) {
  switch (part.status) {
    case WireToolResultStatus.ok:
      final result = part.result;
      return result is String ? result : jsonEncode(result);
    case WireToolResultStatus.declined:
      return jsonEncode({'error': declinedSentence});
    case WireToolResultStatus.error:
      return jsonEncode({'error': part.error ?? 'The tool failed.'});
  }
}

List<WireMessage> withSupportedImages(
  List<WireMessage> history, {
  required Set<String> imageTypes,
}) => [
  for (final message in history)
    WireMessage(
      role: message.role,
      parts: [
        for (final part in message.parts)
          if (part is WireImagePart &&
              (message.role != WireRole.user ||
                  !imageTypes.contains(part.mimeType)))
            WireTextPart(unsentAttachmentText(part.label, part.mimeType))
          else
            part,
      ],
    ),
];

List<WireMessage> withToolResults(List<WireMessage> history) {
  final out = <WireMessage>[];
  var index = 0;
  while (index < history.length) {
    final message = history[index++];
    out.add(message);
    if (message.role != WireRole.assistant) continue;
    final calls = [
      for (final part in message.parts)
        if (part is WireToolCallPart) part,
    ];
    if (calls.isEmpty) continue;
    final next = index < history.length ? history[index] : null;
    final user = next != null && next.role == WireRole.user ? next : null;
    final answered = {
      if (user != null)
        for (final part in user.parts)
          if (part is WireToolResultPart) part.id,
    };
    final missing = [
      for (final call in calls)
        if (!answered.contains(call.id))
          WireToolResultPart(
            id: call.id,
            name: call.name,
            status: WireToolResultStatus.error,
            error: 'Not executed.',
          ),
    ];
    if (missing.isEmpty) continue;
    if (user != null) {
      index++;
      out.add(
        WireMessage(role: WireRole.user, parts: [...missing, ...user.parts]),
      );
    } else {
      out.add(WireMessage(role: WireRole.user, parts: missing));
    }
  }
  return out;
}

Map<String, dynamic>? decodeJsonObject(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

Map<String, dynamic>? objectAt(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is Map<String, dynamic> ? value : null;
}

List<Map<String, dynamic>> objectsAt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

String? stringAt(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

int? intAt(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is int ? value : null;
}
