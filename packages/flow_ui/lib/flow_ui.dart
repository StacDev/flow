/// [Flow UI](https://flowui.stac.dev/) is an open-source Flutter UI library
/// to build production-grade Chat & AI assistant interfaces.
///
/// flow_ui renders state and reports intent through callbacks — it contains
/// nothing model-facing and builds only on Flutter's own first-party
/// packages.
///
/// The one thing it does reach out for is a file: `showFlowAttachmentPicker`
/// opens the platform's own dialog — from the composer's attach button or
/// a host's own "+" menu — and on the web the chat surface accepts drops
/// and the field takes pasted images. All are opt-in, all hand back
/// `FlowAttachment`s for the host to hold, and none sends anything
/// anywhere.
library;

export 'src/models/flow_attachment.dart';
export 'src/models/flow_attachment_options.dart';
export 'src/utils/flow_file_picker.dart' show showFlowAttachmentPicker;
export 'src/models/flow_message_data.dart';
export 'src/models/flow_message_part.dart';
export 'src/theme/flow_colors.dart';
export 'src/theme/flow_syntax_colors.dart';
export 'src/theme/flow_theme.dart';
export 'src/theme/flow_typography.dart';
export 'src/widgets/flow_attachment_group.dart';
export 'src/widgets/flow_attachment_preview.dart';
export 'src/widgets/flow_chat_view.dart';
export 'src/styles/flow_chat_view_style.dart';
export 'src/widgets/flow_code_block.dart';
export 'src/styles/flow_code_block_style.dart';
export 'src/widgets/flow_composer.dart';
export 'src/styles/flow_composer_style.dart';
export 'src/widgets/flow_confirmation.dart';
export 'src/styles/flow_confirmation_style.dart';
export 'src/widgets/flow_drop_target.dart';
export 'src/widgets/flow_error_state.dart';
export 'src/styles/flow_error_state_style.dart';
export 'src/widgets/flow_greeting.dart';
export 'src/widgets/flow_markdown.dart';
export 'src/styles/flow_markdown_style.dart';
export 'src/widgets/flow_menu.dart';
export 'src/styles/flow_menu_style.dart';
export 'src/widgets/flow_message.dart';
export 'src/widgets/flow_message_actions.dart';
export 'src/styles/flow_message_actions_style.dart';
export 'src/styles/flow_message_style.dart';
export 'src/widgets/flow_model_selector.dart';
export 'src/widgets/flow_pill.dart';
export 'src/styles/flow_pill_style.dart';
export 'src/widgets/flow_shimmer_text.dart';
export 'src/widgets/flow_streaming_text.dart';
export 'src/widgets/flow_suggestion.dart';
export 'src/styles/flow_suggestion_style.dart';
export 'src/widgets/flow_thinking_indicator.dart';
export 'src/widgets/flow_thread.dart';
export 'src/widgets/flow_thread_list.dart';
export 'src/styles/flow_thread_list_style.dart';
export 'src/widgets/flow_toast.dart';
export 'src/styles/flow_toast_style.dart';
export 'src/utils/flow_toast_layer.dart' show showFlowToast, FlowToastHandle;
export 'src/widgets/flow_tool.dart';
export 'src/styles/flow_tool_style.dart';
