import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';

class DriverStatusCard extends StatelessWidget {
  final DriverModel driver;

  const DriverStatusCard({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final lewat = driver.checkpoint.where((c) => c.status == 'lewat').length;
    final totalCp = driver.checkpoint.length;
    final progress = totalCp > 0 ? lewat / totalCp : 0.0;
    final isDalam = driver.status == 'dalam_perjalanan';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                  color: BGNColors.primaryLight, shape: BoxShape.circle,
                ),
                child: const Icon(TablerIcons.user, color: BGNColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.nama, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: BGNColors.textPrimary,
                    )),
                    Text(driver.armada, style: const TextStyle(
                      fontSize: 12, color: BGNColors.textSecondary,
                    )),
                  ],
                ),
              ),
              _StatusBadge(isDalam: isDalam),
            ],
          ),
          const SizedBox(height: 16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tujuan sekarang', style: TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(driver.tujuanSekarang, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimasi tiba', style: TextStyle(fontSize: 10, color: BGNColors.primary)),
                      const SizedBox(height: 4),
                      Text(driver.eta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progress checkpoint', style: TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
              Text('$lewat/$totalCp', style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: BGNColors.border,
              valueColor: const AlwaysStoppedAnimation(BGNColors.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isDalam;
  const _StatusBadge({required this.isDalam});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDalam ? BGNColors.warningLight : BGNColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isDalam ? BGNColors.warning : BGNColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isDalam ? 'Dalam Perjalanan' : 'Standby',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500,
              color: isDalam ? BGNColors.warning : BGNColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
