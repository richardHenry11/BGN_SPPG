import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bgn/distribusi/theme/colors.dart';

class NavArrowMarker extends StatefulWidget {
  final double heading;

  const NavArrowMarker({super.key, required this.heading});

  @override
  State<NavArrowMarker> createState() => _NavArrowMarkerState();
}

class _NavArrowMarkerState extends State<NavArrowMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 2.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = BGNColors.primary;
    return SizedBox(
      width: 60,
      height: 60,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Radar ring
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.0),
                    border: Border.all(
                      color: color.withOpacity(_opacity.value),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
            // Arrow pointing up, rotated by heading
            Transform.rotate(
              angle: widget.heading * math.pi / 180,
              child: Icon(
                Icons.navigation,
                color: Colors.white,
                size: 30,
              ),
            ),
            // Outer border ring for the arrow
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.85),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Transform.rotate(
                angle: widget.heading * math.pi / 180,
                child: Icon(
                  Icons.navigation,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
