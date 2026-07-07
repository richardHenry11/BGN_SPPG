import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bgn/distribusi/widgets/common/car_refresh_indicator.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/providers/tracking_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';
import 'package:bgn/distribusi/widgets/tracking/driver_chips.dart';
import 'package:bgn/distribusi/widgets/tracking/driver_status_card.dart';
import 'package:bgn/distribusi/widgets/tracking/checkpoint_list_widget.dart';
import 'package:bgn/distribusi/widgets/tracking/riwayat_card.dart';
import 'package:bgn/distribusi/widgets/tracking/riwayat_detail_sheet.dart';
import 'package:bgn/distribusi/widgets/common/truck_marker.dart';
import 'package:bgn/distribusi/widgets/common/nav_arrow_marker.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  String _activeTab = 'live';
  final PackagingService _packagingService = PackagingService(ApiClient());

  // ── Live tracking (original) ──
  int _activeDriverId = 1;

  // ── Live map state ──
  bool _loadingMap = false;
  String? _errorMap;
  LatLng? _currentPosition;
  List<_DeliveryPoint> _deliveryPoints = [];
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(-6.9150, 107.6100);

  // ── Route & selection ──
  int _selectedDestIndex = 0;
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  RouteNavigationData? _navData;
  bool _isNavigating = false;
  bool _autoRecenter = true;
  int _currentStepIndex = 0;
  int _navTickCount = 0;
  bool _arrivedDestination = false;
  Timer? _navGpsTimer;

  static const bool _showExtraCards = false;

  // ── WebSocket / GPS ──
  bool _wsConnected = false;
  int? _activePackagingId;
  Timer? _statusPollTimer;

  // ── Riwayat state ──
  List<dynamic> _riwayatList = [];
  bool _loadingRiwayat = false;
  String? _errorRiwayat;

  static const _tabs = [
    {'id': 'live',    'label': 'Live Tracking'},
    {'id': 'livemap', 'label': 'Live Tracking Map'},
    {'id': 'navigasi', 'label': 'Navigasi'},
    {'id': 'riwayat', 'label': 'Riwayat'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) return;
      _connectWebSocket(auth);
      _loadRiwayat();
      _loadLiveMap();
    });
  }

  void _connectWebSocket(AuthProvider auth) {
    if (_wsConnected) return;
    final userId = auth.userId;
    if (userId == null) return;
    final tracking = context.read<TrackingProvider>();
    tracking.connect(userId);
    _wsConnected = true;
    // Driver role: auto-start GPS sending (need packaging_id from trip)
    if (auth.isDriver || auth.isAslab || auth.isAsistenLapangan || auth.isSupplier) {
      tracking.addLog('Role: ${auth.currentRole} — polling status Dikirim...');
      _startGpsForDriver(tracking);
    } else {
      tracking.addLog('Role: ${auth.currentRole} — monitoring only');
    }
  }

  Future<void> _startGpsForDriver(TrackingProvider tracking) async {
    try {
      final data = await _packagingService.getList(headers: _authHeaders());
      final count = data.length;
      final active = data.cast<Map<String, dynamic>>().firstWhere(
        (d) => d['delivery_status'] == 'Dikirim',
        orElse: () => <String, dynamic>{},
      );
      if (active.isNotEmpty) {
        final packagingId = active['id'] as int?;
        final name = active['beneficiary_name'] as String? ?? '-';
        if (packagingId != null) {
          tracking.addLog('Poll OK: packaging #$packagingId ($name) status=Dikirim → GPS start');
          _activePackagingId = packagingId;
          _statusPollTimer?.cancel();
          _statusPollTimer = null;
          tracking.startSendingGps(packagingId);
          if (mounted) setState(() {});
        }
        return;
      }
      tracking.addLog('Poll: $count packaging, none with status Dikirim, retry in 5s');
    } catch (e) {
      tracking.addLog('Poll ERROR: $e', isError: true);
    }
    // Belum ada status "Dikirim" — poll tiap 5 detik
    if (!mounted) return;
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) { _statusPollTimer?.cancel(); return; }
      _startGpsForDriver(tracking);
    });
  }

  void _selectDestination(int index) {
    _arrivedDestination = false;
    setState(() => _selectedDestIndex = index);
    if (index < _deliveryPoints.length) {
      _mapController.move(_deliveryPoints[index].latLng, 15);
    }
    _loadRouteToSelected();
  }

  Future<void> _loadRouteToSelected() async {
    if (_deliveryPoints.isEmpty) return;
    final point = _deliveryPoints[_selectedDestIndex];
    final origin = point.startLatLng ?? _currentPosition;
    if (origin == null) return;

    setState(() => _loadingRoute = true);

    try {
      final navData = await _fetchRoute(origin, point.latLng);
      if (!mounted) return;
      setState(() {
        _routePoints = navData.polyline;
        _navData = navData;
        _loadingRoute = false;
      });
    } catch (_) {
      final path = _straightLinePath(origin, point.latLng, 30);
      if (!mounted) return;
      setState(() {
        _routePoints = path;
        _navData = null;
        _loadingRoute = false;
      });
    }
  }

  void _startNavigation() {
    if (_navData == null) return;
    setState(() {
      _isNavigating = true;
      _currentStepIndex = 0;
      _navTickCount = 0;
      _arrivedDestination = false;
    });
    _updateNavPosition();
    _navGpsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_isNavigating) { _navGpsTimer?.cancel(); return; }
      _updateNavPosition();
    });
  }

  void _stopNavigation() {
    _navGpsTimer?.cancel();
    _navGpsTimer = null;
    setState(() {
      _isNavigating = false;
      _currentStepIndex = 0;
    });
  }

  void _updateNavPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      if (!mounted || !_isNavigating) return;
      final userPos = LatLng(pos.latitude, pos.longitude);
      _currentPosition = userPos;
      _navTickCount++;
      if (_autoRecenter) _mapController.move(userPos, _mapController.camera.zoom);
      _updateCurrentStep(userPos);
    } catch (_) {}
  }

  void _updateCurrentStep(LatLng userPos) {
    if (_navData == null || _navData!.steps.isEmpty) return;
    const threshold = 50.0;
    for (int i = _currentStepIndex; i < _navData!.steps.length; i++) {
      final stepLoc = _navData!.steps[i].location;
      final dist = const Distance().as(LengthUnit.Meter, userPos, stepLoc);
      if (dist < threshold && i > _currentStepIndex) {
        if (_navTickCount < 2) continue;
        setState(() => _currentStepIndex = i);
        if (i == _navData!.steps.length - 1 && _navTickCount >= 3) {
          _arrivedDestination = true;
          _stopNavigation();
        }
        return;
      }
    }
    if (mounted) setState(() {});
  }

  Future<RouteNavigationData> _fetchRoute(LatLng from, LatLng to) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?geometries=geojson&overview=full&steps=true&annotations=false';

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) throw Exception('OSRM error ${response.statusCode}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List;
    if (routes.isEmpty) throw Exception('No route found');
    final route = routes[0] as Map<String, dynamic>;

    final totalDistance = (route['distance'] as num).toDouble();
    final totalDuration = (route['duration'] as num).toDouble();

    final geometry = route['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List;
    final polyline = coords.map((c) {
      final list = c as List;
      return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
    }).toList();

    final legs = route['legs'] as List;
    final steps = <NavStep>[];
    if (legs.isNotEmpty) {
      final leg = legs[0] as Map<String, dynamic>;
      final rawSteps = leg['steps'] as List;
      for (final s in rawSteps) {
        final step = s as Map<String, dynamic>;
        final stepDistance = (step['distance'] as num).toDouble();
        final stepDuration = (step['duration'] as num).toDouble();
        final name = step['name'] as String? ?? '';
        final maneuver = step['maneuver'] as Map<String, dynamic>;
        final type = maneuver['type'] as String? ?? '';
        final modifier = maneuver['modifier'] as String? ?? '';
        final loc = maneuver['location'] as List;
        final location = LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble());

        List<LatLng> stepGeom = [];
        if (step['geometry'] != null) {
          final stepGeo = step['geometry'] as Map<String, dynamic>;
          final stepCoords = stepGeo['coordinates'] as List;
          stepGeom = stepCoords.map((c) {
            final list = c as List;
            return LatLng((list[1] as num).toDouble(), (list[0] as num).toDouble());
          }).toList();
        }

        steps.add(NavStep(
          distance: stepDistance,
          duration: stepDuration,
          instruction: _formatInstruction(type, modifier, name),
          roadName: name,
          location: location,
          geometry: stepGeom,
        ));
      }
    }

    return RouteNavigationData(
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      polyline: polyline,
      steps: steps,
    );
  }

  String _formatInstruction(String type, String modifier, String roadName) {
    final dir = _maneuverText(modifier);
    final road = roadName.isNotEmpty ? ' $roadName' : '';
    switch (type) {
      case 'turn':
        return '$dir$road';
      case 'new name':
        return 'Lanjut$road';
      case 'depart':
        return 'Mulai dari$road';
      case 'arrive':
        return 'Sampai tujuan$road';
      case 'merge':
        return 'Gabung ke$road';
      case 'fork':
        return 'Di pertigaan, $dir$road';
      case 'end of road':
        return 'Di ujung jalan, $dir$road';
      case 'continue':
        return 'Lurus$road';
      case 'roundabout':
        final exit = _extractExit(modifier);
        return 'Putaran ke-$exit';
      case 'rotary':
        final exit = _extractExit(modifier);
        return 'Rotary ke-$exit';
      case 'use lane':
        return 'Ambil lajur$road';
      default:
        return '$dir$road';
    }
  }

  String _maneuverText(String modifier) {
    switch (modifier) {
      case 'left': return 'Belok kiri';
      case 'right': return 'Belok kanan';
      case 'slight left': return 'Belok kiri sedikit';
      case 'slight right': return 'Belok kanan sedikit';
      case 'sharp left': return 'Belok kiri tajam';
      case 'sharp right': return 'Belok kanan tajam';
      case 'straight': return 'Lurus';
      case 'uturn': return 'Putar balik';
      default: return modifier;
    }
  }

  String _extractExit(String modifier) {
    final parts = modifier.split(' ');
    return parts.length > 1 ? parts.last : '1';
  }

  String _stepDistanceText(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  List<LatLng> _straightLinePath(LatLng from, LatLng to, int steps) {
    final points = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      points.add(LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ));
    }
    return points;
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _navGpsTimer?.cancel();
    if (_wsConnected) {
      context.read<TrackingProvider>().reset();
      _wsConnected = false;
    }
    super.dispose();
  }

  Map<String, String> _authHeaders() {
    final auth = context.read<AuthProvider>();
    final h = <String, String>{
      'X-User-Role': auth.apiRole,
    };
    if (auth.token != null) h['Authorization'] = 'Bearer ${auth.token}';
    if (auth.sppgId != null) h['X-User-Sppg-Id'] = auth.sppgId.toString();
    return h;
  }

  Future<void> _loadLiveMap() async {
    if (!mounted) return;
    setState(() { _loadingMap = true; _errorMap = null; });

    Position? position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _errorMap = 'Layanan lokasi tidak aktif');
      } else {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          if (!mounted) return;
          setState(() => _errorMap = 'Izin lokasi tidak diberikan');
        } else {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          if (mounted) _currentPosition = LatLng(position.latitude, position.longitude);
        }
      }
    } catch (_) {}

    try {
      final data = await _packagingService.getList(headers: _authHeaders());
      if (!mounted) return;
      final points = <_DeliveryPoint>[];
      for (final item in data) {
        if (item['delivery_status'] != 'Dikirim') continue;
        LatLng? startCoord;
        final slat = item['start_latitude'];
        final slng = item['start_longitude'];
        if (slat != null && slng != null) {
          startCoord = LatLng((slat as num).toDouble(), (slng as num).toDouble());
        }
        LatLng? endCoord;
        final elat = item['end_latitude'];
        final elng = item['end_longitude'];
        if (elat != null && elng != null) {
          endCoord = LatLng((elat as num).toDouble(), (elng as num).toDouble());
        }
        endCoord ??= _parseCoords(item['delivery_route'] as String? ?? '');
        if (endCoord == null) continue;
        points.add(_DeliveryPoint(
          name: item['beneficiary_name'] as String? ?? item['delivery_route'] as String? ?? '-',
          menu: item['menu_name'] as String? ?? '',
          targetPorsi: (item['target_portions'] as num?)?.toInt() ?? 0,
          latLng: endCoord,
          startLatLng: startCoord,
        ));
      }
      setState(() => _deliveryPoints = points);
    } catch (e) {
      if (mounted) setState(() => _errorMap = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingMap = false);
    }

    if (_currentPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(_currentPosition!, 13);
      });
    } else if (_deliveryPoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(_deliveryPoints.first.latLng, 13);
      });
    }
  }

  LatLng? _parseCoords(String raw) {
    final re = RegExp(r'\(([\d\.\-]+),\s*([\d\.\-]+)\)');
    final match = re.firstMatch(raw);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  Future<void> _loadRiwayat() async {
    setState(() { _loadingRiwayat = true; _errorRiwayat = null; });
    try {
      final data = await _packagingService.getList();
      data.sort((a, b) {
        final ta = DateTime.tryParse(a['timestamp'] ?? '');
        final tb = DateTime.tryParse(b['timestamp'] ?? '');
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
      _riwayatList = data;
    } catch (e) {
      _errorRiwayat = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loadingRiwayat = false);
  }

  void _bukaDetail(int id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RiwayatDetailSheet(id: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driverList = context.select<DistribusiProvider, List<DriverModel>>((d) => d.driverList);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: _tabs.map((t) {
              final active = _activeTab == t['id'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _activeTab = t['id']!);
                      if (t['id'] == 'livemap' && _deliveryPoints.isEmpty) _loadLiveMap();
                      if (t['id'] == 'navigasi' && _deliveryPoints.isEmpty) _loadLiveMap();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? BGNColors.primary : BGNColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? BGNColors.primary : BGNColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(t['label']!, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: active ? Colors.white : BGNColors.textSecondary,
                        )),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: _activeTab == 'live'
              ? CarRefreshIndicator(
                  onRefresh: () => context.read<DistribusiProvider>().refresh(),
                  child: _buildLiveTab(driverList),
                )
              : _activeTab == 'livemap'
                  ? CarRefreshIndicator(
                      onRefresh: _loadLiveMap,
                      child: _buildLiveMapTab(),
                    )
                  : _activeTab == 'navigasi'
                      ? _buildNavigasiTab()
                      : CarRefreshIndicator(
                          onRefresh: _loadRiwayat,
                          child: _buildRiwayatTab(),
                        ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════
  // Live Tracking (original — driver based)
  // ═════════════════════════════════════════════════════════

  Widget _buildLiveTab(List<DriverModel> driverList) {
    final activeDriver = driverList
        .firstWhere((d) => d.id == _activeDriverId);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          DriverChips(
            drivers: driverList,
            activeId: _activeDriverId,
            onChanged: (id) => setState(() => _activeDriverId = id),
          ),
          const SizedBox(height: 12),
          DriverStatusCard(driver: activeDriver),
          const SizedBox(height: 12),
          CheckpointListWidget(checkpoints: activeDriver.checkpoint),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Navigasi (Fullscreen Google-like)
  // ═════════════════════════════════════════════════════════

  Widget _buildNavigasiTab() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition ?? _defaultCenter,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.distribusi.bgn',
            ),
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: BGNColors.primary,
                    strokeWidth: 6,
                  ),
                ],
              ),
            if (_navData != null && _isNavigating)
              MarkerLayer(
                markers: _navData!.steps.map((step) => Marker(
                  point: step.location,
                  width: 22,
                  height: 22,
                  child: _StepArrow(step.instruction),
                )).toList(),
              ),
            if (_routePoints.length > 10)
              MarkerLayer(
                markers: () {
                  final markers = <Marker>[];
                  final step = (_routePoints.length - 1) ~/ 4;
                  for (int i = 1; i < 4; i++) {
                    final idx = i * step;
                    if (idx < _routePoints.length) {
                      final pt = _routePoints[idx];
                      final nextIdx = (idx + 1 < _routePoints.length) ? idx + 1 : idx - 1;
                      final from = _routePoints[idx.clamp(0, _routePoints.length - 1)];
                      final to = _routePoints[nextIdx.clamp(0, _routePoints.length - 1)];
                      final dLon = (to.longitude - from.longitude) * math.pi / 180;
                      final lat1 = from.latitude * math.pi / 180;
                      final lat2 = to.latitude * math.pi / 180;
                      final y = math.sin(dLon) * math.cos(lat2);
                      final x = math.cos(lat1) * math.sin(lat2) -
                          math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
                      final bearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
                      markers.add(Marker(
                        point: pt,
                        width: 18,
                        height: 18,
                        child: Transform.rotate(
                          angle: bearing * math.pi / 180,
                          child: Icon(
                            TablerIcons.chevron_right,
                            color: BGNColors.primary.withOpacity(0.7),
                            size: 18,
                          ),
                        ),
                      ));
                    }
                  }
                  return markers;
                }(),
              ),
            if (_deliveryPoints.isNotEmpty)
              MarkerLayer(
                markers: _deliveryPoints.asMap().entries.where((e) => e.value.startLatLng != null).map((e) => Marker(
                  point: e.value.startLatLng!,
                  width: 36,
                  height: 36,
                  child: Image.asset(
                    'assets/images/kitchen_source.png',
                    fit: BoxFit.contain,
                  ),
                )).toList(),
              ),
            if (_deliveryPoints.isNotEmpty)
              MarkerLayer(
                markers: _deliveryPoints.asMap().entries.map((e) => Marker(
                  point: e.value.latLng,
                  width: 36,
                  height: 36,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/destination_pin.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                      ),
                      if (e.key == _selectedDestIndex && _routePoints.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: BGNColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('TUJUAN', style: TextStyle(fontSize: 7, color: Colors.white)),
                        ),
                    ],
                  ),
                )).toList(),
              ),
            // ── User's own position (arrow + radar ring) ──
            if (_currentPosition != null)
              Builder(builder: (_) {
                final heading = context.read<TrackingProvider>().heading ?? 0;
                return MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 60,
                      height: 60,
                      child: NavArrowMarker(heading: heading),
                    ),
                  ],
                );
              }),
            // ── WS driver positions ──
            Consumer<TrackingProvider>(
              builder: (_, tracking, __) {
                final positions = tracking.positionsList;
                if (positions.isEmpty) return const SizedBox.shrink();
                return MarkerLayer(
                  markers: positions.map((pos) => Marker(
                    point: pos.latLng,
                    width: 64,
                    height: 64,
                    child: const TruckMarker(),
                  )).toList(),
                );
              },
            ),
          ],
        ),

        // ── Zoom controls (right side, Google Maps style) ──
        Positioned(
          right: 8,
          top: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapButton(
                icon: TablerIcons.plus,
                onTap: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, (zoom + 1).clamp(3, 19));
                },
              ),
              const SizedBox(height: 4),
              _MapButton(
                icon: TablerIcons.minus,
                onTap: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, (zoom - 1).clamp(3, 19));
                },
              ),
              const SizedBox(height: 12),
              _MapButton(
                icon: _autoRecenter ? TablerIcons.current_location : TablerIcons.current_location_off,
                onTap: () {
                  setState(() => _autoRecenter = !_autoRecenter);
                  if (_autoRecenter && _currentPosition != null) {
                    _mapController.move(_currentPosition!, 15);
                  }
                },
              ),
            ],
          ),
        ),

        // ── Top overlay: destination picker + nav info ──
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_deliveryPoints.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: BGNColors.surface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BGNColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Tujuan',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BGNColors.textHint)),
                            const Spacer(),
                            Text('${_deliveryPoints.length} titik',
                                style: const TextStyle(fontSize: 9, color: BGNColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 60,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _deliveryPoints.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (_, i) {
                              final point = _deliveryPoints[i];
                              final active = i == _selectedDestIndex;
                              return GestureDetector(
                                onTap: () => _selectDestination(i),
                                child: Container(
                                  width: 100,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: active ? BGNColors.primaryLight : BGNColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(8),
                                    border: active ? Border.all(color: BGNColors.primary, width: 1) : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(point.name,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: active ? BGNColors.primary : BGNColors.textPrimary,
                                          ),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('${point.targetPorsi} porsi',
                                          style: const TextStyle(fontSize: 8, color: BGNColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                if (_navData != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BGNColors.surface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BGNColors.primary.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(TablerIcons.map_pin, size: 12, color: BGNColors.primary),
                                  const SizedBox(width: 4),
                                  Text(_navData!.distanceText,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: BGNColors.textPrimary)),
                                  const SizedBox(width: 12),
                                  const Icon(TablerIcons.clock, size: 12, color: BGNColors.primary),
                                  const SizedBox(width: 4),
                                  Text(_navData!.durationText,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: BGNColors.textPrimary)),
                                  const SizedBox(width: 12),
                                  const Icon(TablerIcons.flag, size: 12, color: BGNColors.primary),
                                  const SizedBox(width: 4),
                                  Text(_navData!.etaText,
                                      style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_isNavigating) {
                                _stopNavigation();
                              } else {
                                _startNavigation();
                              }
                            },
                            icon: Icon(
                              _isNavigating ? TablerIcons.square : TablerIcons.navigation,
                              size: 14,
                            ),
                            label: Text(
                              _isNavigating ? 'Stop' : 'Mulai',
                              style: const TextStyle(fontSize: 10),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Bottom overlay: placeholder sebelum navigasi aktif ──
        if (!_isNavigating && _navData != null && _navData!.steps.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BGNColors.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BGNColors.border),
              ),
              child: Row(
                children: [
                  const Icon(TablerIcons.navigation, size: 18, color: BGNColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rute siap. Tekan Mulai untuk memulai navigasi',
                      style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Next Turn Card (floating, di atas panel) ──
        if (_isNavigating && _navData != null && _navData!.steps.isNotEmpty)
          Positioned(
            bottom: 216,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BGNColors.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BGNColors.primary.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  _DirectionIcon(_navData!.steps[_currentStepIndex].instruction),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _navData!.steps[_currentStepIndex].instruction,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_navData!.steps[_currentStepIndex].roadName.isNotEmpty)
                          Text(
                            _navData!.steps[_currentStepIndex].roadName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: BGNColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_currentStepIndex < _navData!.steps.length - 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: BGNColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _stepDistanceText(_navData!.steps[_currentStepIndex].distance),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: BGNColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // ── Bottom overlay: turn-by-turn panel (hanya saat navigasi aktif) ──
        if (_isNavigating && _navData != null && _navData!.steps.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
              color: BGNColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: BGNColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      const Icon(TablerIcons.arrows_sort, size: 16, color: BGNColors.textSecondary),
                      const SizedBox(width: 6),
                      const Text('Petunjuk Arah',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BGNColors.textSecondary)),
                        const Spacer(),
                        Text('${_navData!.steps.length} langkah',
                            style: const TextStyle(fontSize: 9, color: BGNColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: BGNColors.border),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _navData!.steps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final step = _navData!.steps[i];
                        final isLast = i == _navData!.steps.length - 1;
                        final isCurrent = _isNavigating && i == _currentStepIndex;
                        final isDone = _isNavigating && i < _currentStepIndex;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent ? BGNColors.primaryLight : isDone ? BGNColors.surfaceAlt : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              _DirectionIcon(step.instruction),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  step.instruction,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDone ? BGNColors.textHint : isCurrent ? BGNColors.textPrimaryDark : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: BGNColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('SEDANG',
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                                )
                              else
                                Text(
                                  isLast ? '' : _stepDistanceText(step.distance),
                                  style: TextStyle(fontSize: 10, color: isDone ? BGNColors.textHint : BGNColors.textSecondary),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        // ── Arrived Banner (hijau, saat sampai tujuan) ──
        if (_arrivedDestination)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BGNColors.success.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BGNColors.success, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(TablerIcons.flag, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Anda telah tiba di tujuan',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _arrivedDestination = false),
                    child: const Icon(TablerIcons.x, size: 18, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }

  // ═════════════════════════════════════════════════════════
  // Live Tracking Map
  // ═════════════════════════════════════════════════════════



  Widget _buildLiveMapTab() {
    if (_loadingMap) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMap != null && _currentPosition == null && _deliveryPoints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(TablerIcons.alert_circle, size: 40, color: BGNColors.danger),
              const SizedBox(height: 12),
              Text(_errorMap!, style: const TextStyle(fontSize: 12, color: BGNColors.danger), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadLiveMap,
                icon: const Icon(TablerIcons.refresh, size: 16),
                label: const Text('Coba lagi', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── GPS status bar ──
          Consumer<TrackingProvider>(
            builder: (_, tracking, __) {
              if (!tracking.connected && !tracking.sendingGps) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: tracking.sendingGps ? BGNColors.primaryLight : BGNColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: tracking.sendingGps
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(TablerIcons.gps, size: 16, color: BGNColors.primary),
                              const SizedBox(width: 8),
                              const Text('Mengirim lokasi',
                                  style: TextStyle(fontSize: 11, color: BGNColors.primary, fontWeight: FontWeight.w500)),
                              const Spacer(),
                              SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: BGNColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Packaging #${_activePackagingId ?? "-"} • ${tracking.sentCount}x dikirim',
                              style: const TextStyle(fontSize: 9, color: BGNColors.primary)),
                          if (tracking.lastSentLat != null)
                            Text('${tracking.lastSentLat!.toStringAsFixed(6)}, ${tracking.lastSentLng!.toStringAsFixed(6)}  •  ${tracking.lastSentTimeStr ?? ""}',
                                style: const TextStyle(fontSize: 9, color: BGNColors.primary)),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(TablerIcons.antenna, size: 16, color: BGNColors.success),
                          const SizedBox(width: 8),
                          Text('Terhubung — ${tracking.positionsList.length} asisten lapangan aktif',
                              style: const TextStyle(fontSize: 11, color: BGNColors.success, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BGNColors.success,
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),

          // ── Detail koordinat real-time ──
          Consumer<TrackingProvider>(
            builder: (_, tracking, __) {
              final list = tracking.positionsList;
              if (list.isEmpty && !tracking.sendingGps) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: BGNColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BGNColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(TablerIcons.gps, size: 14, color: BGNColors.primary),
                        const SizedBox(width: 6),
                        const Text('Koordinat Real-time',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: BGNColors.textHint)),
                        const Spacer(),
                        Text('${list.length} aktif',
                            style: const TextStyle(fontSize: 9, color: BGNColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                      if (tracking.sendingGps && tracking.lastSentLat != null)
                      _CoordRow(
                        label: 'Saya',
                        lat: tracking.lastSentLat!,
                        lng: tracking.lastSentLng!,
                        time: tracking.lastSentTimeStr ?? '',
                        delta: tracking.lastDelta,
                        isMe: true,
                      ),
                    if (tracking.sendingGps && list.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Divider(height: 1, color: BGNColors.border),
                      ),
                    ...list.map((pos) => _CoordRow(
                      label: 'Pack #${pos.packagingId}',
                      lat: pos.latitude,
                      lng: pos.longitude,
                      time: pos.routeHistory.isNotEmpty
                          ? pos.routeHistory.last.time
                          : '',
                      isMe: false,
                    )),
                  ],
                ),
              );
            },
          ),

          // ── Route loading ──
          if (_loadingRoute)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: BGNColors.warningLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Mencari rute jalan...', style: TextStyle(fontSize: 11, color: BGNColors.warning, fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          // ── Delivery points list (di atas map) ──
          if (_deliveryPoints.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tujuan pengiriman',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BGNColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_deliveryPoints.length} titik',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: BGNColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._deliveryPoints.asMap().entries.map((e) => _DeliveryPointCard(
              point: e.value,
              isActive: e.key == _selectedDestIndex,
              onTap: () => _selectDestination(e.key),
            )),
            const SizedBox(height: 12),
          ],

          // ── Navigation info card ──
          if (_navData != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: BGNColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BGNColors.primary.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(TablerIcons.map_pin, size: 14, color: BGNColors.primary),
                      const SizedBox(width: 6),
                      Text(_navData!.distanceText,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BGNColors.textPrimary)),
                      const SizedBox(width: 16),
                      const Icon(TablerIcons.clock, size: 14, color: BGNColors.primary),
                      const SizedBox(width: 6),
                      Text(_navData!.durationText,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BGNColors.textPrimary)),
                      const SizedBox(width: 16),
                      const Icon(TablerIcons.flag, size: 14, color: BGNColors.primary),
                      const SizedBox(width: 6),
                      Text(_navData!.etaText,
                          style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                    SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_isNavigating) {
                          _stopNavigation();
                        } else {
                          _startNavigation();
                        }
                      },
                      icon: Icon(
                        _isNavigating ? TablerIcons.square : TablerIcons.navigation,
                        size: 16,
                      ),
                      label: Text(
                        _isNavigating ? 'Akhiri Navigasi' : 'Mulai Navigasi',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Map ──
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BGNColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition ?? _defaultCenter,
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.distribusi.bgn',
                  ),
                  // Route polyline
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: BGNColors.primary,
                          strokeWidth: 6,
                        ),
                      ],
                    ),
                  // Navigation step markers (arrow direction)
                  if (_navData != null && _isNavigating)
                    MarkerLayer(
                      markers: _navData!.steps.map((step) {
                        return Marker(
                          point: step.location,
                          width: 22,
                          height: 22,
                          child: _StepArrow(step.instruction),
                        );
                      }).toList(),
                    ),
                  // Direction chevrons along route polyline
                  if (_routePoints.length > 10)
                    MarkerLayer(
                      markers: () {
                        final markers = <Marker>[];
                        final step = (_routePoints.length - 1) ~/ 4;
                        for (int i = 1; i < 4; i++) {
                          final idx = i * step;
                          if (idx < _routePoints.length) {
                            final pt = _routePoints[idx];
                            final nextIdx = (idx + 1 < _routePoints.length) ? idx + 1 : idx - 1;
                            final from = _routePoints[idx.clamp(0, _routePoints.length - 1)];
                            final to = _routePoints[nextIdx.clamp(0, _routePoints.length - 1)];
                            final dLon = (to.longitude - from.longitude) * math.pi / 180;
                            final lat1 = from.latitude * math.pi / 180;
                            final lat2 = to.latitude * math.pi / 180;
                            final y = math.sin(dLon) * math.cos(lat2);
                            final x = math.cos(lat1) * math.sin(lat2) -
                                math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
                            final bearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
                            markers.add(Marker(
                              point: pt,
                              width: 18,
                              height: 18,
                              child: Transform.rotate(
                                angle: bearing * math.pi / 180,
                                child: Icon(
                                  TablerIcons.chevron_right,
                                  color: BGNColors.primary.withOpacity(0.7),
                                  size: 18,
                                ),
                              ),
                            ));
                          }
                        }
                        return markers;
                      }(),
                    ),
                  // Start point markers (SPPG kitchen image)
                  if (_deliveryPoints.isNotEmpty)
                    MarkerLayer(
                      markers: _deliveryPoints.asMap().entries.where((e) => e.value.startLatLng != null).map((e) => Marker(
                        point: e.value.startLatLng!,
                        width: 36,
                        height: 36,
                        child: Image.asset(
                          'assets/images/kitchen_source.png',
                          fit: BoxFit.contain,
                        ),
                      )).toList(),
                    ),
                  // End point / destination markers
                  if (_deliveryPoints.isNotEmpty)
                    MarkerLayer(
                      markers: _deliveryPoints.asMap().entries.map((e) => Marker(
                        point: e.value.latLng,
                        width: 36,
                        height: 36,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/destination_pin.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                            ),
                            if (e.key == _selectedDestIndex && _routePoints.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BGNColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('TUJUAN', style: TextStyle(fontSize: 7, color: Colors.white)),
                              ),
                          ],
                        ),
                      )).toList(),
                    ),
                  // Driver positions (user + WS drivers)
                  Consumer<TrackingProvider>(
                    builder: (_, tracking, __) {
                      final positions = tracking.positionsList;
                      if (positions.isEmpty) return const SizedBox.shrink();
                      return MarkerLayer(
                        markers: positions.map((pos) {
                          return Marker(
                            point: pos.latLng,
                            width: 64,
                            height: 64,
                            child: const TruckMarker(),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Placeholder sebelum navigasi aktif ──
          if (!_isNavigating && _navData != null && _navData!.steps.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: BGNColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BGNColors.border),
              ),
              child: Row(
                children: [
                  const Icon(TablerIcons.navigation, size: 18, color: BGNColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rute siap. Tekan Mulai untuk memulai navigasi',
                      style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // ── Turn-by-turn panel (hanya saat navigasi aktif) ──
          if (_isNavigating && _navData != null && _navData!.steps.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: BGNColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BGNColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        const Icon(TablerIcons.arrows_sort, size: 16, color: BGNColors.textSecondary),
                        const SizedBox(width: 6),
                        const Text('Petunjuk Arah',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BGNColors.textSecondary)),
                        const Spacer(),
                        Text('${_navData!.steps.length} langkah',
                            style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: BGNColors.border),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _navData!.steps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final step = _navData!.steps[i];
                        final isLast = i == _navData!.steps.length - 1;
                        final isCurrent = _isNavigating && i == _currentStepIndex;
                        final isDone = _isNavigating && i < _currentStepIndex;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? BGNColors.primaryLight
                                : isDone
                                    ? BGNColors.surfaceAlt
                                    : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              _DirectionIcon(step.instruction),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  step.instruction,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDone
                                        ? BGNColors.textSecondary
                                        : isCurrent
                                            ? BGNColors.textPrimaryDark
                                            : Colors.white,
                                    fontWeight: isCurrent
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: BGNColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SEDANG',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  isLast ? '' : _stepDistanceText(step.distance),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDone
                                        ? BGNColors.textHint
                                        : BGNColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // ── Driver positions list ──
          if (_showExtraCards) Consumer<TrackingProvider>(
            builder: (_, tracking, __) {
              final positions = tracking.positionsList;
              if (positions.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Posisi asisten lapangan',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: BGNColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${positions.length} aktif',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: BGNColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...positions.map((pos) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BGNColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BGNColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: BGNColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(TablerIcons.truck, size: 18, color: BGNColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Packaging #${pos.packagingId}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
                              Text('${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 10, color: BGNColors.textHint)),
                            ],
                          ),
                        ),
                        if (pos.routeHistory.isNotEmpty)
                          Text('${pos.routeHistory.length} titik',
                              style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                      ],
                    ),
                  )),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),

          // ── Debug log ──
          if (_showExtraCards) Consumer<TrackingProvider>(
            builder: (_, tracking, __) {
              final logs = tracking.logs;
              if (logs.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: BGNColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BGNColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          const Icon(TablerIcons.bug, size: 14, color: BGNColors.textHint),
                          const SizedBox(width: 6),
                          const Text('Debug GPS Log',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: BGNColors.textHint)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => tracking.reset(),
                            child: const Icon(TablerIcons.x, size: 14, color: BGNColors.textHint),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: BGNColors.border),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (_, i) {
                          final log = logs[i];
                          return Text(
                            '[${log.timeStr}] ${log.message}',
                            style: TextStyle(
                              fontSize: 8,
                              fontFamily: 'monospace',
                              color: log.isError ? BGNColors.danger : BGNColors.textHint,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (_deliveryPoints.isEmpty && !_loadingMap && _errorMap == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Icon(TablerIcons.truck_off, size: 32, color: BGNColors.textHint),
                  const SizedBox(height: 8),
                  const Text('Belum ada pengiriman dalam perjalanan',
                      style: TextStyle(fontSize: 12, color: BGNColors.textSecondary)),
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRiwayatTab() {
    if (_loadingRiwayat) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: List.generate(3, (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 180,
          decoration: BoxDecoration(
            color: BGNColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
        )),
      );
    }

    if (_errorRiwayat != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(TablerIcons.alert_circle, size: 40, color: BGNColors.danger),
              const SizedBox(height: 12),
              const Text('Gagal memuat data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.danger)),
              const SizedBox(height: 4),
              Text(_errorRiwayat!, style: const TextStyle(fontSize: 11, color: BGNColors.textHint), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadRiwayat,
                icon: const Icon(TablerIcons.refresh, size: 16),
                label: const Text('Coba lagi', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    if (_riwayatList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.inbox, size: 48, color: BGNColors.border),
            SizedBox(height: 12),
            Text('Belum ada data riwayat', style: TextStyle(fontSize: 13, color: BGNColors.textSecondary)),
          ],
        ),
      );
    }

    final totalPorsi = _riwayatList.fold<int>(0, (s, i) => s + ((i['actual_portions'] as num?)?.toInt() ?? 0));
    final avgEfektif = _riwayatList.isEmpty ? 0.0
        : _riwayatList.fold<double>(0, (s, i) => s + ((i['effectiveness'] as num?)?.toDouble() ?? 0)) / _riwayatList.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          children: [
            _SummaryBox(label: 'Total riwayat', value: '${_riwayatList.length}', color: BGNColors.primary, bg: BGNColors.primaryLight),
            const SizedBox(width: 8),
            _SummaryBox(label: 'Rata-rata efektivitas', value: '${avgEfektif.toStringAsFixed(0)}%', color: Colors.green, bg: Colors.green.withOpacity(0.1)),
            const SizedBox(width: 8),
            _SummaryBox(label: 'Total porsi', value: totalPorsi.toString(), color: Colors.amber, bg: Colors.amber.withOpacity(0.1)),
          ],
        ),
        const SizedBox(height: 16),

        ..._riwayatList.map((item) => RiwayatCard(
          item: item as Map<String, dynamic>,
          onTapDetail: () => _bukaDetail(item['id'] as int),
        )),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _SummaryBox({
    required this.label, required this.value,
    required this.color, required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: color,
            )),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Live Map models & widgets
// ═══════════════════════════════════════════════════════════

class _DeliveryPoint {
  final String name;
  final String menu;
  final int targetPorsi;
  final LatLng latLng;
  final LatLng? startLatLng;

  const _DeliveryPoint({
    required this.name,
    required this.menu,
    required this.targetPorsi,
    required this.latLng,
    this.startLatLng,
  });
}

class _DeliveryPointCard extends StatelessWidget {
  final _DeliveryPoint point;
  final bool isActive;
  final VoidCallback? onTap;

  const _DeliveryPointCard({
    required this.point,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BGNColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? BGNColors.primary : BGNColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isActive ? BGNColors.primaryLight : BGNColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/destination_pin.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (point.menu.isNotEmpty)
                    Text(point.menu,
                        style: const TextStyle(fontSize: 10, color: BGNColors.textHint),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${point.targetPorsi} porsi',
                      style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BGNColors.primaryLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AKTIF', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: BGNColors.primary)),
              )
            else
              Text(
                '${point.latLng.latitude.toStringAsFixed(4)}, ${point.latLng.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 9, color: BGNColors.textHint),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _StepArrow — small arrow marker on map at maneuver point
// ═══════════════════════════════════════════════════════════

class _StepArrow extends StatelessWidget {
  final String instruction;
  const _StepArrow(this.instruction);

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color bgColor;
    if (instruction.contains('kanan')) {
      icon = TablerIcons.arrow_curve_right;
      bgColor = BGNColors.primaryLight;
    } else if (instruction.contains('kiri')) {
      icon = TablerIcons.arrow_curve_left;
      bgColor = BGNColors.primaryLight;
    } else if (instruction.contains('Sampai')) {
      icon = TablerIcons.flag;
      bgColor = BGNColors.successLight;
    } else if (instruction.contains('Putar balik')) {
      icon = TablerIcons.arrow_back_up;
      bgColor = BGNColors.warningLight;
    } else {
      icon = TablerIcons.arrow_forward_up;
      bgColor = BGNColors.surfaceAlt;
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: BGNColors.primary.withOpacity(0.5), width: 1.5),
      ),
      child: Center(
        child: Icon(icon, size: 12, color: BGNColors.primary),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _DirectionIcon — arrow direction for turn-by-turn list
// ═══════════════════════════════════════════════════════════

class _DirectionIcon extends StatelessWidget {
  final String instruction;
  const _DirectionIcon(this.instruction);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: BGNColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(
          _iconForInstruction(instruction),
          size: 14,
          color: BGNColors.primary,
        ),
      ),
    );
  }

  IconData _iconForInstruction(String instruction) {
    if (instruction.contains('kanan')) return TablerIcons.arrow_curve_right;
    if (instruction.contains('kiri')) return TablerIcons.arrow_curve_left;
    if (instruction.contains('Putar balik')) return TablerIcons.arrow_back_up;
    if (instruction.contains('Sampai')) return TablerIcons.flag;
    if (instruction.contains('Mulai')) return TablerIcons.map_pin;
    if (instruction.contains('Lurus') || instruction.contains('Lanjut')) {
      return TablerIcons.arrow_forward_up;
    }
    return TablerIcons.arrow_forward_up;
  }
}

// ═══════════════════════════════════════════════════════════
// Navigation model — hasil parse OSRM dengan steps=true
// ═══════════════════════════════════════════════════════════

class NavStep {
  final double distance;
  final double duration;
  final String instruction;
  final String roadName;
  final LatLng location;
  final List<LatLng> geometry;

  NavStep({
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.roadName,
    required this.location,
    required this.geometry,
  });
}

class RouteNavigationData {
  final double totalDistance;
  final double totalDuration;
  final List<LatLng> polyline;
  final List<NavStep> steps;

  RouteNavigationData({
    required this.totalDistance,
    required this.totalDuration,
    required this.polyline,
    required this.steps,
  });

  String get distanceText {
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(1)} km';
    }
    return '${totalDistance.toStringAsFixed(0)} m';
  }

  String get durationText {
    if (totalDuration >= 60) {
      final min = (totalDuration / 60).floor();
      final sec = (totalDuration % 60).floor();
      return '$min menit${sec > 0 ? ' $sec detik' : ''}';
    }
    return '${totalDuration.toStringAsFixed(0)} detik';
  }

  String get etaText {
    final now = DateTime.now();
    final eta = now.add(Duration(seconds: totalDuration.round()));
    final h = eta.hour.toString().padLeft(2, '0');
    final m = eta.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ═══════════════════════════════════════════════════════════
// CoordRow — menampilkan lat/lng real-time + delta meter
// ═══════════════════════════════════════════════════════════

class _CoordRow extends StatelessWidget {
  final String label;
  final double lat;
  final double lng;
  final String time;
  final double? delta;
  final bool isMe;

  const _CoordRow({
    required this.label,
    required this.lat,
    required this.lng,
    required this.time,
    this.delta,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: isMe ? BGNColors.primary : BGNColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isMe ? BGNColors.primary : BGNColors.textPrimary,
              )),
          const Spacer(),
          Text(
            '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: isMe ? BGNColors.primary : BGNColors.textSecondary,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(width: 6),
            Text(
              delta! < 1 ? '<1m' : '${delta!.toStringAsFixed(1)}m',
              style: TextStyle(
                fontSize: 8,
                color: delta! < 5 ? BGNColors.textHint : BGNColors.warning,
                fontWeight: delta! >= 5 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
          if (time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(time.length >= 19 ? time.substring(11, 19) : time,
                style: const TextStyle(fontSize: 8, color: BGNColors.textHint)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _MapButton — small floating button for zoom/re-center
// ═══════════════════════════════════════════════════════════

class _MapButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BGNColors.surface.withOpacity(0.95),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: BGNColors.textPrimary),
        ),
      ),
    );
  }
}
