import 'dart:async';
import 'dart:convert';

import 'package:stacflow/src/generated/sse_events.dart';
import 'package:stacflow/src/tools/tool.dart';
import 'package:stacflow/src/transport/turn_request.dart';
import 'package:stacflow/src/transport/turn_transport.dart';

/// Decides whether a gated call may run.
typedef ToolApprover = Future<bool> Function(ToolCallRecord record);

/// Hears every change to a call's record.
typedef ToolCallObserver = void Function(ToolCallRecord record);

/// Runs one turn with client-side tools: every segment's events as one
/// stream, handlers run between segments, results fed back until the
/// model answers or [maxRounds] segments have called tools.
Stream<SseEvent> runToolLoop({
  required TurnTransport transport,
  required TurnRequest request,
  required ToolApprover approve,
  required ToolCallObserver onCall,
  int maxRounds = 8,
}) => _ToolLoop(
  transport: transport,
  request: request,
  approve: approve,
  onCall: onCall,
  maxRounds: maxRounds,
).stream;

final class _ToolLoop {
  new({
    required this.transport,
    required this.request,
    required this.approve,
    required this.onCall,
    required this.maxRounds,
  }) : _tools = {for (final tool in request.tools) tool.name: tool} {
    _controller = StreamController<SseEvent>(
      onListen: _start,
      onCancel: _finish,
      sync: true,
    );
  }

  final TurnTransport transport;
  final TurnRequest request;
  final ToolApprover approve;
  final ToolCallObserver onCall;
  final int maxRounds;
  final Map<String, Tool> _tools;
  final Map<String, ToolCallRecord> _records = {};
  final Completer<void> _abort = Completer<void>();
  late final StreamController<SseEvent> _controller;
  StreamSubscription<SseEvent>? _subscription;
  _Segment? _segment;
  bool _finished = false;

  Stream<SseEvent> get stream => _controller.stream;

  void _start() {
    unawaited(request.abortTrigger.then((_) => _cancelHandlers()));
    _runSegment(request.history, 0);
  }

  void _runSegment(List<WireMessage> history, int index) {
    if (_finished) return;
    final segment = _Segment(index: index, history: history);
    _segment = segment;
    _subscription = transport
        .run(
          TurnRequest(
            history: history,
            agent: request.agent,
            ids: request.ids,
            abortTrigger: request.abortTrigger,
            tools: request.tools,
            segment: index,
          ),
        )
        .listen(
          (event) => _onEvent(segment, event),
          onError: (Object error, StackTrace stack) {
            if (_finished) return;
            _cancelHandlers();
            _controller.addError(error, stack);
            _finish();
          },
          onDone: () {
            if (!segment.done) _finish();
          },
          cancelOnError: true,
        );
  }

  void _onEvent(_Segment segment, SseEvent event) {
    if (_finished || !identical(_segment, segment)) return;
    switch (event) {
      case DeltaEvent(:final text):
        segment.text.write(text);
        _controller.add(event);
      case ToolCallStartEvent(:final toolCallId, :final toolName):
        segment.flushText();
        final record = ToolCallRecord(
          id: toolCallId,
          name: toolName,
          segment: segment.index,
        );
        _records[toolCallId] = record;
        segment.callIds.add(toolCallId);
        onCall(record);
        _controller.add(event);
      case ToolCallEndEvent(:final toolCallId, :final args):
        final record = _records[toolCallId];
        if (record == null) {
          _controller.add(event);
          return;
        }
        final updated = record.copyWith(args: args);
        _records[toolCallId] = updated;
        segment.parts.add(WireToolCallPart.of(updated));
        _controller.add(event);
        segment.dispatched.add(_dispatch(updated));
      case DoneEvent(:final status, :final seq, :final turnId):
        segment
          ..done = true
          ..flushText();
        switch (status) {
          case DoneEventStatus.complete:
          case DoneEventStatus.awaitingClientTools:
            if (segment.callIds.isEmpty) {
              _controller.add(event);
              _finish();
            } else {
              _controller.add(
                DoneEvent(
                  seq: seq,
                  status: DoneEventStatus.awaitingClientTools,
                  turnId: turnId,
                  pendingToolCallIds: List.of(segment.callIds),
                ),
              );
              unawaited(_continue(segment, seq));
            }
          case DoneEventStatus.error:
          case DoneEventStatus.cancelled:
            _cancelHandlers();
            _controller.add(event);
            _finish();
        }
      case _:
        _controller.add(event);
    }
  }

