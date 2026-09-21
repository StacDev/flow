import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

import '../styles/flow_suggestion_style.dart';
import '../theme/flow_theme.dart';

/// A tappable prompt row: the host's suggested message, optionally with a
/// leading icon. Usable on its own, or in a [FlowSuggestionGroup]:
///
/// ```dart
/// FlowSuggestion(
///   label: 'Summarize this thread',
///   icon: Icons.summarize_outlined,
///   onTap: () => send('Summarize this thread'),
/// )
/// ```
///
/// Two variants, per the design: a plain row resting in the secondary ink
/// with no chrome of its own, and — with [outlined] — a row on the faint
/// fill and hairline, in full ink. The outlined form is also the treatment
/// for suggestions embedded inside an assistant message.
///
/// [label] is the whole content — the package ships no strings and does not
/// derive prompt text. A null [onTap] renders the row disabled.
class FlowSuggestion extends StatefulWidget {
  const FlowSuggestion({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.outlined = false,
    this.enabled = true,
    this.tooltip,
    this.padding,
    this.borderRadius,
    this.style,
  });

  /// The suggestion text, on one line — it ellipsizes rather than wrapping.
  final String label;

  /// Optional leading glyph.
  final IconData? icon;

  /// Null renders the row disabled.
  final VoidCallback? onTap;

  /// Draws the row on the design's faint fill and hairline, in full ink.
  /// Plain rows carry no chrome and rest in the secondary ink.
  final bool outlined;

  final bool enabled;

  /// Host-localized tooltip, e.g. the full text of a long suggestion.
  final String? tooltip;

  /// Inside the row. Defaults to the design's 10 horizontally.
  final EdgeInsetsGeometry? padding;

  /// The row's corner. Defaults to the design's 8.
  final BorderRadius? borderRadius;

  /// Per-instance restyling, merged over [FlowTheme.suggestionStyle]'s
  /// fields; nulls fall through to the theme tokens.
  final FlowSuggestionStyle? style;

  @override
  State<FlowSuggestion> createState() => _FlowSuggestionState();
}

class _FlowSuggestionState extends State<FlowSuggestion> {
  /// The design's row: 36 tall on an 8px corner, padded 10, a 20px glyph a
  /// 16px gap from the label.
  static const double _rowHeight = 36;
  static const BorderRadius _rowRadius = BorderRadius.all(Radius.circular(8));
  static const EdgeInsetsGeometry _rowPadding = EdgeInsets.symmetric(
    horizontal: 10,
  );
  static const double _iconSize = 20;
  static const double _iconGap = 16;

  /// The hover affordance in the column form: a 16px arrow at the row's
  /// far end, in the muted ink.
  static const double _arrowSize = 16;

  /// The outlined row's ground, as an alpha over the ink — a step fainter
  /// than the attachment tile's wash, per the design.
  static const double _outlinedFillOpacity = 0.02;

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final enabled = widget.enabled && widget.onTap != null;
    final style =
        context.flowTheme.suggestionStyle?.merge(widget.style) ?? widget.style;

    // Plain rows rest a step down; outlined rows carry full ink. Hover
    // lifts both to full ink so the affordance stays.
    final restForeground =
        style?.foregroundColor ??
        (widget.outlined ? colors.onSurface : colors.onSurfaceVariant);
    final Color foreground;
    if (!enabled) {
      foreground = colors.onSurfaceDisabled;
    } else if (_hovered) {
      foreground = colors.onSurface;
    } else {
      foreground = restForeground;
    }

    final shape = RoundedRectangleBorder(
      borderRadius: widget.borderRadius ?? _rowRadius,
      side: widget.outlined
          ? BorderSide(color: style?.borderColor ?? colors.outline)
          : BorderSide.none,
    );

