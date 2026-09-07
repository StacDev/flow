import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// The sidebar's destinations — one example plus the component demos to
/// come. Icons are Phosphor regular, the set the design is drawn in.
/// [codeFile] is the filename the code panel shows for the item, per the
/// design's snippets.
enum PlaygroundItem {
  fullChat(
    'Full Chat',
    PhosphorIconsRegular.sunHorizon,
    'full_chat_screen.dart',
    isExample: true,
  ),
  composer(
    'Composer',
    PhosphorIconsRegular.textAlignLeft,
    'flow_composer.dart',
  ),
  modalSelector(
    'Modal Selector',
    PhosphorIconsRegular.caretDown,
    'flow_model_selector.dart',
  ),
  message('Message', PhosphorIconsRegular.chat, 'flow_message.dart'),
  streamingMessage(
    'Streaming Message',
    PhosphorIconsRegular.chatCircleDots,
    'flow_streaming_message.dart',
  ),
  codeBlock('Code Block', PhosphorIconsRegular.code, 'flow_code_block.dart'),
  markdown('Markdown', PhosphorIconsRegular.markdownLogo, 'flow_markdown.dart'),
  errorState(
    'Error State',
    PhosphorIconsRegular.warningCircle,
    'flow_error_state.dart',
  ),
  confirmation(
    'Confirmation',
    PhosphorIconsRegular.shieldCheck,
    'flow_confirmation.dart',
  ),
  toast('Toast', PhosphorIconsRegular.bellSimple, 'flow_toast.dart'),
  tool('Tool', PhosphorIconsRegular.wrench, 'flow_tool.dart'),
  addToChat(
    'Add to Chat',
    PhosphorIconsRegular.plus,
    'flow_add_to_chat_menu.dart',
  ),
  pill('Pill', PhosphorIconsRegular.pill, 'flow_pill.dart'),
  attachments(
    'Attachments',
    PhosphorIconsRegular.paperclip,
    'flow_attachments.dart',
  ),
  thread('Thread', PhosphorIconsRegular.chats, 'flow_thread.dart'),
  threadList(
    'Thread List',
    PhosphorIconsRegular.clockCounterClockwise,
    'flow_thread_list.dart',
  ),
  messageActions(
    'Message Actions',
    PhosphorIconsRegular.thumbsUp,
    'flow_message_actions.dart',
  ),
  streamingText(
    'Streaming Text',
    PhosphorIconsRegular.textAa,
    'flow_streaming_text.dart',
  ),
  shimmerText(
    'Shimmer Text',
    PhosphorIconsRegular.sparkle,
    'flow_shimmer_text.dart',
  ),
  thinkingIndicator(
    'Thinking Indicator',
    PhosphorIconsRegular.asterisk,
    'flow_thinking_indicator.dart',
  ),
  suggestions(
    'Suggestions',
    PhosphorIconsRegular.lightbulb,
    'flow_suggestion.dart',
  ),
  greeting('Greeting', PhosphorIconsRegular.handWaving, 'flow_greeting.dart');

  const PlaygroundItem(
    this.label,
    this.icon,
    this.codeFile, {
    this.isExample = false,
  });

  final String label;
  final IconData icon;
  final String codeFile;

  /// Examples sit in their own sidebar section above the components.
  final bool isExample;

  /// The item's URL id: the enum name in kebab-case (`fullChat` →
  /// `full-chat`). One id serves both contracts — the playground's path
  /// (`/playground/full-chat`) and the docs' embed query
  /// (`?embed=full-chat`) — so they can't drift apart, and renaming a
  /// value moves both.
  String get slug =>
      name.replaceAllMapped(_camelBoundary, (m) => '-${m[0]!.toLowerCase()}');
}

final RegExp _camelBoundary = RegExp('[A-Z]');

/// The item [PlaygroundItem.slug] names, or null when nothing matches —
/// the caller decides what an unknown id means: the router redirects to
/// the default, the embed renders its "Unknown demo" surface.
PlaygroundItem? playgroundItemForSlug(String slug) {
  for (final item in PlaygroundItem.values) {
    if (item.slug == slug) return item;
  }
  return null;
}