  Future<void> _continue(_Segment segment, int lastSeq) async {
    await Future.wait(segment.dispatched);
    if (_finished) return;
    if (_abort.isCompleted) {
      _controller.add(
        DoneEvent(
          seq: lastSeq + 1,
          status: DoneEventStatus.cancelled,
          turnId: request.ids.turnId,
        ),
      );
      _finish();
      return;
    }
    final exceeded = segment.callIds.any(
      (id) => _records[id]?.error?.code == ToolErrorCodes.roundsExceeded,
    );
    if (exceeded) {
      _controller
        ..add(
          ErrorEvent(
            seq: lastSeq + 1,
            failureClass: FailureClass.policy,
            code: ToolErrorCodes.roundsExceeded,
            message:
                'The model called tools in more than $maxRounds segments '
                'of one turn.',
            retryable: true,
          ),
        )
        ..add(
          DoneEvent(
            seq: lastSeq + 2,
            status: DoneEventStatus.error,
            turnId: request.ids.turnId,
          ),
        );
      _finish();
      return;
    }
    _runSegment([
      ...segment.history,
      WireMessage(role: WireRole.assistant, parts: segment.parts),
      WireMessage(
        role: WireRole.user,
        parts: [
          for (final id in segment.callIds)
            WireToolResultPart.of(_records[id]!),
        ],
      ),
    ], segment.index + 1);
  }

  Future<void> _dispatch(ToolCallRecord initial) async {
    var record = initial;
    void update(
      ToolCallStatus status, {
      Object? result,
      ToolCallError? error,
      DateTime? startedAt,
      DateTime? finishedAt,
    }) {
      record = record.copyWith(
        status: status,
        result: result,
        error: error,
        startedAt: startedAt,
        finishedAt: finishedAt,
      );
      _records[record.id] = record;
      onCall(record);
    }

    void settle(ToolCallStatus status, {Object? result, ToolCallError? error}) {
      update(status, result: result, error: error, finishedAt: DateTime.now());
    }

    final tool = _tools[record.name];
    if (tool == null) {
      settle(
        ToolCallStatus.error,
        error: ToolCallError(
          code: ToolErrorCodes.unknownTool,
          message: 'No tool named "${record.name}" is registered.',
        ),
      );
      return;
    }
    if (record.segment >= maxRounds) {
      settle(
        ToolCallStatus.error,
        error: const ToolCallError(
          code: ToolErrorCodes.roundsExceeded,
          message: 'Tool calls are not allowed in this segment.',
        ),
      );
      return;
    }
    if (tool.requiresConfirmation) {
      update(ToolCallStatus.awaitingApproval);
      var approved = false;
      try {
        approved = await Future.any([
          approve(record),
          _abort.future.then((_) => false),
        ]);
      } on Object {
        approved = false;
      }
      if (_abort.isCompleted) {
        settle(ToolCallStatus.error, error: ToolCallError.cancelled);
        return;
      }
      if (!approved) {
        settle(
          ToolCallStatus.declined,
          error: const ToolCallError(
            code: ToolErrorCodes.declined,
            message: 'The user declined this call.',
          ),
        );
        return;
      }
    }
    update(ToolCallStatus.running, startedAt: DateTime.now());
    final callAbort = Completer<void>();
    unawaited(
      _abort.future.then((_) {
        if (!callAbort.isCompleted) callAbort.complete();
      }),
    );
    final call = ToolCall(
      id: record.id,
      name: record.name,
      args: record.args,
      aborted: callAbort.future,
    );
    final done = Completer<Object?>();
    unawaited(
      Future.sync(() => tool.run(call)).then(
        (value) {
          if (!done.isCompleted) done.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!done.isCompleted) done.completeError(error, stack);
        },
      ),
    );
    unawaited(
      _abort.future.then((_) {
        if (!done.isCompleted) done.completeError(const _Aborted());
      }),
    );
    try {
      final value = await done.future.timeout(tool.timeout);
      settle(ToolCallStatus.ok, result: _normalize(value));
    } on TimeoutException {
      if (!callAbort.isCompleted) callAbort.complete();
      settle(
        ToolCallStatus.error,
        error: ToolCallError(
          code: ToolErrorCodes.timeout,
          message:
              'The tool did not finish within '
              '${tool.timeout.inSeconds} seconds.',
        ),
      );
    } on _Aborted {
      settle(ToolCallStatus.error, error: ToolCallError.cancelled);
    } on ToolException catch (error) {
      settle(
        ToolCallStatus.error,
        error: ToolCallError(
          code: ToolErrorCodes.toolError,
          message: error.message,
        ),
      );
    } on Object catch (error) {
      settle(
        ToolCallStatus.error,
        error: ToolCallError(
          code: ToolErrorCodes.toolFailed,
          message: error.toString(),
        ),
      );
    }
  }

  void _cancelHandlers() {
    if (!_abort.isCompleted) _abort.complete();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _cancelHandlers();
    unawaited(_subscription?.cancel());
    unawaited(_controller.close());
  }
}

Object? _normalize(Object? value) =>
    jsonDecode(jsonEncode(value, toEncodable: (object) => object.toString()));

final class _Segment {
  new({required this.index, required this.history});

  final int index;
  final List<WireMessage> history;
  final StringBuffer text = StringBuffer();
  final List<WirePart> parts = [];
  final List<Future<void>> dispatched = [];
  final List<String> callIds = [];
  bool done = false;

  void flushText() {
    if (text.isEmpty) return;
    parts.add(WireTextPart(text.toString()));
    text.clear();
  }
}

final class _Aborted implements Exception {
  const new();
}
