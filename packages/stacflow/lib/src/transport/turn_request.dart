import 'dart:typed_data';

import 'package:stacflow/src/providers/provider.dart';
import 'package:stacflow/src/tools/tool.dart';
import 'package:stacflow/src/transport/turn_ids.dart';

/// One turn's input: the conversation as providers see it, the agent
/// settings, the tools, the ids and the future that cancels it.
final class TurnRequest {
  const TurnRequest({
    required this.history,
    required this.agent,
    required this.ids,
    required this.abortTrigger,
    this.tools = const [],
    this.segment = 0,
  });

  /// Oldest first, ending with the user turn being answered.
  final List<WireMessage> history;
  final AgentConfig agent;
  final TurnIds ids;
  final Future<void> abortTrigger;

  /// The tools declared to the model; empty declares none.
  final List<Tool> tools;

  /// 0 for a turn's first request, one more for each continuation that
  /// carries tool results.
  final int segment;
}

/// Who wrote a wire message.
enum WireRole { user, assistant }

/// A piece of a wire message.
sealed class WirePart {
  const WirePart();
}

/// Plain text.
final class WireTextPart extends WirePart {
  const WireTextPart(this.text);

  final String text;
}

/// An inline image.
final class WireImagePart extends WirePart {
  const WireImagePart({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// A tool call the model made; only on assistant messages.
final class WireToolCallPart extends WirePart {
  const WireToolCallPart({
    required this.id,
    required this.name,
    required this.args,
  });

  /// The call as [record] holds it.
  factory WireToolCallPart.of(ToolCallRecord record) =>
      WireToolCallPart(id: record.id, name: record.name, args: record.args);

  final String id;
  final String name;
  final Map<String, dynamic> args;
}

/// How a tool call ended, as the model hears it.
enum WireToolResultStatus { ok, error, declined }

/// A tool's answer; only on user messages, ahead of any other part.
final class WireToolResultPart extends WirePart {
  const WireToolResultPart({
    required this.id,
    required this.name,
    required this.status,
    this.result,
    this.error,
  });

  /// The outcome [record] holds; a call that never ran reports it was
  /// cancelled.
  factory WireToolResultPart.of(ToolCallRecord record) => WireToolResultPart(
    id: record.id,
    name: record.name,
    status: switch (record.status) {
      ToolCallStatus.ok => WireToolResultStatus.ok,
      ToolCallStatus.declined => WireToolResultStatus.declined,
      _ => WireToolResultStatus.error,
    },
    result: record.result,
    error: record.status == ToolCallStatus.ok
        ? null
        : record.error?.message ?? ToolCallError.cancelled.message,
  );

  final String id;
  final String name;
  final WireToolResultStatus status;

  /// The JSON value the tool returned, when [status] is ok.
  final Object? result;

  /// The reason, when [status] is error or declined.
  final String? error;
}

/// One message as providers see it.
final class WireMessage {
  const WireMessage({required this.role, required this.parts});

  final WireRole role;
  final List<WirePart> parts;
}
