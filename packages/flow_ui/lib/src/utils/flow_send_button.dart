import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import '../styles/flow_composer_style.dart';
import '../theme/flow_theme.dart';

class FlowSendButton extends StatefulWidget {
  const FlowSendButton({
    super.key,
    required this.streaming,
    required this.canSend,
    required this.onSend,
    this.onStop,
    this.sendTooltip,
    this.stopTooltip,
    this.style,
  });

  final bool streaming;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final String? sendTooltip;
  final String? stopTooltip;
  final FlowComposerStyle? style;

  @override
  State<FlowSendButton> createState() => _FlowSendButtonState();
}

class _FlowSendButtonState extends State<FlowSendButton>
    with TickerProviderStateMixin {
  /// Send and stop are the design's ringed button: a 26px disc inside a
  /// surface-colored gap and a 1px ring, on a 32px frame.
  static const double _frame = 32;
  static const double _disc = 26;

  /// Centers the stop glyph on the disc (26 = 18 + 2 × 4).
  static const double _stopPadding = 4;
  static const double _stopIconSize = 18;

  static const Duration _glyphDuration = Duration(milliseconds: 180);
  static const Duration _ringDuration = Duration(milliseconds: 240);
  static const Duration _turnDuration = Duration(milliseconds: 1200);
  static const double _streamingSweep = 100 * math.pi / 180;
  static const double _glyphShift = 6 / _disc;
  static const double _stopEntryScale = 0.6;
  static const ValueKey<String> _arrowKey = ValueKey('arrow');
  static const ValueKey<String> _stopKey = ValueKey('stop');
  static final Animatable<double> _ease = CurveTween(curve: Curves.easeOut);

  late final AnimationController _unwind;
  late final AnimationController _presence;
  late final AnimationController _turn;
  late final CurvedAnimation _unwound;
  late final CurvedAnimation _present;
  bool? _reduceMotion;
  Duration _fillDuration = Duration.zero;

  bool get _animates =>
      !(_reduceMotion ?? false) && (widget.style?.animateStreaming ?? true);

  @override
  void initState() {
    super.initState();
    _unwind = AnimationController(vsync: this, duration: _ringDuration);
    _presence = AnimationController(vsync: this, duration: _ringDuration)
      ..addStatusListener(_handlePresenceStatus);
    _turn = AnimationController(vsync: this, duration: _turnDuration);
    _unwound = CurvedAnimation(parent: _unwind, curve: Curves.easeOut);
    _present = CurvedAnimation(parent: _presence, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion == _reduceMotion) return;
    final first = _reduceMotion == null;
    _reduceMotion = reduceMotion;
    _syncRing(settle: first);
  }

  @override
  void didUpdateWidget(FlowSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final flipped = widget.streaming != oldWidget.streaming;
    _fillDuration = flipped && _animates ? _glyphDuration : Duration.zero;
    if (flipped ||
        (widget.style?.animateStreaming ?? true) !=
            (oldWidget.style?.animateStreaming ?? true)) {
      _syncRing(
        settle: false,
        fadeIn: !(oldWidget.streaming || oldWidget.canSend),
      );
    }
  }

  @override
  void dispose() {
    _unwound.dispose();
    _present.dispose();
    _unwind.dispose();
    _presence.dispose();
    _turn.dispose();
    super.dispose();
  }

  void _handlePresenceStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    _turn
      ..stop()
      ..value = 0;
    _unwind.value = 0;
  }

  void _syncRing({required bool settle, bool fadeIn = true}) {
    if (!_animates) {
      _presence.value = 0;
      return;
    }
    if (widget.streaming) {
      if (settle) {
        _unwind.value = 1;
        _presence.value = 1;
      } else if (_presence.isDismissed) {
        _unwind.forward(from: 0);
        if (fadeIn) {
          _presence.forward(from: 0);
        } else {
          _presence.value = 1;
        }
      } else {
        _presence.forward();
      }
      if (!_turn.isAnimating) _turn.repeat();
    } else if (settle) {
      _presence.value = 0;
    } else if (!_presence.isDismissed) {
      _presence.reverse();
    }
  }

  static Widget _stackGlyphs(Widget? current, List<Widget> previous) => Stack(
    fit: StackFit.expand,
    alignment: Alignment.center,
    children: [...previous, ?current],
  );

  Widget _transition(Widget child, Animation<double> animation, Key current) {
    final opacity = animation.drive(_ease);
    if (child.key == _stopKey) {
      return FadeTransition(
        opacity: opacity,
        child: ScaleTransition(
          scale: animation.drive(
            Tween<double>(begin: _stopEntryScale, end: 1).chain(_ease),
          ),
          child: child,
        ),
      );
    }
    final shift = child.key == current ? _glyphShift : -_glyphShift;
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(begin: Offset(0, shift), end: Offset.zero).chain(_ease),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.flowColors;
    final style = widget.style;
    final streaming = widget.streaming;
    final canSend = widget.canSend;
    final discColor = style?.sendBackgroundColor ?? colors.primary;
    final glyphColor = style?.sendForegroundColor ?? colors.onPrimary;
    final animates = _animates;
    final active = streaming || canSend;
    final ringColor = active && !(streaming && animates)
        ? discColor
        : colors.outlineVariant;
    final ground = style?.backgroundColor ?? colors.surfaceBright;
    final label = streaming ? widget.stopTooltip : widget.sendTooltip;
    final glyphKey = streaming ? _stopKey : _arrowKey;

    final Widget glyph = streaming
        ? Padding(
            key: _stopKey,
            padding: const EdgeInsets.all(_stopPadding),
            child: Icon(
              Icons.stop_rounded,
              size: _stopIconSize,
              color: glyphColor,
            ),
          )
        : CustomPaint(
            key: _arrowKey,
            // The design's arrow is a thin stroke, not the chunky
            // Material glyph.
            painter: _ArrowUpPainter(color: glyphColor),
          );

    final button = Semantics(
      container: true,
      button: true,
      enabled: streaming ? widget.onStop != null : canSend,
      label: label,
      child: RepaintBoundary(
        child: CustomPaint(
          foregroundPainter: _ArcPainter(
            unwind: _unwound,
            presence: _present,
            turn: _turn,
            color: discColor,
          ),
          // The design's button anatomy: the disc floats inside a gap of the
          // card's own surface, enclosed by a hairline ring — the ring muted
          // while the button can't act, so the geometry never jumps on enable.
          child: Container(
            width: _frame,
            height: _frame,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: ground,
              shape: CircleBorder(side: BorderSide(color: ringColor)),
            ),
            child: SizedBox.square(
              dimension: _disc,
              child: TweenAnimationBuilder<Color?>(
                // Disabled keeps the arrow's ink and only drains the disc:
                // primary gives way to the 30% disabled wash.
                tween: _FillTween(
                  end: active ? discColor : colors.onSurfaceDisabled,
                  ground: ground,
                ),
                duration: _fillDuration,
                curve: Curves.easeOut,
                builder: (context, fill, child) => Material(
                  color: fill,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: child,
                ),
                child: InkWell(
                  onTap: streaming
                      ? widget.onStop
                      : (canSend ? widget.onSend : null),
                  customBorder: const CircleBorder(),
                  child: AnimatedSwitcher(
                    duration: animates ? _glyphDuration : Duration.zero,
                    layoutBuilder: _stackGlyphs,
                    transitionBuilder: (child, animation) =>
                        _transition(child, animation, glyphKey),
                    child: glyph,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (label == null) return button;
    return Tooltip(message: label, excludeFromSemantics: true, child: button);
  }
}

class _FillTween extends ColorTween {
  _FillTween({super.end, required this.ground});

  final Color ground;

  @override
  Color? lerp(double t) {
    final begin = this.begin;
    final end = this.end;
    if (begin == null || end == null) return super.lerp(t);
    return Color.lerp(
      Color.alphaBlend(begin, ground),
      Color.alphaBlend(end, ground),
      t,
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.unwind,
    required this.presence,
    required this.turn,
    required this.color,
  }) : super(repaint: Listenable.merge([unwind, presence, turn]));

  final Animation<double> unwind;
  final Animation<double> presence;
  final Animation<double> turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = presence.value;
    if (opacity <= 0) return;
    final sweep = lerpDouble(
      2 * math.pi,
      _FlowSendButtonState._streamingSweep,
      unwind.value,
    )!;
    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: (size.shortestSide - 1) / 2,
      ),
      turn.value * 2 * math.pi - math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: color.a * opacity),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.unwind != unwind ||
      oldDelegate.presence != presence ||
      oldDelegate.turn != turn;
}

/// The send arrow: a thin rounded stroke, matching the design's 1.5-weight
/// mark rather than the Material icon's filled glyph. Drawn to scale with
/// the disc it sits on.
class _ArrowUpPainter extends CustomPainter {
  const _ArrowUpPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.shortestSide / 17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final center = size.center(Offset.zero);
    // The design's proportions on its 26px disc: a 12-tall stem with a
    // 10-wide head.
    final stem = size.shortestSide * (12 / 26) / 2;
    final head = size.shortestSide * (10 / 26) / 2;
    final top = Offset(center.dx, center.dy - stem);
    canvas.drawLine(top, Offset(center.dx, center.dy + stem), paint);
    final path = Path()
      ..moveTo(center.dx - head, top.dy + head)
      ..lineTo(top.dx, top.dy)
      ..lineTo(center.dx + head, top.dy + head);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowUpPainter oldDelegate) => oldDelegate.color != color;
}
