import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowConfirmation]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.confirmationStyle] to
/// restyle every confirmation card — confirmation parts in a thread
/// included; a widget's own `style` wins field by field:
///
/// ```dart
/// FlowConfirmation(
///   title: 'Approval required',
///   message: 'Delete 3 files in drafts/?',
///   style: const FlowConfirmationStyle(pendingColor: Color(0xFFB65C33)),
/// )
/// ```
///
/// The three accents color a state's marks — the header asterisk, the
/// settled glyph and its wash — so one override recolors a state
/// coherently. The title and the settled label read in the ink ramp, not
/// the accent: the light accents fall short of WCAG AA for text on the
/// card, so the words stay legible and the accent signals beside them.
@immutable
class FlowConfirmationStyle {
  const FlowConfirmationStyle({
    this.backgroundColor,
    this.borderColor,
    this.pendingColor,
    this.approvedColor,
    this.rejectedColor,
    this.titleStyle,
    this.messageStyle,
    this.approveButtonColor,
    this.approveButtonForegroundColor,
    this.rejectButtonColor,
    this.rejectButtonBorderColor,
    this.rejectButtonForegroundColor,
  });

  /// The card's fill. Defaults to `surfaceBright`.
  final Color? backgroundColor;

  /// The card's hairline. Defaults to `outline`.
  final Color? borderColor;

  /// The pending accent. Defaults to `warning`.
  final Color? pendingColor;

  /// The approved accent. Defaults to `success`.
  final Color? approvedColor;

  /// The rejected accent. Defaults to `error`.
  final Color? rejectedColor;

  /// Merged over the title's default `labelSmallEmphasised` +
  /// `onSurfaceVariant` style.
  final TextStyle? titleStyle;

  /// Merged over the message's default `bodyMedium` + `onSurface` style.
  final TextStyle? messageStyle;

  /// The approve button's fill. Defaults to `inverseSurface`.
  final Color? approveButtonColor;

  /// The approve button's ink. Defaults to `onInverseSurface`.
  final Color? approveButtonForegroundColor;

  /// The reject button's fill. Defaults to `surfaceContainerLowest`.
  final Color? rejectButtonColor;

  /// The reject button's hairline. Defaults to `outlineVariant`.
  final Color? rejectButtonBorderColor;

  /// The reject button's resting ink. Defaults to `onSurfaceVariant`,
  /// lifting to `onSurface` on hover.
  final Color? rejectButtonForegroundColor;

  /// A copy where [other]'s fields win over this style's.
  FlowConfirmationStyle merge(FlowConfirmationStyle? other) {
    if (other == null) return this;
    return FlowConfirmationStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      borderColor: other.borderColor ?? borderColor,
      pendingColor: other.pendingColor ?? pendingColor,
      approvedColor: other.approvedColor ?? approvedColor,
      rejectedColor: other.rejectedColor ?? rejectedColor,
      titleStyle: other.titleStyle ?? titleStyle,
      messageStyle: other.messageStyle ?? messageStyle,
      approveButtonColor: other.approveButtonColor ?? approveButtonColor,
      approveButtonForegroundColor:
          other.approveButtonForegroundColor ?? approveButtonForegroundColor,
      rejectButtonColor: other.rejectButtonColor ?? rejectButtonColor,
      rejectButtonBorderColor:
          other.rejectButtonBorderColor ?? rejectButtonBorderColor,
      rejectButtonForegroundColor:
          other.rejectButtonForegroundColor ?? rejectButtonForegroundColor,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowConfirmationStyle lerp(FlowConfirmationStyle? other, double t) {
    if (other == null) return this;
    return FlowConfirmationStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      pendingColor: Color.lerp(pendingColor, other.pendingColor, t),
      approvedColor: Color.lerp(approvedColor, other.approvedColor, t),
      rejectedColor: Color.lerp(rejectedColor, other.rejectedColor, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      messageStyle: TextStyle.lerp(messageStyle, other.messageStyle, t),
      approveButtonColor: Color.lerp(
        approveButtonColor,
        other.approveButtonColor,
        t,
      ),
      approveButtonForegroundColor: Color.lerp(
        approveButtonForegroundColor,
        other.approveButtonForegroundColor,
        t,
      ),
      rejectButtonColor: Color.lerp(
        rejectButtonColor,
        other.rejectButtonColor,
        t,
      ),
      rejectButtonBorderColor: Color.lerp(
        rejectButtonBorderColor,
        other.rejectButtonBorderColor,
        t,
      ),
      rejectButtonForegroundColor: Color.lerp(
        rejectButtonForegroundColor,
        other.rejectButtonForegroundColor,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowConfirmationStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.pendingColor == pendingColor &&
        other.approvedColor == approvedColor &&
        other.rejectedColor == rejectedColor &&
        other.titleStyle == titleStyle &&
        other.messageStyle == messageStyle &&
        other.approveButtonColor == approveButtonColor &&
        other.approveButtonForegroundColor == approveButtonForegroundColor &&
        other.rejectButtonColor == rejectButtonColor &&
        other.rejectButtonBorderColor == rejectButtonBorderColor &&
        other.rejectButtonForegroundColor == rejectButtonForegroundColor;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    pendingColor,
    approvedColor,
    rejectedColor,
    titleStyle,
    messageStyle,
    approveButtonColor,
    approveButtonForegroundColor,
    rejectButtonColor,
    rejectButtonBorderColor,
    rejectButtonForegroundColor,
  );
}
