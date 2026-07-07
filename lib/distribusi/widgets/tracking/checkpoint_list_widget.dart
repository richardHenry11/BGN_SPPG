import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';

class CheckpointListWidget extends StatelessWidget {
  final List<CheckpointModel> checkpoints;

  const CheckpointListWidget({super.key, required this.checkpoints});

  @override
  Widget build(BuildContext context) {
    if (checkpoints.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Checkpoint perjalanan', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary,
          )),
          const SizedBox(height: 12),
          ...List.generate(checkpoints.length, (i) {
            final cp = checkpoints[i];
            final isLast = i == checkpoints.length - 1;
            return _CheckpointRow(cp: cp, isLast: isLast);
          }),
        ],
      ),
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  final CheckpointModel cp;
  final bool isLast;

  const _CheckpointRow({required this.cp, required this.isLast});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color, bgColor;
    String label;
    switch (cp.status) {
      case 'lewat':
        icon = TablerIcons.circle_check;
        color = BGNColors.primary;
        bgColor = BGNColors.primaryLight;
        label = 'Sudah dilalui';
        break;
      case 'menuju':
        icon = TablerIcons.navigation;
        color = BGNColors.warning;
        bgColor = BGNColors.warningLight;
        label = 'Sedang menuju';
        break;
      default:
        icon = TablerIcons.circle;
        color = BGNColors.textSecondary;
        bgColor = BGNColors.background;
        label = 'Belum dilalui';
    }

    Color waktuColor;
    switch (cp.status) {
      case 'lewat':
        waktuColor = BGNColors.primary;
        break;
      case 'menuju':
        waktuColor = BGNColors.warning;
        break;
      default:
        waktuColor = BGNColors.textSecondary;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Container(
                  width: 1.5,
                  height: 28,
                  color: cp.status == 'lewat' ? BGNColors.primaryLight : BGNColors.border,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cp.lokasi, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: cp.status == 'belum' ? BGNColors.textSecondary : BGNColors.textPrimary,
                      )),
                      Text(label, style: TextStyle(fontSize: 10, color: color)),
                    ],
                  ),
                  Text(cp.waktu, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: waktuColor,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
