import 'dart:async';

/// What a tool may do. Read runs silently, write runs unless the tool
/// asks to confirm, destructive always asks first.
enum ToolPermission { read, write, destructive }

/// An action the app lets the model take: the model reads [description]
/// and [parameters], the SDK runs [run] with the arguments it chose.
final class Tool {
  const new({
    required this.name,
    required this.description,
    required this.run,
    this.parameters = emptyParameters,
    this.permission = ToolPermission.write,
    this.confirm = false,
    this.label,
    this.detail,
    this.confirmation,
    this.timeout = const Duration(seconds: 30),
  }) : assert(
         permission != ToolPermission.read || !confirm,
         'read tools run without asking',
       );

  /// A parameter schema for a tool that takes nothing.
  static const Map<String, dynamic> emptyParameters = {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  /// Letters, digits, underscores and dashes, at most 64 characters.
  static bool isValidName(String name) => _namePattern.hasMatch(name);

  static final RegExp _namePattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// The name the model calls; unique within a chat.
  final String name;

  /// What the tool does and when to use it, written for the model.
  final String description;

  /// A JSON Schema object describing the arguments.
  final Map<String, dynamic> parameters;

  final ToolPermission permission;

  /// Asks the user before running a write tool.
  final bool confirm;

  /// The card's title; the name shows when null.
  final String? label;

  /// The card's chip for a call's arguments, e.g. the file being deleted.
  final String? Function(Map<String, dynamic> args)? detail;

  /// The confirmation card's question for a call's arguments.
  final String Function(Map<String, dynamic> args)? confirmation;

  /// Runs the call and returns a JSON-encodable result; throw a
  /// [ToolException] to report a failure in your own words.
  final FutureOr<Object?> Function(ToolCall call) run;

  /// How long a call may run before it fails.
  final Duration timeout;

  /// Whether a call waits for the user's approval before it runs.
  bool get requiresConfirmation => switch (permission) {
    ToolPermission.read => false,
    ToolPermission.write => confirm,
    ToolPermission.destructive => true,
  };
}

/// One call of a tool, as its handler receives it.
final class ToolCall {
  new({
    required this.id,
    required this.name,
    required this.args,
    required this.aborted,
  }) {
    unawaited(aborted.then((_) => _isAborted = true));
  }

  final String id;
  final String name;
  final Map<String, dynamic> args;

  /// Completes when the call is stopped, times out or the turn ends.
  final Future<void> aborted;

  bool _isAborted = false;

  /// Whether [aborted] has completed.
  bool get isAborted => _isAborted;
}

/// A failure a tool reports in its own words; the message reaches the
/// card and the model.
class ToolException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'ToolException: $message';
}

/// Where a tool call stands.
enum ToolCallStatus { pending, awaitingApproval, running, ok, error, declined }

/// The codes a [ToolCallError] carries.
abstract final class ToolErrorCodes {
  static const String declined = 'declined';
  static const String cancelled = 'cancelled';
  static const String timeout = 'timeout';
  static const String unknownTool = 'unknown_tool';
  static const String toolError = 'tool_error';
  static const String toolFailed = 'tool_failed';
  static const String roundsExceeded = 'tool_rounds_exceeded';
}

/// Why a tool call did not return a result.
final class ToolCallError {
  const new({required this.code, required this.message});

  static const ToolCallError cancelled = ToolCallError(
    code: ToolErrorCodes.cancelled,
    message: 'The call was cancelled.',
  );

  final String code;

  /// Model-facing English; the card shows the SDK's own wording.
  final String message;
}

/// One tool call the thread made: its arguments, status and outcome.
final class ToolCallRecord {
  const new({
    required this.id,
    required this.name,
    required this.segment,
    this.args = const {},
    this.status = ToolCallStatus.pending,
    this.result,
    this.error,
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String name;

  /// The turn segment that made the call.
  final int segment;

  /// Empty until the model finishes streaming them.
  final Map<String, dynamic> args;

  final ToolCallStatus status;

  /// The JSON value the tool returned, once [status] is ok.
  final Object? result;

  /// Set when [status] is error or declined.
  final ToolCallError? error;

  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// Whether the call has an outcome.
  bool get isSettled => switch (status) {
    ToolCallStatus.ok ||
    ToolCallStatus.error ||
    ToolCallStatus.declined => true,
    _ => false,
  };

  ToolCallRecord copyWith({
    Map<String, dynamic>? args,
    ToolCallStatus? status,
    Object? result,
    ToolCallError? error,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) => ToolCallRecord(
    id: id,
    name: name,
    segment: segment,
    args: args ?? this.args,
    status: status ?? this.status,
    result: result ?? this.result,
    error: error ?? this.error,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );
}
