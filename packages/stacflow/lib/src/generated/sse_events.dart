// GENERATED CODE - DO NOT EDIT.
// Source: contracts/ - regenerate with `dart run tool/contracts_gen.dart`.
// coverage:ignore-file

/// The StacFlow SSE protocol v1 (contracts/sse-events.schema.json).
///
/// `SseEvent.decode` NEVER throws: unknown event names and payloads that
/// fail to decode become [SseUnknownEvent] - the additive-evolution
/// compatibility mechanism. Local-mode provider adapters emit this same
/// union, so cloud and local modes share one event grammar.
library;

sealed class SseEvent {
  const SseEvent();
  int get seq;

  /// Decodes one SSE frame. Never throws.
  static SseEvent decode(String event, Map<String, dynamic> data) {
    try {
      return switch (event) {
        'start' => StartEvent.fromJson(data),
        'delta' => DeltaEvent.fromJson(data),
        'tool_call' => ToolCallEvent.fromJson(data),
        'ui_payload' => UiPayloadEvent.fromJson(data),
        'usage' => UsageEvent.fromJson(data),
        'error' => ErrorEvent.fromJson(data),
        'done' => DoneEvent.fromJson(data),
        _ => SseUnknownEvent(event, data),
      };
    } on Object {
      return SseUnknownEvent(event, data);
    }
  }
}

/// Passthrough for event names or shapes this build does not know.
final class SseUnknownEvent extends SseEvent {
  const SseUnknownEvent(this.event, this.data);
  final String event;
  final Map<String, dynamic> data;
  @override
  int get seq => data['seq'] is int ? data['seq'] as int : -1;
}

sealed class ToolCallEvent extends SseEvent {
  const ToolCallEvent();
  String get toolCallId;

  factory ToolCallEvent.fromJson(Map<String, dynamic> json) =>
      switch (json['phase'] as String) {
        'start' => ToolCallStartEvent.fromJson(json),
        'delta' => ToolCallDeltaEvent.fromJson(json),
        'end' => ToolCallEndEvent.fromJson(json),
        final other => throw FormatException('unknown phase: $other'),
      };
}

enum FailureClass {
  provider('provider'),
  developerApi('developer_api'),
  gateway('gateway'),
  policy('policy'),
  timeout('timeout'),
  cancelled('cancelled');

  const FailureClass(this.wire);
  final String wire;
  static FailureClass fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum ToolCallStartEventExecutor {
  client('client'),
  server('server');

  const ToolCallStartEventExecutor(this.wire);
  final String wire;
  static ToolCallStartEventExecutor fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum ToolCallStartEventPermissionClass {
  read('read'),
  write('write'),
  destructive('destructive');

  const ToolCallStartEventPermissionClass(this.wire);
  final String wire;
  static ToolCallStartEventPermissionClass fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

enum DoneEventStatus {
  complete('complete'),
  awaitingClientTools('awaiting_client_tools'),
  error('error'),
  cancelled('cancelled');

  const DoneEventStatus(this.wire);
  final String wire;
  static DoneEventStatus fromWire(String wire) =>
      values.firstWhere((v) => v.wire == wire);
}

final class Upstream {
  const Upstream({this.provider, this.status, this.code});

  factory Upstream.fromJson(Map<String, dynamic> json) => Upstream(
    provider: json['provider'] as String?,
    status: json['status'] as int?,
    code: json['code'] as String?,
  );

  final String? provider;
  final int? status;
  final String? code;

  Map<String, dynamic> toJson() => <String, dynamic>{}
    ..addAll(
      provider == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'provider': provider},
    )
    ..addAll(
      status == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'status': status},
    )
    ..addAll(
      code == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'code': code},
    );
}

final class StartEvent extends SseEvent {
  const StartEvent({
    required this.seq,
    required this.turnId,
    required this.segment,
    required this.messageId,
    required this.threadId,
    required this.model,
    required this.agentVersionId,
  });

  factory StartEvent.fromJson(Map<String, dynamic> json) => StartEvent(
    seq: json['seq'] as int,
    turnId: json['turn_id'] as String,
    segment: json['segment'] as int,
    messageId: json['message_id'] as String,
    threadId: json['thread_id'] as String,
    model: json['model'] as String,
    agentVersionId: json['agent_version_id'] as String,
  );

  final int seq;
  final String turnId;
  final int segment;
  final String messageId;
  final String threadId;
  final String model;
  final String agentVersionId;
  int get protocol => 1;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'protocol': 1,
    'seq': seq,
    'turn_id': turnId,
    'segment': segment,
    'message_id': messageId,
    'thread_id': threadId,
    'model': model,
    'agent_version_id': agentVersionId,
  };
}

final class DeltaEvent extends SseEvent {
  const DeltaEvent({required this.seq, required this.text});

  factory DeltaEvent.fromJson(Map<String, dynamic> json) =>
      DeltaEvent(seq: json['seq'] as int, text: json['text'] as String);

  final int seq;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{'seq': seq, 'text': text};
}

final class ToolCallStartEvent extends ToolCallEvent {
  const ToolCallStartEvent({
    required this.seq,
    required this.toolCallId,
    required this.toolName,
    required this.executor,
    required this.permissionClass,
  });

