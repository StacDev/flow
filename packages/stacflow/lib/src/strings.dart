import 'package:flow_ui/flow_ui.dart';

/// Every string the SDK shows, with English defaults. Subclass and override
/// to localise.
class FlowStrings {
  const FlowStrings();

  String get thinking => 'Thinking...';
  String get placeholder => 'How can I help you today?';
  String get errorTitle => 'Something went wrong';
  String get retry => 'Try again';
  String get copy => 'Copy';
  String get copied => 'Copied';
  String get copyCode => 'Copy code';
  String get dismiss => 'Dismiss';
  String get goodResponse => 'Good response';
  String get badResponse => 'Bad response';
  String get regenerate => 'Regenerate';
  String get edit => 'Edit';
  String get jumpToLatest => 'Jump to latest';
  String get attach => 'Attach';
  String get dropFiles => 'Drop files to attach';
  String get removeAttachment => 'Remove';
  String get approvalTitle => 'Approval required';
  String get approve => 'Approve';
  String get reject => 'Reject';
  String get approved => 'Approved';
  String get rejected => 'Rejected';
  String get toolInput => 'Input';
  String get toolOutput => 'Output';
  String get toolDeclined => 'You declined this call.';
  String get toolFailed => 'The tool failed.';
  String get toolTimedOut => 'The tool took too long to finish.';
  String get toolCancelled => 'The call was stopped.';
  String get toolUnknown =>
      'The model asked for a tool this app does not have.';
  String get errorAuth =>
      'The API key was rejected. Check the key and try again.';
  String get errorRateLimited =>
      'The model is busy right now. Try again in a moment.';
  String get errorTimeout => 'The model took too long to answer.';
  String get errorNetwork =>
      'Could not reach the model. Check your connection and try again.';
  String get errorProvider => 'The model returned an error.';
  String get errorToolRounds =>
      'The model kept calling tools without answering. Try again.';
  String get errorGeneric => 'Something went wrong. Try again.';

  /// The error card's text for a failed turn, by error [code]; [detail] is
  /// the provider's own message when it is worth showing.
  String errorMessage(String code, {String? detail}) => switch (code) {
    'provider_auth_failed' => errorAuth,
    'provider_rate_limited' => errorRateLimited,
    'segment_timeout' => errorTimeout,
    'network' || 'stream_closed' => errorNetwork,
    'tool_rounds_exceeded' => errorToolRounds,
    'provider_error' || 'validation_failed' =>
      detail == null || detail.isEmpty ? errorProvider : detail,
    _ => errorGeneric,
  };

  /// The confirmation card's question when the tool writes none.
  String approvalMessage(String label) => 'Allow $label to run?';

  /// The tool card's failure line, by error [code]; [detail] is the tool's
  /// own message when it wrote one.
  String toolError(String code, {String? detail}) => switch (code) {
    'declined' => toolDeclined,
    'timeout' => toolTimedOut,
    'cancelled' => toolCancelled,
    'unknown_tool' => toolUnknown,
    'tool_error' => detail == null || detail.isEmpty ? toolFailed : detail,
    _ => toolFailed,
  };

  /// The composer's banner for a file it refused.
  String attachmentRejected(String name, FlowAttachmentRejection reason) =>
      switch (reason) {
        FlowAttachmentRejection.tooLarge => '$name is too large.',
        FlowAttachmentRejection.unsupportedType => '$name is not an image.',
        FlowAttachmentRejection.unreadable => '$name could not be read.',
      };
}
