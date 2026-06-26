// lib/widgets/common/foto_bukti_widget.dart
//
// Dependency yang dibutuhkan (tambahkan di pubspec.yaml):
//   image_picker: ^1.1.2
//   geolocator: ^13.0.2
//   geocoding: ^3.0.0
//   intl: ^0.19.0

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'car_loading.dart';

// ── Model data foto ───────────────────────────────────────
class FotoBuktiData {
  final String filePath;
  final String tanggal;
  final String jam;
  final double latitude;
  final double longitude;
  final String alamatLengkap;
  final String petugas;

  FotoBuktiData({
    required this.filePath,
    required this.tanggal,
    required this.jam,
    required this.latitude,
    required this.longitude,
    required this.alamatLengkap,
    required this.petugas,
  });
}

// ── Widget utama ──────────────────────────────────────────
class FotoBuktiWidget extends StatefulWidget {
  final String title;
  final String petugas; // dari auth provider, pass dari parent
  final Function(FotoBuktiData? data) onUpdate;

  const FotoBuktiWidget({
    super.key,
    required this.title,
    required this.petugas,
    required this.onUpdate,
  });

  @override
  State<FotoBuktiWidget> createState() => _FotoBuktiWidgetState();
}

class _FotoBuktiWidgetState extends State<FotoBuktiWidget> {
  FotoBuktiData? _data;
  bool _isLoading = false;
  String? _errorMsg;

  final ImagePicker _picker = ImagePicker();

  // ── Ambil foto dari kamera ──
  Future<void> _ambilFoto() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // 1. Ambil foto dari kamera
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 960,
      );

      if (foto == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Ambil lokasi GPS
      final position = await _getLocation();

      // 3. Reverse geocoding → alamat lengkap
      final alamat = await _getAlamat(position.latitude, position.longitude);

      // 4. Format waktu
      final now = DateTime.now();
      final tanggal = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
      final jam = DateFormat('HH:mm').format(now);

      final data = FotoBuktiData(
        filePath: foto.path,
        tanggal: tanggal,
        jam: jam,
        latitude: position.latitude,
        longitude: position.longitude,
        alamatLengkap: alamat,
        petugas: widget.petugas,
      );

      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });

      widget.onUpdate(data);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isLoading = false;
        _errorMsg = msg.contains('ACCESS_FINE_LOCATION')
            ? 'Izin lokasi belum diatur. Tutup aplikasi dan jalankan ulang.'
            : msg;
      });
    }
  }

  // ── Hapus foto ──
  void _hapusFoto() {
    setState(() {
      _data = null;
      _errorMsg = null;
    });
    widget.onUpdate(null);
  }

  // ── Dapatkan posisi GPS ──
  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS tidak aktif. Aktifkan lokasi di pengaturan.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Izin lokasi diblokir permanen. Buka pengaturan aplikasi.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ),
    );
  }

  // ── Reverse geocoding ──
  Future<String> _getAlamat(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return 'Alamat tidak ditemukan';

      final p = placemarks.first;
      final parts = [
        if (p.street != null && p.street!.isNotEmpty) p.street,
        if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
        if (p.locality != null && p.locality!.isNotEmpty) p.locality,
        if (p.subAdministrativeArea != null &&
            p.subAdministrativeArea!.isNotEmpty)
          p.subAdministrativeArea,
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
          p.administrativeArea,
      ];
      return parts.take(3).join(', ');
    } catch (_) {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
  }

  // ── Format koordinat ──
  String _formatKoordinat(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(5)}° $latDir, '
        '${lng.abs().toStringAsFixed(5)}° $lngDir';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: BGNColors.textPrimary,
                ),
              ),
              if (_data != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BGNColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(TablerIcons.circle_check,
                          size: 12, color: BGNColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Foto tersimpan',
                        style:
                            TextStyle(fontSize: 10, color: BGNColors.primary),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Loading state ──
          if (_isLoading)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: BGNColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CarLoading(size: 24),
                    SizedBox(height: 10),
                    Text(
                      'Mengambil foto & lokasi...',
                      style: TextStyle(
                        fontSize: 12,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )

          // ── Preview foto + overlay ──
          else if (_data != null)
            Column(
              children: [
                Stack(
                  children: [
                    // Foto
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_data!.filePath),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 440,
                      ),
                    ),

                    // Tombol hapus
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _hapusFoto,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(TablerIcons.x,
                              color: Colors.white, size: 15),
                        ),
                      ),
                    ),

                    // Overlay info (watermark style)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.75),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Baris 1: tanggal + jam
                              Row(
                                children: [
                                  const Icon(TablerIcons.calendar,
                                      size: 10, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    _data!.tanggal,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(TablerIcons.clock,
                                      size: 10, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    _data!.jam,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),

                              // Baris 2: koordinat GPS
                              Row(
                                children: [
                                  const Icon(TablerIcons.gps,
                                      size: 10, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatKoordinat(
                                        _data!.latitude, _data!.longitude),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white70,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),

                              // Baris 3: alamat lengkap
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(TablerIcons.map_pin,
                                      size: 10, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _data!.alamatLengkap,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),

                              // Baris 4: petugas
                              Row(
                                children: [
                                  const Icon(TablerIcons.user,
                                      size: 10, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.petugas,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Badge BGN
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: BGNColors.primary
                                          .withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BGN',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Detail info di bawah foto (card)
                const SizedBox(height: 8),
                _InfoCard(data: _data!),
              ],
            )

          // ── Empty state + tombol ──
          else ...[
            GestureDetector(
              onTap: _ambilFoto,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: BGNColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: BGNColors.border, style: BorderStyle.solid),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(TablerIcons.camera,
                          size: 32, color: BGNColors.textSecondary),
                      SizedBox(height: 8),
                      Text(
                        'Tap untuk buka kamera',
                        style: TextStyle(
                            fontSize: 12, color: BGNColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _ambilFoto,
                icon: const Icon(TablerIcons.camera, size: 16),
                label: const Text('Ambil foto + lokasi GPS',
                    style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BGNColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],

          // ── Error ──
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BGNColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(TablerIcons.alert_circle,
                      size: 14, color: BGNColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                          fontSize: 11, color: BGNColors.danger),
                    ),
                  ),
                  GestureDetector(
                    onTap: _ambilFoto,
                    child: const Text(
                      'Coba lagi',
                      style: TextStyle(
                        fontSize: 11,
                        color: BGNColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Info card di bawah foto ───────────────────────────────
class _InfoCard extends StatelessWidget {
  final FotoBuktiData data;
  const _InfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BGNColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        children: [
          _Row(
            icon: TablerIcons.calendar,
            label: 'Tanggal',
            value: data.tanggal,
          ),
          const SizedBox(height: 5),
          _Row(
            icon: TablerIcons.clock,
            label: 'Waktu',
            value: data.jam,
          ),
          const SizedBox(height: 5),
          _Row(
            icon: TablerIcons.gps,
            label: 'Koordinat',
            value:
                '${data.latitude.toStringAsFixed(6)}, ${data.longitude.toStringAsFixed(6)}',
            mono: true,
          ),
          const SizedBox(height: 5),
          _Row(
            icon: TablerIcons.map_pin,
            label: 'Alamat',
            value: data.alamatLengkap,
            multiline: true,
          ),
          const SizedBox(height: 5),
          _Row(
            icon: TablerIcons.user,
            label: 'Petugas',
            value: data.petugas,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  final bool multiline;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: BGNColors.textSecondary),
        const SizedBox(width: 6),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: BGNColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: BGNColors.textPrimary,
              fontFamily: mono ? 'monospace' : null,
            ),
            maxLines: multiline ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}