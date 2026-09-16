import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// How a flow_ui menu presents when its trigger is tapped.
enum FlowMenuPresentation {
  /// A bottom sheet on iOS and Android, an anchored menu everywhere else.
  ///
  /// Resolved against `Theme.of(context).platform`, so a host (or a test)
  /// can steer it by overriding the ambient theme's platform.
  auto,

  /// Always an anchored menu, hanging off the trigger.
  menu,

  /// Always a modal bottom sheet.
  sheet,
}

/// Host overrides for a flow_ui menu's look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. One instance covers both presentations — the anchored
/// menu and the bottom sheet draw from the same palette. Install one on
/// [FlowTheme.menuStyle] to restyle every menu; a widget's own `menuStyle`
/// wins field by field:
///
/// ```dart
/// FlowModelSelector(
///   models: models,
///   menuStyle: const FlowMenuStyle(
///     backgroundColor: Color(0xFF102030),
///     labelStyle: TextStyle(fontSize: 15),
///   ),
/// )
/// ```
@immutable
class FlowMenuStyle {
  const FlowMenuStyle({
    this.backgroundColor,
    this.borderColor,
    this.separatorColor,
    this.hoverColor,
    this.labelStyle,
    this.descriptionStyle,
    this.iconColor,
    this.checkColor,
    this.accentColor,
    this.menuRadius,
    this.sheetRadius,
    this.minWidth,
    this.barrierColor,
  });

  /// The menu card and the sheet. Defaults to `surfaceBright`.
  final Color? backgroundColor;

  /// Hairline around the card and the sheet. The card's default is a
  /// gradient from ink at 20% to ink at 12%; setting this flattens it to
  /// one solid color. The sheet's default is `outlineVariant`.
  final Color? borderColor;

  /// Rule between sections. Defaults to `outlineVariant`.
  final Color? separatorColor;

  /// Row fill on hover and focus. Defaults to `surfaceContainer`.
  final Color? hoverColor;

  /// Merged over the default row label style (`labelMediumEmphasised` in
  /// the menu, `labelLargeEmphasised` in the sheet). A disabled row's label
  /// paints `onSurfaceDisabled` regardless of a color here.
  final TextStyle? labelStyle;

  /// Merged over the default description style (`labelMedium` in
  /// `onSurfaceMuted`); disabled paints `onSurfaceDisabled` regardless.
  final TextStyle? descriptionStyle;

  /// Leading row icons. Defaults to `onSurfaceVariant`; a disabled row
  /// paints `onSurfaceDisabled` regardless.
  final Color? iconColor;

  /// The selected check. Defaults to `primary`.
  final Color? checkColor;

  /// Accented trailing values, e.g. the chosen effort on its row.
  /// Defaults to `primary`.
  final Color? accentColor;

  /// Corner radius of the anchored menu card. Defaults to the design's 12.
  /// The bottom sheet's top corners come from [sheetRadius].
  final BorderRadius? menuRadius;

  /// The bottom sheet's top corners. Defaults to the design's 24.
  final Radius? sheetRadius;

  /// Minimum width of the anchored menu's rows. Defaults to 220.
  final double? minWidth;

  /// Scrim behind the bottom sheet. Defaults to the framework's.
  final Color? barrierColor;

  /// A copy where [other]'s fields win over this style's.
  FlowMenuStyle merge(FlowMenuStyle? other) {
    if (other == null) return this;
    return FlowMenuStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      borderColor: other.borderColor ?? borderColor,
      separatorColor: other.separatorColor ?? separatorColor,
      hoverColor: other.hoverColor ?? hoverColor,
      labelStyle: other.labelStyle ?? labelStyle,
      descriptionStyle: other.descriptionStyle ?? descriptionStyle,
      iconColor: other.iconColor ?? iconColor,
      checkColor: other.checkColor ?? checkColor,
      accentColor: other.accentColor ?? accentColor,
      menuRadius: other.menuRadius ?? menuRadius,
      sheetRadius: other.sheetRadius ?? sheetRadius,
      minWidth: other.minWidth ?? minWidth,
      barrierColor: other.barrierColor ?? barrierColor,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowMenuStyle lerp(FlowMenuStyle? other, double t) {
    if (other == null) return this;
    return FlowMenuStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      separatorColor: Color.lerp(separatorColor, other.separatorColor, t),
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      descriptionStyle: TextStyle.lerp(
        descriptionStyle,
        other.descriptionStyle,
        t,
      ),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      checkColor: Color.lerp(checkColor, other.checkColor, t),
      accentColor: Color.lerp(accentColor, other.accentColor, t),
      menuRadius: BorderRadius.lerp(menuRadius, other.menuRadius, t),
      sheetRadius: Radius.lerp(sheetRadius, other.sheetRadius, t),
      minWidth: lerpDouble(minWidth, other.minWidth, t),
      barrierColor: Color.lerp(barrierColor, other.barrierColor, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowMenuStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.separatorColor == separatorColor &&
        other.hoverColor == hoverColor &&
        other.labelStyle == labelStyle &&
        other.descriptionStyle == descriptionStyle &&
        other.iconColor == iconColor &&
        other.checkColor == checkColor &&
        other.accentColor == accentColor &&
        other.menuRadius == menuRadius &&
        other.sheetRadius == sheetRadius &&
        other.minWidth == minWidth &&
        other.barrierColor == barrierColor;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    separatorColor,
    hoverColor,
    labelStyle,
    descriptionStyle,
    iconColor,
    checkColor,
    accentColor,
    menuRadius,
    sheetRadius,
    minWidth,
    barrierColor,
  );
}
