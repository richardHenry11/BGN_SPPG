// lib/widgets/laporan/penerima_section.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';
import 'package:bgn/distribusi/widgets/laporan/handover_form.dart';

class PenerimaSection extends StatelessWidget {
  const PenerimaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _HandoverView(onRefresh: () {});
  }
}

class _HandoverView extends StatefulWidget {
  final VoidCallback onRefresh;

  const _HandoverView({required this.onRefresh});

  @override
  State<_HandoverView> createState() => _HandoverViewState();
}

class _HandoverViewState extends State<_HandoverView> {
  final PackagingService _packagingService = PackagingService(ApiClient());

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _selesai = [];

  bool _loading = true;
  String? _error;

  bool _showSelesai = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchAll();
    });
  }

  Map<String, String> _authHeaders() {
    final auth = context.read<AuthProvider>();
    final h = <String, String>{'X-User-Role': auth.apiRole};
    if (auth.token != null) h['Authorization'] = 'Bearer ${auth.token}';
    if (auth.sppgId != null) h['X-User-Sppg-Id'] = auth.sppgId.toString();
    return h;
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _packagingService.getList(headers: _authHeaders());
      if (!mounted) return;
      final all = data.cast<Map<String, dynamic>>();
      setState(() {
        final filtered = auth.currentRole == 'pm'
            ? all.where((d) {
                final name = (d['beneficiary_name'] as String? ?? '').toLowerCase();
                return name.contains(auth.activeUser.unit.toLowerCase());
              }).toList()
            : all;
        _pending = filtered.where((d) => (d['qc_status'] as String?) == 'Pending').toList();
        _selesai = filtered.where((d) => (d['qc_status'] as String?) != 'Pending').toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleSuccess(int id) {
    setState(() => _showSelesai = true);
    widget.onRefresh();
    _fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(TablerIcons.alert_circle,
                size: 36, color: BGNColors.danger),
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: BGNColors.danger),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _fetchAll, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    final activePending = _pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryBar(activePending.length, _selesai.length),
        const SizedBox(height: 14),

        if (activePending.isEmpty)
          _buildAllDoneCard()
        else ...[
          _buildSectionHeader(
            icon: TablerIcons.clock,
            title: '${activePending.length} pengiriman menunggu konfirmasi',
            color: BGNColors.warning,
            bg: BGNColors.warningLight,
            trailing: GestureDetector(
              onTap: _fetchAll,
              child: const Icon(TablerIcons.reload,
                  size: 16, color: BGNColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activePending.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: HandoverForm(
                delivery: activePending[i],
                onSuccess: () => _handleSuccess(activePending[i]['id'] as int),
                onCancel: () {},
              ),
            ),
          ),
        ],

        if (_selesai.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildSelesaiToggle(),
          if (_showSelesai) ...[
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selesai.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SelesaiCard(delivery: _selesai[i]),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSummaryBar(int pendingCount, int selesaiCount) {
    return Row(
      children: [
        _StatChip(
          icon: TablerIcons.clock,
          label: 'Menunggu',
          value: '$pendingCount',
          color: BGNColors.warning,
          bg: BGNColors.warningLight,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: TablerIcons.circle_check,
          label: 'Selesai',
          value: '$selesaiCount',
          color: BGNColors.success,
          bg: BGNColors.successLight,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: TablerIcons.package,
          label: 'Total',
          value: '${pendingCount + selesaiCount}',
          color: BGNColors.primary,
          bg: BGNColors.primaryLight,
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required Color bg,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color)),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildAllDoneCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'Semua pengiriman sudah dikonfirmasi',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: BGNColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSelesaiToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showSelesai = !_showSelesai),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BGNColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BGNColors.border),
        ),
        child: Row(
          children: [
            const Icon(TablerIcons.history,
                size: 14, color: BGNColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Riwayat selesai (${_selesai.length})',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.textSecondary),
              ),
            ),
            Transform.rotate(
              angle: _showSelesai ? math.pi : 0,
              child: const Icon(TablerIcons.chevron_down,
                  size: 16, color: BGNColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 3),
                Text(label,
                    style: TextStyle(fontSize: 9, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelesaiCard extends StatefulWidget {
  final Map<String, dynamic> delivery;
  const _SelesaiCard({required this.delivery});

  @override
  State<_SelesaiCard> createState() => _SelesaiCardState();
}

class _SelesaiCardState extends State<_SelesaiCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final lokasi = d['beneficiary_name'] as String? ??
        d['delivery_route'] as String? ?? '-';
    final menu = d['menu_name'] as String? ?? '-';
    final target = (d['target_portions'] as num?)?.toInt() ?? 0;
    final actual = (d['actual_portions'] as num?)?.toInt() ?? 0;
    final aslab = d['field_assistant'] as String? ?? '-';
    final rating = (d['rating'] as num?)?.toInt() ?? 0;
    final ratingLateness = (d['rating_lateness'] as num?)?.toInt() ?? 0;
    final ratingCompliance = (d['rating_compliance'] as num?)?.toInt() ?? 0;
    final brokenQty = (d['pm_broken_qty'] as num?)?.toInt() ?? 0;
    final missingQty = (d['pm_missing_qty'] as num?)?.toInt() ?? 0;
    final damagedLabel = d['pm_damaged_label'] as bool? ?? false;
    final damagedSeal = d['pm_damaged_seal'] as bool? ?? false;
    final reviewComment = d['review_comment'] as String? ?? '';
    final reviewPhotoUrl = d['review_photo_url'] as String? ?? '';
    final hasSignature = (d['digital_signature'] as String?)?.isNotEmpty ?? false;
    final timestamp = d['timestamp'] as String?;

    final adaMasalah =
        brokenQty > 0 || missingQty > 0 || damagedLabel || damagedSeal;

    return Container(
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? BGNColors.success.withOpacity(0.4)
              : BGNColors.border,
        ),
      ),
      child: Column(
        children: [
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
                      color: BGNColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(TablerIcons.circle_check,
                        size: 16, color: BGNColors.success),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lokasi,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: BGNColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '$menu · $target porsi · ${_formatTanggal(timestamp)}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: BGNColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < rating
                            ? TablerIcons.star_filled
                            : TablerIcons.star,
                        size: 12,
                        color: i < rating
                            ? BGNColors.warning
                            : BGNColors.border,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.rotate(
                    angle: _expanded ? math.pi : 0,
                    child: const Icon(TablerIcons.chevron_down,
                        size: 16, color: BGNColors.textHint),
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1, color: BGNColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DetailBox(
                          label: 'Target',
                          value: '$target',
                          color: BGNColors.textPrimary),
                      const SizedBox(width: 8),
                      _DetailBox(
                          label: 'Diterima',
                          value: '$actual',
                          color: BGNColors.primary),
                      const SizedBox(width: 8),
                      _DetailBox(
                          label: 'Selisih',
                          value: '${actual - target}',
                          color: actual < target
                              ? BGNColors.danger
                              : BGNColors.success),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Penilaian kurir',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: BGNColors.textSecondary)),
                  const SizedBox(height: 8),
                  _RatingReadRow(
                      label: 'Keseluruhan', value: rating),
                  const SizedBox(height: 4),
                  _RatingReadRow(
                      label: 'Ketepatan waktu',
                      value: ratingLateness),
                  const SizedBox(height: 4),
                  _RatingReadRow(
                      label: 'Kepatuhan & sopan',
                      value: ratingCompliance),
                  const SizedBox(height: 12),

                  const Text('Kondisi fisik',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: BGNColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: adaMasalah
                          ? BGNColors.dangerLight
                          : BGNColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _KondisiReadRow(
                            label: 'Kemasan pecah',
                            value: '$brokenQty',
                            isProblem: brokenQty > 0),
                        const SizedBox(height: 4),
                        _KondisiReadRow(
                            label: 'Kemasan kurang',
                            value: '$missingQty',
                            isProblem: missingQty > 0),
                        const SizedBox(height: 4),
                        _KondisiReadRow(
                            label: 'Label rusak',
                            value: damagedLabel ? 'Ya' : 'Tidak',
                            isProblem: damagedLabel),
                        const SizedBox(height: 4),
                        _KondisiReadRow(
                            label: 'Segel rusak',
                            value: damagedSeal ? 'Ya' : 'Tidak',
                            isProblem: damagedSeal),
                      ],
                    ),
                  ),

                  if (reviewComment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Masukan / komentar',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: BGNColors.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BGNColors.background,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color: BGNColors.border),
                      ),
                      child: Text(reviewComment,
                          style: const TextStyle(
                              fontSize: 11,
                              color: BGNColors.textPrimary)),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: BGNColors.background,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(TablerIcons.user,
                            size: 12,
                            color: BGNColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(aslab,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color:
                                      BGNColors.textSecondary)),
                        ),
                        if (reviewPhotoUrl.isNotEmpty) ...[
                          const Icon(TablerIcons.photo,
                              size: 12,
                              color: BGNColors.primary),
                          const SizedBox(width: 3),
                          const Text('Foto',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: BGNColors.primary)),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          hasSignature
                              ? TablerIcons.signature
                              : TablerIcons.signature_off,
                          size: 12,
                          color: hasSignature
                              ? BGNColors.primary
                              : BGNColors.textHint,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          hasSignature ? 'TTD' : 'Tanpa TTD',
                          style: TextStyle(
                              fontSize: 10,
                              color: hasSignature
                                  ? BGNColors.primary
                                  : BGNColors.textHint),
                        ),
                      ],
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

  String _formatTanggal(String? ts) {
    if (ts == null) return '-';
    final date = DateTime.tryParse(ts);
    if (date == null) return '-';
    const bulan = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${bulan[date.month]} · $h:$m';
  }
}

class _DetailBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: BGNColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: BGNColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _RatingReadRow extends StatelessWidget {
  final String label;
  final int value;

  const _RatingReadRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10, color: BGNColors.textSecondary)),
        ),
        Row(
          children: List.generate(
            5,
            (i) => Icon(
              i < value ? TablerIcons.star_filled : TablerIcons.star,
              size: 14,
              color: i < value ? BGNColors.warning : BGNColors.border,
            ),
          ),
        ),
      ],
    );
  }
}

class _KondisiReadRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isProblem;

  const _KondisiReadRow(
      {required this.label,
      required this.value,
      required this.isProblem});

  @override
  Widget build(BuildContext context) {
    final color = isProblem ? BGNColors.danger : BGNColors.primary;
    return Row(
      children: [
        Icon(
          isProblem
              ? TablerIcons.alert_triangle
              : TablerIcons.circle_check,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 10, color: color)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}