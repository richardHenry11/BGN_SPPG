import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/widgets/common/car_refresh_indicator.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';
import 'package:bgn/distribusi/providers/pengiriman_provider.dart';
import 'package:bgn/distribusi/widgets/laporan/ringkasan_harian.dart';
import 'package:bgn/distribusi/widgets/laporan/evaluasi_chart.dart';
import 'package:bgn/distribusi/widgets/laporan/komplain_card.dart';
import 'package:bgn/distribusi/widgets/laporan/penerima_section.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  String _activeTab = 'ringkasan';

  static const _penerimaRoles = ['pic_sekolah', 'pm'];

  static const _allTabs = [
    _TabConfig(id: 'bukti',     label: 'Bukti Terima', roles: ['pic_sekolah', 'pm']),
    _TabConfig(id: 'ringkasan', label: 'Ringkasan',    roles: ['kepala_sppg']),
    _TabConfig(id: 'komplain',  label: 'Komplain',     roles: ['kepala_sppg']),
    _TabConfig(id: 'evaluasi',  label: 'Evaluasi',     roles: ['kepala_sppg']),
    _TabConfig(id: 'penerima',  label: 'Penerima',     roles: ['pm', 'pic_sekolah']),
  ];

  List<_TabConfig> get _tabsFiltered {
    final role = context.read<AuthProvider>().currentRole;
    return _allTabs.where((t) => t.roles.contains(role)).toList();
  }

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().currentRole;
    _activeTab = _penerimaRoles.contains(role) ? 'penerima' : 'ringkasan';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsFiltered;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return CarRefreshIndicator(
      onRefresh: () {
        final role = context.read<AuthProvider>().currentRole;
        if (role == 'kepala_sppg' || role == 'pm') {
          return context.read<DistribusiProvider>().refresh();
        }
        return context.read<PengirimanProvider>().refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TabBar(
              tabs: tabs,
              activeTab: _activeTab,
              onTabChanged: (id) => setState(() => _activeTab = id),
            ),
            const SizedBox(height: 16),
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'bukti':
        return _BuktiTerimaSection();
      case 'ringkasan':
        return const RingkasanHarian();
      case 'komplain':
        return _KomplainSection();
      case 'evaluasi':
        return const EvaluasiChart();
      case 'penerima':
        return const PenerimaSection();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TabConfig {
  final String id;
  final String label;
  final List<String> roles;

  const _TabConfig({required this.id, required this.label, required this.roles});
}

class _TabBar extends StatelessWidget {
  final List<_TabConfig> tabs;
  final String activeTab;
  final ValueChanged<String> onTabChanged;

  const _TabBar({required this.tabs, required this.activeTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isActive = tab.id == activeTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onTabChanged(tab.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? BGNColors.primary : BGNColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? BGNColors.primary : BGNColors.border,
                  ),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : BGNColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Bukti Terima (pic_sekolah / pm) ───────────────────

class _BuktiTerimaSection extends StatefulWidget {
  @override
  State<_BuktiTerimaSection> createState() => _BuktiTerimaSectionState();
}

class _BuktiTerimaSectionState extends State<_BuktiTerimaSection> {
  final PackagingService _packagingService = PackagingService(ApiClient());

  List<dynamic> _list = [];
  bool _loading = false;
  String? _error;

  Map<String, String> _authHeaders() {
    final auth = context.read<AuthProvider>();
    final h = <String, String>{'X-User-Role': auth.apiRole};
    if (auth.token != null) h['Authorization'] = 'Bearer ${auth.token}';
    if (auth.sppgId != null) h['X-User-Sppg-Id'] = auth.sppgId.toString();
    return h;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _packagingService.getList(headers: _authHeaders());
      if (!mounted) return;
      setState(() {
        if (auth.currentRole == 'pm') {
          final unit = auth.activeUser.unit.toLowerCase();
          _list = data.where((item) {
            final name = (item['beneficiary_name'] as String? ?? '').toLowerCase();
            return name.contains(unit);
          }).toList();
        } else {
          _list = data;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 64,
            decoration: BoxDecoration(
              color: BGNColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BGNColors.dangerLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(TablerIcons.alert_circle, size: 16, color: BGNColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 11, color: BGNColors.danger),
              ),
            ),
            GestureDetector(
              onTap: _fetch,
              child: const Text(
                'Coba lagi',
                style: TextStyle(
                  fontSize: 11,
                  color: BGNColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(TablerIcons.package_off, size: 32, color: BGNColors.textHint),
            const SizedBox(height: 8),
            const Text(
              'Tidak ada pengiriman hari ini',
              style: TextStyle(fontSize: 12, color: BGNColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pengiriman (${_list.length})',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: BGNColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._list.map((item) => _DeliveryCard(
              item: item,
            )),
      ],
    );
  }
}

// ── Card item delivery (expandable) ──────────────────────

class _DeliveryCard extends StatefulWidget {
  final dynamic item;

  const _DeliveryCard({required this.item});

  @override
  State<_DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<_DeliveryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelesai = (item['qc_status'] as String?) != 'Pending';
    final lokasi = item['beneficiary_name'] as String? ??
        item['delivery_route'] as String? ?? '-';
    final menu = item['menu_name'] as String? ?? '-';
    final target = (item['target_portions'] as num?)?.toInt() ?? 0;
    final actual = (item['actual_portions'] as num?)?.toInt() ?? 0;
    final discrepancy = (item['discrepancy'] as num?)?.toInt() ?? (target - actual);
    final aslab = item['field_assistant'] as String? ?? '-';
    final route = item['delivery_route'] as String? ?? '-';
    final rating = (item['rating'] as num?)?.toInt();
    final reviewComment = item['review_comment'] as String?;
    final timestamp = item['timestamp'] as String?;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? BGNColors.primary
              : isSelesai
                  ? BGNColors.border
                  : BGNColors.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // ── Header (tap to expand) ──
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelesai ? BGNColors.primaryLight : BGNColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSelesai ? TablerIcons.circle_check : TablerIcons.truck_delivery,
                      size: 16,
                      color: isSelesai ? BGNColors.primary : BGNColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lokasi,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: BGNColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          menu,
                          style: const TextStyle(fontSize: 10, color: BGNColors.textHint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelesai ? BGNColors.primaryLight : BGNColors.warningLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSelesai ? 'Selesai' : 'Perlu konfirmasi',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isSelesai ? BGNColors.primary : BGNColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.rotate(
                    angle: _expanded ? math.pi : 0,
                    child: const Icon(
                      TablerIcons.chevron_down,
                      size: 16,
                      color: BGNColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail ──
          if (_expanded) Column(
                    children: [
                      const Divider(height: 1, color: BGNColors.border),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Stat porsi ──
                            Row(
                              children: [
                                _MiniInfo(label: 'Target', value: '$target porsi'),
                                const SizedBox(width: 8),
                                _MiniInfo(label: 'Dikirim', value: '$actual porsi'),
                                const SizedBox(width: 8),
                                _MiniInfo(
                                  label: 'Selisih',
                                  value: discrepancy == 0 ? 'Sesuai' : '$discrepancy',
                                  valueColor: discrepancy == 0
                                      ? BGNColors.primary
                                      : BGNColors.danger,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // ── Rute & Asisten ──
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: BGNColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  _DetailRow(
                                    icon: TablerIcons.map_pin,
                                    label: 'Rute',
                                    value: route,
                                  ),
                                  const SizedBox(height: 6),
                                  _DetailRow(
                                    icon: TablerIcons.user,
                                    label: 'Asisten lapangan',
                                    value: aslab,
                                  ),
                                  if (timestamp != null) ...[
                                    const SizedBox(height: 6),
                                    _DetailRow(
                                      icon: TablerIcons.clock,
                                      label: 'Waktu',
                                      value: _formatTimestamp(timestamp),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // ── QC kondisi (jika sudah selesai) ──
                            if (isSelesai) ...[
                              const SizedBox(height: 10),
                              _buildQCSection(item),
                            ],

                            // ── Rating (jika sudah selesai dan ada rating) ──
                            if (isSelesai && rating != null) ...[
                              const SizedBox(height: 10),
                              _buildRatingRow(rating),
                            ],

                            // ── Review comment ──
                            if (isSelesai &&
                                reviewComment != null &&
                                reviewComment.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: BGNColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(TablerIcons.message_circle,
                                            size: 12, color: BGNColors.primary),
                                        SizedBox(width: 4),
                                        Text(
                                          'Masukan',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: BGNColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      reviewComment,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: BGNColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                          ],
                        ),
                      ),
                    ],
                  )

        ],
      ),
    );
  }

  Widget _buildQCSection(dynamic item) {
    final brokenQty = (item['pm_broken_qty'] as num?)?.toInt() ?? 0;
    final missingQty = (item['pm_missing_qty'] as num?)?.toInt() ?? 0;
    final damagedLabel = item['pm_damaged_label'] as bool? ?? false;
    final damagedSeal = item['pm_damaged_seal'] as bool? ?? false;
    final adaMasalah = brokenQty > 0 || missingQty > 0 || damagedLabel || damagedSeal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QC kondisi penerimaan',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: BGNColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _QCBadge(
              label: 'Pecah',
              value: '$brokenQty',
              isProblem: brokenQty > 0,
            ),
            const SizedBox(width: 6),
            _QCBadge(
              label: 'Kurang',
              value: '$missingQty',
              isProblem: missingQty > 0,
            ),
            const SizedBox(width: 6),
            _QCBadge(
              label: 'Label',
              value: damagedLabel ? 'Rusak' : 'Baik',
              isProblem: damagedLabel,
            ),
            const SizedBox(width: 6),
            _QCBadge(
              label: 'Segel',
              value: damagedSeal ? 'Rusak' : 'Baik',
              isProblem: damagedSeal,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: adaMasalah ? BGNColors.dangerLight : BGNColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                adaMasalah ? TablerIcons.alert_triangle : TablerIcons.circle_check,
                size: 14,
                color: adaMasalah ? BGNColors.danger : BGNColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                adaMasalah ? 'Ada masalah kondisi' : 'Kondisi kemasan baik',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: adaMasalah ? BGNColors.danger : BGNColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BGNColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Text(
            'Rating kurir',
            style: TextStyle(fontSize: 11, color: BGNColors.textSecondary),
          ),
          const Spacer(),
          ...List.generate(5, (i) {
            final filled = i < rating;
            return Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Icon(
                filled ? TablerIcons.star_filled : TablerIcons.star,
                size: 16,
                color: filled ? BGNColors.warning : BGNColors.border,
              ),
            );
          }),
          const SizedBox(width: 6),
          Text(
            '$rating/5',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: BGNColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String ts) {
    final date = DateTime.tryParse(ts);
    if (date == null) return ts;
    const bulan = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${bulan[date.month]} ${date.year} · $h:$m';
  }
}

// ── QC badge ─────────────────────────────────────────────

class _QCBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool isProblem;

  const _QCBadge({required this.label, required this.value, required this.isProblem});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isProblem ? BGNColors.dangerLight : BGNColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isProblem ? BGNColors.danger : BGNColors.primary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: BGNColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail row (icon + label + value) ────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: BGNColors.textHint),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: BGNColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniInfo({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: BGNColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: BGNColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: valueColor ?? BGNColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Komplain Section ──────────────────────────────────────

class _KomplainSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final komplainList = context.watch<DistribusiProvider>().komplainList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar komplain',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: BGNColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BGNColors.dangerLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${komplainList.length} masuk',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: BGNColors.danger,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (komplainList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(TablerIcons.mood_happy, size: 32, color: BGNColors.textHint),
                const SizedBox(height: 8),
                const Text(
                  'Tidak ada komplain hari ini',
                  style: TextStyle(fontSize: 12, color: BGNColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ...komplainList.map((k) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: KomplainCard(komplain: k),
              )),
      ],
    );
  }
}