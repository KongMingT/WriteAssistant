import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 32, this.showText = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: size, height: size, child: CustomPaint(painter: _LogoPainter())),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            'WriterAssistant',
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);

    // === Background: rounded square with gradient ===
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: s, height: s),
      Radius.circular(s * 0.22),
    );

    final bgGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF7C3AED),
          const Color(0xFF4F46E5),
          const Color(0xFF6366F1),
          const Color(0xFF8B5CF6),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCenter(center: center, width: s, height: s));

    canvas.drawRRect(bgRect, bgGradient);

    // === Inner glow ===
    final glowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: s * 0.85, height: s * 0.85),
      Radius.circular(s * 0.18),
    );
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withAlpha(30), Colors.transparent],
      ).createShader(Rect.fromCenter(center: center, width: s * 0.85, height: s * 0.85));
    canvas.drawRRect(glowRect, glowPaint);

    // === W letter parameters ===
    final w = s * 0.58;
    final h = s * 0.5;
    final left = (s - w) / 2;
    final top = (s - h) / 2 + s * 0.02;
    final strokeWidth = w * 0.15;

    // W key points
    final p1 = Offset(left, top + h);                 // bottom-left
    final p2 = Offset(left + w * 0.33, top);          // left peak
    final p3 = Offset(left + w * 0.5, top + h * 0.55); // middle valley
    final p4 = Offset(left + w * 0.67, top);          // right peak
    final p5 = Offset(left + w, top + h);             // bottom-right

    // Shadow layer
    canvas.save();
    canvas.translate(s * 0.015, s * 0.025);
    _drawW(canvas, p1, p2, p3, p4, p5, strokeWidth * 1.1,
        Paint()..color = const Color(0x40000000)..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.restore();

    // Extrusion layer
    canvas.save();
    canvas.translate(s * 0.008, 0);
    _drawW(canvas, p1, p2, p3, p4, p5, strokeWidth * 1.05,
        Paint()..color = const Color(0xFF3B34CC)..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.restore();

    // Main W shape with gradient
    _drawW(canvas, p1, p2, p3, p4, p5, strokeWidth,
        Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFE0E7FF), const Color(0xFFC7D2FE), Colors.white],
          ).createShader(Rect.fromCenter(center: center, width: s, height: s)));

    // Highlight on upward segments
    final hl = Paint()..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.3..strokeCap = StrokeCap.round
      ..color = Colors.white.withAlpha(120);
    _drawStroke(canvas, p1, p2, hl);
    _drawStroke(canvas, p3, p4, hl);
  }

  void _drawW(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4, Offset p5, double sw, Paint paint) {
    paint.strokeWidth = sw;
    _drawStroke(canvas, p1, p2, paint);
    _drawStroke(canvas, p2, p3, paint);
    _drawStroke(canvas, p3, p4, paint);
    _drawStroke(canvas, p4, p5, paint);
  }

  void _drawStroke(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawPath(Path()..moveTo(from.dx, from.dy)..lineTo(to.dx, to.dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
