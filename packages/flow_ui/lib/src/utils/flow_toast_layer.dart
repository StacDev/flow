import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:material_ui/material_ui.dart';

import '../styles/flow_toast_style.dart';
import '../widgets/flow_toast.dart';

// The toast layer: one OverlayEntry per Overlay, raised by the first toast
// and dropped once the last one has left. Only showFlowToast and
// FlowToastHandle are exported from the package barrel.

/// The frost under every toast: the design's 3px blur of the page. One
/// filter for all of them — a [BackdropFilter] repaints the whole viewport
/// whenever its filter changes, the preview's note.
final ImageFilter _blurFilter = ImageFilter.blur(sigmaX: 3, sigmaY: 3);

/// Floats a [FlowToast] in the nearest [Overlay] and hands back its handle.
///
/// ```dart
/// showFlowToast(
///   context: context,
///   icon: Icons.copy_outlined,
///   message: 'Message copied to clipboard',
///   dismissTooltip: 'Dismiss',
/// )
/// ```
///
/// No setup: the layer raises itself in the overlay above [context] — a
/// `MaterialApp`, a `Navigator`, or an `Overlay` of the host's own, the
/// nearest one, so an `Overlay.wrap` around a pane keeps its toasts inside
/// it; [rootOverlay] reaches the app's instead, as `Overlay.of` does — and
/// leaves again once the last toast has gone. Toasts sit above every
/// route, dialogs and sheets included.
///
/// Where it floats is read from the overlay's own width: 358 wide, 24 in
/// from the top end corner, on layouts 600 and wider; the full width inside
/// 16 from the top edge below that. Both distances measure from the
/// display's edge and absorb its own insets — a notch pushes the card only
/// as far as it exceeds them.
///
/// Toasts stack as a deck: the newest in front, the ones behind it peeking
/// out above, each a step smaller, three at most; a fourth dismisses the
/// oldest. Under the pointer the deck fans out, so every line can be read
/// and every cross reached, and it stays fanned out under assistive
/// navigation.
///
/// A toast leaves on its own after [duration] — four seconds unless told
/// otherwise, every clock paused while the pointer is over the deck — or
/// at once
/// from its cross or [FlowToastHandle.dismiss]. Null keeps it up until
/// dismissed, for a notice that tracks work in progress. Under assistive
/// navigation no toast leaves on its own, the snack bar's rule: a notice
/// gone before it was reached was never shown.
///
/// Call it from a handler, not from a build: raising the layer rebuilds
/// the overlay, which a build in progress forbids — the same rule as
/// pushing a route.
FlowToastHandle showFlowToast({
  required BuildContext context,
  required String message,
  IconData? icon,
  Duration? duration = const Duration(seconds: 4),
  String? dismissTooltip,
  bool rootOverlay = false,
  FlowToastStyle? style,
}) {
  assert(
    duration == null || duration > Duration.zero,
    'duration must be positive, or null for a toast that stays until '
    'dismissed',
  );
  final toast = FlowToast(
    message: message,
    icon: icon,
    dismissTooltip: dismissTooltip,
    style: style,
  );
  // The framework's own error names the widget: "No Overlay widget found.
  // FlowToast widgets require an Overlay widget ancestor…".
  final overlay = Overlay.of(
    context,
    rootOverlay: rootOverlay,
    debugRequiredFor: toast,
  );
  return _FlowToastStack.of(overlay).show(toast, duration: duration);
}

/// A toast [showFlowToast] floated: dismiss it early, or wait for it to go.
class FlowToastHandle {
  FlowToastHandle._(this._record);

  final _FlowToastRecord _record;

  /// Starts the exit. A no-op once the toast has left.
  void dismiss() => _record.dismiss();

  /// Completes once the toast has left the tree — dismissed, timed out,
  /// pushed off by newer ones, or its overlay torn down.
  Future<void> get closed => _record.closed.future;

  /// True until [closed] completes, the exit animation included.
  bool get isShowing => !_record.closed.isCompleted;
}

/// One floated toast: what to draw, how long it stays, and where it is in
/// its life.
class _FlowToastRecord {
  _FlowToastRecord(this.toast, {required this.duration});

  final FlowToast toast;
  final Duration? duration;
  final Completer<void> closed = Completer<void>();

  /// Installed by the item once it is on screen; the handle's dismiss
  /// lands here. A dismiss before that is remembered and honoured on
  /// mount.
  VoidCallback? leave;
  bool dismissed = false;

