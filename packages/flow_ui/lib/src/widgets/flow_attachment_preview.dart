import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/flow_attachment.dart';
import '../theme/flow_theme.dart';
import '../utils/flow_attachment_error.dart';
import '../utils/flow_circle_button.dart';

const Duration _transition = Duration(milliseconds: 180);

/// Frosted glass over the page — the chat view's drop treatment, so the
/// two frosts read as one: a 12 blur under a vertical wash from
/// `surfaceBright` at 40% to `surface` at 80%, enough tint to carry the
/// chrome without erasing what shows through.
const double _backdropBlur = 12;
const double _backdropTopOpacity = 0.40;
const double _backdropBottomOpacity = 0.80;

/// The design's viewer metrics: the image inset from the screen edge, and
/// the top bar's inset and internal gap.
const EdgeInsets _pagePadding = EdgeInsets.all(24);
const double _barInset = 12;
const double _barGap = 12;

/// The close disc, on the jump button's idiom: an opaque ground, a firm
/// hairline and the theme's shadow, so it reads over any picture — a
/// translucent wash vanished over a dark photo in the light theme and a
/// light one in the dark. 34 on pointer platforms (18 glyph + 8), 44 on
/// touch (20 + 12), the platform taken from the theme like the composer's.
const double _closeIconSize = 18;
const double _closePadding = 8;
const double _closeTouchIconSize = 20;
const double _closeTouchPadding = 12;
const double _closeShadowBlur = 12;

/// One filter for the whole animation: a [BackdropFilter] repaints the entire
/// viewport whenever its filter changes, so the fade animates the tint only.
final ImageFilter _blurFilter = ImageFilter.blur(
  sigmaX: _backdropBlur,
  sigmaY: _backdropBlur,
);

/// Opens [FlowAttachmentPreview] over the current route.
///
/// ```dart
/// showFlowAttachmentPreview(
///   context: context,
///   attachments: attachments,
///   initialId: tappedId,
/// )
/// ```
///
/// This is what a [FlowAttachmentGroup] tile does on tap when the group has
/// no `onTap` of its own. Call it directly to open the preview from a host's
/// own handler. An empty [attachments] list opens nothing.
///
/// The list is read once, at push time: the preview pages through a snapshot
/// and is unaffected by later changes to the list the host passed.
Future<void> showFlowAttachmentPreview({
  required BuildContext context,
  required List<FlowAttachment> attachments,
  String? initialId,
  int? initialIndex,
  String? closeTooltip,
}) {
  if (attachments.isEmpty) return Future<void>.value();

  // Copied, not aliased: the route outlives the host's list, which it is free
  // to mutate — or empty — while the preview is open.
  final snapshot = List<FlowAttachment>.unmodifiable(attachments);

  // An explicit index wins: ids only have to be unique within a group, so a
  // caller that already knows which tile was tapped must not be resolved by
  // an id lookup that would land on the first duplicate.
  final resolved =
      initialIndex ?? snapshot.indexWhere((a) => a.id == initialId);
  assert(
    initialIndex != null || initialId == null || resolved >= 0,
    'initialId "$initialId" does not match any attachment in the list',
  );

  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      // The preview frosts the page rather than covering it, so the route
      // underneath has to keep painting.
      opaque: false,
      fullscreenDialog: true,
      transitionDuration: _transition,
      reverseTransitionDuration: _transition,
      pageBuilder: (context, animation, secondaryAnimation) =>
          FlowAttachmentPreview(
            attachments: snapshot,
            initialIndex: resolved.clamp(0, snapshot.length - 1),
            closeTooltip: closeTooltip,
          ),
      // No FadeTransition around the page: an opacity layer over a
      // BackdropFilter stops the filter sampling the route beneath, which
      // costs the blur and, on web, the filtered child's paint as well. The
      // preview frosts itself in instead, driven by this same animation so
      // the fade reverses on the way out.
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ),
  );
}

