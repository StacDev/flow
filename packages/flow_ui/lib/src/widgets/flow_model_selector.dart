import 'package:material_ui/material_ui.dart';

import '../styles/flow_menu_style.dart';
import '../theme/flow_theme.dart';
import '../utils/flow_menu_core.dart';
import '../utils/flow_menu_sheet.dart';

/// One model choice in a [FlowModelSelector].
@immutable
class FlowModelOption {
  const FlowModelOption({
    required this.id,
    required this.label,
    this.description,
    this.enabled = true,
  });

  /// Reported through `onSelected`.
  final String id;

  /// Host-supplied display name, e.g. 'Sonnet 5'.
  final String label;

  /// Optional second line in the menu, e.g. 'Fast and balanced'.
  final String? description;

  final bool enabled;
}

/// One effort choice in a [FlowModelSelector].
@immutable
class FlowEffortOption {
  const FlowEffortOption({
    required this.id,
    required this.label,
    this.description,
    this.enabled = true,
  });

  /// Reported through `onEffortSelected`.
  final String id;

  /// Host-supplied display name, e.g. 'Medium'.
  final String label;

  /// Optional second line, e.g. what this effort trades away.
  final String? description;

  final bool enabled;
}

/// Compact model picker: a pill trigger showing the selected model, opening
/// a token-styled menu — or, on phones, a bottom sheet. Designed for a
/// composer's `trailingActions` slot.
///
/// Passing [efforts] adds an Effort row under the models, its chosen value
/// accented, and the selected effort's label, muted, to the trigger —
/// `Sonnet 5  Medium`. [moreModels] adds an overflow section for models
/// that don't earn a top-level row. Picking anything applies immediately
/// and closes the menu.
///
/// [presentation] decides between the anchored menu and the sheet —
/// automatic by platform unless forced — and [menuStyle] overrides the
/// token-derived look.
///
/// The sheet rides material_ui's modal route, so a host not built on
/// [MaterialApp] needs `DefaultMaterialLocalizations.delegate` among its
/// `localizationsDelegates` for the phone presentation.
class FlowModelSelector extends StatefulWidget {
  const FlowModelSelector({
    super.key,
    required this.models,
    this.selectedId,
    this.onSelected,
    this.efforts = const <FlowEffortOption>[],
    this.selectedEffortId,
    this.onEffortSelected,
    this.effortLabel = 'Effort',
    this.moreModels = const <FlowModelOption>[],
    this.moreModelsLabel = 'More models',
    this.presentation = FlowMenuPresentation.auto,
    this.menuStyle,
    this.sheetTitle,
    this.enabled = true,
    this.tooltip,
  }) : assert(
         efforts.length == 0 || selectedEffortId != null,
         'selectedEffortId is required when efforts are provided.',
       ),
       assert(
         efforts.length == 0 || onEffortSelected != null,
         'onEffortSelected is required when efforts are provided.',
       );

  /// Menu entries, in order.
  final List<FlowModelOption> models;

  /// Highlighted in the menu; its label shows on the trigger.
  /// Falls back to the first model's label when null.
  final String? selectedId;

  /// Called with the chosen option's id — from [models] or [moreModels]
  /// alike. Null disables the selector.
  final ValueChanged<String>? onSelected;

  /// Effort levels, in order. Empty hides the effort section and the
  /// trigger's effort label.
  final List<FlowEffortOption> efforts;

  /// Highlighted in the effort section; its label shows muted on the
  /// trigger and accented on the Effort row. Required when [efforts] is
  /// non-empty.
  final String? selectedEffortId;

  /// Called with the chosen effort's id. Required when [efforts] is
  /// non-empty.
  final ValueChanged<String>? onEffortSelected;

  /// Host-localized label on the effort row; also titles the effort page
  /// in the sheet.
  final String effortLabel;

  /// Overflow models behind a "More models" row. Empty hides the row.
  final List<FlowModelOption> moreModels;

