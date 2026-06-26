import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/widgets/common/car_refresh_indicator.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';
import 'package:bgn/distribusi/widgets/tracking/driver_chips.dart';
import 'package:bgn/distribusi/widgets/tracking/driver_status_card.dart';
import 'package:bgn/distribusi/widgets/tracking/checkpoint_list_widget.dart';
import 'package:bgn/distribusi/widgets/tracking/riwayat_card.dart';
import 'package:bgn/distribusi/widgets/tracking/riwayat_detail_sheet.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  String _activeTab = 'live';
  final PackagingService _packagingService = PackagingService(ApiClient());
  int _activeDriverId = 1;

  List<dynamic> _riwayatList = [];
  bool _loadingRiwayat = false;
  String? _errorRiwayat;

  static const _tabs = [
    {'id': 'live', 'label': 'Live Tracking'},
    {'id': 'riwayat', 'label': 'Riwayat'},
  ];

  @override
  void initState() {
    super.initState();
    if (context.read<AuthProvider>().isLoggedIn) _loadRiwayat();
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
    final distribusi = context.watch<DistribusiProvider>();

    return Column(
      children: [
        // Tab bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: _tabs.map((t) {
              final active = _activeTab == t['id'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = t['id']!),
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
                  child: _buildLiveTab(distribusi),
                )
              : CarRefreshIndicator(
                  onRefresh: _loadRiwayat,
                  child: _buildRiwayatTab(),
                ),
        ),
      ],
    );
  }

  Widget _buildLiveTab(DistribusiProvider distribusi) {
    final activeDriver = distribusi.driverList
        .firstWhere((d) => d.id == _activeDriverId);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          DriverChips(
            drivers: distribusi.driverList,
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
        // Summary
        Row(
          children: [
            _SummaryBox(label: 'Total riwayat', value: '${_riwayatList.length}', color: BGNColors.primary, bg: BGNColors.primaryLight),
            const SizedBox(width: 8),
            _SummaryBox(label: 'Rata-rata efektivitas', value: '${avgEfektif.toStringAsFixed(0)}%', color: Colors.green, bg: Colors.green.withValues(alpha: 0.1)),
            const SizedBox(width: 8),
            _SummaryBox(label: 'Total porsi', value: totalPorsi.toString(), color: Colors.amber, bg: Colors.amber.withValues(alpha: 0.1)),
          ],
        ),
        const SizedBox(height: 16),

        // List
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
