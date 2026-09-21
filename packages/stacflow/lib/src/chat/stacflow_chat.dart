import 'dart:async';
import 'dart:convert';

import 'package:flow_ui/flow_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stacflow/src/chat/chat_state.dart';
import 'package:stacflow/src/chat/wire_history.dart';
import 'package:stacflow/src/errors.dart';
import 'package:stacflow/src/providers/provider.dart';
import 'package:stacflow/src/strings.dart';
import 'package:stacflow/src/tools/tool.dart';
import 'package:stacflow/src/tools/tool_loop.dart';
import 'package:stacflow/src/transport/sse_events.dart';
import 'package:stacflow/src/transport/turn_ids.dart';
import 'package:stacflow/src/transport/turn_request.dart';

/// A chat against one provider: it holds the thread, runs each turn with
/// the app's tools, and exposes everything as one [ChatState] per change.
final class StacFlowChat {
  StacFlowChat({
    required StacFlowProvider provider,
    this.agent = const AgentConfig(),
    this.tools = const [],
    this.maxToolRounds = 8,
    this.strings = const FlowStrings(),
    this.attachmentOptions = const FlowAttachmentOptions(),
    List<FlowMessageData> initialMessages = const [],
    IdGenerator? ids,
  }) : assert(
         tools.every((tool) => Tool.isValidName(tool.name)),
         'tool names use letters, digits, underscores and dashes, at most '
         '64 characters',
       ),
       assert(
         tools.every((tool) => tool.description.isNotEmpty),
         'every tool needs a description',
       ),
       assert(
         tools.map((tool) => tool.name).toSet().length == tools.length,
         'tool names must be unique',
       ),
       _provider = provider,
       _ids = ids ?? IdGenerator(),
       _toolsByName = {for (final tool in tools) tool.name: tool} {
    _state = ValueNotifier(
      ChatState(
        model: provider.model,
        threadId: _ids.thread(),
        messages: initialMessages,
      ),
    );
  }

  /// The type of the custom part that follows every tool card; its data
  /// is the call's [ToolCallRecord].
  static const String toolPartType = 'stacflow.tool';

  /// The instructions and sampling settings every turn carries.
  final AgentConfig agent;

  /// The actions the model may take.
  final List<Tool> tools;

  /// How many segments of one turn may call tools before the turn fails.
  final int maxToolRounds;

  /// The words the chat shows.
  final FlowStrings strings;

  /// What the composer accepts as an attachment.
  final FlowAttachmentOptions attachmentOptions;

  final IdGenerator _ids;
  final Map<String, Tool> _toolsByName;
  late final ValueNotifier<ChatState> _state;
  StacFlowProvider _provider;
  _Turn? _turn;
  Timer? _copiedReset;
  bool _disposed = false;

  /// The state, re-emitted whole on every change.
  ValueListenable<ChatState> get state => _state;

  /// The provider answering the next turn.
  StacFlowProvider get provider => _provider;

  /// The thread, oldest first.
  List<FlowMessageData> get messages => _state.value.messages;

  /// Whether a reply is being generated.
  bool get isGenerating => _state.value.isGenerating;

  /// Attachments waiting to go with the next message.
  List<FlowAttachment> get pendingAttachments =>
      _state.value.pendingAttachments;

  /// Sends [text] with the pending attachments and resolves when the reply
  /// settles. Does nothing while generating or with nothing to send.
  Future<void> send(String text) {
    final pending = pendingAttachments;
    if (isGenerating || (text.isEmpty && pending.isEmpty)) {
      return Future.value();
    }
    final message = FlowMessageData(
      id: _ids.message(),
      role: FlowMessageRole.user,
      timestamp: DateTime.now(),
      parts: [
        if (pending.isNotEmpty) FlowAttachmentPart(List.of(pending)),
        if (text.isNotEmpty) FlowTextPart(text),
      ],
    );
    _update(
      (s) => s.copyWith(
        messages: [...s.messages, message],
        pendingAttachments: const [],
        clearAttachmentError: true,
        clearError: true,
      ),
    );
    return _generate();
  }

  /// Aborts the reply being generated, keeping any text that arrived.
  void stop() {
    final turn = _turn;
    if (turn == null) return;
    turn.abort.complete();
    unawaited(turn.cancel());
    _finishCancelled(turn);
  }

