import 'package:flutter/material.dart';
import 'car_loading.dart';

class CarRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CarRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<CarRefreshIndicator> createState() => _CarRefreshIndicatorState();
}

class _CarRefreshIndicatorState extends State<CarRefreshIndicator> {
  bool _isRefreshing = false;
  double _pullOffset = 0;

  static const double _indicatorHeight = 50;
  static const double _triggerThreshold = 55;
  static const double _maxPull = 80;

  bool _onScroll(ScrollNotification notification) {
    if (!mounted) return false;
    if (_isRefreshing) return true;

    // Handle bouncing scroll physics (iOS)
    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      final minExtent = notification.metrics.minScrollExtent;

      if (pixels < minExtent) {
        _pullOffset = (minExtent - pixels).clamp(0, _maxPull);
        setState(() {});
        return true;
      }
    }

    // Handle clamping scroll physics (Android)
    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        _pullOffset =
            (_pullOffset + notification.overscroll.abs() * 0.4)
                .clamp(0, _maxPull);
      } else {
        _pullOffset =
            (_pullOffset - notification.overscroll.abs() * 0.6)
                .clamp(0, _maxPull);
      }
      setState(() {});
      return true;
    }

    if (notification is ScrollEndNotification) {
      if (_pullOffset >= _triggerThreshold) {
        _startRefresh();
      } else {
        _pullOffset = 0;
        setState(() {});
      }
    }

    return false;
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
      _pullOffset = _indicatorHeight;
    });
    await widget.onRefresh();
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _pullOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showIndicator = _pullOffset > 0;
    final carTop = _isRefreshing ? 8.0 : _pullOffset - _indicatorHeight + 8;

    return ClipRect(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: showIndicator ? _indicatorHeight : 0),
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
          ),
          if (showIndicator)
            Positioned(
              top: carTop,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: _indicatorHeight,
                  alignment: Alignment.center,
                  child: CarLoading(size: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
