import 'package:material_ui/material_ui.dart';

import '../styles/flow_code_block_style.dart';
import '../theme/flow_syntax_colors.dart';
import '../theme/flow_theme.dart';
import '../utils/flow_selection.dart';
import '../utils/flow_syntax_highlighter.dart';

export '../utils/flow_syntax_highlighter.dart'
    show FlowCodeLanguage, FlowSyntaxRule, FlowSyntaxToken;

/// A code block: a fenced snippet on its own washed ground, under a header
/// that names the content and offers copy.
///
/// ```dart
/// FlowCodeBlock(
///   code: source,
///   language: 'dart',
///   copyTooltip: 'Copy code',
///   copied: copied,
///   onCopy: () => copy(source),
/// )
/// ```
///
/// Highlighting is built in and synchronous — no setup call, nothing
/// async. [language] picks a rule table via [FlowCodeLanguage.find];
/// unknown ids render plain, never an error, and hosts add languages with
/// [FlowCodeLanguage.register]. Token inks come from the theme's
/// [FlowSyntaxColors].
///
/// Copying reports intent, per the package's contract: [onCopy] fires, the
/// host writes the clipboard, then holds [copied] true while its
/// confirmation lasts — the affordance swaps to a check, tinted primary
/// like a selected message action. The package touches no clipboard and
/// ships no strings; [copyTooltip] is the affordance's accessible name.
///
/// The code is selectable: in a thread it joins the thread's selection,
/// so a drag from the prose above runs straight through it; on its own it
/// hosts its own selection area, with the platform's handles and menu.
/// Inside a `FlowThread` that opted out of selection, or under a
/// `SelectionContainer.disabled`, it does neither.
///
/// Fills the width it's given, so it needs a bounded width — any column,
/// list or message slot provides one.
class FlowCodeBlock extends StatefulWidget {
  const FlowCodeBlock({
    super.key,
    required this.code,
    this.language,
    this.filename,
    this.onCopy,
    this.copyTooltip,
    this.copied = false,
    this.isStreaming = false,
    this.wrap = false,
    this.padding,
    this.borderRadius,
    this.style,
  });

  /// The source, rendered verbatim.
  final String code;

  /// [FlowCodeLanguage] id or alias, case-insensitive — usually the fence
  /// info string. Null or unknown renders plain.
  final String? language;

  /// Header label; null falls back to [language], and with neither the
  /// header keeps only the copy affordance.
  final String? filename;

  /// Copy intent. Null hides the affordance.
  final VoidCallback? onCopy;

  /// Host-localized; also the affordance's accessible name.
  final String? copyTooltip;

  /// Swaps the affordance to a check while true. The host owns the
  /// confirmation and its timing, as with `FlowMessageAction.thumbUp`.
  final bool copied;

  /// While true the copy affordance hides — there is nothing complete to
  /// copy — and each delivery renders whole, with no per-character reveal:
  /// streamed code arrives re-highlighted as often as appended, which a
  /// reveal would restart on.
  final bool isStreaming;

  /// False scrolls long lines horizontally inside the block, keeping the
  /// author's line breaks; true wraps them instead.
  final bool wrap;

  /// Around the code. Defaults to the design's 16/12.
  final EdgeInsetsGeometry? padding;

  /// The block's corner. Defaults to the design's 12.
  final BorderRadius? borderRadius;

  /// Per-instance restyling, merged over [FlowTheme.codeBlockStyle]'s
  /// fields; nulls fall through to the theme tokens.
  final FlowCodeBlockStyle? style;

  @override
  State<FlowCodeBlock> createState() => _FlowCodeBlockState();
}

