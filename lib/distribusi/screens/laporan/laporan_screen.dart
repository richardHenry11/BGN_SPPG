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

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  String _activeTab = 'ringkasan';

  static const _allTabs = [
    _TabConfig(id: 'bukti',     label: 'Bukti Terima', roles: ['pic_sekolah']),
    _TabConfig(id: 'ringkasan', label: 'Ringkasan',    roles: ['kepala_sppg']),
    _TabConfig(id: 'komplain',  label: 'Komplain',     roles: ['kepala_sppg']),
    _TabConfig(id: 'evaluasi',  label: 'Evaluasi',     roles: ['kepala_sppg']),
    _TabConfig(id: 'penerima',  label: 'Penerima',     roles: ['kepala_sppg']),
  ];

  List<_TabConfig> get _tabsFiltered {
    final role = context.read<AuthProvider>().currentRole;
    return _allTabs.where((t) => t.roles.contains(role)).toList();
  }

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().currentRole;
    _activeTab = role == 'pic_sekolah' ? 'bukti' : 'ringkasan';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsFiltered;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return CarRefreshIndicator(
      onRefresh: () {
        final role = context.read<AuthProvider>().currentRole;
        if (role == 'kepala_sppg') {
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
                  color: isActive ? BGNColors.primary : Colors.white,
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

// ── Bukti Terima (pic_sekolah) ────────────────────────────

class _BuktiTerimaSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pengirimanList = context.watch<PengirimanProvider>().pengirimanList;
    final myDeliveries = pengirimanList.where((p) => p.penerima == auth.activeUser.name).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status penerimaan saya',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary),
        ),
        const SizedBox(height: 12),
        if (myDeliveries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(TablerIcons.package_off, size: 32, color: BGNColors.textHint),
                const SizedBox(height: 8),
                const Text('Tidak ada pengiriman untuk Anda hari ini',
                    style: TextStyle(fontSize: 12, color: BGNColors.textSecondary)),
              ],
            ),
          )
        else
          ...myDeliveries.map((item) => _PengirimanSayaCard(item: item)),
      ],
    );
  }
}

class _PengirimanSayaCard extends StatefulWidget {
  final dynamic item;

  const _PengirimanSayaCard({required this.item});

  @override
  State<_PengirimanSayaCard> createState() => _PengirimanSayaCardState();
}

class _PengirimanSayaCardState extends State<_PengirimanSayaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isSelesai = widget.item.status == 'selesai';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? BGNColors.primary : BGNColors.border,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.alamat,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${widget.item.waktu} · ${widget.item.porsiRencana} porsi',
                            style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelesai ? BGNColors.primaryLight : BGNColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSelesai ? 'Selesai' : 'Menunggu',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isSelesai ? BGNColors.primary : BGNColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? TablerIcons.chevron_up : TablerIcons.chevron_down,
                    size: 16,
                    color: BGNColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) _RingkasanPenerima(item: widget.item),
        ],
      ),
    );
  }
}

class _RingkasanPenerima extends StatelessWidget {
  final dynamic item;

  const _RingkasanPenerima({required this.item});

  @override
  Widget build(BuildContext context) {
    final selisih = item.selisih ?? (item.porsiRencana - item.porsiRencana);
    final kondisi = item.validasiMasuk?.kondisi ?? '-';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _DetailItem(label: 'Porsi rencana', value: '${item.porsiRencana}'),
              _DetailItem(label: 'Porsi terkirim', value: '${item.validasiMasuk?.jumlah ?? '-'}'),
              _DetailItem(label: 'Selisih', value: '$selisih'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(TablerIcons.clipboard_check, size: 14, color: BGNColors.primary),
              const SizedBox(width: 6),
              Text('Kondisi: $kondisi',
                  style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: BGNColors.primary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
        ],
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
            const Text('Daftar komplain',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BGNColors.dangerLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${komplainList.length} masuk',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: BGNColors.danger),
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
                const Text('Tidak ada komplain hari ini',
                    style: TextStyle(fontSize: 12, color: BGNColors.textSecondary)),
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
