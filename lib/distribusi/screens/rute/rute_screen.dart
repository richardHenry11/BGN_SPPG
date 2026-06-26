// lib/screens/rute/rute_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/widgets/common/car_loading.dart';
import 'package:bgn/distribusi/widgets/common/car_refresh_indicator.dart';

class RuteScreen extends StatefulWidget {
  const RuteScreen({super.key});

  @override
  State<RuteScreen> createState() => _RuteScreenState();
}

class _RuteScreenState extends State<RuteScreen> {
  bool _isGenerated = false;
  bool _isLoading = false;
  final MapController _mapController = MapController();

  final List<Map<String, dynamic>> _titikRute = [
    {
      'id': 0,
      'nama': 'Dapur SPPG',
      'koordinat': LatLng(-6.9150, 107.6400),
      'tipe': 'start'
    },
    {
      'id': 1,
      'nama': 'SDN 01 Bandung',
      'koordinat': LatLng(-6.9175, 107.6191),
      'tipe': 'tujuan'
    },
    {
      'id': 2,
      'nama': 'Posyandu 01',
      'koordinat': LatLng(-6.9218, 107.6072),
      'tipe': 'tujuan'
    },
    {
      'id': 3,
      'nama': 'SMP 01 Cimahi',
      'koordinat': LatLng(-6.8842, 107.5424),
      'tipe': 'tujuan'
    },
    {
      'id': 4,
      'nama': 'Posyandu 02',
      'koordinat': LatLng(-6.9301, 107.6284),
      'tipe': 'tujuan'
    },
  ];

  final Map<String, dynamic> _infoRute = {
    'totalJarak': '42 km',
    'estimasiWaktu': '2j 15m',
    'totalTitik': 4,
  };

  final List<Map<String, String>> _jadwalRute = [
    {'nama': 'Dapur SPPG',    'waktu': '07:00', 'tipe': 'start'  },
    {'nama': 'SDN 01 Bandung', 'waktu': '07:25', 'tipe': 'tujuan' },
    {'nama': 'Posyandu 01',   'waktu': '08:10', 'tipe': 'tujuan' },
    {'nama': 'SMP 01 Cimahi', 'waktu': '09:00', 'tipe': 'tujuan' },
    {'nama': 'Posyandu 02',   'waktu': '10:30', 'tipe': 'tujuan' },
  ];

  Future<void> _generateRute() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isLoading = false;
      _isGenerated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CarRefreshIndicator(
      onRefresh: () async {
        await _generateRute();
      },
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [

          // Peta
          Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BGNColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(-6.9150, 107.6100),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.distribusi.bgn',
                  ),

                  // Garis rute
                  if (_isGenerated)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _titikRute
                              .map((t) => t['koordinat'] as LatLng)
                              .toList(),
                          color: BGNColors.primary,
                          strokeWidth: 3,
                          pattern: StrokePattern.dashed(
                            segments: const [10, 6],
                          ),
                        ),
                      ],
                    ),

                  // Marker
                  MarkerLayer(
                    markers: _titikRute.asMap().entries.map((entry) {
                      final index = entry.key;
                      final titik = entry.value;
                      final isStart = titik['tipe'] == 'start';

                      return Marker(
                        point: titik['koordinat'] as LatLng,
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isStart
                                ? BGNColors.primary
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: BGNColors.primary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isStart ? 'S' : '$index',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isStart
                                    ? Colors.white
                                    : BGNColors.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Info rute
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BGNColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi rute',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoRuteCard(
                      icon: TablerIcons.route,
                      value: _isGenerated
                          ? _infoRute['totalJarak']
                          : '-',
                      label: 'Total jarak',
                    ),
                    const SizedBox(width: 8),
                    _InfoRuteCard(
                      icon: TablerIcons.clock,
                      value: _isGenerated
                          ? _infoRute['estimasiWaktu']
                          : '-',
                      label: 'Est. waktu',
                    ),
                    const SizedBox(width: 8),
                    _InfoRuteCard(
                      icon: TablerIcons.map_pin,
                      value: _isGenerated
                          ? '${_infoRute['totalTitik']}'
                          : '-',
                      label: 'Titik tujuan',
                    ),
                  ],
                ),
                if (!_isGenerated) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BGNColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          TablerIcons.info_circle,
                          size: 14,
                          color: BGNColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tekan generate untuk menghitung rute tercepat',
                          style: TextStyle(
                            fontSize: 11,
                            color: BGNColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tombol generate
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateRute,
              icon: _isLoading
                  ? const ButtonCarLoading()
                  : Icon(
                      _isGenerated ? TablerIcons.refresh : TablerIcons.route,
                    ),
              label: Text(
                _isLoading
                    ? 'Menghitung rute tercepat...'
                    : _isGenerated
                        ? 'Generate ulang rute'
                        : 'Generate rute tercepat',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isGenerated
                    ? BGNColors.primaryLight
                    : BGNColors.primary,
                foregroundColor: _isGenerated
                    ? BGNColors.primary
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: _isGenerated
                      ? const BorderSide(color: BGNColors.primary)
                      : BorderSide.none,
                ),
              ),
            ),
          ),

          // Urutan rute
          if (_isGenerated) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BGNColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Urutan rute optimal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BGNColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._jadwalRute.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isStart = item['tipe'] == 'start';
                    final isLast = index == _jadwalRute.length - 1;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isStart
                                    ? BGNColors.primary
                                    : BGNColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isStart
                                        ? Colors.white
                                        : BGNColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 1.5,
                                height: 24,
                                color: BGNColors.border,
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['nama']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: BGNColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      index == 0
                                          ? 'Titik keberangkatan'
                                          : 'Tujuan $index',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: BGNColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  item['waktu']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: BGNColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],

        ],
      ),
    ),
    );
  }
}

// ── Widget helpers ─────────────────────────────────────────

class _InfoRuteCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InfoRuteCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: BGNColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: BGNColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BGNColors.primary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: BGNColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}