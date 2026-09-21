import 'package:flow_ui/flow_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:stacflow/src/errors.dart';
import 'package:stacflow/src/tools/tool.dart';

/// Tokens a turn consumed, as the provider reported them.
@immutable
final class ChatUsage {
  const ChatUsage({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
  });

  final String model;
  final int inputTokens;
  final int outputTokens;
}

/// How the last turn went: time to the first token, total time, tokens.
@immutable
final class ChatTurnStats {
  const ChatTurnStats({required this.total, this.firstToken, this.usage});

  final Duration total;
  final Duration? firstToken;
  final ChatUsage? usage;
}

/// Everything a chat shows, as one immutable value per change.
@immutable
final class ChatState {
  ChatState({
    required this.model,
    required this.threadId,
    List<FlowMessageData> messages = const [],
    this.isGenerating = false,
    List<FlowAttachment> pendingAttachments = const [],
    this.attachmentError,
    Map<String, bool> feedback = const {},
    this.copiedCodePart,
    this.error,
    this.lastTurn,
    Map<String, ToolCallRecord> toolCalls = const {},
  }) : messages = List.unmodifiable(messages),
       pendingAttachments = List.unmodifiable(pendingAttachments),
       feedback = Map.unmodifiable(feedback),
       toolCalls = Map.unmodifiable(toolCalls);

  /// The model answering the next turn.
  final String model;

  /// The conversation's id; a new conversation gets a new one.
  final String threadId;

  /// The thread, oldest first.
  final List<FlowMessageData> messages;

  /// Whether a reply is being generated.
  final bool isGenerating;

  /// Attachments waiting to go with the next message.
  final List<FlowAttachment> pendingAttachments;

  /// The composer's banner text after a refused file, if any.
  final String? attachmentError;

  /// Thumbs per message id: true for up, false for down.
  final Map<String, bool> feedback;

  /// The code part whose copy confirmation is showing.
  final FlowCodePart? copiedCodePart;

  /// The last turn's failure, cleared by the next send.
  final ChatError? error;

  /// Timing and tokens of the last settled turn.
  final ChatTurnStats? lastTurn;

  /// Every tool call the thread made, by id: the records behind the tool
  /// cards and the history sent to the model.
  final Map<String, ToolCallRecord> toolCalls;

  /// A copy with the given fields replaced; the `clear` flags null a field.
  ChatState copyWith({
    String? model,
    String? threadId,
    List<FlowMessageData>? messages,
    bool? isGenerating,
    List<FlowAttachment>? pendingAttachments,
    String? attachmentError,
    Map<String, bool>? feedback,
    FlowCodePart? copiedCodePart,
    ChatError? error,
    ChatTurnStats? lastTurn,
    Map<String, ToolCallRecord>? toolCalls,
    bool clearAttachmentError = false,
    bool clearCopiedCodePart = false,
    bool clearError = false,
    bool clearLastTurn = false,
  }) => ChatState(
    model: model ?? this.model,
    threadId: threadId ?? this.threadId,
    messages: messages ?? this.messages,
    isGenerating: isGenerating ?? this.isGenerating,
    pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    attachmentError: clearAttachmentError
        ? null
        : attachmentError ?? this.attachmentError,
    feedback: feedback ?? this.feedback,
    copiedCodePart: clearCopiedCodePart
        ? null
        : copiedCodePart ?? this.copiedCodePart,
    error: clearError ? null : error ?? this.error,
    lastTurn: clearLastTurn ? null : lastTurn ?? this.lastTurn,
    toolCalls: toolCalls ?? this.toolCalls,
  );
}
