// lib/screens/validasi/validasi_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/widgets/common/car_loading.dart';
import 'package:bgn/distribusi/widgets/common/car_refresh_indicator.dart';

class ValidasiScreen extends StatefulWidget {
  const ValidasiScreen({super.key});

  @override
  State<ValidasiScreen> createState() => _ValidasiScreenState();
}

class _ValidasiScreenState extends State<ValidasiScreen> {
  int? _activeJadwalId;
  bool _isScanning = false;
  bool _scanSelesai = false;

  final List<Map<String, dynamic>> _validasiList = [
    {
      'id': 1,
      'jadwalId': 1,
      'tujuan': 'SDN 01 Bandung',
      'porsiRencana': 120,
      'porsiTerdeteksi': 120,
      'status': 'sesuai',
      'timestamp': '07:28:14',
      'konfirmasi': true,
    },
    {
      'id': 2,
      'jadwalId': 2,
      'tujuan': 'Posyandu 01',
      'porsiRencana': 45,
      'porsiTerdeteksi': 0,
      'status': 'menunggu',
      'timestamp': null,
      'konfirmasi': false,
    },
  ];

  void _mulaiScan() async {
    setState(() {
      _isScanning = true;
      _scanSelesai = false;
    });
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _scanSelesai = true;
      final item = _validasiList.firstWhere(
        (v) => v['jadwalId'] == _activeJadwalId,
      );
      item['porsiTerdeteksi'] = item['porsiRencana'];
      item['status'] = 'sesuai';
      item['timestamp'] = TimeOfDay.now().format(context);
    });
  }

  void _resetScan() {
    setState(() {
      _isScanning = false;
      _scanSelesai = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CarRefreshIndicator(
      onRefresh: () async {
        setState(() {
          _isScanning = false;
          _scanSelesai = false;
          _activeJadwalId = null;
        });
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [

          // Pilih lokasi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BGNColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BGNColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih lokasi penerimaan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ..._validasiList.map((item) {
                  final isActive = _activeJadwalId == item['jadwalId'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeJadwalId = item['jadwalId'];
                        _scanSelesai = item['konfirmasi'] == true;
                        _isScanning = false;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? BGNColors.primaryLight
                            : BGNColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? BGNColors.primary
                              : BGNColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.building,
                            size: 16,
                            color: isActive
                                ? BGNColors.primary
                                : BGNColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['tujuan'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? BGNColors.primary
                                        : BGNColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${item['porsiRencana']} porsi rencana',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: BGNColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: item['konfirmasi'] == true
                                  ? BGNColors.primaryLight
                                  : BGNColors.background,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item['konfirmasi'] == true
                                  ? 'Selesai'
                                  : 'Menunggu',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: item['konfirmasi'] == true
                                    ? BGNColors.primary
                                    : BGNColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Kamera simulasi
          if (_activeJadwalId != null) ...[
            const SizedBox(height: 12),

            // Kamera area
            Container(
              decoration: BoxDecoration(
                color: BGNColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BGNColors.border),
              ),
              child: Column(
                children: [

                  // Kamera view
                  Container(
                    height: 200,
                    color: const Color(0xFF111111),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [

                        // Grid simulasi makanan
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(12, (i) {
                            return Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE68A),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              child: const Icon(
                                TablerIcons.package,
                                size: 14,
                                color: Color(0xFFD97706),
                              ),
                            );
                          }),
                        ),

                        // Frame sudut
                        Positioned(
                          child: CustomPaint(
                            size: const Size(160, 120),
                            painter: _CameraFramePainter(),
                          ),
                        ),

                        // Scan line animasi
                        if (_isScanning)
                          _ScanLine(),

                        // Overlay selesai
                        if (_scanSelesai)
                          Container(
                            color: BGNColors.primary.withOpacity(0.2),
                            child: const Center(
                              child: Icon(
                                TablerIcons.circle_check,
                                color: BGNColors.primary,
                                size: 48,
                              ),
                            ),
                          ),

                        // Label status
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isScanning
                                  ? BGNColors.primary
                                  : _scanSelesai
                                      ? BGNColors.success
                                      : Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isScanning) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: BGNColors.surface,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (_scanSelesai)
                                  const Icon(
                                    TablerIcons.circle_check,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  _isScanning
                                      ? 'AI menghitung porsi...'
                                      : _scanSelesai
                                          ? 'Scan selesai'
                                          : 'Kamera siap',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tombol scan
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isScanning || _scanSelesai
                                ? null
                                : _mulaiScan,
                            icon: _isScanning
                                ? const ButtonCarLoading()
                                : Icon(
                                    _scanSelesai
                                        ? TablerIcons.circle_check
                                        : TablerIcons.camera,
                                  ),
                            label: Text(
                              _isScanning
                                  ? 'Memproses...'
                                  : _scanSelesai
                                      ? 'Scan selesai'
                                      : 'Mulai scan AI',
                            ),
                          ),
                        ),
                        if (_scanSelesai) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _resetScan,
                              icon: const Icon(TablerIcons.refresh, size: 16),
                              label: const Text('Scan ulang'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: BGNColors.textSecondary,
                                side: const BorderSide(
                                    color: BGNColors.border),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Hasil validasi
            if (_scanSelesai) ...[
              const SizedBox(height: 12),
              _HasilValidasi(
                validasi: _validasiList.firstWhere(
                  (v) => v['jadwalId'] == _activeJadwalId,
                ),
              ),
            ],
          ],

        ],
      ),
    ),
    );
  }
}

// ── Widget helpers ─────────────────────────────────────────

class _HasilValidasi extends StatelessWidget {
  final Map<String, dynamic> validasi;

  const _HasilValidasi({required this.validasi});

  @override
  Widget build(BuildContext context) {
    final selisih = (validasi['porsiTerdeteksi'] as int) -
        (validasi['porsiRencana'] as int);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hasil validasi AI',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: BGNColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Angka
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BGNColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Porsi rencana',
                        style: TextStyle(
                          fontSize: 10,
                          color: BGNColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${validasi['porsiRencana']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: BGNColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BGNColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Terdeteksi AI',
                        style: TextStyle(
                          fontSize: 10,
                          color: BGNColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${validasi['porsiTerdeteksi']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: BGNColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selisih == 0
                  ? BGNColors.primaryLight
                  : BGNColors.dangerLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  selisih == 0
                      ? TablerIcons.circle_check
                      : TablerIcons.alert_triangle,
                  color: selisih == 0
                      ? BGNColors.primary
                      : BGNColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selisih == 0
                            ? 'Jumlah sesuai'
                            : selisih < 0
                                ? 'Porsi kurang'
                                : 'Porsi lebih',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selisih == 0
                              ? BGNColors.primary
                              : BGNColors.danger,
                        ),
                      ),
                      Text(
                        selisih == 0
                            ? 'Porsi terdeteksi sesuai dengan rencana'
                            : 'Selisih ${selisih.abs()} porsi dari rencana',
                        style: TextStyle(
                          fontSize: 11,
                          color: selisih == 0
                              ? BGNColors.primary
                              : BGNColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Timestamp
          if (validasi['timestamp'] != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  TablerIcons.clock,
                  size: 12,
                  color: BGNColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Divalidasi pada ${validasi['timestamp']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: BGNColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Tombol konfirmasi
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: validasi['konfirmasi'] == true ? null : () {},
              icon: const Icon(TablerIcons.check),
              label: Text(
                validasi['konfirmasi'] == true
                    ? 'Sudah dikonfirmasi'
                    : 'Konfirmasi & tanda tangan digital',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BGNColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const cornerSize = 16.0;

    // Top left
    canvas.drawLine(Offset.zero, const Offset(cornerSize, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, cornerSize), paint);

    // Top right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerSize, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerSize), paint);

    // Bottom left
    canvas.drawLine(Offset(0, size.height), Offset(cornerSize, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerSize), paint);

    // Bottom right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerSize, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLine extends StatefulWidget {
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          top: _animation.value * 180,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            color: BGNColors.primary.withOpacity(0.8),
          ),
        );
      },
    );
  }
}