  /// Drops the failed reply [message] and asks again.
  Future<void> retry(FlowMessageData message) {
    if (isGenerating) return Future.value();
    _update(
      (s) => _withMessages(s, [
        for (final m in s.messages)
          if (m.id != message.id) m,
      ]),
    );
    return _generate();
  }

  /// Drops the latest reply and asks again.
  Future<void> regenerate() {
    if (isGenerating || messages.isEmpty) return Future.value();
    final last = messages.last;
    if (last.role == FlowMessageRole.assistant) {
      _update(
        (s) => _withMessages(s, s.messages.sublist(0, s.messages.length - 1)),
      );
    }
    return _generate();
  }

  /// Replaces the user turn [messageId] and everything after it with
  /// [text], keeping that turn's attachments, and asks again.
  Future<void> editAndResend(String messageId, String text) {
    if (isGenerating) return Future.value();
    final index = messages.indexWhere(
      (m) => m.id == messageId && m.role == FlowMessageRole.user,
    );
    if (index == -1) return Future.value();
    final attachments = [
      for (final part in messages[index].parts)
        if (part is FlowAttachmentPart) ...part.attachments,
    ];
    _update(
      (s) => _withMessages(
        s,
        s.messages.sublist(0, index),
      ).copyWith(pendingAttachments: attachments),
    );
    return send(text);
  }

  /// Answers the confirmation card of the tool call [toolCallId]; ignored
  /// unless that call is waiting.
  void respondToToolCall(String toolCallId, {required bool approved}) {
    final turn = _turn;
    final block = turn?.tool(toolCallId);
    final approval = block?.approval;
    if (turn == null ||
        block == null ||
        approval == null ||
        approval.isCompleted) {
      return;
    }
    block.confirmation = approved
        ? FlowConfirmationStatus.approved
        : FlowConfirmationStatus.rejected;
    approval.complete(approved);
    _render(turn);
  }

  /// The flow_ui form of [respondToToolCall]: answers the tool call whose
  /// card [part] sits under in [message].
  void respondToConfirmation(
    FlowMessageData message,
    FlowConfirmationPart part, {
    required bool approved,
  }) {
    final index = message.parts.indexWhere((p) => identical(p, part));
    for (var i = index - 1; i >= 0; i--) {
      if (message.parts[i] case FlowToolPart(:final id?)) {
        respondToToolCall(id, approved: approved);
        return;
      }
    }
  }

  /// Adds picked, dropped or pasted files to the next message.
  void addAttachments(List<FlowAttachment> attachments) {
    if (attachments.isEmpty) return;
    _update(
      (s) => s.copyWith(
        pendingAttachments: [...s.pendingAttachments, ...attachments],
        clearAttachmentError: true,
      ),
    );
  }

  /// Removes a pending attachment by id.
  void removeAttachment(String id) {
    _update(
      (s) => s.copyWith(
        pendingAttachments: [
          for (final a in s.pendingAttachments)
            if (a.id != id) a,
        ],
      ),
    );
  }

  /// Records a refused file for the composer's banner.
  void rejectAttachment(String name, FlowAttachmentRejection reason) {
    _update(
      (s) =>
          s.copyWith(attachmentError: strings.attachmentRejected(name, reason)),
    );
  }

  /// Clears the composer's banner.
  void dismissAttachmentError() {
    _update((s) => s.copyWith(clearAttachmentError: true));
  }

  /// Thumbs a reply up or down; the same thumb again clears it.
  void setFeedback(String messageId, {required bool positive}) {
    _update((s) {
      final feedback = Map<String, bool>.of(s.feedback);
      if (feedback[messageId] == positive) {
        feedback.remove(messageId);
      } else {
        feedback[messageId] = positive;
      }
      return s.copyWith(feedback: feedback);
    });
  }

  /// Copies the message's text to the clipboard.
  Future<void> copy(FlowMessageData message) {
    final text = [
      for (final part in message.parts)
        if (part is FlowTextPart) part.text,
    ].join('\n');
    return Clipboard.setData(ClipboardData(text: text));
  }

