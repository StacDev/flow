import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowComposer]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.composerStyle] to restyle
/// every composer; a widget's own `style` wins field by field:
///
/// ```dart
/// FlowComposer(
///   onSend: send,
///   style: const FlowComposerStyle(
///     backgroundColor: Color(0xFF102030),
///     sendBackgroundColor: Color(0xFFB65C33),
///   ),
/// )
/// ```
@immutable
class FlowComposerStyle {
  const FlowComposerStyle({
    this.backgroundColor,
    this.outlineColor,
    this.sendBackgroundColor,
    this.sendForegroundColor,
    this.textStyle,
    this.hintColor,
    this.attachIconColor,
    this.dropHighlightColor,
    this.errorBackgroundColor,
    this.errorForegroundColor,
  });

  /// The card's fill. Defaults to `surfaceBright`, the raised card's
  /// ground in both themes.
  final Color? backgroundColor;

  /// The card's 1px hairline. The default is a gradient from ink at 14%
  /// to ink at 8% (20% to 12% while hovered or focused); setting this
  /// flattens it to one solid color in every state.
  final Color? outlineColor;

  /// The send/stop disc. Defaults to `primary`.
  final Color? sendBackgroundColor;

  /// The glyph on the send/stop disc. Defaults to `onPrimary`.
  final Color? sendForegroundColor;

  /// Merged over the field's default `bodyLarge` + `onSurface` on the
  /// compressed composer's 1.3 line; a `height` here replaces that.
  final TextStyle? textStyle;

  /// The placeholder hint. Defaults to `onSurfaceMuted`.
  final Color? hintColor;

  /// The attach button's resting glyph. Defaults to `onSurfaceVariant`;
  /// hover still lifts it to `onSurface` regardless.
  final Color? attachIconColor;

  /// What the card lights up in while a file is dragged over it, when
  /// the composer owns the drop (`onAttachmentsDropped`). Defaults to
  /// `primary`: it paints the hairline solid and washes the card's fill
  /// at 6%. Unused when nothing is wired to drop.
  final Color? dropHighlightColor;

  /// The error banner's wash and its hairline — the tab above the card
  /// that `errorMessage` raises. Defaults to `errorContainer`.
  final Color? errorBackgroundColor;

  /// The error banner's glyph and text. Defaults to `onErrorContainer`.
  final Color? errorForegroundColor;

  /// A copy where [other]'s fields win over this style's.
  FlowComposerStyle merge(FlowComposerStyle? other) {
    if (other == null) return this;
    return FlowComposerStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      outlineColor: other.outlineColor ?? outlineColor,
      sendBackgroundColor: other.sendBackgroundColor ?? sendBackgroundColor,
      sendForegroundColor: other.sendForegroundColor ?? sendForegroundColor,
      textStyle: other.textStyle ?? textStyle,
      hintColor: other.hintColor ?? hintColor,
      attachIconColor: other.attachIconColor ?? attachIconColor,
      dropHighlightColor: other.dropHighlightColor ?? dropHighlightColor,
      errorBackgroundColor: other.errorBackgroundColor ?? errorBackgroundColor,
      errorForegroundColor: other.errorForegroundColor ?? errorForegroundColor,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowComposerStyle lerp(FlowComposerStyle? other, double t) {
    if (other == null) return this;
    return FlowComposerStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t),
      sendBackgroundColor: Color.lerp(
        sendBackgroundColor,
        other.sendBackgroundColor,
        t,
      ),
      sendForegroundColor: Color.lerp(
        sendForegroundColor,
        other.sendForegroundColor,
        t,
      ),
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
      hintColor: Color.lerp(hintColor, other.hintColor, t),
      attachIconColor: Color.lerp(attachIconColor, other.attachIconColor, t),
      dropHighlightColor: Color.lerp(
        dropHighlightColor,
        other.dropHighlightColor,
        t,
      ),
      errorBackgroundColor: Color.lerp(
        errorBackgroundColor,
        other.errorBackgroundColor,
        t,
      ),
      errorForegroundColor: Color.lerp(
        errorForegroundColor,
        other.errorForegroundColor,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowComposerStyle &&
        other.backgroundColor == backgroundColor &&
        other.outlineColor == outlineColor &&
        other.sendBackgroundColor == sendBackgroundColor &&
        other.sendForegroundColor == sendForegroundColor &&
        other.textStyle == textStyle &&
        other.hintColor == hintColor &&
        other.attachIconColor == attachIconColor &&
        other.dropHighlightColor == dropHighlightColor &&
        other.errorBackgroundColor == errorBackgroundColor &&
        other.errorForegroundColor == errorForegroundColor;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    outlineColor,
    sendBackgroundColor,
    sendForegroundColor,
    textStyle,
    hintColor,
    attachIconColor,
    dropHighlightColor,
    errorBackgroundColor,
    errorForegroundColor,
  );
}