/// A full-screen look at one attachment, with the rest of its group a swipe
/// away, over a frosted view of the page beneath.
///
/// Each image is zoomable and pannable. A tap on the frosted space around
/// the picture closes the viewer, as the close button does; on a hardware
/// keyboard Escape closes and the arrow keys page. Usually reached through
/// [showFlowAttachmentPreview] rather than built directly.
class FlowAttachmentPreview extends StatefulWidget {
  FlowAttachmentPreview({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
    this.closeTooltip,
  }) : assert(attachments.isNotEmpty, 'attachments must not be empty'),
       assert(
         initialIndex >= 0 && initialIndex < attachments.length,
         'initialIndex must point at one of the attachments',
       );

  /// Shown in order; the viewer pages between them.
  final List<FlowAttachment> attachments;

  /// Which one opens first.
  final int initialIndex;

  /// Host-localized; defaults to material_ui's own close-button label when
  /// [MaterialLocalizations] is available, so the package still ships no
  /// strings of its own.
  final String? closeTooltip;

  @override
  State<FlowAttachmentPreview> createState() => _FlowAttachmentPreviewState();
}

class _FlowAttachmentPreviewState extends State<FlowAttachmentPreview> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );

  /// Only the top bar reads it, so it rebuilds alone — a setState here would
  /// take the full-screen backdrop filter and every live page with it.
  late final ValueNotifier<int> _index = ValueNotifier<int>(
    widget.initialIndex,
  );

  /// True while the visible image is zoomed in. Paging is suspended then:
  /// the pager's drag recognizer wins the arena at half the slop the viewer's
  /// pan needs, so without this a drag across a magnified image swipes to the
  /// next attachment instead of panning to its edge.
  final ValueNotifier<bool> _zoomed = ValueNotifier<bool>(false);

  /// Held explicitly: the shortcuts below only see keys routed through the
  /// focus tree, and the tile that opened the preview keeps focus otherwise.
  final FocusNode _focusNode = FocusNode(debugLabel: 'FlowAttachmentPreview');

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _index.dispose();
    _zoomed.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  /// A page reports on the way out too, so `mounted` is the guard against a
  /// notifier this state has already disposed.
  void _setZoomed(bool value) {
    if (mounted) _zoomed.value = value;
  }

  void _step(int delta) {
    // From the controller, not from [_index]: onPageChanged lands partway
    // through the animation, so a held arrow key would otherwise keep
    // re-targeting the page already in flight.
    final from = (_controller.page ?? _index.value.toDouble()).round();
    final target = from + delta;
    if (target < 0 || target >= widget.attachments.length) return;
    _controller.animateToPage(
      target,
      duration: _transition,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final total = widget.attachments.length;
    final routeAnimation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    // A PageView takes its direction from the ambient Directionality, so in
    // RTL the next page is the one to the *left*. The arrow keys have to
    // follow the pixels, not the index.
    final forward = Directionality.of(context) == TextDirection.rtl ? -1 : 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-forward),
        SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(forward),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Stack(
          children: [
            // The frosting is a sibling *behind* the content, never an
            // ancestor of it: anything inside a BackdropFilter joins the
            // filtered layer, and on web that costs the child its paint.
            // It is also outside the SafeArea below — the tint is full-bleed
            // even though the chrome is not.
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: _blurFilter,
                  // `drive`, not a CurvedAnimation: this is rebuilt on every
                  // page change and a CurvedAnimation would need disposing.
                  child: FadeTransition(
                    opacity: routeAnimation.drive(
                      CurveTween(curve: Curves.easeOut),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.surfaceBright.withValues(
                              alpha: _backdropTopOpacity,
                            ),
                            colors.surface.withValues(
                              alpha: _backdropBottomOpacity,
                            ),
                          ],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            // The only widget in the package that owns the whole screen, so
            // the only one that has to ask for the display's insets.
            SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _zoomed,
                      builder: (context, zoomed, _) => PageView.builder(
                        controller: _controller,
                        itemCount: total,
                        physics: zoomed
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        onPageChanged: (value) {
                          _index.value = value;
                          // A new page always opens at 1x.
                          _zoomed.value = false;
                        },
                        itemBuilder: (context, index) => _ZoomablePage(
                          attachment: widget.attachments[index],
                          padding: _pagePadding,
                          onZoomChanged: _setZoomed,
                          onDismiss: _close,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: _barInset,
                    left: _barInset,
                    right: _barInset,
                    // This route has no Scaffold, and text with no Material
                    // ancestor inherits MaterialApp's yellow-underlined
                    // fallback style for the fields our typography tokens
                    // don't set.
                    child: Material(
                      type: MaterialType.transparency,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _index,
                        builder: (context, index, _) => _TopBar(
                          // Numerals rather than prose, so there is nothing
                          // to translate; a caption only appears if the host
                          // named it.
                          counter: total > 1 ? '${index + 1} / $total' : null,
                          caption: widget.attachments[index].label,
                          closeTooltip:
                              widget.closeTooltip ??
                              // Not MaterialLocalizations.of: the rest of the
                              // package works under any WidgetsApp, and a
                              // missing tooltip must not be the one thing
                              // that throws.
                              Localizations.of<MaterialLocalizations>(
                                context,
                                MaterialLocalizations,
                              )?.closeButtonTooltip,
                          onClose: _close,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page of the viewer: a zoomable image that reports whether it is
/// currently magnified, so the pager can stand down while it is.
class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    required this.attachment,
    required this.padding,
    required this.onZoomChanged,
    required this.onDismiss,
  });

  final FlowAttachment attachment;
  final EdgeInsets padding;
  final ValueChanged<bool> onZoomChanged;

  /// A tap that lands on the frosted space rather than the picture.
  final VoidCallback onDismiss;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_handleTransform);
  }

  @override
  void dispose() {
    // Nothing is reported from here: the tree is locked during dispose, so a
    // setState from a listener would throw. A magnified page can't be
    // scrolled off screen anyway — paging is suspended while it is zoomed —
    // and the parent resets the flag on every page change.
    _transform.removeListener(_handleTransform);
    _transform.dispose();
    super.dispose();
  }

  void _handleTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  @override
  Widget build(BuildContext context) {
    // The inset wraps the viewer rather than its child: inside, it would be
    // part of the transformed content, so zooming to 5x would blow a 24dp
    // gutter up to 120dp and widen the dead band at the pan extremes.
    final image = widget.attachment.previewImage;
    // Two tap targets, one inside the other, and the arena hands a tap to
    // the innermost: on the picture it lands on the absorbing detector
    // and nothing happens; anywhere else — the frosted space, the gutter
    // outside the viewer — it reaches the outer one and closes. Drags and
    // pinches are the viewer's and the pager's as before, since a tap
    // recognizer only wins a pointer that never moved.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: Padding(
        padding: widget.padding,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          // An attachment with no image of its own can't be opened from
          // its own tile, but paging can still land on one from a
          // neighbour.
          child: image == null
              ? const FlowAttachmentError(iconSize: 48, filled: false)
              // Centred so the image's box is the picture's painted
              // bounds rather than the whole viewport — under a tight
              // constraint it would fill the page and swallow every tap.
              : Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Image(
                      image: image,
                      fit: BoxFit.contain,
                      errorBuilder: flowAttachmentErrorBuilder(
                        iconSize: 48,
                        filled: false,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onClose,
    this.closeTooltip,
    this.counter,
    this.caption,
  });

  final String? closeTooltip;
  final VoidCallback onClose;
  final String? counter;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final typography = context.flowTypography;
    final label = caption;
    final count = counter;
    final platform = Theme.of(context).platform;
    final touch =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              if (count != null)
                Text(
                  count,
                  // Two digit runs around a neutral separator: in an RTL
                  // paragraph the bidi algorithm would render '1 / 4' as
                  // '4 / 1'. Numerals need no translation, but they do need
                  // a direction.
                  textDirection: TextDirection.ltr,
                  style: typography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: _barGap),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: colors.shadow, blurRadius: _closeShadowBlur),
            ],
          ),
          // The hairline rides in front of the disc — behind it, the
          // opaque circle would paint over the stroke. outlineVariant, the
          // firm one, because the disc sits over host pixels.
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: FlowCircleButton(
            icon: Icons.close,
            // surfaceBright rather than the jump button's surface: the
            // backdrop here is surface at 72%, and a surface disc would
            // sink into it.
            background: colors.surfaceBright,
            foreground: colors.onSurface,
            iconSize: touch ? _closeTouchIconSize : _closeIconSize,
            padding: touch ? _closeTouchPadding : _closePadding,
            tooltip: closeTooltip,
            onTap: onClose,
          ),
        ),
      ],
    );
  }
}
