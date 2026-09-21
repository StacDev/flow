import 'package:material_ui/material_ui.dart';

import '../styles/flow_menu_style.dart';
import '../theme/flow_theme.dart';
import 'flow_gradient_outline.dart';
import 'flow_menu_sheet.dart';

// Internal menu infrastructure shared by the selector widgets.
// Not exported from the package barrel.

/// The menu card's edges and fills, as alphas over the ink.
///
/// The outline is the composer's active gradient — a menu floats over
/// arbitrary content, so the design draws its edge a step firmer than the
/// cards that sit in the page — and rows wash with the same 6% ink the
/// triggers use while open.
const double _borderOpacity = 0.2;
const double _borderFadeOpacity = 0.12;

/// The card's lift: the theme's shadow ink at the composer's blur.
const double _shadowBlur = 12;

/// The design's menu metrics: a 12px card standing 14 above and 16 below
/// its rows' text (6/8 here plus the rows' own 8), rows padded 16/8 with a
/// 12px icon gap, and hairline rules inset like the rows and sitting a
/// step closer to the section they close.
const BorderRadius _menuRadius = BorderRadius.all(Radius.circular(12));
const EdgeInsetsGeometry _cardPadding = EdgeInsets.only(top: 6, bottom: 8);

/// The sheet's rows: inset 20 from the sheet's edge, their 9s pairing into
/// the design's 18 between neighbouring rows' text. Sheet rules share the
/// same rhythm.
const EdgeInsetsGeometry _rowPadding = EdgeInsets.symmetric(
  horizontal: 20,
  vertical: 9,
);
const EdgeInsetsGeometry _dividerMargin = EdgeInsets.fromLTRB(16, 6, 16, 4);
const EdgeInsetsGeometry _sheetDividerMargin = EdgeInsets.symmetric(
  horizontal: 20,
  vertical: 9,
);

/// In the anchored menu the hover wash is a chip, not a bar: inset 8 from
/// the card's edge on 8px corners, its content padded 8 so the text keeps
/// the design's 16 from the edge. The sheet keeps edge-to-edge rows on
/// [_rowPadding].
const double _rowOuterInset = 8;
const Radius _rowRadius = Radius.circular(8);
const EdgeInsetsGeometry _menuRowPadding = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 8,
);

/// The design's 2px between a row's label and its description.
const double _descriptionGap = 2;

/// The gap between a row's leading icon and its label — shared with the
/// SubmenuButton rows built outside this file, so neighbouring rows in one
/// menu can't drift out of column.
const double flowMenuIconGap = 12;
const double _valueGap = 8;
const double _checkGap = 12;
const double _chevronGap = 4;

/// Whether [presentation] means a bottom sheet in this context.
bool flowMenuPresentsAsSheet(
  BuildContext context,
  FlowMenuPresentation presentation,
) {
  switch (presentation) {
    case FlowMenuPresentation.menu:
      return false;
    case FlowMenuPresentation.sheet:
      return true;
    case FlowMenuPresentation.auto:
      // The theme's platform rather than the real one, so hosts and tests
      // can steer the resolution without a device.
      final platform = Theme.of(context).platform;
      return platform == TargetPlatform.iOS ||
          platform == TargetPlatform.android;
  }
}

Color flowMenuBackground(BuildContext context, FlowMenuStyle? style) =>
    style?.backgroundColor ?? context.flowColors.surfaceBright;

Color flowMenuBorderColor(BuildContext context, FlowMenuStyle? style) =>
    style?.borderColor ?? context.flowColors.outlineVariant;

Color flowMenuSeparatorColor(BuildContext context, FlowMenuStyle? style) =>
    style?.separatorColor ?? context.flowColors.outlineVariant;

/// The row wash on hover and focus — the design's 6% ink, which is the
/// `surfaceContainer` rung of the ladder, the same wash the open trigger
/// wears.
Color flowMenuHoverColor(BuildContext context, FlowMenuStyle? style) =>
    style?.hoverColor ?? context.flowColors.surfaceContainer;

Color flowMenuAccentColor(BuildContext context, FlowMenuStyle? style) =>
    style?.accentColor ?? context.flowColors.primary;

/// [MenuStyle] for selector menus: an invisible panel. The card itself —
/// fill, gradient outline, shadow, padding — is [FlowMenuCard], passed as
/// the panel's single child, because [MenuStyle] can draw neither the
/// design's gradient stroke nor its soft ambient shadow.
MenuStyle flowMenuStyle(BuildContext context, {FlowMenuStyle? style}) {
  return MenuStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: style?.menuRadius ?? _menuRadius),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
  );
}

