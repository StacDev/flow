import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The six-armed asterisk: three rounded strokes through the center. Drawn
/// rather than shipped — no SDK glyph matches the design's mark, and paint
/// stays crisp at any size and tint.
///
/// The mark of the library's own chrome — the thinking indicator turns it,
/// the confirmation card plants it on the header — shared here rather than
/// duplicated. Internal, like `FlowCircleButton`: not exported from the
/// package barrel.
class FlowAsteriskPainter extends CustomPainter {
  const FlowAsteriskPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // A translucent ink would composite twice where the strokes cross,
    // darkening the hub against text in the same ink. Flatten the mark
    // into one layer and apply the ink's alpha to the whole glyph once.
    final translucent = color.a < 1;
    if (translucent) {
      canvas.saveLayer(
        (Offset.zero & size).inflate(strokeWidth),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: color.a),
      );
      paint.color = color.withValues(alpha: 1);
    }
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    for (var i = 0; i < 3; i++) {
      // Three diameters at 60° steps, starting upright so the resting mark
      // has the design's vertical arm.
      final angle = math.pi / 2 + math.pi * i / 3;
      final delta = Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(center - delta, center + delta, paint);
    }
    if (translucent) canvas.restore();
  }

  @override
  bool shouldRepaint(FlowAsteriskPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
