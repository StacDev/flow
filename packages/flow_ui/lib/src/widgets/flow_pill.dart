import 'package:material_ui/material_ui.dart';

import '../styles/flow_pill_style.dart';
import '../theme/flow_theme.dart';

/// A removable pill showing an enabled tool or mode — "Research", "Web
/// Search" — in the composer's action row, typically appended to
/// `FlowComposer.leadingActions` while the host's toggle is on:
///
/// ```dart
/// if (researchOn)
///   FlowPill(
///     icon: Icons.school_outlined,
///     label: 'Research',
///     removeTooltip: 'Turn off Research',
///     onRemove: () => setResearch(false),
///   )
/// ```
///
/// The whole pill is one control: hovering highlights it edge to edge and
/// tapping anywhere on it reports through [onRemove] — the X is the visual
/// affordance, not a separate target. Actually turning the tool off is the
/// host's move. On phones the label drops away to the design's icon-only
/// form (see [showLabel]).
///
/// A pill without [onRemove] is a static status token in full ink, not a
/// disabled control — unlike `FlowSuggestion`, where a null tap renders
/// the row disabled. Disabling here is explicit, through [enabled].
class FlowPill extends StatefulWidget {
  const FlowPill({
    super.key,
    required this.icon,
    required this.label,
    this.onRemove,
    this.onTap,
    this.removeTooltip,
    this.tooltip,
    this.showLabel,
    this.enabled = true,
    this.padding,
    this.borderRadius,
    this.style,
  });

  /// The tool's glyph — always drawn; the pill's whole identity in the
  /// icon-only form.
  final IconData icon;

  /// The tool's name. Always the pill's accessible name, drawn only while
  /// the labeled form is in effect (see [showLabel]).
  final String label;

  /// Remove intent — the whole pill's tap, with the trailing X as its
  /// affordance. Null leaves the X off entirely: a static status pill.
  final VoidCallback? onRemove;

  /// Tap on the pill when it is *not* removable, e.g. reopening the
  /// tool's options. With [onRemove] set the pill's tap is removal and
  /// this is ignored.
  final VoidCallback? onTap;

  /// Host-localized name for the removal tap, e.g. 'Turn off Research' —
  /// the pill's tooltip while removable. Pass one whenever [onRemove] is
  /// set, or the affordance goes unexplained.
  final String? removeTooltip;

  /// Host-localized tooltip while the pill is not removable — the tool's
  /// name when a host forces the icon-only form on a hovering device.
  final String? tooltip;

  /// Whether the label is drawn. Null resolves by platform — hidden on
  /// iOS and Android (the design's compact composer), shown elsewhere —
  /// reading the theme's platform rather than the real one, like the
  /// menus' sheet resolution, so hosts and tests can steer it without a
  /// device.
  final bool? showLabel;

  final bool enabled;

  /// Inside the pill. Defaults to the design's 8 horizontally.
  final EdgeInsetsGeometry? padding;

  /// The pill's corner. Defaults to the design's 8.
  final BorderRadius? borderRadius;

  /// Per-instance restyling, merged over [FlowTheme.pillStyle]'s fields;
  /// nulls fall through to the theme tokens.
  final FlowPillStyle? style;

  @override
  State<FlowPill> createState() => _FlowPillState();
}

