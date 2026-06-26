// lib/screens/pengiriman/tab_jadwal.dart

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/widgets/common/car_loading.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';

class TabJadwal extends StatefulWidget {
  const TabJadwal({super.key});

  @override
  State<TabJadwal> createState() => _TabJadwalState();
}

class _TabJadwalState extends State<TabJadwal> {
  final PackagingService _packagingService = PackagingService(ApiClient());
  List<dynamic> _jadwalList = [];
  bool _loading = false;
  String? _error;
  String _filterStatus = 'semua';
  bool _isBerangkat = false;

  final List<Map<String, String>> _filterOptions = [
    {'value': 'semua',    'label': 'Semua'    },
    {'value': 'Selesai',  'label': 'Selesai'  },
    {'value': 'Dikirim',  'label': 'Dikirim'  },
    {'value': 'Menunggu', 'label': 'Menunggu' },
  ];

  @override
  void initState() {
    super.initState();
    _fetchJadwal();
  }

  // ── API ──────────────────────────────────────────────────

  Future<void> _fetchJadwal() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final data = await _packagingService.getList();
      if (!mounted) return;
      setState(() {
        _jadwalList = data..sort((a, b) {
          final ta = DateTime.tryParse(a['timestamp'] ?? '');
          final tb = DateTime.tryParse(b['timestamp'] ?? '');
          if (ta == null || tb == null) return 0;
          return tb.compareTo(ta);
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleBerangkat() async {
    if (_isBerangkat) return;
    if (!mounted) return;
    setState(() => _isBerangkat = true);
    try {
      final siap = _jadwalHariIniSiap;

      await Future.wait(siap.map((item) async {
        final id = item['id'] as int;
        final data = Map<String, dynamic>.from(item)
          ..['delivery_status'] = 'Dikirim';
        await _packagingService.update(id.toString(), data);
      }));

      // Update lokal — tidak perlu re-fetch seluruh list
      if (!mounted) return;
      setState(() {
        for (final item in siap) {
          final id = item['id'] as int;
          final idx = _jadwalList.indexWhere((i) => (i['id'] as int) == id);
          if (idx != -1) {
            _jadwalList[idx] = {..._jadwalList[idx], 'delivery_status': 'Dikirim'};
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isBerangkat = false);
    }
  }

  // ── Computed ─────────────────────────────────────────────

  List<dynamic> get _jadwalFiltered {
    if (_filterStatus == 'semua') return _jadwalList;
    return _jadwalList
        .where((i) => i['delivery_status'] == _filterStatus)
        .toList(growable: false);
  }

  List<dynamic> get _jadwalHariIniSiap {
    final today = DateTime.now();
    return _jadwalList.where((i) {
      final ts  = DateTime.tryParse(i['timestamp'] ?? '');
      final tgl = ts != null &&
          ts.year  == today.year &&
          ts.month == today.month &&
          ts.day   == today.day;
      final status = i['delivery_status'] as String? ?? '';
      return tgl && status != 'Selesai' && status != 'Dikirim';
    }).toList(growable: false);
  }

  Map<String, int> get _statusCounts {
    int selesai = 0, dikirim = 0, menunggu = 0;
    for (final i in _jadwalList) {
      final s = i['delivery_status'] as String?;
      if (s == 'Selesai') { selesai++; }
      else if (s == 'Dikirim') { dikirim++; }
      else { menunggu++; }
    }
    return {'Selesai': selesai, 'Dikirim': dikirim, 'menunggu': menunggu};
  }

  List<Widget> _buildSummaryRow() {
    final counts = _statusCounts;
    return [
      Row(
        children: [
          _SummaryChip(
            label: 'Selesai',
            count: counts['Selesai'] ?? 0,
            color: BGNColors.primary,
            bgColor: BGNColors.primaryLight,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Dikirim',
            count: counts['Dikirim'] ?? 0,
            color: BGNColors.warning,
            bgColor: BGNColors.warningLight,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Menunggu',
            count: counts['menunggu'] ?? 0,
            color: BGNColors.textSecondary,
            bgColor: BGNColors.background,
          ),
        ],
      ),
    ];
  }

  // ── Helpers ───────────────────────────────────────────────

  String _formatTanggal(String? ts) {
    if (ts == null) return '-';
    final date = DateTime.tryParse(ts);
    if (date == null) return '-';
    const bulan = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${bulan[date.month]} ${date.year}';
  }

  Map<String, dynamic> _statusConfig(String? status) {
    switch (status) {
      case 'Selesai':
        return {'label': 'Selesai', 'color': BGNColors.primary, 'bg': BGNColors.primaryLight};
      case 'Dikirim':
        return {'label': 'Dikirim', 'color': BGNColors.warning, 'bg': BGNColors.warningLight};
      default:
        return {'label': 'Menunggu', 'color': BGNColors.textSecondary, 'bg': BGNColors.background};
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Filter status
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterOptions.map((f) {
              final isActive = _filterStatus == f['value'];
              final counts  = _statusCounts;
              final count   = f['value'] == 'semua'
                  ? _jadwalList.length
                  : counts[f['value']!] ?? 0;

              return GestureDetector(
                onTap: () => setState(() => _filterStatus = f['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8, bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? BGNColors.primary : BGNColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? BGNColors.primary : BGNColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        f['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isActive ? BGNColors.white : BGNColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive
                              ? BGNColors.white.withValues(alpha: 0.7)
                              : BGNColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Tombol berangkat
        if (_jadwalHariIniSiap.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBerangkat ? null : _handleBerangkat,
              icon: _isBerangkat
                  ? const ButtonCarLoading()
                  : const Icon(TablerIcons.truck, size: 18),
              label: Text(
                _isBerangkat
                    ? 'Mengirim...'
                    : 'Berangkat Sekarang (${_jadwalHariIniSiap.length} pengiriman)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BGNColors.primary,
                foregroundColor: BGNColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hanya untuk jadwal hari ini yang belum dikirim',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: BGNColors.textHint),
          ),
          const SizedBox(height: 12),
        ],

        // Summary
        ..._buildSummaryRow(),

        const SizedBox(height: 12),

        // Loading
        if (_loading)
          Column(
            children: List.generate(3, (i) => _LoadingSkeleton()),
          )

        // Error
        else if (_error != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BGNColors.dangerLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(TablerIcons.alert_circle, color: BGNColors.danger, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gagal memuat data',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: BGNColors.danger,
                        ),
                      ),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: BGNColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _fetchJadwal,
                  child: const Text(
                    'Coba lagi',
                    style: TextStyle(fontSize: 11, color: BGNColors.danger),
                  ),
                ),
              ],
            ),
          )

        // List jadwal
        else if (_jadwalFiltered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: const [
                  Icon(TablerIcons.inbox, size: 48, color: BGNColors.border),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada data pengiriman',
                    style: TextStyle(fontSize: 13, color: BGNColors.textSecondary),
                  ),
                ],
              ),
            ),
          )

        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _jadwalFiltered.length,
            itemBuilder: (context, index) {
              final item = _jadwalFiltered[index];
              final statusCfg = _statusConfig(item['delivery_status'] as String?);
              final effectiveness = (item['effectiveness'] as num?)?.toDouble() ?? 0.0;
              final discrepancy   = (item['discrepancy'] as num?)?.toInt() ?? 0;
              final actual        = (item['actual_portions'] as num?)?.toInt() ?? 0;
              final target        = (item['target_portions'] as num?)?.toInt() ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: BGNColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BGNColors.border),
                ),
                child: Column(
                  children: [

                    // Header
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['menu_name'] as String? ?? 'Menu belum ditentukan',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: BGNColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatTanggal(item['timestamp'] as String?)} · $target porsi',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: BGNColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusCfg['bg'] as Color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusCfg['label'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: statusCfg['color'] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: BGNColors.border),

                    // Info rute & aslab
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  TablerIcons.map_pin,
                                  size: 12,
                                  color: BGNColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item['delivery_route'] as String? ?? 'Rute belum ditentukan',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: BGNColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  TablerIcons.user,
                                  size: 12,
                                  color: BGNColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item['field_assistant'] as String? ?? '-',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: BGNColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Footer: porsi + efektivitas + selisih
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          // Porsi
                          _FooterChip(
                            label: '$actual/$target porsi',
                            color: BGNColors.textSecondary,
                            bgColor: BGNColors.background,
                            icon: TablerIcons.package,
                          ),
                          const SizedBox(width: 6),
                          // Efektivitas
                          _FooterChip(
                            label: '${effectiveness.toStringAsFixed(1)}%',
                            color: effectiveness >= 95
                                ? BGNColors.primary
                                : BGNColors.warning,
                            bgColor: effectiveness >= 95
                                ? BGNColors.primaryLight
                                : BGNColors.warningLight,
                            icon: TablerIcons.chart_bar,
                          ),
                          const Spacer(),
                          // Selisih
                          _FooterChip(
                            label: discrepancy == 0
                                ? 'Sesuai'
                                : 'Selisih ${discrepancy.abs()}',
                            color: discrepancy == 0
                                ? BGNColors.primary
                                : BGNColors.warning,
                            bgColor: discrepancy == 0
                                ? BGNColors.primaryLight
                                : BGNColors.warningLight,
                            icon: discrepancy == 0
                                ? TablerIcons.circle_check
                                : TablerIcons.alert_triangle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Micro widgets ──────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _FooterChip({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BGNColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 12, width: double.infinity, color: BGNColors.background),
          const SizedBox(height: 8),
          Container(height: 10, width: 160, color: BGNColors.background),
          const SizedBox(height: 12),
          Container(height: 10, width: 200, color: BGNColors.background),
        ],
      ),
    );
  }
}