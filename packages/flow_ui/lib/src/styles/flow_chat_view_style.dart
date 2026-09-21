import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowChatView]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.chatViewStyle] to
/// restyle every surface; a widget's own `style` wins field by field:
///
/// ```dart
/// FlowChatView(
///   onAttachmentsDropped: addAttachments,
///   dropLabel: 'Drop files to add to chat',
///   style: FlowChatViewStyle(
///     dropGradient: LinearGradient(
///       begin: Alignment.topCenter,
///       end: Alignment.bottomCenter,
///       colors: [Color(0xCCFFFFFF), Color(0xF2FFFFFF)],
///     ),
///   ),
/// )
/// ```
///
/// Everything here is the drop treatment, which is the one part of the
/// surface with a look of its own — the thread and the composer carry
/// their own styles.
@immutable
class FlowChatViewStyle {
  const FlowChatViewStyle({
    this.dropGradient,
    this.dropIconColor,
    this.dropLabelStyle,
  });

  /// The wash the drop treatment paints over the blurred surface.
  /// Defaults to
  /// the design's vertical gradient — `surfaceBright` at 40% down to
  /// `surface` at 80% — so the page reads through it without competing
  /// with the label.
  ///
  /// Any [Gradient] works — swap in a radial or change the stops to match
  /// a design file. For a flat tint, use a [LinearGradient] with the same
  /// colour at both ends.
  final Gradient? dropGradient;

  /// The drop glyph. Defaults to `onSurface`.
  final Color? dropIconColor;

  /// Merged over the label's default `titleSmallEmphasised` +
  /// `onSurface` style.
  final TextStyle? dropLabelStyle;

  /// A copy where [other]'s fields win over this style's.
  FlowChatViewStyle merge(FlowChatViewStyle? other) {
    if (other == null) return this;
    return FlowChatViewStyle(
      dropGradient: other.dropGradient ?? dropGradient,
      dropIconColor: other.dropIconColor ?? dropIconColor,
      dropLabelStyle: other.dropLabelStyle ?? dropLabelStyle,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowChatViewStyle lerp(FlowChatViewStyle? other, double t) {
    if (other == null) return this;
    return FlowChatViewStyle(
      dropGradient: Gradient.lerp(dropGradient, other.dropGradient, t),
      dropIconColor: Color.lerp(dropIconColor, other.dropIconColor, t),
      dropLabelStyle: TextStyle.lerp(dropLabelStyle, other.dropLabelStyle, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowChatViewStyle &&
        other.dropGradient == dropGradient &&
        other.dropIconColor == dropIconColor &&
        other.dropLabelStyle == dropLabelStyle;
  }

  @override
  int get hashCode => Object.hash(dropGradient, dropIconColor, dropLabelStyle);
}
