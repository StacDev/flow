import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowToast]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.toastStyle] to restyle
/// every toast — the ones `showFlowToast` floats included; a widget's own
/// `style` wins field by field. The glyph is where a toast carries its
/// meaning, so the failure form is one override:
///
/// ```dart
/// showFlowToast(
///   context: context,
///   icon: Icons.error_outline,
///   message: 'Image upload failed. Try again',
///   style: FlowToastStyle(iconColor: context.flowColors.error),
/// )
/// ```
@immutable
class FlowToastStyle {
  const FlowToastStyle({
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    this.dismissIconColor,
    this.messageStyle,
  });

  /// The card's fill. Defaults to `surfaceBright` at 80%.
  final Color? backgroundColor;

  /// The card's hairline. Defaults to `outlineVariant`.
  final Color? borderColor;

  /// The leading glyph. Defaults to `onSurface`; a failure toast passes
  /// `error`, a success one `success`.
  final Color? iconColor;

  /// The dismiss cross. Defaults to `onSurfaceVariant`.
  final Color? dismissIconColor;

  /// Merged over the message's default `labelMediumEmphasised` +
  /// `onSurface` style.
  final TextStyle? messageStyle;

  /// A copy where [other]'s fields win over this style's.
  FlowToastStyle merge(FlowToastStyle? other) {
    if (other == null) return this;
    return FlowToastStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      borderColor: other.borderColor ?? borderColor,
      iconColor: other.iconColor ?? iconColor,
      dismissIconColor: other.dismissIconColor ?? dismissIconColor,
      messageStyle: other.messageStyle ?? messageStyle,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowToastStyle lerp(FlowToastStyle? other, double t) {
    if (other == null) return this;
    return FlowToastStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      dismissIconColor: Color.lerp(dismissIconColor, other.dismissIconColor, t),
      messageStyle: TextStyle.lerp(messageStyle, other.messageStyle, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowToastStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.iconColor == iconColor &&
        other.dismissIconColor == dismissIconColor &&
        other.messageStyle == messageStyle;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    iconColor,
    dismissIconColor,
    messageStyle,
  );
}