  /// Copies a code block and shows its copied state for two seconds.
  Future<void> copyCode(FlowCodePart part) {
    _copiedReset?.cancel();
    _update((s) => s.copyWith(copiedCodePart: part));
    _copiedReset = Timer(const Duration(seconds: 2), () {
      _copiedReset = null;
      if (_disposed) return;
      if (identical(_state.value.copiedCodePart, part)) {
        _update((s) => s.copyWith(clearCopiedCodePart: true));
      }
    });
    return Clipboard.setData(ClipboardData(text: part.code));
  }

  /// Answers the next turns with [modelId]; the turn in flight keeps its
  /// model.
  void selectModel(String modelId) {
    _provider = _provider.withModel(modelId);
    _update((s) => s.copyWith(model: modelId));
  }

  /// Starts an empty thread with a new id.
  void newConversation() {
    stop();
    _update((s) => ChatState(model: s.model, threadId: _ids.thread()));
  }

  /// Releases the chat; the reply in flight is aborted.
  void dispose() {
    if (_disposed) return;
    final turn = _turn;
    if (turn != null) {
      turn.abort.complete();
      unawaited(turn.cancel());
      _settleToolCalls(turn);
      turn.completer.complete();
    }
    _turn = null;
    _copiedReset?.cancel();
    _disposed = true;
    _state.dispose();
  }

  Future<void> _generate() {
    final history = wireHistoryOf(messages, toolCalls: _state.value.toolCalls);
    final ids = TurnIds.generate(threadId: _state.value.threadId, ids: _ids);
    final placeholder = FlowMessageData(
      id: ids.messageId,
      role: FlowMessageRole.assistant,
      status: FlowMessageStatus.pending,
      timestamp: DateTime.now(),
    );
    _update(
      (s) => s.copyWith(
        messages: [...s.messages, placeholder],
        isGenerating: true,
        clearError: true,
      ),
    );
    final turn = _Turn(ids: ids);
    _turn = turn;
    turn.subscription =
        runToolLoop(
          transport: _provider,
          request: TurnRequest(
            history: history,
            agent: agent,
            ids: ids,
            abortTrigger: turn.abort.future,
            tools: tools,
          ),
          approve: (record) => _approve(turn, record),
          onCall: (record) => _onToolCall(turn, record),
          maxRounds: maxToolRounds,
        ).listen(
          (event) => _onEvent(turn, event),
          onError: (Object error) => _onStreamError(turn, error),
          onDone: () => _onStreamDone(turn),
          cancelOnError: true,
        );
    return turn.completer.future;
  }

  void _onEvent(_Turn turn, SseEvent event) {
    if (!identical(_turn, turn)) return;
    switch (event) {
      case StartEvent(:final segment):
        if (segment > 0) turn.breakText();
      case DeltaEvent(:final text):
        turn
          ..write(text)
          ..firstDeltaAt ??= DateTime.now();
        _render(turn);
      case ToolCallDeltaEvent(:final toolCallId, :final argsDelta):
        final block = turn.tool(toolCallId);
        if (block != null) {
          block.argsBuffer.write(argsDelta);
          _render(turn);
        }
      case UsageEvent(:final model, :final inputTokens, :final outputTokens):
        final previous = turn.usage;
        turn.usage = ChatUsage(
          model: model,
          inputTokens: (previous?.inputTokens ?? 0) + inputTokens,
          outputTokens: (previous?.outputTokens ?? 0) + outputTokens,
        );
      case ErrorEvent():
        _fail(turn, ChatError.fromEvent(event, strings));
      case DoneEvent(:final status):
        switch (status) {
          case DoneEventStatus.complete:
            _finishComplete(turn);
          case DoneEventStatus.awaitingClientTools:
            break;
          case DoneEventStatus.error:
            if (turn.error == null) {
              _fail(
                turn,
                ChatError.runtime(code: 'internal', strings: strings),
              );
            }
            _settle(turn);
          case DoneEventStatus.cancelled:
            _finishCancelled(turn);
        }
      case ToolCallStartEvent():
      case ToolCallEndEvent():
      case SseUnknownEvent():
        break;
    }
  }