/// The raised card a selector menu draws inside its (invisible) panel:
/// the composer's surface and ambient shadow under the composer's active
/// outline gradient, clipped so the rows' hover wash respects the corners.
class FlowMenuCard extends StatelessWidget {
  const FlowMenuCard({super.key, this.style, required this.children});

  final FlowMenuStyle? style;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final radius = style?.menuRadius ?? _menuRadius;
    final borderOverride = style?.borderColor;
    return CustomPaint(
      foregroundPainter: FlowGradientOutlinePainter(
        radius: radius,
        start:
            borderOverride ??
            colors.onSurface.withValues(alpha: _borderOpacity),
        end:
            borderOverride ??
            colors.onSurface.withValues(alpha: _borderFadeOpacity),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: flowMenuBackground(context, style),
          borderRadius: radius,
          boxShadow: [BoxShadow(color: colors.shadow, blurRadius: _shadowBlur)],
        ),
        padding: _cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// The hairline rule between menu sections, inset like the rows beside it —
/// what a `FlowMenuDivider` entry renders. [large] switches to the sheet's
/// insets and rhythm.
class FlowMenuRule extends StatelessWidget {
  const FlowMenuRule({super.key, this.style, this.large = false});

  final FlowMenuStyle? style;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: large ? _sheetDividerMargin : _dividerMargin,
      color: flowMenuSeparatorColor(context, style),
    );
  }
}

/// Token-styled [ButtonStyle] for a [SubmenuButton] row, matching
/// [FlowMenuRow]'s metrics and hover treatment.
///
/// The wash follows the pointer and [open] — never focus. Material menu
/// rows grab focus on hover and keep it after the pointer leaves, so a
/// focus-driven fill would strand a highlight on the row.
ButtonStyle _submenuRowStyle(
  BuildContext context, {
  FlowMenuStyle? style,
  required bool open,
}) {
  final hover = flowMenuHoverColor(context, style);
  final colors = context.flowColors;
  final foreground = colors.onSurface;
  final disabled = colors.onSurfaceDisabled;
  return ButtonStyle(
    // The off state is the wash at zero alpha, not Colors.transparent —
    // Material lerps color changes, and fading toward transparent *black*
    // drags the row through a smoky flash on the way out.
    backgroundColor: WidgetStatePropertyAll(
      open ? hover : hover.withValues(alpha: 0),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? disabled : foreground,
    ),
    // The idle branch must not be Colors.transparent: menu rows create a
    // focus highlight the moment hover focuses them, and the CanvasKit
    // renderer paints a transparent-*black* ink highlight as solid black.
    // A hair of the wash's own hue keeps the highlight invisible instead.
    overlayColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered)
          ? hover
          : hover.withValues(alpha: 1 / 255),
    ),
    padding: const WidgetStatePropertyAll(_menuRowPadding),
    minimumSize: WidgetStatePropertyAll(Size(style?.minWidth ?? 220, 0)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.all(_rowRadius)),
    ),
    // Desktop's compact ambient density would shave the padding above,
    // leaving these rows visibly thinner than the FlowMenuRows beside
    // them, which are not buttons and never densify.
    visualDensity: VisualDensity.standard,
  );
}

/// A [SubmenuButton] dressed as a [FlowMenuRow]: the menu's inset, rounded
/// hover chip, staying filled while its submenu is open and clearing the
/// moment it isn't.
class FlowSubmenuRow extends StatefulWidget {
  const FlowSubmenuRow({
    super.key,
    this.style,
    this.trailingIcon,
    required this.menuChildren,
    required this.child,
  });

  final FlowMenuStyle? style;

  /// Before the chevron, e.g. the chosen effort's accented label.
  final Widget? trailingIcon;

  final List<Widget> menuChildren;
  final Widget child;

  @override
  State<FlowSubmenuRow> createState() => _FlowSubmenuRowState();
}

class _FlowSubmenuRowState extends State<FlowSubmenuRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _rowOuterInset),
      child: SubmenuButton(
        menuStyle: flowMenuStyle(context, style: widget.style),
        style: _submenuRowStyle(context, style: widget.style, open: _open),
        // The chevron goes in the submenu-indicator slot; putting it in
        // trailingIcon would double up with the button's built-in arrow.
        submenuIcon: flowSubmenuChevron(context),
        trailingIcon: widget.trailingIcon,
        onOpen: () => setState(() => _open = true),
        onClose: () => setState(() => _open = false),
        menuChildren: widget.menuChildren,
        child: widget.child,
      ),
    );
  }
}

/// The submenu indicator for a [SubmenuButton], sized for the menu.
WidgetStatePropertyAll<Widget> flowSubmenuChevron(BuildContext context) {
  return WidgetStatePropertyAll(
    Icon(
      Icons.chevron_right,
      size: 16,
      color: context.flowColors.onSurfaceVariant,
    ),
  );
}

