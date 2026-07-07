import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/configs/routes.dart';
import 'package:bgn/distribusi/widgets/layout/animated_bottom_nav.dart';

class MainLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: navigationShell,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 8),
      child: AppBar(
        backgroundColor: BGNColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.activeRole.label,
              style: const TextStyle(
                fontSize: 11,
                color: BGNColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              auth.activeUser.name,
              style: const TextStyle(
                fontSize: 14,
                color: BGNColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              auth.activeUser.unit,
              style: const TextStyle(
                fontSize: 11,
                color: BGNColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Tidak'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Ya'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              if (!context.mounted) return;
              context.read<AuthProvider>().logout();
            },
            icon: const Icon(
              TablerIcons.logout,
              color: BGNColors.textSecondary,
              size: 16,
            ),
            label: const Text(
              'Logout',
              style: TextStyle(
                color: BGNColors.textSecondary,
                fontSize: 12,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: BGNColors.surfaceAlt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  static const _allNavItems = [
    AnimatedNavItem(path: '/',            icon: TablerIcons.home,          activeIcon: TablerIcons.home,             label: 'Beranda',  roles: ['kepala_sppg', 'asisten_lapangan', 'aslab', 'driver', 'pic_sekolah', 'superadmin', 'accounting', 'supplier', 'pm', 'masyarakat']),
    AnimatedNavItem(path: '/pengiriman',  icon: TablerIcons.package,        activeIcon: TablerIcons.package,           label: 'Kirim',    roles: ['kepala_sppg','asisten_lapangan', 'aslab', 'supplier', 'superadmin']),
    AnimatedNavItem(path: '/rute',        icon: TablerIcons.map,            activeIcon: TablerIcons.map,               label: 'Rute',     roles: ['asisten_lapangan', 'driver', 'superadmin']),
    AnimatedNavItem(path: '/tracking',    icon: TablerIcons.truck,          activeIcon: TablerIcons.truck,             label: 'Tracking', roles: ['kepala_sppg', 'asisten_lapangan', 'aslab', 'driver', 'pic_sekolah', 'superadmin', 'accounting', 'supplier', 'pm']),
    AnimatedNavItem(path: '/laporan',     icon: TablerIcons.chart_bar,      activeIcon: TablerIcons.chart_bar,         label: 'Laporan',  roles: ['kepala_sppg', 'pic_sekolah', 'accounting', 'superadmin', 'pm']),
    AnimatedNavItem(path: '/setting',    icon: TablerIcons.settings,        activeIcon: TablerIcons.settings,          label: 'Setting',  roles: ['kepala_sppg']),
  ];

  Widget _buildBottomNav(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentBranch = navigationShell.currentIndex;

    final visibleItems = _allNavItems
        .where((item) => item.roles.contains(auth.currentRole))
        .toList(growable: false);

    final currentPath = branchPaths[currentBranch];
    final visibleIndex = visibleItems.indexWhere((item) => item.path == currentPath);

    return AnimatedBottomNav(
      currentIndex: visibleIndex < 0 ? 0 : visibleIndex,
      items: visibleItems,
      onTap: (index) {
        final path = visibleItems[index].path;
        final branchIndex = branchPaths.indexOf(path);
        navigationShell.goBranch(branchIndex);
      },
    );
  }

}


