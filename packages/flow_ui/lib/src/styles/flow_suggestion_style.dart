import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowSuggestion]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.suggestionStyle] to
/// restyle every suggestion; a widget's own `style` wins field by field:
///
/// ```dart
/// FlowSuggestion(
///   label: 'Plan my week',
///   style: const FlowSuggestionStyle(borderColor: Color(0x33336699)),
/// )
/// ```
@immutable
class FlowSuggestionStyle {
  const FlowSuggestionStyle({
    this.backgroundColor,
    this.borderColor,
    this.hoverColor,
    this.foregroundColor,
    this.labelStyle,
  });

  /// The row's fill. Defaults to ink at 2% on the outlined form and
  /// transparent on the plain one.
  final Color? backgroundColor;

  /// The outlined form's hairline. Defaults to `outline`; the
  /// plain form draws none regardless.
  final Color? borderColor;

  /// The fill while hovered. Defaults to `surfaceContainerLow`.
  final Color? hoverColor;

  /// Icon and label ink at rest. Defaults to `onSurface` on the outlined
  /// form and `onSurfaceVariant` on the plain one; hover lifts both to
  /// `onSurface`, and disabled paints `onSurfaceDisabled`, regardless.
  final Color? foregroundColor;

  /// Merged over the default label style.
  final TextStyle? labelStyle;

  /// A copy where [other]'s fields win over this style's.
  FlowSuggestionStyle merge(FlowSuggestionStyle? other) {
    if (other == null) return this;
    return FlowSuggestionStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      borderColor: other.borderColor ?? borderColor,
      hoverColor: other.hoverColor ?? hoverColor,
      foregroundColor: other.foregroundColor ?? foregroundColor,
      labelStyle: other.labelStyle ?? labelStyle,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowSuggestionStyle lerp(FlowSuggestionStyle? other, double t) {
    if (other == null) return this;
    return FlowSuggestionStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t),
      foregroundColor: Color.lerp(foregroundColor, other.foregroundColor, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowSuggestionStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.hoverColor == hoverColor &&
        other.foregroundColor == foregroundColor &&
        other.labelStyle == labelStyle;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    hoverColor,
    foregroundColor,
    labelStyle,
  );
}