  /// Its exit is running: it holds its place in the deck and counts for
  /// no card behind it.
  bool leaving = false;

  void dismiss() {
    if (dismissed || closed.isCompleted) return;
    dismissed = true;
    leave?.call();
  }

  void close() {
    if (!closed.isCompleted) closed.complete();
  }
}

/// The toasts over one [Overlay], and the entry that draws them.
class _FlowToastStack extends ChangeNotifier {
  _FlowToastStack._(this.overlay);

  /// Three at most; a fourth pushes the oldest off.
  static const int _maxVisible = 3;

  /// Live stacks by overlay. Statics survive a hot reload and so do the
  /// [OverlayState]s keying them, so the map stays valid across one; a hot
  /// restart starts both over.
  static final Map<OverlayState, _FlowToastStack> _stacks = {};

  static _FlowToastStack of(OverlayState overlay) =>
      _stacks.putIfAbsent(overlay, () => _FlowToastStack._(overlay).._mount());

  final OverlayState overlay;

  /// Newest first — the order they stack in, nearest the edge.
  final List<_FlowToastRecord> toasts = [];

  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => _FlowToastLayer(stack: this),
  );
  bool _released = false;

  void _mount() => overlay.insert(_entry);

  FlowToastHandle show(FlowToast toast, {required Duration? duration}) {
    final record = _FlowToastRecord(toast, duration: duration);
    toasts.insert(0, record);
    for (final old in toasts.skip(_maxVisible)) {
      old.dismiss();
    }
    notifyListeners();
    return FlowToastHandle._(record);
  }

  /// From an item as its exit begins: the deck moves the cards behind
  /// up at once, not once the card has gone.
  void leaving(_FlowToastRecord record) {
    record.leaving = true;
    notifyListeners();
  }

  /// From an item, once its exit has run.
  void remove(_FlowToastRecord record) {
    if (!toasts.remove(record)) return;
    record.close();
    if (toasts.isNotEmpty) {
      notifyListeners();
      return;
    }
    // The last one left: the entry goes now, and the layer's dispose —
    // next frame, once the overlay has rebuilt without it — drops the
    // notifier. remove() then dispose() back to back is the SDK's own
    // idiom.
    _release();
    _entry
      ..remove()
      ..dispose();
  }

  void _release() {
    _released = true;
    _stacks.remove(overlay);
  }

  /// The layer unmounted. After a release that is the tail of the normal
  /// path. Otherwise the overlay is going away under live toasts — its
  /// route popped, the playground remounting its phone, a hot restart —
  /// and this runs inside its unmount cascade, while `overlay.mounted`
  /// still reads true: the entry is let go a microtask later, when
  /// remove() on a dead overlay is the documented no-op.
  void layerUnmounted() {
    if (_released) {
      dispose();
      return;
    }
    _release();
    for (final record in toasts) {
      record.close();
    }
    toasts.clear();
    scheduleMicrotask(() {
      _entry
        ..remove()
        ..dispose();
      dispose();
    });
  }
}

/// The entry's widget: the stack's toasts as a deck at the overlay's top
/// edge, placed by the overlay's own width.
class _FlowToastLayer extends StatefulWidget {
  const _FlowToastLayer({required this.stack});

  final _FlowToastStack stack;

  @override
  State<_FlowToastLayer> createState() => _FlowToastLayerState();
}

/// Room kept around a card's clip for its shadow: the 24 blur reaches a
/// little past its own radius.
const double _shadowSlack = 36;

/// Taller than any card: an uncovered card whose height is not yet known
/// is clipped this far down, and the clipper stops at the card's own edge
/// anyway.
const double _anyCard = 400;

/// Where a card sits in the deck: how far down from the deck's top, how
/// much smaller than the front card, and where its clip ends — the foot
/// of the strip that peeks out above the card in front, or the shadow's
/// slack below an uncovered card.
@immutable
class _Pose {
  const _Pose({
    required this.dy,
    required this.scale,
    required this.clipBottom,
  });

  /// Where a card starts before the deck has placed it.
  static const _Pose open = _Pose(
    dy: 0,
    scale: 1,
    clipBottom: _anyCard + _shadowSlack,
  );

