import 'package:material_ui/material_ui.dart';

import '../styles/flow_chat_view_style.dart';
import '../styles/flow_code_block_style.dart';
import '../styles/flow_composer_style.dart';
import '../styles/flow_confirmation_style.dart';
import '../styles/flow_error_state_style.dart';
import '../styles/flow_markdown_style.dart';
import '../styles/flow_menu_style.dart';
import '../styles/flow_message_actions_style.dart';
import '../styles/flow_message_style.dart';
import '../styles/flow_pill_style.dart';
import '../styles/flow_suggestion_style.dart';
import '../styles/flow_thread_list_style.dart';
import '../styles/flow_toast_style.dart';
import '../styles/flow_tool_style.dart';
import 'flow_colors.dart';
import 'flow_syntax_colors.dart';
import 'flow_typography.dart';

/// The flow_ui design tokens — colors and typography — installed as a
/// [ThemeExtension]:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(extensions: [FlowTheme.light()]),
///   darkTheme: ThemeData(
///     brightness: Brightness.dark,
///     extensions: [FlowTheme.dark()],
///   ),
/// )
/// ```
///
/// Components read tokens via [FlowThemeContext] (`context.flowTheme`,
/// `context.flowColors`, …). When no [FlowTheme] is installed, a preset
/// matching the ambient [ThemeData.brightness] is used, so flow_ui works
/// with zero host setup.
///
/// Beyond the tokens, the theme can carry component styles — app-wide
/// defaults for a widget family's look ([menuStyle], [markdownStyle], …).
/// A widget's own style object wins over the theme's, field by field, and
/// the tokens sit beneath both.
///
/// Spacing and corner radii are not tokens: following Material's structure,
/// each component bakes its own metrics from the design file and exposes
/// per-widget overrides (`padding:`, `borderRadius:`) where hosts retheme.
class FlowTheme extends ThemeExtension<FlowTheme> {
  const FlowTheme({
    required this.colors,
    this._typography,
    this.syntax,
    this.composerStyle,
    this.messageStyle,
    this.menuStyle,
    this.markdownStyle,
    this.codeBlockStyle,
    this.confirmationStyle,
    this.errorStateStyle,
    this.messageActionsStyle,
    this.pillStyle,
    this.suggestionStyle,
    this.threadListStyle,
    this.toastStyle,
    this.toolStyle,
    this.chatViewStyle,
  });

  /// Light preset.
  factory FlowTheme.light() =>
      const FlowTheme(colors: FlowColors.light, syntax: FlowSyntaxColors.light);

  /// Dark preset.
  factory FlowTheme.dark() =>
      const FlowTheme(colors: FlowColors.dark, syntax: FlowSyntaxColors.dark);

  final FlowColors colors;
  final FlowTypography? _typography;

  /// The type scale — [FlowTypography.standard] unless the host set one.
  /// Resolved on read, since the standard scale isn't `const`.
  FlowTypography get typography => _typography ?? FlowTypography.standard;

  /// Syntax token colors for code blocks. Null resolves to the preset
  /// matching the ambient brightness — unlike [typography], the right
  /// default depends on which way the theme leans, which a constructor
  /// default can't see.
  final FlowSyntaxColors? syntax;

  /// App-wide default for every `FlowComposer`.
  final FlowComposerStyle? composerStyle;

  /// App-wide default for every `FlowMessage` — threads included.
  final FlowMessageStyle? messageStyle;

  /// App-wide default for every `FlowMenu` and `FlowModelSelector`.
  final FlowMenuStyle? menuStyle;

  /// App-wide default for every `FlowMarkdown` — assistant turns included.
  final FlowMarkdownStyle? markdownStyle;

  /// App-wide default for every `FlowCodeBlock` — markdown fences and
  /// code parts included.
  final FlowCodeBlockStyle? codeBlockStyle;

  /// App-wide default for every `FlowConfirmation` — confirmation parts
  /// in a thread included.
  final FlowConfirmationStyle? confirmationStyle;

  /// App-wide default for every `FlowErrorState` — failed turns included.
  final FlowErrorStateStyle? errorStateStyle;

  /// App-wide default for every `FlowMessageActions`.
  final FlowMessageActionsStyle? messageActionsStyle;

  /// App-wide default for every `FlowPill`.
  final FlowPillStyle? pillStyle;

  /// App-wide default for every `FlowSuggestion`.
  final FlowSuggestionStyle? suggestionStyle;

  /// App-wide default for every `FlowThreadList`.
  final FlowThreadListStyle? threadListStyle;

  /// App-wide default for every `FlowToast` — the ones `showFlowToast`
  /// floats included.
  final FlowToastStyle? toastStyle;

  /// App-wide default for every `FlowTool` — tool parts in a thread
  /// included.
  final FlowToolStyle? toolStyle;

  /// App-wide default for `FlowChatView.style` — the drop treatment's
  /// gradient, glyph and label.
  final FlowChatViewStyle? chatViewStyle;

