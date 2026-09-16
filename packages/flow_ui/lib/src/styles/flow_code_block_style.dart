import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowCodeBlock]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Token inks inside the code come from the theme's
/// `FlowSyntaxColors`, not from here. Install one on
/// [FlowTheme.codeBlockStyle] to restyle every block — fences in markdown
/// included; a widget's own `style` wins field by field:
///
/// ```dart
/// FlowCodeBlock(
///   code: source,
///   language: 'dart',
///   style: const FlowCodeBlockStyle(
///     backgroundColor: Colors.transparent,
///     borderColor: Colors.transparent,
///   ),
/// )
/// ```
@immutable
class FlowCodeBlockStyle {
  const FlowCodeBlockStyle({
    this.backgroundColor,
    this.borderColor,
    this.hoverBorderColor,
    this.headerStyle,
    this.codeStyle,
  });

  /// The card's fill. Defaults to `surfaceContainerLowest`. Transparent
  /// lets the code sit directly on the host's own surface.
  final Color? backgroundColor;

  /// The card's hairline. Defaults to `outline`; transparent
  /// renders the block borderless.
  final Color? borderColor;

  /// The hairline while hovered. Defaults to `outlineVariant`;
  /// when only [borderColor] is set, hover keeps that color instead of
  /// firming.
  final Color? hoverBorderColor;

  /// Merged over the header label's default `labelMedium` +
  /// `onSurfaceMuted` style.
  final TextStyle? headerStyle;

  /// Merged over the code's default `code` + `onSurface` style. Token
  /// colors from `FlowSyntaxColors` still apply per span.
  final TextStyle? codeStyle;

  /// A copy where [other]'s fields win over this style's.
  FlowCodeBlockStyle merge(FlowCodeBlockStyle? other) {
    if (other == null) return this;
    return FlowCodeBlockStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      borderColor: other.borderColor ?? borderColor,
      hoverBorderColor: other.hoverBorderColor ?? hoverBorderColor,
      headerStyle: other.headerStyle ?? headerStyle,
      codeStyle: other.codeStyle ?? codeStyle,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowCodeBlockStyle lerp(FlowCodeBlockStyle? other, double t) {
    if (other == null) return this;
    return FlowCodeBlockStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      hoverBorderColor: Color.lerp(hoverBorderColor, other.hoverBorderColor, t),
      headerStyle: TextStyle.lerp(headerStyle, other.headerStyle, t),
      codeStyle: TextStyle.lerp(codeStyle, other.codeStyle, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowCodeBlockStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.hoverBorderColor == hoverBorderColor &&
        other.headerStyle == headerStyle &&
        other.codeStyle == codeStyle;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    hoverBorderColor,
    headerStyle,
    codeStyle,
  );
}
