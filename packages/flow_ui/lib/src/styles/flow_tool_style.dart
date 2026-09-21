import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowTool]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.toolStyle] to restyle
/// every tool card — tool parts in a thread included; a widget's own
/// `style` wins field by field:
///
/// ```dart
/// FlowTool(
///   name: 'search_docs',
///   title: 'Searching the docs',
///   status: FlowToolStatus.running,
///   style: const FlowToolStyle(runningColor: Color(0xFFB65C33)),
/// )
/// ```
///
/// The four accents color the header's mark, one per status — the still
/// and the turning asterisk, the settled check, the error glyph — never
/// the words: the title reads in the ink ramp, so an accent that falls
/// short of WCAG AA for text still signals beside it. The nested code
/// blocks follow `FlowTheme.codeBlockStyle`, not this style.
@immutable
class FlowToolStyle {
  const FlowToolStyle({
    this.backgroundColor,
    this.borderColor,
    this.hoverBorderColor,
    this.hoverColor,
    this.pendingColor,
    this.runningColor,
    this.completeColor,
    this.errorColor,
    this.titleStyle,
    this.nameStyle,
    this.detailStyle,
    this.detailChipColor,
    this.dividerColor,
    this.errorMessageStyle,
  });

  /// The card's fill. Defaults to `surfaceContainerLowest`.
  final Color? backgroundColor;

  /// The card's hairline. Defaults to `outline`.
  final Color? borderColor;

  /// The hairline while hovered. Defaults to `outlineVariant`; when only
  /// [borderColor] is set, hover keeps that color instead of firming.
  final Color? hoverBorderColor;

  /// The header row's wash while hovered. Defaults to
  /// `surfaceContainerLow`.
  final Color? hoverColor;

  /// The still asterisk while pending. Defaults to `onSurfaceMuted`.
  final Color? pendingColor;

  /// The turning asterisk while running. Defaults to `onSurfaceMuted`.
  final Color? runningColor;

  /// The settled check. Defaults to `success`.
  final Color? completeColor;

  /// The error glyph. Defaults to `error`.
  final Color? errorColor;

  /// Merged over the title's default `labelMedium` + state ink. Its
  /// color only shows while static: the running shimmer draws with the
  /// muted and full inks.
  final TextStyle? titleStyle;

  /// Merged over the name's default `codeInline` + state ink, for a card
  /// with no title. Same shimmer caveat as [titleStyle].
  final TextStyle? nameStyle;

  /// Merged over the detail chip's default `codeInline` +
  /// `onSurfaceVariant` style.
  final TextStyle? detailStyle;

  /// The detail chip's fill. Defaults to `surfaceContainer`.
  final Color? detailChipColor;

  /// The rule between the header and the open body. Defaults to
  /// `outline`.
  final Color? dividerColor;

  /// Merged over the error message's default `bodyMedium` +
  /// `onSurfaceVariant` style.
  final TextStyle? errorMessageStyle;

  /// A copy where [other]'s fields win over this style's.
  FlowToolStyle merge(FlowToolStyle? other) {
    if (other == null) return this;
    return FlowToolStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      borderColor: other.borderColor ?? borderColor,
      hoverBorderColor: other.hoverBorderColor ?? hoverBorderColor,
      hoverColor: other.hoverColor ?? hoverColor,
      pendingColor: other.pendingColor ?? pendingColor,
      runningColor: other.runningColor ?? runningColor,
      completeColor: other.completeColor ?? completeColor,
      errorColor: other.errorColor ?? errorColor,
      titleStyle: other.titleStyle ?? titleStyle,
      nameStyle: other.nameStyle ?? nameStyle,
      detailStyle: other.detailStyle ?? detailStyle,
      detailChipColor: other.detailChipColor ?? detailChipColor,
      dividerColor: other.dividerColor ?? dividerColor,
      errorMessageStyle: other.errorMessageStyle ?? errorMessageStyle,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowToolStyle lerp(FlowToolStyle? other, double t) {
    if (other == null) return this;
    return FlowToolStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      hoverBorderColor: Color.lerp(hoverBorderColor, other.hoverBorderColor, t),
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t),
      pendingColor: Color.lerp(pendingColor, other.pendingColor, t),
      runningColor: Color.lerp(runningColor, other.runningColor, t),
      completeColor: Color.lerp(completeColor, other.completeColor, t),
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      nameStyle: TextStyle.lerp(nameStyle, other.nameStyle, t),
      detailStyle: TextStyle.lerp(detailStyle, other.detailStyle, t),
      detailChipColor: Color.lerp(detailChipColor, other.detailChipColor, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      errorMessageStyle: TextStyle.lerp(
        errorMessageStyle,
        other.errorMessageStyle,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowToolStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.hoverBorderColor == hoverBorderColor &&
        other.hoverColor == hoverColor &&
        other.pendingColor == pendingColor &&
        other.runningColor == runningColor &&
        other.completeColor == completeColor &&
        other.errorColor == errorColor &&
        other.titleStyle == titleStyle &&
        other.nameStyle == nameStyle &&
        other.detailStyle == detailStyle &&
        other.detailChipColor == detailChipColor &&
        other.dividerColor == dividerColor &&
        other.errorMessageStyle == errorMessageStyle;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    hoverBorderColor,
    hoverColor,
    pendingColor,
    runningColor,
    completeColor,
    errorColor,
    titleStyle,
    nameStyle,
    detailStyle,
    detailChipColor,
    dividerColor,
    errorMessageStyle,
  );
}