    Widget row = Material(
      color:
          style?.backgroundColor ??
          (widget.outlined
              ? colors.onSurface.withValues(alpha: _outlinedFillOpacity)
              : Colors.transparent),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? widget.onTap : null,
        onHover: enabled ? (value) => setState(() => _hovered = value) : null,
        customBorder: shape,
        hoverColor: style?.hoverColor ?? colors.surfaceContainerLow,
        child: Padding(
          padding: widget.padding ?? _rowPadding,
          child: SizedBox(
            height: _rowHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final Widget label = Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.flowTypography.labelLarge
                      .copyWith(color: foreground)
                      .merge(style?.labelStyle),
                );
                // The hovered row in the group's column form points onward
                // with an arrow at its far end — the design's web
                // affordance, so apps (where a trackpad can still hover)
                // never show it. The mobile check reads the theme's
                // platform rather than the real one, like the menus'
                // sheet resolution, so hosts and tests can steer it
                // without a device.
                final platform = Theme.of(context).platform;
                final mobile =
                    platform == TargetPlatform.iOS ||
                    platform == TargetPlatform.android;
                final inColumn =
                    constraints.maxWidth.isFinite &&
                    FlowSuggestionColumnScope.of(context);
                final showArrow =
                    kIsWeb && !mobile && inColumn && _hovered && enabled;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: _iconSize, color: foreground),
                      const SizedBox(width: _iconGap),
                    ],
                    // A row lays non-flex children out unbounded, so the
                    // label only ellipsizes as a flex child — which in turn
                    // is only legal when something bounds the row. The
                    // scrolling layout doesn't, and there a long label just
                    // runs on. In the column form the label owns the whole
                    // stretch — Expanded, not a Spacer beside it, which
                    // would split the row's space with the label and
                    // truncate it at half width.
                    if (inColumn)
                      Expanded(child: label)
                    else if (constraints.maxWidth.isFinite)
                      Flexible(child: label)
                    else
                      label,
                    if (showArrow) ...[
                      const SizedBox(width: _iconGap),
                      Icon(
                        Icons.arrow_forward,
                        size: _arrowSize,
                        color: colors.onSurfaceMuted,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    if (tooltip != null) {
      row = Tooltip(message: tooltip, child: row);
    }
    return row;
  }
}

/// Marks the subtree as a [FlowSuggestionGroup] column, where a hovered
/// [FlowSuggestion] shows its trailing arrow. Public so a host laying out
/// its own full-width column can opt suggestion rows into the same
/// affordance.
class FlowSuggestionColumnScope extends InheritedWidget {
  const FlowSuggestionColumnScope({super.key, required super.child});

  /// Whether [context] sits inside a column of suggestions.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlowSuggestionColumnScope>() !=
      null;

  @override
  bool updateShouldNotify(FlowSuggestionColumnScope oldWidget) => false;
}

/// How a [FlowSuggestionGroup] arranges its rows.
enum FlowSuggestionLayout {
  /// One strip that scrolls horizontally, without a scrollbar. Keeps a long
  /// set to a single line — the usual treatment above a composer.
  scroll,

  /// Wraps onto as many lines as needed; nothing scrolls.
  wrap,

  /// One suggestion per line, each filling the width — the design's
  /// primary form.
  column,
}

/// Lays out prompt suggestions as a scrolling strip, a wrap, or a column —
/// typically above a `FlowComposer` on an empty thread:
///
/// ```dart
/// FlowSuggestionGroup(
///   suggestions: [
///     FlowSuggestion(label: 'Plan a trip', onTap: () => send('Plan a trip')),
///     FlowSuggestion(label: 'Explain a photo', onTap: ...),
///   ],
/// )
/// ```
///
/// An empty [suggestions] list takes no space, so a host can pass whatever
/// it has without guarding.
class FlowSuggestionGroup extends StatelessWidget {
  const FlowSuggestionGroup({
    super.key,
    required this.suggestions,
    this.layout = FlowSuggestionLayout.scroll,
    this.spacing,
    this.padding,
  });

  /// Rendered in order.
  final List<FlowSuggestion> suggestions;

  final FlowSuggestionLayout layout;

  /// Gap between rows, and between lines when wrapping. Defaults to the
  /// design's 6 in a column and 10 in the scrolling and wrapping layouts.
  final double? spacing;

  /// Around the whole group; defaults to none. In the scrolling layout it
  /// scrolls with the rows, so the first and last clear the edge.
  final EdgeInsetsGeometry? padding;

  /// The design's layout gaps: tight in a column, roomier along a strip.
  static const double _columnGap = 6;
  static const double _rowGap = 10;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final gap =
        spacing ??
        (layout == FlowSuggestionLayout.column ? _columnGap : _rowGap);

    switch (layout) {
      case FlowSuggestionLayout.scroll:
        return ScrollConfiguration(
          // No scrollbar over the rows, and draggable with a mouse so the
          // strip works on desktop without a horizontal wheel.
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: PointerDeviceKind.values.toSet(),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _withGaps(gap, Axis.horizontal),
            ),
          ),
        );
      case FlowSuggestionLayout.wrap:
        return _padded(
          Wrap(spacing: gap, runSpacing: gap, children: suggestions),
        );
      case FlowSuggestionLayout.column:
        return _padded(
          FlowSuggestionColumnScope(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Full-width rows, per the design's column form.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withGaps(gap, Axis.vertical),
            ),
          ),
        );
    }
  }

  Widget _padded(Widget child) {
    if (padding == null) return child;
    return Padding(padding: padding!, child: child);
  }

  List<Widget> _withGaps(double gap, Axis axis) {
    return [
      for (var i = 0; i < suggestions.length; i++) ...[
        if (i > 0)
          axis == Axis.horizontal
              ? SizedBox(width: gap)
              : SizedBox(height: gap),
        suggestions[i],
      ],
    ];
  }
}
