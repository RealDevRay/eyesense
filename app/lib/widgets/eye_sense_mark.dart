import 'package:flutter/material.dart';

/// Lens dot with three arcs. Light in, speech out.
class EyeSenseMark extends StatelessWidget {
  final double size;
  final Color color;

  const EyeSenseMark({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(color),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final Color color;
  _MarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width * 0.34, size.height * 0.5);
    canvas.drawCircle(center, size.width * 0.1, paint);
    for (var i = 1; i <= 3; i++) {
      final radius = size.width * (0.16 + i * 0.12);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -0.9,
        1.8,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => oldDelegate.color != color;
}
