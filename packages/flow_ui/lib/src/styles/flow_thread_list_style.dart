import 'package:material_ui/material_ui.dart';

/// Host overrides for [FlowThreadList]'s look, on top of the theme tokens.
///
/// Every field is optional; null falls back to the token-derived default
/// noted on the field. Install one on [FlowTheme.threadListStyle] to
/// restyle every thread list; a widget's own `style` wins field by field:
///
/// ```dart
/// FlowThreadList(
///   sections: sections,
///   style: const FlowThreadListStyle(unreadDotColor: Color(0xFF3366CC)),
/// )
/// ```
///
/// There is deliberately no background field: the list is transparent,
/// and the panel the host mounts it in owns the ground.
@immutable
class FlowThreadListStyle {
  const FlowThreadListStyle({
    this.selectedColor,
    this.hoverColor,
    this.titleStyle,
    this.sectionLabelStyle,
    this.iconColor,
    this.pinColor,
    this.unreadDotColor,
  });

  /// The selected row's fill. Defaults to `surfaceContainer`, the
  /// ladder's selected-row rung.
  final Color? selectedColor;

  /// A row's fill while hovered. Defaults to `surfaceContainerLow`;
  /// translucent, so it composites over the selected fill.
  final Color? hoverColor;

  /// Merged over a title's default — `labelMedium` + `onSurface`, in the
  /// emphasised cut while the thread is unread.
  final TextStyle? titleStyle;

  /// Merged over a section header's default `labelSmall` +
  /// `onSurfaceMuted`.
  final TextStyle? sectionLabelStyle;

  /// A thread's leading glyph. Defaults to `onSurfaceVariant`.
  final Color? iconColor;

  /// The pinned glyph. Defaults to `onSurfaceMuted`.
  final Color? pinColor;

  /// The unread dot. Defaults to `primary`.
  final Color? unreadDotColor;

  /// A copy where [other]'s fields win over this style's.
  FlowThreadListStyle merge(FlowThreadListStyle? other) {
    if (other == null) return this;
    return FlowThreadListStyle(
      selectedColor: other.selectedColor ?? selectedColor,
      hoverColor: other.hoverColor ?? hoverColor,
      titleStyle: other.titleStyle ?? titleStyle,
      sectionLabelStyle: other.sectionLabelStyle ?? sectionLabelStyle,
      iconColor: other.iconColor ?? iconColor,
      pinColor: other.pinColor ?? pinColor,
      unreadDotColor: other.unreadDotColor ?? unreadDotColor,
    );
  }

  /// Linear interpolation, for theme transitions. A null [other] returns
  /// this style unchanged.
  FlowThreadListStyle lerp(FlowThreadListStyle? other, double t) {
    if (other == null) return this;
    return FlowThreadListStyle(
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      sectionLabelStyle: TextStyle.lerp(
        sectionLabelStyle,
        other.sectionLabelStyle,
        t,
      ),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      pinColor: Color.lerp(pinColor, other.pinColor, t),
      unreadDotColor: Color.lerp(unreadDotColor, other.unreadDotColor, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlowThreadListStyle &&
        other.selectedColor == selectedColor &&
        other.hoverColor == hoverColor &&
        other.titleStyle == titleStyle &&
        other.sectionLabelStyle == sectionLabelStyle &&
        other.iconColor == iconColor &&
        other.pinColor == pinColor &&
        other.unreadDotColor == unreadDotColor;
  }

  @override
  int get hashCode => Object.hash(
    selectedColor,
    hoverColor,
    titleStyle,
    sectionLabelStyle,
    iconColor,
    pinColor,
    unreadDotColor,
  );
}
