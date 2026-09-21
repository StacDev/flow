import 'package:flutter/foundation.dart';

import 'flow_message_part.dart';

/// Who authored a message.
enum FlowMessageRole { user, assistant, system }

/// Lifecycle of a message.
enum FlowMessageStatus {
  /// Waiting for the first content (renders a loading indicator).
  pending,

  /// Content is still arriving; the last text part animates its reveal.
  streaming,

  /// Settled; renders statically.
  complete,

  /// Failed. An assistant turn keeps its parts in normal ink and closes
  /// with an error card; a user bubble recolors to the error container.
  error,
}

/// One turn in a conversation.
///
/// A pure, immutable view model — hosts map their own transport/domain
/// models into this. Streaming is data, not streams: while a reply arrives,
/// rebuild with a [copyWith] carrying the grown text and
/// [FlowMessageStatus.streaming].
@immutable
class FlowMessageData {
  const FlowMessageData({
    required this.id,
    required this.role,
    this.parts = const [],
    this.status = FlowMessageStatus.complete,
    this.timestamp,
  });

  /// Convenience for a message with a single text part.
  FlowMessageData.text({
    required String id,
    required FlowMessageRole role,
    required String text,
    FlowMessageStatus status = FlowMessageStatus.complete,
    DateTime? timestamp,
  }) : this(
         id: id,
         role: role,
         parts: [FlowTextPart(text)],
         status: status,
         timestamp: timestamp,
       );

  /// Stable identity — drives list keys and reveal restarts on replacement.
  final String id;

  final FlowMessageRole role;

  /// Ordered content. Treat as immutable; create a new list to change it.
  final List<FlowMessagePart> parts;

  final FlowMessageStatus status;

  final DateTime? timestamp;

  FlowMessageData copyWith({
    String? id,
    FlowMessageRole? role,
    List<FlowMessagePart>? parts,
    FlowMessageStatus? status,
    DateTime? timestamp,
  }) {
    return FlowMessageData(
      id: id ?? this.id,
      role: role ?? this.role,
      parts: parts ?? this.parts,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