  void _onToolCall(_Turn turn, ToolCallRecord record) {
    if (!identical(_turn, turn)) return;
    _update((s) => s.copyWith(toolCalls: {...s.toolCalls, record.id: record}));
    final block = turn.tool(record.id) ?? turn.addTool(record.id);
    if (record.status != ToolCallStatus.pending && block.input == null) {
      block
        ..input = _pretty(record.args)
        ..detail = _toolsByName[record.name]?.detail?.call(record.args);
    }
    if (record.status == ToolCallStatus.ok) {
      final result = record.result;
      final structured = result is Map || result is List;
      block
        ..output = structured ? _pretty(result) : result?.toString()
        ..outputLanguage = structured ? 'json' : null;
    }
    _render(turn);
  }

  Future<bool> _approve(_Turn turn, ToolCallRecord record) {
    if (!identical(_turn, turn)) return Future.value(false);
    final block = turn.tool(record.id) ?? turn.addTool(record.id);
    final tool = _toolsByName[record.name];
    final approval = Completer<bool>();
    block
      ..confirmation = FlowConfirmationStatus.pending
      ..confirmationMessage =
          tool?.confirmation?.call(record.args) ??
          strings.approvalMessage(tool?.label ?? record.name)
      ..approval = approval;
    _render(turn);
    return approval.future;
  }

  void _onStreamError(_Turn turn, Object error) {
    if (!identical(_turn, turn)) return;
    _fail(
      turn,
      ChatError.runtime(
        code: 'network',
        strings: strings,
        detail: error is ProviderTransportException ? error.message : null,
      ),
    );
    _settle(turn);
  }

  void _onStreamDone(_Turn turn) {
    if (!identical(_turn, turn) || turn.settled) return;
    _fail(turn, ChatError.runtime(code: 'stream_closed', strings: strings));
    _settle(turn);
  }

  void _fail(_Turn turn, ChatError error) {
    turn.error = error;
    _settleToolCalls(turn);
    _replace(
      turn.ids.messageId,
      status: FlowMessageStatus.error,
      parts: [
        ..._partsOf(turn),
        FlowErrorPart(message: error.message, retryable: error.retryable),
      ],
    );
  }

  void _finishComplete(_Turn turn) {
    if (turn.hasParts) {
      _render(turn, status: FlowMessageStatus.complete);
    } else {
      _remove(turn.ids.messageId);
    }
    _settle(turn);
  }

  void _finishCancelled(_Turn turn) {
    _settleToolCalls(turn);
    _finishComplete(turn);
  }

  void _settleToolCalls(_Turn turn) {
    final now = DateTime.now();
    for (final block in turn.blocks) {
      if (block is! _ToolBlock) continue;
      final record = _state.value.toolCalls[block.id];
      if (record != null && !record.isSettled) {
        final settled = record.copyWith(
          status: ToolCallStatus.error,
          error: ToolCallError.cancelled,
          finishedAt: now,
        );
        _update(
          (s) => s.copyWith(toolCalls: {...s.toolCalls, settled.id: settled}),
        );
      }
      if (block.confirmation == FlowConfirmationStatus.pending) {
        block.confirmation = FlowConfirmationStatus.rejected;
      }
      final approval = block.approval;
      if (approval != null && !approval.isCompleted) approval.complete(false);
    }
  }

  void _settle(_Turn turn) {
    if (turn.settled) return;
    turn.settled = true;
    if (identical(_turn, turn)) _turn = null;
    final now = DateTime.now();
    final firstDeltaAt = turn.firstDeltaAt;
    _update(
      (s) => s.copyWith(
        isGenerating: false,
        error: turn.error,
        lastTurn: ChatTurnStats(
          total: now.difference(turn.startedAt),
          firstToken: firstDeltaAt?.difference(turn.startedAt),
          usage: turn.usage,
        ),
      ),
    );
    turn.completer.complete();
  }

  void _render(
    _Turn turn, {
    FlowMessageStatus status = FlowMessageStatus.streaming,
  }) {
    _replace(
      turn.ids.messageId,
      parts: _partsOf(turn),
      status: turn.hasParts ? status : FlowMessageStatus.pending,
    );
  }