class _FlowPillState extends State<FlowPill> {
  /// The design's pill: 32 tall on an 8px corner, padded 8, an 18px glyph
  /// 6 from its label with the 14px X another 6 along — the gap closing
  /// to 4 in the icon-only form, per the compact composer.
  static const double _height = 32;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(8));
  static const EdgeInsetsGeometry _padding = EdgeInsets.symmetric(
    horizontal: 8,
  );
  static const double _iconSize = 18;
  static const double _removeSize = 14;
  static const double _gap = 6;
  static const double _compactGap = 4;

  bool _hovered = false;

  bool _labelVisible(BuildContext context) {
    final show = widget.showLabel;
    if (show != null) return show;
    final platform = Theme.of(context).platform;
    return platform != TargetPlatform.iOS && platform != TargetPlatform.android;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;
    final enabled = widget.enabled;
    final showLabel = _labelVisible(context);
    final gap = showLabel ? _gap : _compactGap;
    final hasRemove = widget.onRemove != null;

    // Removal is the pill's tap when it has one; a status pill may still
    // carry a body tap of its own.
    final VoidCallback? tapAction = hasRemove ? widget.onRemove : widget.onTap;

    final style =
        context.flowTheme.pillStyle?.merge(widget.style) ?? widget.style;

    // The glyph rests a step down in the secondary ink, the label in full
    // ink, and the X at the muted chrome level — lifting to full ink as
    // the pill is hovered. Disabled, all three take the disabled ink.
    final iconRest = style?.iconColor ?? colors.onSurfaceVariant;
    final iconForeground = enabled ? iconRest : colors.onSurfaceDisabled;
    final labelForeground = enabled
        ? colors.onSurface
        : colors.onSurfaceDisabled;
    final removeRest = enabled
        ? (style?.removeColor ?? colors.onSurfaceMuted)
        : colors.onSurfaceDisabled;
    final removeForeground = _hovered && enabled
        ? colors.onSurface
        : removeRest;

    final shape = RoundedRectangleBorder(
      borderRadius: widget.borderRadius ?? _radius,
      side: BorderSide(color: style?.borderColor ?? colors.outline),
    );

    // The X absorbs the end inset so the affordance reaches the pill's
    // edge; splitting the padding needs the resolved sides — start on the
    // body, end after the X — kept directional so RTL swaps them.
    final direction = Directionality.of(context);
    final resolved = (widget.padding ?? _padding).resolve(direction);
    final startInset = direction == TextDirection.ltr
        ? resolved.left
        : resolved.right;
    final endInset = direction == TextDirection.ltr
        ? resolved.right
        : resolved.left;

    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: startInset,
        end: endInset,
        top: resolved.top,
        bottom: resolved.bottom,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: _iconSize, color: iconForeground),
          if (showLabel) ...[
            const SizedBox(width: _gap),
            Text(
              widget.label,
              style: typography.labelMediumEmphasised
                  .copyWith(color: labelForeground)
                  .merge(style?.labelStyle),
            ),
          ],
          if (hasRemove) ...[
            SizedBox(width: gap),
            Icon(Icons.close, size: _removeSize, color: removeForeground),
          ],
        ],
      ),
    );

    // One control: the hover wash spans the whole pill and a tap anywhere
    // on it fires the pill's action.
    Widget pill = Material(
      color: style?.backgroundColor ?? colors.surfaceContainerLow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _height,
        child: tapAction == null
            ? content
            : InkWell(
                onTap: enabled ? tapAction : null,
                onHover: enabled
                    ? (value) => setState(() => _hovered = value)
                    : null,
                hoverColor: style?.hoverColor ?? colors.surfaceContainer,
                child: content,
              ),
      ),
    );

    // Excluding the subtree keeps the label from reading twice, but it
    // drops the InkWell's tap action with it — the node re-owns
    // activation or assistive tech could announce the pill yet not tap it.
    if (tapAction != null) {
      pill = Semantics(
        button: true,
        label: widget.label,
        excludeSemantics: true,
        onTap: enabled ? tapAction : null,
        child: pill,
      );
    } else if (!showLabel) {
      // The inert icon-only pill still announces the tool's name.
      pill = Semantics(
        label: widget.label,
        child: ExcludeSemantics(child: pill),
      );
    }

    // While removable, the removal name explains the whole pill's tap;
    // otherwise the body tooltip carries the tool's name.
    final tooltip = hasRemove
        ? (widget.removeTooltip ?? widget.tooltip)
        : widget.tooltip;
    if (tooltip != null) {
      pill = Tooltip(message: tooltip, child: pill);
    }

    return pill;
  }
}
