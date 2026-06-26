// lib/widgets/layout/role_switcher.dart

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';

class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BGNColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Ganti Role',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: BGNColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih role yang ingin digunakan',
            style: TextStyle(
              fontSize: 12,
              color: BGNColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Role list
          ...auth.roles.map((role) {
            final isActive = auth.currentRole == role.id;
            return GestureDetector(
              onTap: () {
                auth.switchRole(role.id);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? BGNColors.primaryLight
                      : BGNColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? BGNColors.primary
                        : BGNColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isActive
                            ? BGNColors.primary
                            : BGNColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        role.icon,
                        color: isActive
                            ? Colors.white
                            : BGNColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isActive
                                  ? BGNColors.primary
                                  : BGNColors.textPrimary,
                            ),
                          ),
                          Text(
                            role.description,
                            style: const TextStyle(
                              fontSize: 11,
                              color: BGNColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      const Icon(
                        TablerIcons.circle_check,
                        color: BGNColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}