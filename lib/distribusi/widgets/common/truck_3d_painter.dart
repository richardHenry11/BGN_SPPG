import 'package:flutter/material.dart';
import 'package:bgn/distribusi/theme/colors.dart';

class Truck3DPainter extends CustomPainter {
  final Color color;

  Truck3DPainter({this.color = BGNColors.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawShadow(canvas, w, h);
    _drawBody(canvas, w, h);
    _drawCabin(canvas, w, h);
    _drawGlass(canvas, w, h);
    _drawWheels(canvas, w, h);
  }

  void _drawShadow(Canvas canvas, double w, double h) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.15, h * 0.12, w * 0.7, h * 0.82),
      shadowPaint,
    );
  }

  void _drawBody(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.28, h * 0.2, w * 0.56, h * 0.66),
      const Radius.circular(5),
    );
    final bodyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _darken(color, 0.2),
        color,
        _lighten(color, 0.15),
      ],
    );
    final bodyPaint = Paint()
      ..shader = bodyGradient.createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);

    final outlinePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(bodyRect, outlinePaint);
  }

  void _drawCabin(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final cabinRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.24, h * 0.08, w * 0.48, h * 0.22),
      const Radius.circular(6),
    );
    final cabinPaint = Paint()
      ..color = _lighten(color, 0.25);
    canvas.drawRRect(cabinRect, cabinPaint);
  }

  void _drawGlass(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final glassRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.18, h * 0.10, w * 0.36, h * 0.06),
      const Radius.circular(2),
    );
    final glassPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5);
    canvas.drawRRect(glassRect, glassPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.14, h * 0.11, w * 0.08, h * 0.04),
        const Radius.circular(1),
      ),
      highlightPaint,
    );
  }

  void _drawWheels(Canvas canvas, double w, double h) {
    final cx = w / 2;
    final wheelW = w * 0.06;
    final wheelH = h * 0.10;

    // Front left
    _drawWheel(canvas, Offset(cx - w * 0.30, h * 0.30), wheelW, wheelH);
    // Front right
    _drawWheel(canvas, Offset(cx + w * 0.30, h * 0.30), wheelW, wheelH);
    // Rear left
    _drawWheel(canvas, Offset(cx - w * 0.30, h * 0.72), wheelW, wheelH);
    // Rear right
    _drawWheel(canvas, Offset(cx + w * 0.30, h * 0.72), wheelW, wheelH);
  }

  void _drawWheel(Canvas canvas, Offset center, double wheelW, double wheelH) {
    final rect = Rect.fromCenter(
      center: center,
      width: wheelW,
      height: wheelH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = Colors.black87,
    );
    // Hub highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center - const Offset(0.5, 0.5),
          width: wheelW * 0.4,
          height: wheelH * 0.3,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.grey[700]!,
    );
  }

  Color _darken(Color c, double amount) {
    return Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      ((c.r * 255) * (1 - amount)).round().clamp(0, 255),
      ((c.g * 255) * (1 - amount)).round().clamp(0, 255),
      ((c.b * 255) * (1 - amount)).round().clamp(0, 255),
    );
  }

  Color _lighten(Color c, double amount) {
    return Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      ((c.r * 255) + (255 - (c.r * 255)) * amount).round().clamp(0, 255),
      ((c.g * 255) + (255 - (c.g * 255)) * amount).round().clamp(0, 255),
      ((c.b * 255) + (255 - (c.b * 255)) * amount).round().clamp(0, 255),
    );
  }

  @override
  bool shouldRepaint(covariant Truck3DPainter old) => old.color != color;
}