  final double dy;
  final double scale;
  final double clipBottom;

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
    dy: lerpDouble(a.dy, b.dy, t)!,
    scale: lerpDouble(a.scale, b.scale, t)!,
    clipBottom: lerpDouble(a.clipBottom, b.clipBottom, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is _Pose &&
      other.dy == dy &&
      other.scale == scale &&
      other.clipBottom == clipBottom;

  @override
  int get hashCode => Object.hash(dy, scale, clipBottom);
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({super.end});

  @override
  _Pose lerp(double t) => _Pose.lerp(begin!, end!, t);
}

class _FlowToastLayerState extends State<_FlowToastLayer> {
  /// Compact begins below 600 — the chat view's boundary, read from the
  /// overlay's own constraints so a pane or a phone frame counts. Compact
  /// spans the width inside 16 from the top edge; wide sits 358 across,
  /// 24 in from the top end corner.
  static const double _compactBreakpoint = 600;
  static const double _compactInset = 16;
  static const double _wideInset = 24;
  static const double _wideWidth = 358;

  /// The deck: the oldest card at the top edge, every newer one 10 lower
  /// and in front of it, so the cards behind the newest peek out above
  /// it, each 5% smaller a step back — a hand of cards. Under the pointer
  /// the deck fans out, 8 between the cards, so every line can be read
  /// and every cross reached; it stays fanned out under assistive
  /// navigation, where nothing may hide behind anything.
  static const double _peek = 10;
  static const double _scaleStep = 0.05;
  static const double _gap = 8;

  /// A card moving up the deck, the fan opening or closing: the
  /// jump-to-latest's 240ms.
  static const Duration _shuffle = Duration(milliseconds: 240);

  /// Each card's height, reported after its first layout; the deck is
  /// laid out from them a frame later, the way the web's toasts measure
  /// themselves before they stack. A card the deck cannot place yet holds
  /// where it is.
  final Map<_FlowToastRecord, double> _heights = {};
  bool _hovered = false;
  double? _deckHeight;
  bool _sized = false;

  /// The tallest the box has been under the pointer. A card dismissed
  /// from the fan leaves a gap the pointer is still in, and a box that
  /// closed up around the survivors would fire an exit the pointer never
  /// made — closing the fan and restarting every clock mid-read. The room
  /// is given back once the pointer truly leaves.
  double? _hoverHeight;

  void _measured(_FlowToastRecord record, double height) {
    if (!mounted || _heights[record] == height) return;
    setState(() => _heights[record] = height);
  }

