import 'package:material_ui/material_ui.dart';

import '../styles/flow_menu_style.dart';
import '../theme/flow_theme.dart';
import 'flow_circle_button.dart';
import 'flow_menu_core.dart';

// The bottom-sheet presentation of the selector menus.
// Not exported from the package barrel.

/// Matches the anchored menus' feel; the sheet is the same surface.
const Duration _pageTransition = Duration(milliseconds: 180);

const double _navHeight = 56;
const double _navIconSize = 20;

/// The design's sheet metrics: 24px top corners, the nav bar inset 12 and
/// nudged 4 off the corner, 48 under the last row.
const Radius _sheetCornerRadius = Radius.circular(24);
const double _navInset = 12;
const double _navTopInset = 4;
const double _bottomPadding = 48;

/// The rendered width of the leading nav button — derived, not a spec
/// value, so resizing the icon or the disc keeps the title centered.
const double _navBalanceWidth =
    _navIconSize + 2 * FlowCircleButton.defaultPadding;

/// One screen of a menu sheet: the root list, or a pushed submenu page.
///
/// [children] is a builder rather than a list so rows are created under the
/// [FlowMenuSheetScope], letting them close the sheet or push a deeper page,
/// and so a pushed page re-renders when the host's state changes behind it.
class FlowMenuSheetPage {
  const FlowMenuSheetPage({this.title, required this.children});

  /// Centered in the sheet's nav bar. Null leaves only the close button.
  final String? title;

  final List<Widget> Function(BuildContext context) children;
}

/// Opens [root] as a modal bottom sheet styled like the anchored menus.
///
/// Rides material_ui's modal-sheet route, which itself requires its
/// [MaterialLocalizations]: a host not built on [MaterialApp] must list
/// `DefaultMaterialLocalizations.delegate` in its `localizationsDelegates`
/// for the phone presentation — localized apps get it through
/// `GlobalMaterialLocalizations.delegates`, which since the material_ui
/// move also bundles the widgets and Cupertino delegates. Nothing else in
/// the package needs it.
Future<void> showFlowMenuSheet({
  required BuildContext context,
  required FlowMenuSheetPage root,
  FlowMenuStyle? style,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: flowMenuBackground(context, style),
    barrierColor: style?.barrierColor,
    // The sheet is the raised card again: top corners at the card radius,
    // edged in the palette's firm hairline.
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: style?.sheetRadius ?? _sheetCornerRadius,
      ),
      side: BorderSide(color: flowMenuBorderColor(context, style)),
    ),
    clipBehavior: Clip.antiAlias,
    useSafeArea: true,
    builder: (context) => _FlowMenuSheet(root: root, style: style),
  );
}

/// Lets rows built inside the sheet dismiss it or push a deeper page —
/// the sheet counterpart of the `MenuController` an anchored row reaches
/// through its context.
class FlowMenuSheetScope extends InheritedWidget {
  const FlowMenuSheetScope({
    super.key,
    required this.close,
    required this.push,
    required super.child,
  });

  /// Pops the whole sheet.
  final VoidCallback close;

  /// Pushes a deeper page, e.g. the effort list.
  final ValueChanged<FlowMenuSheetPage> push;

  static FlowMenuSheetScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlowMenuSheetScope>();

  @override
  bool updateShouldNotify(FlowMenuSheetScope oldWidget) =>
      close != oldWidget.close || push != oldWidget.push;
}

class _FlowMenuSheet extends StatefulWidget {
  const _FlowMenuSheet({required this.root, this.style});

  final FlowMenuSheetPage root;
  final FlowMenuStyle? style;

  @override
  State<_FlowMenuSheet> createState() => _FlowMenuSheetState();
}

class _FlowMenuSheetState extends State<_FlowMenuSheet> {
  late final List<FlowMenuSheetPage> _stack = [widget.root];

  void close() => Navigator.of(context).pop();

  void push(FlowMenuSheetPage page) => setState(() => _stack.add(page));

  void _pop() => setState(() => _stack.removeLast());

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final page = _stack.last;
    final atRoot = _stack.length == 1;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _pageTransition;
    // Not MaterialLocalizations.of: like the preview's close button, a
    // missing tooltip must not be the one thing that throws.
    final localizations = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );

    final navBar = SizedBox(
      height: _navHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: _navInset,
          end: _navInset,
          top: _navTopInset,
        ),
        child: Row(
          children: [
            FlowCircleButton(
              icon: atRoot ? Icons.close : Icons.arrow_back,
              background: Colors.transparent,
              foreground: colors.onSurfaceVariant,
              iconSize: _navIconSize,
              tooltip: atRoot
                  ? localizations?.closeButtonTooltip
                  : localizations?.backButtonTooltip,
              onTap: atRoot ? close : _pop,
            ),
            Expanded(
              child: page.title == null
                  ? const SizedBox.shrink()
                  : Text(
                      page.title!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.flowTypography.labelLargeEmphasised
                          .copyWith(color: colors.onSurface),
                    ),
            ),
            // Balances the leading button so the title stays centered.
            const SizedBox(width: _navBalanceWidth),
          ],
        ),
      ),
    );

    // Back gestures pop the pushed page before they dismiss the sheet.
    return PopScope(
      canPop: atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pop();
      },
      child: FlowMenuSheetScope(
        close: close,
        push: push,
        child: AnimatedSize(
          duration: duration,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: duration,
            // A Builder rather than this State's context: the children
            // builder must see a context *below* the scope, or the rows'
            // FlowMenuSheetScope.maybeOf would come back null and pushing
            // a page from them would silently do nothing.
            child: Builder(
              key: ValueKey(_stack.length),
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  navBar,
                  ...page.children(context),
                  const SizedBox(height: _bottomPadding),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
