import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/websocket_service.dart';

class RoutePoint {
  final double lat;
  final double lng;
  final String time;

  RoutePoint({required this.lat, required this.lng, required this.time});

  LatLng get latLng => LatLng(lat, lng);

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      time: json['time'] as String? ?? '',
    );
  }
}

class DriverPosition {
  final int packagingId;
  double latitude;
  double longitude;
  List<RoutePoint> routeHistory;

  LatLng get latLng => LatLng(latitude, longitude);

  DriverPosition({
    required this.packagingId,
    required this.latitude,
    required this.longitude,
    List<RoutePoint>? routeHistory,
  }) : routeHistory = routeHistory ?? [];

  factory DriverPosition.fromJson(Map<String, dynamic> json) {
    final history = (json['route_history'] as List<dynamic>?)
            ?.map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return DriverPosition(
      packagingId: (json['packaging_id'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      routeHistory: history,
    );
  }
}

class TrackingProvider extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final ApiClient _apiClient = ApiClient();
  Timer? _gpsTimer;

  static const String _wsBaseUrl = 'wss://sppg.cbinstrument.com/api/ws';

  bool _connected = false;
  bool _sendingGps = false;
  int? _activePackagingId;
  int _sentCount = 0;
  double? _lastSentLat;
  double? _lastSentLng;
  double? _prevLat;
  double? _prevLng;
  DateTime? _lastSentTime;

  double? _heading;
  double? get heading => _heading;
  LatLng? _lastStablePos;

  final Map<int, double> _driverHeadings = {};

  final Map<int, DriverPosition> _driverPositions = {};
  final Map<int, LatLng> _prevDriverPositions = {};
  Map<int, DriverPosition> get driverPositions =>
      Map<int, DriverPosition>.unmodifiable(_driverPositions);

  bool get connected => _connected;
  bool get sendingGps => _sendingGps;
  int? get activePackagingId => _activePackagingId;
  int get sentCount => _sentCount;
  double? get lastSentLat => _lastSentLat;
  double? get lastSentLng => _lastSentLng;
  String? get lastSentTimeStr => _lastSentTime?.toLocal().toString().substring(11, 19);
  double? get lastDelta => _deltaDistance();

  double? _deltaDistance() {
    if (_prevLat == null || _prevLng == null ||
        _lastSentLat == null || _lastSentLng == null) {
      return null;
    }
    final dlat = _lastSentLat! - _prevLat!;
    final dlng = _lastSentLng! - _prevLng!;
    return math.sqrt(dlat * dlat + dlng * dlng) * 111319.9;
  }

  double headingForDriver(int packagingId) {
    return _driverHeadings[packagingId] ?? _heading ?? 0.0;
  }

  void _updateOwnHeading(LatLng newPos) {
    if (_lastStablePos == null) {
      _lastStablePos = newPos;
      return;
    }
    final distance = const Distance().as(LengthUnit.Meter, _lastStablePos!, newPos);
    if (distance < 5) return;
    final newHeading = _calculateBearing(_lastStablePos!, newPos);
    _heading = _shortestAngleLerp(_heading ?? newHeading, newHeading);
    _lastStablePos = newPos;
  }

  double _shortestAngleLerp(double from, double to) {
    final delta = (to - from + 540) % 360 - 180;
    return (from + delta + 360) % 360;
  }

  static double _calculateBearing(LatLng from, LatLng to) {
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  List<DriverPosition> get positionsList => _driverPositions.values.toList();

  StreamSubscription<Map<String, dynamic>>? _subscription;

  // ── Debug log ──
  static const int _maxLogs = 50;
  final List<GpsLog> _logs = [];
  List<GpsLog> get logs => List.unmodifiable(_logs);

  void addLog(String msg, {bool isError = false}) {
    _logs.add(GpsLog(msg, isError: isError));
    if (_logs.length > _maxLogs) _logs.removeAt(0);
    debugPrint('[GPS] $msg');
    notifyListeners();
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }

  void connect(int userId) {
    if (_connected) {
      addLog('Already connected, skip');
      return;
    }
    addLog('Connecting WS as user #$userId...');
    _wsService.connect(_wsBaseUrl, userId);
    _subscription = _wsService.messages.listen(_handleMessage);
    _connected = true;
    addLog('WS connected');
    notifyListeners();
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    addLog('WS recv: $type  data=${_truncate(jsonEncode(msg['data']), 120)}');
    if (type == 'location_update') {
      final rawData = msg['data'] as Map<String, dynamic>?;
      if (rawData == null) return;
      final pos = DriverPosition.fromJson(rawData);
      final prev = _driverPositions[pos.packagingId];
      if (prev != null) {
        _prevDriverPositions[pos.packagingId] = prev.latLng;
        _driverHeadings[pos.packagingId] = _calculateBearing(
          prev.latLng, pos.latLng,
        );
      } else if (pos.routeHistory.length >= 2) {
        final last = pos.routeHistory.length - 1;
        _driverHeadings[pos.packagingId] = _calculateBearing(
          pos.routeHistory[last - 1].latLng,
          pos.routeHistory[last].latLng,
        );
      }
      _driverPositions[pos.packagingId] = pos;
      notifyListeners();
    }
  }

  void startSendingGps(int packagingId) {
    _activePackagingId = packagingId;
    _sendingGps = true;
    addLog('Start GPS every 3s, packaging #$packagingId');
    notifyListeners();
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendGpsUpdate();
    });
  }