  @override
  void dispose() {
    widget.stack.layerUnmounted();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read above the SafeArea below, which consumes this padding: inside
    // it the value always reads zero. The design's distances measure from
    // the display's edge, so they absorb its insets rather than stacking
    // on them — a notch would otherwise stand the card 24 below a 47pt
    // status bar, a gap the design never drew. Simulated phone frames
    // report no inset and keep the full distance. The chat view's rule.
    final safe = MediaQuery.paddingOf(context);
    final expanded = _hovered || MediaQuery.accessibleNavigationOf(context);
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _shuffle;

    // No Scaffold up here — the overlay sits above every route — and text
    // with no Material ancestor takes the framework's fallback style, the
    // preview's note.
    return Material(
      type: MaterialType.transparency,
      // The layer owns the display's top edge, so it clears the insets
      // itself. Every wrapper below is a proxy box with no hit test of
      // its own, so a tap beside a toast reaches the page.
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _compactBreakpoint;
            final inset = compact ? _compactInset : _wideInset;
            return Align(
              alignment: compact
                  ? Alignment.topCenter
                  : AlignmentDirectional.topEnd,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  math.max(0, inset - safe.left),
                  math.max(0, inset - safe.top),
                  math.max(0, inset - safe.right),
                  math.max(0, inset - safe.bottom),
                ),
                child: SizedBox(
                  width: compact ? double.infinity : _wideWidth,
                  child: ListenableBuilder(
                    listenable: widget.stack,
                    builder: (context, _) => _deck(expanded, motion),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _deck(bool expanded, Duration motion) {
    final toasts = widget.stack.toasts;
    _heights.removeWhere((record, _) => !toasts.contains(record));

    // Each card's place, oldest to newest. A leaving card holds its place
    // while it fades and counts for no one: the card it covered is
    // already growing back. Closed, every place follows from the count
    // alone; fanned out, from the heights of the cards above, and null
    // holds a card where it is until those are measured.
    final live = [
      for (final record in toasts)
        if (!record.leaving) record,
    ];
    final count = live.length;
    final poses = <_FlowToastRecord, _Pose?>{};
    final covered = <_FlowToastRecord>{};
    var offset = 0.0;
    var measured = true;
    for (var depth = count - 1; depth >= 0; depth--) {
      final record = live[depth];
      final height = _heights[record];
      if (expanded) {
        poses[record] = measured
            ? _Pose(
                dy: offset,
                scale: 1,
                clipBottom: (height ?? _anyCard) + _shadowSlack,
              )
            : null;
      } else if (depth == 0) {
        poses[record] = _Pose(
          dy: _peek * (count - 1),
          scale: 1,
          clipBottom: (height ?? _anyCard) + _shadowSlack,
        );
      } else {
        // Scaled about its top edge, which stays put; only the strip
        // above the card in front is drawn.
        covered.add(record);
        final scale = 1 - _scaleStep * depth;
        poses[record] = _Pose(
          dy: _peek * (count - 1 - depth),
          scale: scale,
          clipBottom: _peek / scale,
        );
      }
      if (height == null) {
        measured = false;
      } else {
        offset += height + _gap;
      }
    }
    if (count > 0) {
      final frontHeight = _heights[live.first];
      if (expanded) {
        if (measured) _deckHeight = offset - _gap;
      } else if (frontHeight != null) {
        _deckHeight = _peek * (count - 1) + frontHeight;
      }
    }

    // The deck's box is the pointer's target — a hover over the strips
    // opens the fan too — and it grows with the fan, so the pointer never
    // leaves it crossing a gap; under the pointer it never shrinks. The
    // first size is taken as is; the ones after move with the cards.
    final grow = _sized ? motion : Duration.zero;
    if (_deckHeight != null) _sized = true;
    if (_hovered) {
      _hoverHeight = math.max(_hoverHeight ?? 0, _deckHeight ?? 0);
    }
    final boxHeight = math.max(_deckHeight ?? 0, _hoverHeight ?? 0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: boxHeight),
      duration: grow,
      curve: Curves.easeOut,
      builder: (context, height, child) =>
          SizedBox(height: height, child: child),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _hoverHeight = null;
        }),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Deepest first: the front card paints last and takes the
            // pointer first.
            for (final record in toasts.reversed)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _FlowToastItem(
                  key: ObjectKey(record),
                  stack: widget.stack,
                  record: record,
                  pose: poses[record],
                  covered: covered.contains(record),
                  paused: expanded,
                  motion: motion,
                  onHeight: (height) => _measured(record, height),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One card in the deck: its entrance and exit, its clock, the frost
/// beneath it, and the place the deck hands it.
class _FlowToastItem extends StatefulWidget {
  const _FlowToastItem({
    super.key,
    required this.stack,
    required this.record,
    required this.pose,
    required this.covered,
    required this.paused,
    required this.motion,
    required this.onHeight,
  });

  final _FlowToastStack stack;
  final _FlowToastRecord record;

  /// Where the deck puts the card; null holds it where it is.
  final _Pose? pose;

  /// Behind the front card with the deck closed: only its strip shows,
  /// so it says nothing to assistive tech.
  final bool covered;

  /// The deck is fanned out: every clock waits.
  final bool paused;

  final Duration motion;
  final ValueChanged<double> onHeight;

  @override
  State<_FlowToastItem> createState() => _FlowToastItemState();
}

class _FlowToastItemState extends State<_FlowToastItem>
    with SingleTickerProviderStateMixin {
  /// Enter: fade in and settle 8 down from the edge over the drop
  /// treatment's 150ms; exit: the fade alone, run back.
  static const Duration _reveal = Duration(milliseconds: 150);
  static const double _settle = 8;

  /// The frost's corner — the card's 12, kept in step by hand.
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(12));

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _reveal,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  bool _started = false;
  bool _leaving = false;
  Timer? _timer;
  Duration? _remaining;
  final Stopwatch _elapsed = Stopwatch();
  late _Pose _pose = widget.pose ?? _Pose.open;

  @override
  void initState() {
    super.initState();
    _remaining = widget.record.duration;
    widget.record.leave = _leave;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion collapses both legs to nothing. MediaQuery is a
    // dependency, so it is read here: on the first pass to start, after
    // that to follow a change.
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _reveal;
    if (_started) return;
    _started = true;
    if (widget.record.dismissed) {
      // Dismissed before it was drawn: no entrance, straight out.
      _leaving = true;
      widget.record.leaving = true;
      _exit();
      return;
    }
    _controller.forward();
    _arm();
  }

  @override
  void didUpdateWidget(_FlowToastItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pose = widget.pose;
    if (pose != null) _pose = pose;
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        _pause();
      } else {
        _arm();
      }
    }
  }

  @override
  void dispose() {
    // The record outlives this state in the handle; a late dismiss must
    // not land on it.
    widget.record.leave = null;
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Armed on show, paused while the deck is fanned out under the
  /// pointer, resumed with what was left. Never for a sticky toast, nor
  /// under assistive navigation, where a notice that leaves on its own
  /// may leave before it was reached — the snack bar's rule.
  void _arm() {
    final left = _remaining;
    if (left == null || _leaving || _timer != null || widget.paused) return;
    if (MediaQuery.accessibleNavigationOf(context)) return;
    _elapsed
      ..reset()
      ..start();
    _timer = Timer(left, () {
      _timer = null;
      _leave();
    });
  }

  void _pause() {
    final timer = _timer;
    if (timer == null) return;
    timer.cancel();
    _timer = null;
    _elapsed.stop();
    final left = _remaining! - _elapsed.elapsed;
    _remaining = left.isNegative ? Duration.zero : left;
  }

  void _leave() {
    if (_leaving) return;
    _timer?.cancel();
    _timer = null;
    setState(() => _leaving = true);
    // The card behind moves up as this one fades, not after.
    widget.stack.leaving(widget.record);
    _exit();
  }

  void _exit() {
    // whenCompleteOrCancel, not await: a controller disposed mid-exit —
    // the overlay torn down under a leaving toast — never resolves the
    // plain future, and the stack has already closed the record.
    _controller.reverse().whenCompleteOrCancel(() {
      if (!mounted) return;
      widget.stack.remove(widget.record);
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.record.toast;
    final card = FlowToast(
      message: source.message,
      icon: source.icon,
      dismissTooltip: source.dismissTooltip,
      style: source.style,
      onDismiss: _leave,
    );

    // The transforms sit outermost: RenderTransform is the one box that
    // hit-tests outside its own bounds, and a card behind the front one is
    // drawn well outside the box it was laid out in. Everything that
    // checks its size — the pointer and semantics gates, the clip — comes
    // after them, in the card's own space.
    return TweenAnimationBuilder<_Pose>(
      tween: _PoseTween(end: _pose),
      duration: widget.motion,
      curve: Curves.easeOut,
      child: _ReportHeight(onHeight: widget.onHeight, child: card),
      builder: (context, pose, child) => AnimatedBuilder(
        animation: _curve,
        child: child,
        builder: (context, child) {
          final t = _curve.value;
          // Canvas transforms, not offscreen layers, so the frost below
          // still samples the page through them.
          return Transform.translate(
            offset: Offset(0, pose.dy - _settle * (1 - t)),
            child: Transform.scale(
              scale: pose.scale,
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                ignoring: _leaving,
                child: ExcludeSemantics(
                  excluding: _leaving || widget.covered,
                  // Behind the front card only the strip is drawn: what
                  // the card in front covers never paints, so nothing
                  // ghosts through its frost.
                  child: ClipRect(
                    clipper: _DeckClipper(pose.clipBottom),
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        // The frost is a sibling *behind* the card, never
                        // an ancestor of its fade: anything inside an
                        // Opacity joins that layer, and a BackdropFilter
                        // in there samples the layer, not the page — the
                        // preview's rule. Opacity skips its layer at 1, so
                        // a settled toast costs one filter and nothing
                        // else.
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: _radius,
                            child: BackdropFilter(
                              filter: _blurFilter,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        Opacity(opacity: t, child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The card's clip: down to [bottom] — the strip's foot, or past the
/// card's own edge — with the slack kept above and at the sides for the
/// shadow. Hit tests follow the clip, so a covered card takes the pointer
/// on its strip alone.
class _DeckClipper extends CustomClipper<Rect> {
  const _DeckClipper(this.bottom);

  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -_shadowSlack,
    -_shadowSlack,
    size.width + _shadowSlack,
    math.min(bottom, size.height + _shadowSlack),
  );

  @override
  bool shouldReclip(_DeckClipper oldClipper) => oldClipper.bottom != bottom;
}

/// Reports the card's laid-out height to the deck once the frame is done;
/// the deck places the cards from it on the next.
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
