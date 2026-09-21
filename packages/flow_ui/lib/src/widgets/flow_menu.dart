import 'package:material_ui/material_ui.dart';

import '../styles/flow_menu_style.dart';
import '../theme/flow_theme.dart';
import '../utils/flow_menu_core.dart';
import '../utils/flow_menu_sheet.dart';

/// One entry in a [FlowMenu]: an option or a divider.
@immutable
sealed class FlowMenuEntry {
  const FlowMenuEntry();
}

/// A hairline between groups of options.
class FlowMenuDivider extends FlowMenuEntry {
  const FlowMenuDivider();
}

/// One actionable row in a [FlowMenu].
///
/// With [children] the row opens a submenu — a nested menu on desktop, a
/// pushed page in the sheet — and its own id is never reported. [selected]
/// draws the accent check, for a mode the host has toggled on.
@immutable
class FlowMenuOption extends FlowMenuEntry {
  const FlowMenuOption({
    required this.id,
    required this.label,
    this.icon,
    this.enabled = true,
    this.selected = false,
    this.children = const <FlowMenuOption>[],
  });

  /// Reported through `onSelected`.
  final String id;

  /// Host-supplied display label, e.g. 'Upload a file'.
  final String label;

  /// Optional leading glyph; without one the row starts at the label.
  final IconData? icon;

  final bool enabled;

  /// Draws the check; the row still reports through `onSelected`, so a
  /// toggle is the host flipping this and passing the list back in.
  final bool selected;

  /// Sub-options behind this row. Non-empty turns the row into a submenu
  /// and its own [id] is no longer reported.
  final List<FlowMenuOption> children;
}

/// A menu of options behind a single icon trigger — on phones, a bottom
/// sheet. The composer's "+" menu is this widget with [icon] set to the add
/// glyph, but it carries no add semantics of its own:
///
/// ```dart
/// FlowMenu(
///   icon: Icons.add,
///   tooltip: 'Add to chat',
///   entries: [
///     FlowMenuOption(id: 'files', icon: Icons.upload_file, label: 'Files'),
///     FlowMenuDivider(),
///     FlowMenuOption(id: 'web', icon: Icons.language, label: 'Web Search'),
///   ],
///   onSelected: (id) => handle(id),
/// )
/// ```
///
/// [entries] mixes [FlowMenuOption] rows with [FlowMenuDivider]s; an option
/// with children becomes a submenu. [presentation] forces the anchored menu
/// or the sheet, and [menuStyle] overrides the token-derived look.
///
/// The sheet rides material_ui's modal route, so a host not built on
/// [MaterialApp] needs `DefaultMaterialLocalizations.delegate` among its
/// `localizationsDelegates` for the phone presentation.
class FlowMenu extends StatefulWidget {
  const FlowMenu({
    super.key,
    required this.icon,
    required this.entries,
    this.onSelected,
    this.presentation = FlowMenuPresentation.auto,
    this.menuStyle,
    this.sheetTitle,
    this.enabled = true,
    this.tooltip,
  });

  /// The trigger glyph, e.g. `Icons.add` on a composer.
  final IconData icon;

  /// Menu entries, in order.
  final List<FlowMenuEntry> entries;

  /// Called with the chosen option's id. Null disables the menu.
  final ValueChanged<String>? onSelected;

  /// Anchored menu, bottom sheet, or automatic by platform.
  final FlowMenuPresentation presentation;

  /// Overrides the token-derived menu and sheet look.
  final FlowMenuStyle? menuStyle;

  /// Host-localized title in the sheet's nav bar, e.g. 'Add to chat'.
  /// Null leaves only the close button.
  final String? sheetTitle;

  final bool enabled;

  /// Host-localized trigger tooltip.
  final String? tooltip;

  @override
  State<FlowMenu> createState() => _FlowMenuState();
}

class _FlowMenuState extends State<FlowMenu> {
  /// The effective style: the widget's over [FlowTheme.menuStyle]'s,
  /// tokens beneath both.
  FlowMenuStyle? get _style =>
      context.flowTheme.menuStyle?.merge(widget.menuStyle) ?? widget.menuStyle;

