import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';

class DriverChips extends StatelessWidget {
  final List<DriverModel> drivers;
  final int activeId;
  final ValueChanged<int> onChanged;

  const DriverChips({
    super.key,
    required this.drivers,
    required this.activeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: drivers.map((d) {
          final active = activeId == d.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(d.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? BGNColors.primary : BGNColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? BGNColors.primary : BGNColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(TablerIcons.truck, size: 14,
                        color: active ? Colors.white : BGNColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(d.armada, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: active ? Colors.white : BGNColors.textSecondary,
                    )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