/// Default row label style: the design's 14 Medium in the menu and
/// 16 Medium in the sheet — the label roles' emphasised cuts.
TextStyle flowMenuLabelStyle(
  BuildContext context, {
  required bool large,
  FlowMenuStyle? style,
}) {
  final typography = context.flowTypography;
  final base = large
      ? typography.labelLargeEmphasised
      : typography.labelMediumEmphasised;
  final override = style?.labelStyle;
  return override == null ? base : base.merge(override);
}

/// Default row description style: 14 regular in the muted ink.
TextStyle flowMenuDescriptionStyle(
  BuildContext context, {
  FlowMenuStyle? style,
}) {
  final base = context.flowTypography.labelMedium.copyWith(
    color: context.flowColors.onSurfaceMuted,
  );
  final override = style?.descriptionStyle;
  return override == null ? base : base.merge(override);
}

/// One row inside a selector menu or menu sheet: optional leading icon,
/// label, optional muted description, and a trailing value, chevron or
/// check.
///
/// [large] switches to the bottom sheet's metrics — the 16px label, the
/// 20px glyphs — while everything else stays shared, so the two
/// presentations can't drift apart.
class FlowMenuRow extends StatelessWidget {
  const FlowMenuRow({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.closeOnTap = true,
    this.large = false,
    this.trailingLabel,
    this.showChevron = false,
    this.style,
  });

  final String label;
  final String? description;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  /// Whether tapping dismisses the enclosing menu or sheet. Picking an
  /// option is the decision a selector menu exists for, so it defaults to
  /// true; a row that pushes a sheet page or toggles in place opts out.
  final bool closeOnTap;

  /// Sheet metrics instead of menu metrics.
  final bool large;

  /// Accented value at the row's end, e.g. the chosen effort's label.
  final String? trailingLabel;

  /// A trailing chevron, for a row that opens a sheet page. Anchored menus
  /// get their chevron from [SubmenuButton] instead.
  final bool showChevron;

  final FlowMenuStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;

    final labelStyle = flowMenuLabelStyle(context, large: large, style: style);
    final descriptionStyle = flowMenuDescriptionStyle(context, style: style);
    final iconColor = style?.iconColor ?? colors.onSurfaceVariant;
    final labelColor = labelStyle.color ?? colors.onSurface;

    final iconSize = large ? 20.0 : 18.0;
    final checkSize = large ? 20.0 : 16.0;
    final chevronSize = large ? 18.0 : 16.0;

    // This context sits inside the menu overlay or the sheet, so whichever
    // host is enclosing is in scope here — the row can dismiss it itself,
    // and every selector built on it closes on pick.
    final VoidCallback? handleTap = !enabled || onTap == null
        ? null
        : () {
            if (closeOnTap) {
              MenuController.maybeOf(context)?.close();
              FlowMenuSheetScope.maybeOf(context)?.close();
            }
            onTap!();
          };

    return Padding(
      padding: large
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: _rowOuterInset),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: handleTap,
          // These rows are not menu buttons, so the menu system doesn't
          // know the pointer moved here — a sibling SubmenuButton's open
          // submenu (and its highlight) would just stay put. Closing the
          // enclosing anchor's children on hover restores the native
          // behaviour.
          onHover: (hovering) {
            if (hovering) MenuController.maybeOf(context)?.closeChildren();
          },
          borderRadius: large ? null : const BorderRadius.all(_rowRadius),
          hoverColor: flowMenuHoverColor(context, style),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: large ? 0 : (style?.minWidth ?? 220),
            ),
            child: Padding(
              padding: large ? _rowPadding : _menuRowPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: iconSize,
                      color: enabled ? iconColor : colors.onSurfaceDisabled,
                    ),
                    const SizedBox(width: flowMenuIconGap),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: labelStyle.copyWith(
                            color: enabled
                                ? labelColor
                                : colors.onSurfaceDisabled,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: _descriptionGap),
                          Text(
                            description!,
                            style: enabled
                                ? descriptionStyle
                                : descriptionStyle.copyWith(
                                    color: colors.onSurfaceDisabled,
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingLabel != null) ...[
                    const SizedBox(width: _valueGap),
                    Text(
                      trailingLabel!,
                      style: labelStyle.copyWith(
                        color: flowMenuAccentColor(context, style),
                      ),
                    ),
                  ],
                  if (selected) ...[
                    const SizedBox(width: _checkGap),
                    Icon(
                      Icons.check,
                      size: checkSize,
                      color: style?.checkColor ?? colors.primary,
                    ),
                  ],
                  if (showChevron) ...[
                    const SizedBox(width: _chevronGap),
                    Icon(
                      Icons.chevron_right,
                      size: chevronSize,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
