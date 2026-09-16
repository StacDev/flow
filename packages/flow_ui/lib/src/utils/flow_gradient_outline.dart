import 'package:flutter/widgets.dart';

// Internal painter shared by the raised cards. Not exported from the
// package barrel.

/// A raised card's hairline: a 1px stroke centered on the card's edge,
/// shaded by the design's ink gradient — strongest at the top-left,
/// thinning toward the bottom-right.
///
/// Meant as a `foregroundPainter` over the card's own decoration, so the
/// outline never takes layout space and the card can swap gradients
/// without shifting its content.
class FlowGradientOutlinePainter extends CustomPainter {
  const FlowGradientOutlinePainter({
    required this.radius,
    required this.start,
    required this.end,
  });

  final BorderRadius radius;
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [start, end],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect).deflate(0.5), paint);
  }

  @override
  bool shouldRepaint(FlowGradientOutlinePainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.radius != radius;
}
