import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/utils/watermark.dart';
import 'car_loading.dart';

class FotoBuktiData {
  final String filePath;
  final Uint8List? bytes;
  final String tanggal;
  final String jam;
  final double latitude;
  final double longitude;
  final String alamatLengkap;
  final String petugas;

  FotoBuktiData({
    required this.filePath,
    this.bytes,
    required this.tanggal,
    required this.jam,
    required this.latitude,
    required this.longitude,
    required this.alamatLengkap,
    required this.petugas,
  });
}

class FotoBuktiWidget extends StatefulWidget {
  final String title;
  final String petugas;
  final Function(FotoBuktiData? data) onUpdate;
  final bool enabled;

  const FotoBuktiWidget({
    super.key,
    required this.title,
    required this.petugas,
    required this.onUpdate,
    this.enabled = true,
  });

  @override
  State<FotoBuktiWidget> createState() => _FotoBuktiWidgetState();
}

class _FotoBuktiWidgetState extends State<FotoBuktiWidget> {
  FotoBuktiData? _data;
  bool _isLoading = false;
  String? _errorMsg;

  final ImagePicker _picker = ImagePicker();

  Future<void> _ambilFoto() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;
      final XFile? foto = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 960,
      );
      if (foto == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      await _processPickedImage(foto);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pilihFile() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 960,
      );
      if (foto == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      await _processPickedImage(foto);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _processPickedImage(XFile foto) async {
    double lat = 0;
    double lng = 0;
    String alamat = '(lokasi tidak tersedia)';

    if (!kIsWeb) {
      try {
        final position = await _getLocation();
        lat = position.latitude;
        lng = position.longitude;
        alamat = await _getAlamat(lat, lng);
      } catch (_) {
        // GPS unavailable – continue with dummy
      }
    }

    final now = DateTime.now();
    final tanggal = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    final jam = DateFormat('HH:mm').format(now);

    Uint8List? bytes;
    if (kIsWeb) {
      bytes = await foto.readAsBytes();
    }

    final data = FotoBuktiData(
      filePath: foto.path,
      bytes: bytes,
      tanggal: tanggal,
      jam: jam,
      latitude: lat,
      longitude: lng,
      alamatLengkap: alamat,
      petugas: widget.petugas,
    );

    if (!kIsWeb) {
      await applyWatermark(foto.path, data);
    }

    if (!mounted) return;
    setState(() { _data = data; _isLoading = false; });
    widget.onUpdate(data);
  }

  void _hapusFoto() {
    setState(() { _data = null; _errorMsg = null; });
    widget.onUpdate(null);
  }

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

  String _formatKoordinat(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(5)}° $latDir, '
        '${lng.abs().toStringAsFixed(5)}° $lngDir';
  }

  Widget _buildImagePreview() {
    if (_data!.bytes != null) {
      return Image.memory(
        _data!.bytes!,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 440,
      );
    }
    return Image.file(
      File(_data!.filePath),
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: 440,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    final isDisabled = !widget.enabled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: AbsorbPointer(
        absorbing: isDisabled,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
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
                      'Mengambil foto...',
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildImagePreview(),
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
                              if (!isWeb) ...[
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
                              ],
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: BGNColors.primary
                                          .withValues(alpha: 0.85),
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

                const SizedBox(height: 8),
                _InfoCard(data: _data!),
              ],
            )

          // ── Empty state + tombol ──
          else ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pilihFile,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: BGNColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BGNColors.border),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(TablerIcons.file,
                                size: 28, color: BGNColors.textSecondary),
                            SizedBox(height: 6),
                            Text('File',
                                style: TextStyle(
                                    fontSize: 11, color: BGNColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isWeb) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _ambilFoto,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: BGNColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BGNColors.border),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(TablerIcons.camera,
                                  size: 28, color: BGNColors.textSecondary),
                              SizedBox(height: 6),
                              Text('Kamera',
                                  style: TextStyle(
                                      fontSize: 11, color: BGNColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isWeb ? _pilihFile : _ambilFoto,
                icon: Icon(isWeb ? TablerIcons.file : TablerIcons.camera, size: 16),
                label: Text(
                    isWeb ? 'Pilih file foto' : 'Ambil foto + lokasi GPS',
                    style: const TextStyle(fontSize: 12)),
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
                    onTap: isWeb ? _pilihFile : _ambilFoto,
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
      ),
    ),
  );
  }
}

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