  /// Host-localized label on the overflow row; also titles its sheet page.
  final String moreModelsLabel;

  /// Anchored menu, bottom sheet, or automatic by platform.
  final FlowMenuPresentation presentation;

  /// Overrides the token-derived menu and sheet look.
  final FlowMenuStyle? menuStyle;

  /// Host-localized title in the sheet's nav bar, e.g. 'Select model'.
  /// Null leaves only the close button.
  final String? sheetTitle;

  final bool enabled;

  /// Host-localized trigger tooltip.
  final String? tooltip;

  @override
  State<FlowModelSelector> createState() => _FlowModelSelectorState();
}

class _FlowModelSelectorState extends State<FlowModelSelector> {
  /// The effective style: the widget's over [FlowTheme.menuStyle]'s,
  /// tokens beneath both.
  FlowMenuStyle? get _style =>
      context.flowTheme.menuStyle?.merge(widget.menuStyle) ?? widget.menuStyle;

  /// The design's trigger: an 8px-radius pill padded 8/7 — 32 tall around
  /// its 18px line, matching the action row's buttons — its pieces 4
  /// apart.
  static const BorderRadius _triggerRadius = BorderRadius.all(
    Radius.circular(8),
  );
  static const EdgeInsetsGeometry _triggerPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 7,
  );
  static const double _gap = 4;

  final MenuController _menuController = MenuController();
  bool _sheetOpen = false;

  FlowModelOption? get _selected {
    for (final model in widget.models) {
      if (model.id == widget.selectedId) return model;
    }
    for (final model in widget.moreModels) {
      if (model.id == widget.selectedId) return model;
    }
    return widget.models.isEmpty ? null : widget.models.first;
  }

  FlowEffortOption? get _selectedEffort {
    for (final effort in widget.efforts) {
      if (effort.id == widget.selectedEffortId) return effort;
    }
    return null;
  }

  FlowMenuRow _modelRow(FlowModelOption model, {required bool large}) {
    return FlowMenuRow(
      label: model.label,
      description: model.description,
      selected: model.id == widget.selectedId,
      enabled: model.enabled,
      large: large,
      style: _style,
      onTap: () => widget.onSelected?.call(model.id),
    );
  }

  FlowMenuRow _effortRow(FlowEffortOption option, {required bool large}) {
    return FlowMenuRow(
      label: option.label,
      description: option.description,
      selected: option.id == widget.selectedEffortId,
      enabled: option.enabled,
      large: large,
      style: _style,
      // In the anchored menu the row's own closeOnTap would only dismiss
      // the submenu it sits in; picking an effort should close the whole
      // menu, so the root controller does it. The sheet closes through the
      // row's scope as usual.
      closeOnTap: large,
      onTap: () {
        _menuController.close();
        widget.onEffortSelected?.call(option.id);
      },
    );
  }

  /// The anchored menu's children.
  List<Widget> _menuChildren(BuildContext context) {
    final style = _style;
    final effort = _selectedEffort;
    return [
      for (final model in widget.models) _modelRow(model, large: false),
      if (widget.efforts.isNotEmpty) ...[
        FlowMenuRule(style: style),
        FlowSubmenuRow(
          style: style,
          trailingIcon: effort == null
              ? null
              : Text(
                  effort.label,
                  style: flowMenuLabelStyle(
                    context,
                    large: false,
                    style: style,
                  ).copyWith(color: flowMenuAccentColor(context, style)),
                ),
          menuChildren: [
            FlowMenuCard(
              style: style,
              children: [
                for (final option in widget.efforts)
                  _effortRow(option, large: false),
              ],
            ),
          ],
          child: Text(
            widget.effortLabel,
            style: flowMenuLabelStyle(context, large: false, style: style),
          ),
        ),
      ],
      if (widget.moreModels.isNotEmpty) ...[
        FlowMenuRule(style: style),
        FlowSubmenuRow(
          style: style,
          menuChildren: [
            FlowMenuCard(
              style: style,
              children: [
                for (final model in widget.moreModels)
                  _modelRow(model, large: false),
              ],
            ),
          ],
          child: Text(
            widget.moreModelsLabel,
            style: flowMenuLabelStyle(context, large: false, style: style),
          ),
        ),
      ],
    ];
  }

  void _openSheet() {
    final style = _style;
    setState(() => _sheetOpen = true);
    _showSheet(style).whenComplete(() {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  Future<void> _showSheet(FlowMenuStyle? style) {
    return showFlowMenuSheet(
      context: context,
      style: style,
      root: FlowMenuSheetPage(
        title: widget.sheetTitle,
        children: (context) => [
          for (final model in widget.models) _modelRow(model, large: true),
          if (widget.efforts.isNotEmpty) ...[
            FlowMenuRule(style: style, large: true),
            FlowMenuRow(
              label: widget.effortLabel,
              trailingLabel: _selectedEffort?.label,
              showChevron: true,
              large: true,
              style: style,
              closeOnTap: false,
              onTap: () => FlowMenuSheetScope.maybeOf(context)?.push(
                FlowMenuSheetPage(
                  title: widget.effortLabel,
                  children: (context) => [
                    for (final option in widget.efforts)
                      _effortRow(option, large: true),
                  ],
                ),
              ),
            ),
          ],
          if (widget.moreModels.isNotEmpty) ...[
            FlowMenuRule(style: style, large: true),
            FlowMenuRow(
              label: widget.moreModelsLabel,
              showChevron: true,
              large: true,
              style: style,
              closeOnTap: false,
              onTap: () => FlowMenuSheetScope.maybeOf(context)?.push(
                FlowMenuSheetPage(
                  title: widget.moreModelsLabel,
                  children: (context) => [
                    for (final model in widget.moreModels)
                      _modelRow(model, large: true),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final enabled =
        widget.enabled && widget.onSelected != null && widget.models.isNotEmpty;
    final asSheet = flowMenuPresentsAsSheet(context, widget.presentation);

    // The design's trigger inks: the model name at full strength, the
    // effort a step below it, and the caret at the effort's level.
    final labelColor = enabled ? colors.onSurface : colors.onSurfaceDisabled;
    final effortForeground = enabled
        ? colors.onSurfaceMuted
        : colors.onSurfaceDisabled;
    final effort = _selectedEffort;

    return MenuAnchor(
      controller: _menuController,
      style: flowMenuStyle(context, style: _style),
      menuChildren: asSheet
          ? const []
          : [FlowMenuCard(style: _style, children: _menuChildren(context))],
      builder: (context, controller, _) {
        final active = controller.isOpen || _sheetOpen;
        Widget trigger = Material(
          // Hovered and open wear the same fill: the design's 6% ink,
          // which is the ladder's `surfaceContainer` rung. Off is that
          // wash at zero alpha, not Colors.transparent — Material lerps
          // color changes, and fading toward transparent *black* drags
          // the pill through a smoky flash on the way out.
          color: active
              ? colors.surfaceContainer
              : colors.surfaceContainer.withValues(alpha: 0),
          borderRadius: _triggerRadius,
          child: InkWell(
            onTap: !enabled
                ? null
                : asSheet
                ? _openSheet
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            borderRadius: _triggerRadius,
            hoverColor: colors.surfaceContainer,
            child: Padding(
              padding: _triggerPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selected?.label ?? '',
                    style: context.flowTypography.labelMedium.copyWith(
                      color: labelColor,
                    ),
                  ),
                  if (effort != null) ...[
                    const SizedBox(width: _gap),
                    Text(
                      effort.label,
                      style: context.flowTypography.labelMedium.copyWith(
                        color: effortForeground,
                      ),
                    ),
                  ],
                  const SizedBox(width: _gap),
                  Icon(Icons.expand_more, size: 12, color: effortForeground),
                ],
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
