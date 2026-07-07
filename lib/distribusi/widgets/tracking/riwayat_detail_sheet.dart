import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';

class RiwayatDetailSheet extends StatefulWidget {
  final int id;

  const RiwayatDetailSheet({super.key, required this.id});

  @override
  State<RiwayatDetailSheet> createState() => _RiwayatDetailSheetState();
}

class _RiwayatDetailSheetState extends State<RiwayatDetailSheet> {
  final PackagingService _packagingService = PackagingService(ApiClient());
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      _data = await _packagingService.getDetail(widget.id.toString());
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: BGNColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: BGNColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Detail pengiriman', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: BGNColors.textPrimary,
                  )),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(
                        color: BGNColors.background, shape: BoxShape.circle,
                      ),
                      child: const Icon(TablerIcons.x, size: 14, color: BGNColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: BGNColors.border),

            // Content
            Expanded(
              child: _loading
                  ? const _LoadingView()
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: _fetch)
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: _buildContent(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    final d = _data!;
    final menu = d['menu_name'] as String? ?? '-';
    final target = (d['target_portions'] as num?)?.toInt() ?? 0;
    final actual = (d['actual_portions'] as num?)?.toInt() ?? 0;
    final efektivitas = (d['effectiveness'] as num?)?.toDouble() ?? 0.0;
    final diskrepansi = (d['discrepancy'] as num?)?.toInt() ?? 0;
    final fbQty = (d['fallen_broken_qty'] as num?)?.toInt() ?? 0;
    final missQty = (d['missing_qty'] as num?)?.toInt() ?? 0;
    final labelRusak = d['damaged_label_check'] == true;
    final segelRusak = d['damaged_seal_check'] == true;
    final route = d['delivery_route'] as String? ?? '-';
    final aslab = d['field_assistant'] as String? ?? '-';
    final cctv = d['cctv_link'] as String? ?? '-';
    final beneficiary = d['beneficiary_name'] as String? ?? '-';
    final rating = (d['rating'] as num?)?.toInt() ?? 0;
    final review = d['review_comment'] as String?;
    final reviewFoto = d['review_photo_url'] as String?;
    final fotoBukti = d['proof_photo_url'] as String?;

    return [
      // Menu
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BGNColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Menu', style: TextStyle(fontSize: 10, color: BGNColors.primary)),
            const SizedBox(height: 4),
            Text(menu, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.primary)),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Info grid
      Row(
        children: [
          _StatBox(label: 'Target', value: '$target'),
          const SizedBox(width: 8),
          _StatBox(label: 'Aktual', value: '$actual', color: diskrepansi == 0 ? null : BGNColors.danger),
          const SizedBox(width: 8),
          _StatBox(label: 'Efektivitas', value: '${efektivitas.toStringAsFixed(0)}%',
            color: efektivitas >= 95 ? Colors.green : efektivitas >= 90 ? Colors.blue : Colors.amber),
        ],
      ),
      const SizedBox(height: 12),

      // QC section
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
            const Text('Kondisi QC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
            const SizedBox(height: 12),
            _QcRow(ok: fbQty == 0, label: 'Ompreng jatuh / rusak', value: '$fbQty'),
            const SizedBox(height: 8),
            _QcRow(ok: missQty == 0, label: 'Ompreng kurang / hilang', value: '$missQty'),
            const SizedBox(height: 8),
            _QcRow(ok: !labelRusak, label: labelRusak ? 'Label rusak / lepas' : 'Label baik'),
            const SizedBox(height: 8),
            _QcRow(ok: !segelRusak, label: segelRusak ? 'Segel / kemasan rusak' : 'Segel baik'),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Info pengiriman
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
            const Text('Info pengiriman', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
            const SizedBox(height: 12),
            _InfoRow(icon: TablerIcons.map_pin, value: route),
            const SizedBox(height: 8),
            _InfoRow(icon: TablerIcons.user, value: aslab),
            const SizedBox(height: 8),
            _InfoRow(icon: TablerIcons.video, value: cctv),
            const SizedBox(height: 8),
            _InfoRow(icon: TablerIcons.clock, value: _formatDate(d['timestamp'] as String?)),
            const SizedBox(height: 8),
            _InfoRow(icon: TablerIcons.users, value: beneficiary),
          ],
        ),
      ),

      // Rating & review
      if (rating > 0 || review != null || reviewFoto != null) ...[
        const SizedBox(height: 12),
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
              const Text('Ulasan penerima', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
              if (rating > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) => Icon(
                    i < rating ? TablerIcons.star_filled : TablerIcons.star,
                    size: 18, color: i < rating ? Colors.amber : BGNColors.border,
                  )),
                ),
              ],
              if (review != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BGNColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('"$review"', style: const TextStyle(fontSize: 12, color: BGNColors.textSecondary, fontStyle: FontStyle.italic)),
                ),
              ],
              if (reviewFoto != null && reviewFoto.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(reviewFoto, height: 160, width: double.infinity,
                      fit: BoxFit.cover, cacheWidth: 320, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ],
            ],
          ),
        ),
      ],

      // Foto bukti
      if (fotoBukti != null && fotoBukti.isNotEmpty) ...[
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Foto bukti pengiriman:', style: TextStyle(fontSize: 10, color: BGNColors.textHint)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(fotoBukti, height: 160, width: double.infinity,
                  fit: BoxFit.cover, cacheWidth: 320, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ],
        ),
      ],
    ];
  }

  String _formatDate(String? ts) {
    if (ts == null) return '-';
    final d = DateTime.tryParse(ts);
    if (d == null) return '-';
    const bulan = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${bulan[d.month]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: BGNColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: color ?? BGNColors.textPrimary,
            )),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _QcRow extends StatelessWidget {
  final bool ok;
  final String label;
  final String? value;

  const _QcRow({required this.ok, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? BGNColors.primaryLight : BGNColors.dangerLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(ok ? TablerIcons.circle_check : TablerIcons.alert_triangle,
              size: 16, color: ok ? BGNColors.primary : BGNColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(
            fontSize: 12, color: ok ? BGNColors.primary : BGNColors.danger,
          ))),
          if (value != null)
            Text(value!, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: ok ? BGNColors.primary : BGNColors.danger,
            )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: BGNColors.textHint),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontSize: 12, color: BGNColors.textSecondary)),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(5, (_) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 60,
        decoration: BoxDecoration(
          color: BGNColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
      )),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(TablerIcons.alert_circle, size: 36, color: BGNColors.danger),
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(fontSize: 12, color: BGNColors.danger), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(TablerIcons.refresh, size: 16),
              label: const Text('Coba lagi', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
