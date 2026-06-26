import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';

class KomplainCard extends StatelessWidget {
  final dynamic komplain;

  const KomplainCard({super.key, required this.komplain});

  @override
  Widget build(BuildContext context) {
    final isBelumDitangani = komplain.status == 'belum_ditangani';
    final config = isBelumDitangani
        ? _StatusConfig(
            label: 'Belum ditangani',
            icon: TablerIcons.alert_circle,
            color: BGNColors.danger,
            bg: BGNColors.dangerLight,
          )
        : _StatusConfig(
            label: 'Ditangani',
            icon: TablerIcons.circle_check,
            color: BGNColors.primary,
            bg: BGNColors.primaryLight,
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: config.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(config.icon, size: 16, color: config.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(komplain.lokasi,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
                          Text(komplain.waktu,
                              style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: config.bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        config.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: config.color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(TablerIcons.message_circle, size: 14, color: BGNColors.textHint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(komplain.pesan,
                          style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                if (isBelumDitangani)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.read<DistribusiProvider>().tanganiKomplain(komplain.id);
                      },
                      icon: const Icon(TablerIcons.check, size: 16),
                      label: const Text('Tangani', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BGNColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (isBelumDitangani) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(TablerIcons.eye, size: 16),
                    label: const Text('Detail', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BGNColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: BGNColors.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusConfig {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatusConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });
}
