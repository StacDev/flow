import 'package:material_ui/material_ui.dart';

// Internal — not exported from the package barrel.

/// The shimmer's sweep, extracted so `FlowShimmerText` and the
/// generating-image placeholder share one clock and one gradient.
///
/// Masks [child] with a band of [highlightColor] sliding over
/// [baseColor]; under reduced motion the child renders statically in the
/// base ink instead. Either way the mask multiplies its color by the
/// child's alpha, so the child must paint opaque — a translucent ink
/// there would dim the result a second time.
class FlowShimmerSweep extends StatefulWidget {
  const FlowShimmerSweep({
    super.key,
    required this.baseColor,
    required this.highlightColor,
    this.duration = const Duration(milliseconds: 2400),
    required this.child,
  });

  /// Resting ink.
  final Color baseColor;

  /// The sweeping band.
  final Color highlightColor;

  /// One full sweep across the child.
  final Duration duration;

  /// Opaque content the sweep paints through — glyphs, a block.
  final Widget child;

  @override
  State<FlowShimmerSweep> createState() => _FlowShimmerSweepState();
}

class _FlowShimmerSweepState extends State<FlowShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Null until first resolved, so the initial [didChangeDependencies]
  /// always syncs (starting the animation).
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only resync when reduced-motion actually changes — this fires for any
    // inherited update (e.g. theme toggles), and an unconditional repeat()
    // would restart the sweep and hitch it.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      _syncAnimation();
    }
  }

  @override
  void didUpdateWidget(FlowShimmerSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (_reduceMotion ?? false) {
      _controller.stop();
    } else {
      // (Re)start so a changed duration takes effect immediately.
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion ?? false) {
      // Static: the child parked in the base ink.
      return ColorFiltered(
        colorFilter: ColorFilter.mode(widget.baseColor, BlendMode.srcIn),
        child: widget.child,
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlidingGradient(_controller.value),
          ).createShader(bounds),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Slides the gradient one full width past each edge, so the band enters
/// from off-content and leaves off-content — the repeat's wrap lands
/// while the highlight is invisible and the loop never visibly jumps.
class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.progress);

  final double progress;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (2 * progress - 1), 0, 0);
}