  Future<void> _sendGpsUpdate() async {
    if (_activePackagingId == null) return;
    addLog('GPS tick #${_sentCount + 1}');
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      addLog('GPS got: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} (acc: ${pos.accuracy}m)');

      final payload = jsonEncode({
        'type': 'location_update',
        'user_id': _activePackagingId,
        'data': {
          'packaging_id': _activePackagingId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        },
      });
      if (_wsService.isConnected) {
        _wsService.sendLocation(
          _activePackagingId!,
          pos.latitude,
          pos.longitude,
        );
        addLog('Sent >> ${_truncate(payload, 150)}');
      } else {
        await _apiClient.sendLocation(
          _activePackagingId!,
          pos.latitude,
          pos.longitude,
        );
        addLog('Sent REST (WS down) >> ${_truncate(payload, 150)}');
      }
      _prevLat = _lastSentLat;
      _prevLng = _lastSentLng;
      _sentCount++;
      _lastSentLat = pos.latitude;
      _lastSentLng = pos.longitude;
      _lastSentTime = DateTime.now();
      _updateOwnHeading(LatLng(pos.latitude, pos.longitude));
      notifyListeners();
    } catch (e) {
      addLog('ERROR: $e', isError: true);
    }
  }

  void stopSendingGps() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    _sendingGps = false;
    _activePackagingId = null;
    _sentCount = 0;
    _lastSentLat = null;
    _lastSentLng = null;
    _prevLat = null;
    _prevLng = null;
    _lastSentTime = null;
    _heading = null;
    _lastStablePos = null;
    addLog('GPS stopped');
    notifyListeners();
  }

  void disconnect() {
    stopSendingGps();
    _subscription?.cancel();
    _wsService.disconnect();
    _driverPositions.clear();
    _driverHeadings.clear();
    _prevDriverPositions.clear();
    _connected = false;
    addLog('Disconnected');
    notifyListeners();
  }

  void reset() {
    disconnect();
  }

  @override
  void dispose() {
    stopSendingGps();
    _subscription?.cancel();
    _wsService.dispose();
    _driverPositions.clear();
    super.dispose();
  }
}

class GpsLog {
  final String message;
  final DateTime time;
  final bool isError;

  GpsLog(this.message, {this.isError = false}) : time = DateTime.now();

  String get timeStr => time.toLocal().toString().substring(11, 19);
}
