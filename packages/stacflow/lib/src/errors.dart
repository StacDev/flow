import 'package:stacflow/src/generated/sse_events.dart';
import 'package:stacflow/src/strings.dart';

/// Who is responsible for a failed turn: the wire classes, plus `runtime`
/// for faults that never left the device.
enum ChatFailureClass {
  provider,
  developerApi,
  gateway,
  policy,
  timeout,
  cancelled,
  runtime,
}

/// A failed turn: a stable [code], a user-safe [message], and where the
/// fault lies. [detail] is the provider's own wording, when there is one.
final class ChatError {
  const new({
    required this.failureClass,
    required this.code,
    required this.message,
    required this.retryable,
    this.detail,
    this.upstream,
  });

  /// The error a provider reported on the wire, worded by [strings].
  factory fromEvent(ErrorEvent event, FlowStrings strings) => ChatError(
    failureClass: switch (event.failureClass) {
      FailureClass.provider => ChatFailureClass.provider,
      FailureClass.developerApi => ChatFailureClass.developerApi,
      FailureClass.gateway => ChatFailureClass.gateway,
      FailureClass.policy => ChatFailureClass.policy,
      FailureClass.timeout => ChatFailureClass.timeout,
      FailureClass.cancelled => ChatFailureClass.cancelled,
    },
    code: event.code,
    message: strings.errorMessage(event.code, detail: event.message),
    retryable: event.retryable,
    detail: event.message,
    upstream: event.upstream,
  );

  /// A fault on the device: no network, a closed stream, a bug.
  factory runtime({
    required String code,
    required FlowStrings strings,
    bool retryable = true,
    String? detail,
  }) => ChatError(
    failureClass: ChatFailureClass.runtime,
    code: code,
    message: strings.errorMessage(code, detail: detail),
    retryable: retryable,
    detail: detail,
  );

  final ChatFailureClass failureClass;
  final String code;
  final String message;
  final String? detail;
  final bool retryable;
  final Upstream? upstream;

  @override
  String toString() => 'ChatError($code, ${failureClass.name})';
}