class _FlowCodeBlockState extends State<FlowCodeBlock> {
  /// The design's block: the message bubble's 12px corner, code inset
  /// 16/12, and a ruleless header standing 10 off the top and 12 from the
  /// end, its label a full 16 from the edge so it aligns with the code.
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(12));
  static const EdgeInsetsGeometry _bodyPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
  static const double _headerHeight = 36;
  static const EdgeInsetsGeometry _headerPadding = EdgeInsets.only(
    left: 16,
    right: 12,
    top: 10,
  );

  /// The copy affordance reveals with the pointer — short enough to feel
  /// like part of the hover itself, the attachment tiles' idiom.
  static const Duration _revealDuration = Duration(milliseconds: 120);

  bool _hovered = false;
  bool _copyFocused = false;

  /// Whether the user is currently driving the UI with a device that can
  /// hover — the attachment group's idiom: the framework tracks and
  /// *revises* this, where a platform check could strand the affordance
  /// invisible on a hybrid device.
  late bool _hoverCapable;

  @override
  void initState() {
    super.initState();
    _hoverCapable = _hoverCapableNow;
    FocusManager.instance.addHighlightModeListener(_handleHighlightModeChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(
      _handleHighlightModeChange,
    );
    super.dispose();
  }

  static bool get _hoverCapableNow =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _handleHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted) return;
    final value = mode == FocusHighlightMode.traditional;
    if (_hoverCapable != value) setState(() => _hoverCapable = value);
  }

  /// Hover-revealing is a pointer affordance: it needs a hovering device
  /// *and* a non-phone platform — the theme's platform rather than the
  /// real one, like the menus' sheet resolution.
  bool _revealsOnHover(BuildContext context) {
    if (!_hoverCapable) return false;
    final platform = Theme.of(context).platform;
    return platform != TargetPlatform.iOS && platform != TargetPlatform.android;
  }

  /// The last highlight and the inputs it was computed from. Tokenizing
  /// re-scans the whole source, so a rebuild that changes none of the
  /// inputs — an ancestor animating, a hover elsewhere — must not pay for
  /// one.
  TextSpan? _span;
  String? _spanCode;
  FlowCodeLanguage? _spanLanguage;
  TextStyle? _spanStyle;
  FlowSyntaxColors? _spanColors;

  TextSpan _highlight(
    FlowCodeLanguage? language,
    TextStyle style,
    FlowSyntaxColors colors,
  ) {
    final cached = _span;
    if (cached != null &&
        _spanCode == widget.code &&
        identical(_spanLanguage, language) &&
        _spanStyle == style &&
        identical(_spanColors, colors)) {
      return cached;
    }
    final span = FlowSyntaxHighlighter.highlight(
      widget.code,
      language: language,
      style: style,
      colors: colors,
    );
    _span = span;
    _spanCode = widget.code;
    _spanLanguage = language;
    _spanStyle = style;
    _spanColors = colors;
    return span;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;
    final syntaxColors = context.flowSyntaxColors;

    final style =
        context.flowTheme.codeBlockStyle?.merge(widget.style) ?? widget.style;

    final language = FlowCodeLanguage.find(widget.language);
    final span = _highlight(
      language,
      typography.code.copyWith(color: colors.onSurface).merge(style?.codeStyle),
      syntaxColors,
    );

    final label = widget.filename ?? widget.language;
    final showCopy = widget.onCopy != null && !widget.isStreaming;
    final hasHeader = label != null || widget.onCopy != null;

    final padding = widget.padding ?? _bodyPadding;
    // In a thread the code joins the thread's selection as one block, so
    // a drag runs straight through it; on its own the block hosts its own
    // area, which keeps a standalone snippet selectable and gives it a
    // toolbar. Under a disabled scope — a host's
    // SelectionContainer.disabled, or a thread that opted out of
    // selection — it does neither. One paragraph either way.
    final scope = context
        .dependOnInheritedWidgetOfExactType<SelectionRegistrarScope>();
    final inArea = scope?.registrar != null;
    final code = inArea
        ? FlowSelectionBlock(child: Text.rich(span))
        : Text.rich(span);
    Widget body = widget.wrap
        ? Padding(padding: padding, child: code)
        // Padding inside the scroll view, so the last column of a long
        // line clears the edge instead of sitting against the clip.
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            child: code,
          );
    if (scope == null) body = FlowSelectionArea(child: body);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: style?.backgroundColor ?? colors.surfaceContainerLowest,
          borderRadius: widget.borderRadius ?? _radius,
          // Hover lives on the edge, not the ground: the hairline firms
          // from `outline` to `outlineVariant`.
          // A style's borderColor holds through hover unless the style
          // names its own hover edge.
          border: Border.all(
            color: _hovered
                ? (style?.hoverBorderColor ??
                      style?.borderColor ??
                      colors.outlineVariant)
                : (style?.borderColor ?? colors.outline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader)
              Container(
                height: _headerHeight,
                padding: _headerPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: label == null
                          ? const SizedBox.shrink()
                          // The header is chrome: a selection sweeping
                          // the block takes the code, never the label.
                          : SelectionContainer.disabled(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.labelMedium
                                    .copyWith(color: colors.onSurfaceMuted)
                                    .merge(style?.headerStyle),
                              ),
                            ),
                    ),
                    if (showCopy)
                      // Revealed by the pointer on hover-capable devices,
                      // always present on phones (by the theme's platform,
                      // so hosts and tests can steer it) or wherever
                      // hovering isn't how the UI is being driven — and
                      // kept while focused, so keyboard users aren't
                      // copying blind. Opacity alone still hit-tests, so
                      // the hidden affordance must also ignore the
                      // pointer.
                      IgnorePointer(
                        ignoring:
                            _revealsOnHover(context) &&
                            !_hovered &&
                            !_copyFocused,
                        child: AnimatedOpacity(
                          opacity:
                              !_revealsOnHover(context) ||
                                  _hovered ||
                                  _copyFocused
                              ? 1
                              : 0,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : _revealDuration,
                          child: _CopyButton(
                            copied: widget.copied,
                            tooltip: widget.copyTooltip,
                            onTap: widget.onCopy!,
                            onFocusChange: (value) =>
                                setState(() => _copyFocused = value),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            body,
          ],
        ),
      ),
    );
  }
}

/// The header's copy affordance: a glyph on a 24 frame, resting at the
/// muted ink and lifting to full on hover, with the copied check tinted
/// primary — the message-action dress on a rounder corner.
class _CopyButton extends StatefulWidget {
  const _CopyButton({
    required this.copied,
    required this.tooltip,
    required this.onTap,
    required this.onFocusChange,
  });

  final bool copied;
  final String? tooltip;
  final VoidCallback onTap;
  final ValueChanged<bool> onFocusChange;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  /// Breathing room around the 14 glyph inside its 24 frame.
  static const double _framePadding = 5;
  static const double _iconSize = 14;

  /// The frame's corner — a step under the block's 12, per the ratio the
  /// menu rows keep to their card.
  static const BorderRadius _frameRadius = BorderRadius.all(Radius.circular(6));

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;

    final Color foreground;
    if (widget.copied) {
      foreground = colors.primary;
    } else if (_hovered) {
      foreground = colors.onSurface;
    } else {
      foreground = colors.onSurfaceMuted;
    }

    // Transparent Material so ink and hover fills render inside the
    // block's decorated container.
    Widget button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: widget.onFocusChange,
        borderRadius: _frameRadius,
        hoverColor: colors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(_framePadding),
          child: Icon(
            widget.copied ? Icons.check : Icons.copy_outlined,
            size: _iconSize,
            color: foreground,
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    if (tooltip != null) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}
