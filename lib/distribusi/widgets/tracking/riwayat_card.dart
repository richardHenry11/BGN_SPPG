import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';

class RiwayatCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTapDetail;

  const RiwayatCard({
    super.key,
    required this.item,
    required this.onTapDetail,
  });

  @override
  Widget build(BuildContext context) {
    final status = item['delivery_status'] as String? ?? '-';
    final route = item['delivery_route'] as String? ?? '-';
    final target = (item['target_portions'] as num?)?.toInt() ?? 0;
    final actual = (item['actual_portions'] as num?)?.toInt() ?? 0;
    final efektivitas = (item['effectiveness'] as num?)?.toDouble() ?? 0.0;
    final fbQty = (item['fallen_broken_qty'] as num?)?.toInt() ?? 0;
    final missQty = (item['missing_qty'] as num?)?.toInt() ?? 0;
    final labelRusak = item['damaged_label_check'] == true;
    final segelRusak = item['damaged_seal_check'] == true;
    final aslab = item['field_assistant'] as String? ?? '-';
    final cctv = item['cctv_link'] as String? ?? '-';
    final fotoUrl = item['proof_photo_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BGNColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route, style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary,
                      )),
                      const SizedBox(height: 2),
                      Text(_formatDate(item['timestamp'] as String?), style: const TextStyle(
                        fontSize: 10, color: BGNColors.textSecondary,
                      )),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BGNColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status, style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500, color: BGNColors.primary,
                  )),
                ),
              ],
            ),
          ),

          // Info grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _InfoBox(label: 'Target porsi', value: '$target'),
                const SizedBox(width: 8),
                _InfoBox(
                  label: 'Aktual porsi',
                  value: '$actual',
                  valueColor: item['discrepancy'] == 0 ? null : BGNColors.danger,
                ),
                const SizedBox(width: 8),
                _InfoBox(
                  label: 'Efektivitas',
                  value: '${efektivitas.toStringAsFixed(0)}%',
                  valueColor: efektivitas >= 95 ? BGNColors.primary : BGNColors.warning,
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (efektivitas / 100).clamp(0.0, 1.0),
                backgroundColor: BGNColors.border,
                valueColor: AlwaysStoppedAnimation(
                  efektivitas >= 95 ? Colors.green : efektivitas >= 90 ? Colors.blue : Colors.amber,
                ),
                minHeight: 6,
              ),
            ),
          ),

          // QC badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                _QcBadge(ok: fbQty == 0, label: fbQty > 0 ? '$fbQty rusak' : 'Tidak rusak'),
                _QcBadge(ok: missQty == 0, label: missQty > 0 ? '$missQty kurang' : 'Sesuai'),
                _QcBadge(ok: !labelRusak, label: 'Label'),
                _QcBadge(ok: !segelRusak, label: 'Segel'),
              ],
            ),
          ),

          // Aslab + CCTV
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Icon(TablerIcons.user, size: 12, color: BGNColors.textHint),
                const SizedBox(width: 4),
                Text(aslab, style: const TextStyle(fontSize: 10, color: BGNColors.textHint)),
                const SizedBox(width: 16),
                const Icon(TablerIcons.video, size: 12, color: BGNColors.textHint),
                const SizedBox(width: 4),
                Expanded(child: Text(cctv, style: const TextStyle(fontSize: 10, color: BGNColors.textHint), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),

          // Foto
          if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(fotoUrl, height: 144, width: double.infinity,
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          ],

          // Tombol detail
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTapDetail,
                icon: const Icon(TablerIcons.file_description, size: 16),
                label: const Text('Lihat detail lengkap', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BGNColors.primary,
                  side: const BorderSide(color: BGNColors.primary),
                  backgroundColor: BGNColors.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoBox({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: valueColor ?? BGNColors.textPrimary,
          )),
        ],
      ),
    );
  }
}

class _QcBadge extends StatelessWidget {
  final bool ok;
  final String label;

  const _QcBadge({required this.ok, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? BGNColors.primaryLight : BGNColors.dangerLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? TablerIcons.circle_check : TablerIcons.alert_triangle,
              size: 12, color: ok ? BGNColors.primary : BGNColors.danger),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w500,
            color: ok ? BGNColors.primary : BGNColors.danger,
          )),
        ],
      ),
    );
  }
}