  List<FlowMessagePart> _partsOf(_Turn turn) {
    final toolCalls = _state.value.toolCalls;
    final parts = <FlowMessagePart>[];
    for (final block in turn.blocks) {
      switch (block) {
        case _TextBlock(:final text):
          if (text.isNotEmpty) parts.add(FlowTextPart(text.toString()));
        case _ToolBlock():
          final record = toolCalls[block.id];
          if (record == null) continue;
          parts.add(
            FlowToolPart(
              id: record.id,
              name: record.name,
              title: _toolsByName[record.name]?.label,
              detail: block.detail,
              input: record.status == ToolCallStatus.pending
                  ? (block.argsBuffer.isEmpty
                        ? null
                        : block.argsBuffer.toString())
                  : block.input,
              output: block.output,
              outputLanguage: block.outputLanguage,
              status: switch (record.status) {
                ToolCallStatus.pending ||
                ToolCallStatus.awaitingApproval => FlowToolStatus.pending,
                ToolCallStatus.running => FlowToolStatus.running,
                ToolCallStatus.ok => FlowToolStatus.complete,
                ToolCallStatus.error ||
                ToolCallStatus.declined => FlowToolStatus.error,
              },
              errorMessage: switch (record.status) {
                ToolCallStatus.error => strings.toolError(
                  record.error?.code ?? '',
                  detail: record.error?.message,
                ),
                ToolCallStatus.declined => strings.toolDeclined,
                _ => null,
              },
            ),
          );
          if (block.confirmation case final confirmation?) {
            parts.add(
              FlowConfirmationPart(
                title: strings.approvalTitle,
                message: block.confirmationMessage,
                status: confirmation,
              ),
            );
          }
          parts.add(FlowCustomPart(type: toolPartType, data: record));
      }
    }
    return parts;
  }

  ChatState _withMessages(ChatState s, List<FlowMessageData> messages) {
    final kept = <String>{
      for (final message in messages)
        for (final part in message.parts)
          if (part case FlowToolPart(:final id?)) id,
    };
    return s.copyWith(
      messages: messages,
      toolCalls: {
        for (final entry in s.toolCalls.entries)
          if (kept.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  void _replace(
    String id, {
    List<FlowMessagePart>? parts,
    FlowMessageStatus? status,
  }) {
    _update(
      (s) => s.copyWith(
        messages: [
          for (final m in s.messages)
            if (m.id == id) m.copyWith(parts: parts, status: status) else m,
        ],
      ),
    );
  }

  void _remove(String id) {
    _update(
      (s) => s.copyWith(
        messages: [
          for (final m in s.messages)
            if (m.id != id) m,
        ],
      ),
    );
  }

  void _update(ChatState Function(ChatState state) change) {
    if (_disposed) return;
    _state.value = change(_state.value);
  }
}

String _pretty(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

final class _Turn {
  _Turn({required this.ids});

  final TurnIds ids;
  final Completer<void> abort = Completer<void>();
  final Completer<void> completer = Completer<void>();
  final DateTime startedAt = DateTime.now();
  final List<_Block> blocks = [];
  StreamSubscription<SseEvent>? subscription;
  DateTime? firstDeltaAt;
  ChatUsage? usage;
  ChatError? error;
  bool settled = false;

  bool get hasParts => blocks.any(
    (block) => switch (block) {
      _TextBlock(:final text) => text.isNotEmpty,
      _ToolBlock() => true,
    },
  );

  void write(String delta) {
    final last = blocks.isEmpty ? null : blocks.last;
    if (last is _TextBlock) {
      last.text.write(delta);
    } else {
      blocks.add(_TextBlock()..text.write(delta));
    }
  }

  void breakText() {
    final last = blocks.isEmpty ? null : blocks.last;
    if (last is _TextBlock && last.text.isNotEmpty) blocks.add(_TextBlock());
  }

  _ToolBlock? tool(String id) {
    for (final block in blocks) {
      if (block is _ToolBlock && block.id == id) return block;
    }
    return null;
  }

  _ToolBlock addTool(String id) {
    final block = _ToolBlock(id);
    blocks.add(block);
    return block;
  }

  Future<void> cancel() => subscription?.cancel() ?? Future.value();
}

sealed class _Block;

final class _TextBlock extends _Block {
  final StringBuffer text = StringBuffer();
}

final class _ToolBlock extends _Block {
  _ToolBlock(this.id);

  final String id;
  final StringBuffer argsBuffer = StringBuffer();
  String? input;
  String? detail;
  String? output;
  String? outputLanguage;
  FlowConfirmationStatus? confirmation;
  String? confirmationMessage;
  Completer<bool>? approval;
}
