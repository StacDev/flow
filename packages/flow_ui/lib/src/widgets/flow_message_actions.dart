import 'package:material_ui/material_ui.dart';

import '../styles/flow_message_actions_style.dart';
import '../theme/flow_theme.dart';

/// One action in a [FlowMessageActions] row.
///
/// Purely descriptive: an icon, an intent callback, and optional
/// host-localized [tooltip] — the package ships no strings. The named
/// constructors are icon presets for the common chat actions.
@immutable
class FlowMessageAction {
  const FlowMessageAction({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.selected = false,
    this.selectedIcon,
  });

  /// Copy the message content.
  const FlowMessageAction.copy({this.onPressed, this.tooltip})
    : icon = Icons.copy_outlined,
      selected = false,
      selectedIcon = null;

  /// Regenerate the response.
  const FlowMessageAction.regenerate({this.onPressed, this.tooltip})
    : icon = Icons.refresh,
      selected = false,
      selectedIcon = null;

  /// Edit the message.
  const FlowMessageAction.edit({this.onPressed, this.tooltip})
    : icon = Icons.edit_outlined,
      selected = false,
      selectedIcon = null;

  /// Positive feedback; toggles to a filled thumb when [selected].
  const FlowMessageAction.thumbUp({
    this.onPressed,
    this.tooltip,
    this.selected = false,
  }) : icon = Icons.thumb_up_outlined,
       selectedIcon = Icons.thumb_up;

  /// Negative feedback; toggles to a filled thumb when [selected].
  const FlowMessageAction.thumbDown({
    this.onPressed,
    this.tooltip,
    this.selected = false,
  }) : icon = Icons.thumb_down_outlined,
       selectedIcon = Icons.thumb_down;

  final IconData icon;

  /// Shown instead of [icon] while [selected] (e.g. a filled thumb).
  final IconData? selectedIcon;

  /// Null renders the action disabled.
  final VoidCallback? onPressed;

  /// Host-localized tooltip; omitted → no tooltip.
  final String? tooltip;

  /// Toggled state, tinted with the primary color.
  final bool selected;
}

/// Compact icon-button row for message actions — designed for the
/// `footer` slot of a `FlowMessage`:
///
/// ```dart
/// FlowMessage(
///   message,
///   footer: FlowMessageActions(actions: [
///     FlowMessageAction.copy(tooltip: 'Copy', onPressed: ...),
///     FlowMessageAction.thumbUp(selected: liked, onPressed: ...),
///   ]),
/// )
/// ```
class FlowMessageActions extends StatelessWidget {
  const FlowMessageActions({
    super.key,
    required this.actions,
    this.iconSize = 15,
    this.padding,
    this.style,
  });

  /// The design's strip sets the frames 4 apart — a component spec
  /// value, not a scale step.
  static const double _gap = 4;

  /// Rendered in order.
  final List<FlowMessageAction> actions;

  /// Compact by default, per the design.
  final double iconSize;

  /// Around the whole row; defaults to none.
  final EdgeInsetsGeometry? padding;

  /// Per-instance restyling, merged over [FlowTheme.messageActionsStyle]'s
  /// fields; nulls fall through to the theme tokens.
  final FlowMessageActionsStyle? style;

  @override
  Widget build(BuildContext context) {
    final effective =
        context.flowTheme.messageActionsStyle?.merge(style) ?? style;
    // The design's action strip: 15px glyphs on 20px frames, 4 apart.
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          _ActionButton(
            action: actions[i],
            iconSize: iconSize,
            style: effective,
          ),
        ],
      ],
    );
    if (padding == null) return row;
    return Padding(padding: padding!, child: row);
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.action,
    required this.iconSize,
    this.style,
  });

  final FlowMessageAction action;
  final double iconSize;
  final FlowMessageActionsStyle? style;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  /// The spec frame: a host's `iconSize` resizes the glyph inside it,
  /// never the strip — an oversize glyph overflows.
  static const double _frameSize = 20;

  /// The frame's corner, tighter than any shared step reads at this size.
  static const BorderRadius _frameRadius = BorderRadius.all(Radius.circular(2));

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final action = widget.action;
    final enabled = action.onPressed != null;

    // Rest at the muted ink — the design's 50% for message-action glyphs —
    // lifting to full ink on hover so the affordance stays.
    final style = widget.style;
    final rest = style?.iconColor ?? colors.onSurfaceMuted;
    final Color foreground;
    if (!enabled) {
      foreground = colors.onSurfaceDisabled;
    } else if (action.selected) {
      foreground = style?.selectedColor ?? colors.primary;
    } else if (_hovered) {
      foreground = style?.hoverIconColor ?? colors.onSurface;
    } else {
      foreground = rest;
    }

    // Transparent Material so ink and hover fills render anywhere,
    // including inside decorated containers.
    Widget button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: action.onPressed,
        onHover: enabled ? (value) => setState(() => _hovered = value) : null,
        borderRadius: _frameRadius,
        hoverColor: style?.hoverColor ?? colors.surfaceContainer,
        child: SizedBox.square(
          dimension: _frameSize,
          child: Center(
            child: Icon(
              action.selected
                  ? (action.selectedIcon ?? action.icon)
                  : action.icon,
              size: widget.iconSize,
              color: foreground,
            ),
          ),
        ),
      ),
    );

    final tooltip = action.tooltip;
    if (tooltip != null) {
      button = Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}