  /// The design's trigger: an 18px glyph centered on a 32px disc, washed
  /// with the ladder's 6% `surfaceContainer` rung on hover.
  static const double _triggerIconSize = 18;
  static const double _triggerPadding = 7;

  bool _hovered = false;

  bool get _hasOptions => widget.entries.whereType<FlowMenuOption>().isNotEmpty;

  FlowMenuRow _optionRow(FlowMenuOption option, {required bool large}) {
    return FlowMenuRow(
      label: option.label,
      icon: option.icon,
      selected: option.selected,
      enabled: option.enabled,
      large: large,
      style: _style,
      onTap: () => widget.onSelected?.call(option.id),
    );
  }

  /// The anchored menu's children.
  List<Widget> _menuChildren(BuildContext context) {
    final style = _style;
    return [
      for (final entry in widget.entries)
        switch (entry) {
          FlowMenuDivider() => FlowMenuRule(style: style),
          FlowMenuOption(children: []) => _optionRow(entry, large: false),
          FlowMenuOption() => FlowSubmenuRow(
            style: style,
            menuChildren: [
              FlowMenuCard(
                style: style,
                children: [
                  for (final child in entry.children)
                    _optionRow(child, large: false),
                ],
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.icon != null) ...[
                  Icon(
                    entry.icon,
                    size: 18,
                    color: entry.enabled
                        ? (style?.iconColor ??
                              context.flowColors.onSurfaceVariant)
                        : context.flowColors.onSurfaceDisabled,
                  ),
                  const SizedBox(width: flowMenuIconGap),
                ],
                Text(
                  entry.label,
                  style: flowMenuLabelStyle(
                    context,
                    large: false,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        },
    ];
  }

  void _openSheet() {
    final style = _style;
    showFlowMenuSheet(
      context: context,
      style: style,
      root: FlowMenuSheetPage(
        title: widget.sheetTitle,
        children: (context) => [
          for (final entry in widget.entries)
            switch (entry) {
              FlowMenuDivider() => FlowMenuRule(style: style, large: true),
              FlowMenuOption(children: []) => _optionRow(entry, large: true),
              FlowMenuOption() => FlowMenuRow(
                label: entry.label,
                icon: entry.icon,
                enabled: entry.enabled,
                showChevron: true,
                large: true,
                style: style,
                closeOnTap: false,
                onTap: () => FlowMenuSheetScope.maybeOf(context)?.push(
                  FlowMenuSheetPage(
                    title: entry.label,
                    children: (context) => [
                      for (final child in entry.children)
                        _optionRow(child, large: true),
                    ],
                  ),
                ),
              ),
            },
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final enabled = widget.enabled && widget.onSelected != null && _hasOptions;
    final asSheet = flowMenuPresentsAsSheet(context, widget.presentation);

    final Color foreground;
    if (!enabled) {
      foreground = colors.onSurfaceDisabled;
    } else if (_hovered) {
      foreground = colors.onSurface;
    } else {
      foreground = colors.onSurfaceVariant;
    }

    return MenuAnchor(
      style: flowMenuStyle(context, style: _style),
      menuChildren: asSheet
          ? const []
          : [FlowMenuCard(style: _style, children: _menuChildren(context))],
      builder: (context, controller, _) {
        Widget trigger = Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: !enabled
                ? null
                : asSheet
                ? _openSheet
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            onHover: enabled
                ? (value) => setState(() => _hovered = value)
                : null,
            customBorder: const CircleBorder(),
            hoverColor: colors.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(_triggerPadding),
              child: Icon(
                widget.icon,
                size: _triggerIconSize,
                color: foreground,
              ),
            ),
          ),
        );
        final tooltip = widget.tooltip;
        if (tooltip != null) {
          trigger = Tooltip(message: tooltip, child: trigger);
        }
        return trigger;
      },
    );
  }
}