  factory ToolCallStartEvent.fromJson(Map<String, dynamic> json) =>
      ToolCallStartEvent(
        seq: json['seq'] as int,
        toolCallId: json['tool_call_id'] as String,
        toolName: json['tool_name'] as String,
        executor: ToolCallStartEventExecutor.fromWire(
          json['executor'] as String,
        ),
        permissionClass: ToolCallStartEventPermissionClass.fromWire(
          json['permission_class'] as String,
        ),
      );

  final int seq;
  final String toolCallId;
  final String toolName;
  final ToolCallStartEventExecutor executor;
  final ToolCallStartEventPermissionClass permissionClass;
  String get phase => 'start';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'phase': 'start',
    'seq': seq,
    'tool_call_id': toolCallId,
    'tool_name': toolName,
    'executor': executor.wire,
    'permission_class': permissionClass.wire,
  };
}

final class ToolCallDeltaEvent extends ToolCallEvent {
  const ToolCallDeltaEvent({
    required this.seq,
    required this.toolCallId,
    required this.argsDelta,
  });

  factory ToolCallDeltaEvent.fromJson(Map<String, dynamic> json) =>
      ToolCallDeltaEvent(
        seq: json['seq'] as int,
        toolCallId: json['tool_call_id'] as String,
        argsDelta: json['args_delta'] as String,
      );

  final int seq;
  final String toolCallId;
  final String argsDelta;
  String get phase => 'delta';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'phase': 'delta',
    'seq': seq,
    'tool_call_id': toolCallId,
    'args_delta': argsDelta,
  };
}

final class ToolCallEndEvent extends ToolCallEvent {
  const ToolCallEndEvent({
    required this.seq,
    required this.toolCallId,
    required this.args,
  });

  factory ToolCallEndEvent.fromJson(Map<String, dynamic> json) =>
      ToolCallEndEvent(
        seq: json['seq'] as int,
        toolCallId: json['tool_call_id'] as String,
        args: (json['args'] as Map).cast<String, dynamic>(),
      );

  final int seq;
  final String toolCallId;
  final Map<String, dynamic> args;
  String get phase => 'end';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'phase': 'end',
    'seq': seq,
    'tool_call_id': toolCallId,
    'args': args,
  };
}

final class UiPayloadEvent extends SseEvent {
  const UiPayloadEvent({
    required this.seq,
    required this.surfaceId,
    required this.a2ui,
  });

  factory UiPayloadEvent.fromJson(Map<String, dynamic> json) => UiPayloadEvent(
    seq: json['seq'] as int,
    surfaceId: json['surface_id'] as String,
    a2ui: (json['a2ui'] as Map).cast<String, dynamic>(),
  );

  final int seq;
  final String surfaceId;
  final Map<String, dynamic> a2ui;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'seq': seq,
    'surface_id': surfaceId,
    'a2ui': a2ui,
  };
}

final class UsageEvent extends SseEvent {
  const UsageEvent({
    required this.seq,
    required this.providerCall,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
  });

  factory UsageEvent.fromJson(Map<String, dynamic> json) => UsageEvent(
    seq: json['seq'] as int,
    providerCall: json['provider_call'] as int,
    model: json['model'] as String,
    inputTokens: json['input_tokens'] as int,
    outputTokens: json['output_tokens'] as int,
  );

  final int seq;
  final int providerCall;
  final String model;
  final int inputTokens;
  final int outputTokens;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'seq': seq,
    'provider_call': providerCall,
    'model': model,
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
  };
}

final class ErrorEvent extends SseEvent {
  const ErrorEvent({
    required this.seq,
    required this.failureClass,
    required this.code,
    required this.message,
    required this.retryable,
    this.upstream,
  });

  factory ErrorEvent.fromJson(Map<String, dynamic> json) => ErrorEvent(
    seq: json['seq'] as int,
    failureClass: FailureClass.fromWire(json['failure_class'] as String),
    code: json['code'] as String,
    message: json['message'] as String,
    retryable: json['retryable'] as bool,
    upstream: json['upstream'] == null
        ? null
        : Upstream.fromJson((json['upstream'] as Map).cast<String, dynamic>()),
  );

  final int seq;
  final FailureClass failureClass;
  final String code;
  final String message;
  final bool retryable;
  final Upstream? upstream;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{
        'seq': seq,
        'failure_class': failureClass.wire,
        'code': code,
        'message': message,
        'retryable': retryable,
      }..addAll(
        upstream == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'upstream': upstream!.toJson()},
      );
}

final class DoneEvent extends SseEvent {
  const DoneEvent({
    required this.seq,
    required this.status,
    required this.turnId,
    this.pendingToolCallIds,
  });

  factory DoneEvent.fromJson(Map<String, dynamic> json) => DoneEvent(
    seq: json['seq'] as int,
    status: DoneEventStatus.fromWire(json['status'] as String),
    turnId: json['turn_id'] as String,
    pendingToolCallIds: json['pending_tool_call_ids'] == null
        ? null
        : List<String>.from(json['pending_tool_call_ids'] as List),
  );

  final int seq;
  final DoneEventStatus status;
  final String turnId;
  final List<String>? pendingToolCallIds;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'seq': seq, 'status': status.wire, 'turn_id': turnId}
        ..addAll(
          pendingToolCallIds == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'pending_tool_call_ids': pendingToolCallIds},
        );
}
