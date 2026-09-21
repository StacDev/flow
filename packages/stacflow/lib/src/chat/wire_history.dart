import 'dart:typed_data';

import 'package:flow_ui/flow_ui.dart';
import 'package:stacflow/src/tools/tool.dart';
import 'package:stacflow/src/transport/turn_request.dart';

List<WireMessage> wireHistoryOf(
  List<FlowMessageData> history, {
  Map<String, ToolCallRecord> toolCalls = const {},
}) {
  final messages = <WireMessage>[];
  for (final message in history) {
    if (message.role == FlowMessageRole.system ||
        message.status != FlowMessageStatus.complete) {
      continue;
    }
    if (message.role == FlowMessageRole.assistant) {
      _appendAssistant(messages, message.parts, toolCalls);
    } else {
      _append(messages, WireRole.user, _wirePartsOf(message.parts));
    }
  }
  assert(
    messages.isEmpty || messages.last.role == WireRole.user,
    'the wire history must end with a user turn',
  );
  return messages;
}

void _append(List<WireMessage> messages, WireRole role, List<WirePart> parts) {
  if (parts.isEmpty) return;
  if (messages.isEmpty && role == WireRole.assistant) return;
  if (messages.isNotEmpty && messages.last.role == role) {
    final previous = messages.removeLast();
    messages.add(WireMessage(role: role, parts: [...previous.parts, ...parts]));
  } else {
    messages.add(WireMessage(role: role, parts: parts));
  }
}

void _appendAssistant(
  List<WireMessage> messages,
  List<FlowMessagePart> parts,
  Map<String, ToolCallRecord> toolCalls,
) {
  var current = <WirePart>[];
  var calls = <ToolCallRecord>[];
  void flush() {
    if (messages.isNotEmpty) {
      _append(messages, WireRole.assistant, current);
      _append(messages, WireRole.user, [
        for (final record in calls) WireToolResultPart.of(record),
      ]);
    }
    current = [];
    calls = [];
  }

  for (var index = 0; index < parts.length; index++) {
    final part = parts[index];
    switch (part) {
      case FlowToolPart(:final id?):
        final record = toolCalls[id];
        if (record == null) continue;
        if (calls.isNotEmpty && record.segment != calls.last.segment) flush();
        current.add(WireToolCallPart.of(record));
        calls.add(record);
      case FlowToolPart():
      case FlowConfirmationPart():
      case FlowCustomPart():
      case FlowErrorPart():
      case FlowAttachmentPart():
        continue;
      case FlowTextPart():
      case FlowImagePart():
      case FlowCodePart():
        if (calls.isNotEmpty &&
            !_callFollowsInSegment(
              parts,
              index,
              calls.last.segment,
              toolCalls,
            )) {
          flush();
        }
        current.addAll(_wirePartsOf([part]));
    }
  }
  flush();
}

bool _callFollowsInSegment(
  List<FlowMessagePart> parts,
  int index,
  int segment,
  Map<String, ToolCallRecord> toolCalls,
) {
  for (var i = index + 1; i < parts.length; i++) {
    if (parts[i] case FlowToolPart(:final id?)) {
      final record = toolCalls[id];
      if (record != null) return record.segment == segment;
    }
  }
  return false;
}

List<WirePart> _wirePartsOf(List<FlowMessagePart> parts) {
  final out = <WirePart>[];
  for (final part in parts) {
    switch (part) {
      case FlowTextPart(:final text) when text.isNotEmpty:
        out.add(WireTextPart(text));
      case FlowAttachmentPart(:final attachments):
        for (final attachment in attachments) {
          final image = _imageOf(
            attachment.bytes,
            attachment.mimeType,
            attachment.label,
          );
          out.add(
            image ??
                WireTextPart(
                  unsentAttachmentText(attachment.label, attachment.mimeType),
                ),
          );
        }
      case FlowImagePart(:final bytes, :final mimeType, :final semanticLabel):
        final image = _imageOf(bytes, mimeType, semanticLabel);
        out.add(
          image ?? WireTextPart(unsentAttachmentText(semanticLabel, mimeType)),
        );
      case FlowCodePart(:final code, :final language):
        out.add(WireTextPart('```${language ?? ''}\n$code\n```'));
      case FlowTextPart():
      case FlowErrorPart():
      case FlowConfirmationPart():
      case FlowToolPart():
      case FlowCustomPart():
        break;
    }
  }
  return out;
}

WireImagePart? _imageOf(Uint8List? bytes, String? mimeType, String? label) {
  if (bytes == null || mimeType == null || !mimeType.startsWith('image/')) {
    return null;
  }
  return WireImagePart(bytes: bytes, mimeType: mimeType, label: label);
}
