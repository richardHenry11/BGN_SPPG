import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'dart:math' as math;
import '../../theme/colors.dart';

class CarLoading extends StatefulWidget {
  final double size;
  final Color? color;
  final String? label;

  const CarLoading({
    super.key,
    this.size = 24,
    this.color,
    this.label,
  });

  @override
  State<CarLoading> createState() => _CarLoadingState();
}

class _CarLoadingState extends State<CarLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carColor = widget.color ?? BGNColors.primary;
    final size = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: size * 4,
          height: size * 1.8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Road lines
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(size * 4, size * 0.3),
                  painter: _RoadPainter(
                    progress: _controller.value,
                    color: carColor.withOpacity(0.5),
                  ),
                ),
              ),
              // Car body
              Positioned(
                left: (size * 3.5) * _controller.value,
                top: size * 0.15,
                child: Transform(
                  transform: Matrix4.identity()
                    ..setTranslationRaw(0.0, size * 0.08 * _bounce(_controller.value), 0),
                  child: Icon(
                    TablerIcons.truck,
                    size: size,
                    color: carColor,
                  ),
                ),
              ),
              if (widget.label != null)
                Positioned(
                  bottom: -size * 0.3,
                  left: 0,
                  right: 0,
                  child: Text(
                    widget.label!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: size * 0.35,
                      color: carColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _bounce(double value) {
    return math.sin(value * math.pi * 2).abs() * 0.5;
  }
}

class _RoadPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RoadPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashCount = 6;
    final dashWidth = size.width / dashCount / 2;
    final gapWidth = size.width / dashCount / 2;

    final offset = (progress * size.width) % (dashWidth + gapWidth);

    for (var i = -1; i < dashCount + 1; i++) {
      final x = i * (dashWidth + gapWidth) - offset;
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + dashWidth, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RoadPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class InlineCarLoading extends StatelessWidget {
  final double size;
  final Color? color;
  final String? label;

  const InlineCarLoading({
    super.key,
    this.size = 18,
    this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final carColor = color ?? BGNColors.primary;

    if (label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size * 5,
            height: size * 2,
            child: CarLoading(size: size, color: carColor),
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                fontSize: size * 0.6,
                color: carColor,
              ),
            ),
          ],
        ],
      );
    }

    return SizedBox(
      width: size * 5,
      height: size * 2,
      child: CarLoading(size: size, color: carColor),
    );
  }
}

class ButtonCarLoading extends StatelessWidget {
  final String? label;

  const ButtonCarLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return InlineCarLoading(
      size: 14,
      color: Colors.white,
      label: label,
    );
  }
}