  @override
  FlowTheme copyWith({
    FlowColors? colors,
    FlowTypography? typography,
    FlowSyntaxColors? syntax,
    FlowComposerStyle? composerStyle,
    FlowMessageStyle? messageStyle,
    FlowMenuStyle? menuStyle,
    FlowMarkdownStyle? markdownStyle,
    FlowCodeBlockStyle? codeBlockStyle,
    FlowConfirmationStyle? confirmationStyle,
    FlowErrorStateStyle? errorStateStyle,
    FlowMessageActionsStyle? messageActionsStyle,
    FlowPillStyle? pillStyle,
    FlowSuggestionStyle? suggestionStyle,
    FlowThreadListStyle? threadListStyle,
    FlowToastStyle? toastStyle,
    FlowToolStyle? toolStyle,
    FlowChatViewStyle? chatViewStyle,
  }) {
    return FlowTheme(
      colors: colors ?? this.colors,
      typography: typography ?? _typography,
      syntax: syntax ?? this.syntax,
      composerStyle: composerStyle ?? this.composerStyle,
      messageStyle: messageStyle ?? this.messageStyle,
      menuStyle: menuStyle ?? this.menuStyle,
      markdownStyle: markdownStyle ?? this.markdownStyle,
      codeBlockStyle: codeBlockStyle ?? this.codeBlockStyle,
      confirmationStyle: confirmationStyle ?? this.confirmationStyle,
      errorStateStyle: errorStateStyle ?? this.errorStateStyle,
      messageActionsStyle: messageActionsStyle ?? this.messageActionsStyle,
      pillStyle: pillStyle ?? this.pillStyle,
      suggestionStyle: suggestionStyle ?? this.suggestionStyle,
      threadListStyle: threadListStyle ?? this.threadListStyle,
      toastStyle: toastStyle ?? this.toastStyle,
      toolStyle: toolStyle ?? this.toolStyle,
      chatViewStyle: chatViewStyle ?? this.chatViewStyle,
    );
  }

  @override
  FlowTheme lerp(ThemeExtension<FlowTheme>? other, double t) {
    if (other is! FlowTheme) return this;
    return FlowTheme(
      colors: colors.lerp(other.colors, t),
      typography: typography.lerp(other.typography, t),
      syntax: syntax == null ? other.syntax : syntax!.lerp(other.syntax, t),
      composerStyle: composerStyle == null
          ? other.composerStyle
          : composerStyle!.lerp(other.composerStyle, t),
      messageStyle: messageStyle == null
          ? other.messageStyle
          : messageStyle!.lerp(other.messageStyle, t),
      menuStyle: menuStyle == null
          ? other.menuStyle
          : menuStyle!.lerp(other.menuStyle, t),
      markdownStyle: markdownStyle == null
          ? other.markdownStyle
          : markdownStyle!.lerp(other.markdownStyle, t),
      codeBlockStyle: codeBlockStyle == null
          ? other.codeBlockStyle
          : codeBlockStyle!.lerp(other.codeBlockStyle, t),
      confirmationStyle: confirmationStyle == null
          ? other.confirmationStyle
          : confirmationStyle!.lerp(other.confirmationStyle, t),
      errorStateStyle: errorStateStyle == null
          ? other.errorStateStyle
          : errorStateStyle!.lerp(other.errorStateStyle, t),
      messageActionsStyle: messageActionsStyle == null
          ? other.messageActionsStyle
          : messageActionsStyle!.lerp(other.messageActionsStyle, t),
      pillStyle: pillStyle == null
          ? other.pillStyle
          : pillStyle!.lerp(other.pillStyle, t),
      suggestionStyle: suggestionStyle == null
          ? other.suggestionStyle
          : suggestionStyle!.lerp(other.suggestionStyle, t),
      threadListStyle: threadListStyle == null
          ? other.threadListStyle
          : threadListStyle!.lerp(other.threadListStyle, t),
      toastStyle: toastStyle == null
          ? other.toastStyle
          : toastStyle!.lerp(other.toastStyle, t),
      toolStyle: toolStyle == null
          ? other.toolStyle
          : toolStyle!.lerp(other.toolStyle, t),
      chatViewStyle: chatViewStyle == null
          ? other.chatViewStyle
          : chatViewStyle!.lerp(other.chatViewStyle, t),
    );
  }
}

/// Token access for widgets: `context.flowColors.primary`,
/// `context.flowTypography.bodyLarge`, …
extension FlowThemeContext on BuildContext {
  /// The installed [FlowTheme], or a brightness-matched preset if none is.
  FlowTheme get flowTheme {
    final theme = Theme.of(this);
    return theme.extension<FlowTheme>() ??
        (theme.brightness == Brightness.dark
            ? FlowTheme.dark()
            : FlowTheme.light());
  }

  FlowColors get flowColors => flowTheme.colors;
  FlowTypography get flowTypography => flowTheme.typography;

  /// Syntax colors: the installed set, or the preset matching the ambient
  /// brightness when the theme carries none.
  FlowSyntaxColors get flowSyntaxColors {
    final syntax = flowTheme.syntax;
    if (syntax != null) return syntax;
    return Theme.of(this).brightness == Brightness.dark
        ? FlowSyntaxColors.dark
        : FlowSyntaxColors.light;
  }
}
