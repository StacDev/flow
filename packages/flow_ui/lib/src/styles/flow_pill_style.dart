import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowPill]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.pillStyle] to restyle
/// every pill; a widget's own `style` wins field by field:
///
/// ```dart
/// FlowPill(
///   icon: icon,
///   label: 'Research',
///   style: const FlowPillStyle(backgroundColor: Color(0x1433A060)),
/// )
/// ```
@immutable
class FlowPillStyle {
  const FlowPillStyle({
    this.backgroundColor,
    this.hoverColor,
    this.borderColor,
    this.iconColor,
    this.labelStyle,
    this.removeColor,
  });

  /// The pill's fill. Defaults to `surfaceContainerLow`.
  final Color? backgroundColor;

  /// The fill while hovered. Defaults to `surfaceContainer`.
  final Color? hoverColor;

  /// The pill's hairline. Defaults to `outline`.
  final Color? borderColor;

  /// The leading icon. Defaults to `onSurfaceVariant`; disabled paints
  /// `onSurfaceDisabled` regardless.
  final Color? iconColor;

  /// Merged over the default `labelMediumEmphasised` + `onSurface` label.
  final TextStyle? labelStyle;

  /// The remove X at rest. Defaults to `onSurfaceMuted`; hover lifts it
  /// to `onSurface`, and disabled paints `onSurfaceDisabled`, regardless.
  final Color? removeColor;

  /// A copy where [other]'s fields win over this style's.
  FlowPillStyle merge(FlowPillStyle? other) {
    if (other == null) return this;
    return FlowPillStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      hoverColor: other.hoverColor ?? hoverColor,
      borderColor: other.borderColor ?? borderColor,
      iconColor: other.iconColor ?? iconColor,
      labelStyle: other.labelStyle ?? labelStyle,
      removeColor: other.removeColor ?? removeColor,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowPillStyle lerp(FlowPillStyle? other, double t) {
    if (other == null) return this;
    return FlowPillStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      removeColor: Color.lerp(removeColor, other.removeColor, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowPillStyle &&
        other.backgroundColor == backgroundColor &&
        other.hoverColor == hoverColor &&
        other.borderColor == borderColor &&
        other.iconColor == iconColor &&
        other.labelStyle == labelStyle &&
        other.removeColor == removeColor;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    hoverColor,
    borderColor,
    iconColor,
    labelStyle,
    removeColor,
  );
}
