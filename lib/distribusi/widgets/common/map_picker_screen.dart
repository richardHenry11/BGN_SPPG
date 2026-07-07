// lib/widgets/common/map_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:bgn/distribusi/theme/colors.dart';

class MapPickerResult {
  final LatLng startLocation;
  final LatLng endLocation;
  final String startAddress;
  final String endAddress;

  MapPickerResult({
    required this.startLocation,
    required this.endLocation,
    required this.startAddress,
    required this.endAddress,
  });
}

class MapPickerScreen extends StatefulWidget {
  final LatLng initialStart;
  final LatLng initialEnd;
  final String initialStartAddress;
  final String initialEndAddress;

  const MapPickerScreen({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    this.initialStartAddress = '',
    this.initialEndAddress = '',
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _startLocation;
  late LatLng _endLocation;
  late String _startAddress;
  late String _endAddress;
  bool _isSelectingStart = true;
  bool _isLoadingGeo = false;
  bool _isSearching = false;

  final TextEditingController _searchCtl = TextEditingController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _startLocation = widget.initialStart;
    _endLocation = widget.initialEnd;
    _startAddress = widget.initialStartAddress;
    _endAddress = widget.initialEndAddress;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_startAddress.isEmpty) {
        _updateAddressFromCoords(_startLocation, isStart: true);
      }
      if (_endAddress.isEmpty) {
        _updateAddressFromCoords(_endLocation, isStart: false);
      }
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _updateAddressFromCoords(LatLng pos, {required bool isStart}) async {
    if (!mounted) return;
    setState(() => _isLoadingGeo = true);
    try {
      final places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;
      String addr;
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = [
          if (p.street != null && p.street!.isNotEmpty) p.street,
          if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality,
          if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) p.subAdministrativeArea,
        ];
        addr = parts.isNotEmpty ? parts.join(', ') : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      } else {
        addr = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      }
      if (mounted) {
        setState(() {
          if (isStart) {
            _startAddress = addr;
          } else {
            _endAddress = addr;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final addr = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          if (isStart) {
            _startAddress = addr;
          } else {
            _endAddress = addr;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingGeo = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng pos) {
    if (!mounted) return;
    setState(() {
      if (_isSelectingStart) {
        _startLocation = pos;
      } else {
        _endLocation = pos;
      }
    });
    _updateAddressFromCoords(pos, isStart: _isSelectingStart);
  }

  Future<void> _onSearch() async {
    final query = _searchCtl.text.trim();
    if (query.isEmpty) return;
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final locations = await locationFromAddress(query);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final pos = LatLng(loc.latitude, loc.longitude);
        setState(() {
          if (_isSelectingStart) {
            _startLocation = pos;
          } else {
            _endLocation = pos;
          }
        });
        _mapController.move(pos, 15);
        _updateAddressFromCoords(pos, isStart: _isSelectingStart);
      } else {
        _showSnackBar('Lokasi tidak ditemukan');
      }
    } catch (_) {
      if (mounted) _showSnackBar('Gagal mencari lokasi');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _handleKonfirmasi() {
    Navigator.pop(context, MapPickerResult(
      startLocation: _startLocation,
      endLocation: _endLocation,
      startAddress: _startAddress,
      endAddress: _endAddress,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        leading: IconButton(
          icon: const Icon(TablerIcons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Toggle + Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isSelectingStart = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isSelectingStart ? BGNColors.primary : BGNColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isSelectingStart ? BGNColors.primary : BGNColors.border,
                          ),
                        ),
                        child: Text('Titik Awal', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: _isSelectingStart ? BGNColors.white : BGNColors.textSecondary,
                        )),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _isSelectingStart = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isSelectingStart ? BGNColors.primary : BGNColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: !_isSelectingStart ? BGNColors.primary : BGNColors.border,
                          ),
                        ),
                        child: Text('Titik Tujuan', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: !_isSelectingStart ? BGNColors.white : BGNColors.textSecondary,
                        )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _isSelectingStart ? 'Cari titik awal...' : 'Cari titik tujuan...',
                    hintStyle: const TextStyle(fontSize: 12, color: BGNColors.textHint),
                    prefixIcon: const Icon(TablerIcons.search, size: 16),
                    suffixIcon: _isSearching
                        ? const SizedBox(width: 16, height: 16, child: Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                        : IconButton(
                            icon: const Icon(TablerIcons.arrow_right, size: 16),
                            onPressed: _onSearch,
                          ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BGNColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BGNColors.border)),
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ],
            ),
          ),

          // ── Map ──
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _endLocation,
                    initialZoom: 15,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.distribusi.bgn',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_startLocation, _endLocation],
                          color: BGNColors.primary.withOpacity(0.4),
                          strokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _startLocation,
                          width: 30,
                          height: 30,
                          child: const Icon(Icons.flag, color: Colors.green, size: 30),
                        ),
                        Marker(
                          point: _endLocation,
                          width: 30,
                          height: 30,
                          child: const Icon(Icons.location_on, color: BGNColors.danger, size: 30),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isLoadingGeo)
                  Positioned(
                    top: 8, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: BGNColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 6),
                            Text('Mencari alamat...', style: TextStyle(fontSize: 11, color: BGNColors.textHint)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom panel ──
          Container(
            decoration: BoxDecoration(
              color: BGNColors.surface,
              border: Border(top: BorderSide(color: BGNColors.border)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag, size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _startAddress.isNotEmpty ? _startAddress : '${_startLocation.latitude.toStringAsFixed(4)}, ${_startLocation.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12, color: BGNColors.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: BGNColors.danger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _endAddress.isNotEmpty ? _endAddress : '${_endLocation.latitude.toStringAsFixed(4)}, ${_endLocation.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12, color: BGNColors.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleKonfirmasi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BGNColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Konfirmasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
