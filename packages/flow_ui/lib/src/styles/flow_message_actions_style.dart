import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowMessageActions]' look, on top of the theme
/// tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.messageActionsStyle] to
/// restyle every actions row; a widget's own `style` wins field by field:
///
/// ```dart
/// FlowMessageActions(
///   actions: actions,
///   style: const FlowMessageActionsStyle(selectedColor: Color(0xFF33A060)),
/// )
/// ```
@immutable
class FlowMessageActionsStyle {
  const FlowMessageActionsStyle({
    this.iconColor,
    this.hoverIconColor,
    this.selectedColor,
    this.hoverColor,
  });

  /// Action icons at rest. Defaults to `onSurfaceMuted`; a disabled action
  /// paints `onSurfaceDisabled` regardless.
  final Color? iconColor;

  /// Action icons while hovered. Defaults to `onSurface`.
  final Color? hoverIconColor;

  /// A selected action's icon (a chosen thumb). Defaults to `primary`.
  final Color? selectedColor;

  /// The wash behind a hovered action. Defaults to `surfaceContainer`.
  final Color? hoverColor;

  /// A copy where [other]'s fields win over this style's.
  FlowMessageActionsStyle merge(FlowMessageActionsStyle? other) {
    if (other == null) return this;
    return FlowMessageActionsStyle(
      iconColor: other.iconColor ?? iconColor,
      hoverIconColor: other.hoverIconColor ?? hoverIconColor,
      selectedColor: other.selectedColor ?? selectedColor,
      hoverColor: other.hoverColor ?? hoverColor,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowMessageActionsStyle lerp(FlowMessageActionsStyle? other, double t) {
    if (other == null) return this;
    return FlowMessageActionsStyle(
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      hoverIconColor: Color.lerp(hoverIconColor, other.hoverIconColor, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowMessageActionsStyle &&
        other.iconColor == iconColor &&
        other.hoverIconColor == hoverIconColor &&
        other.selectedColor == selectedColor &&
        other.hoverColor == hoverColor;
  }

  @override
  int get hashCode =>
      Object.hash(iconColor, hoverIconColor, selectedColor, hoverColor);
}
