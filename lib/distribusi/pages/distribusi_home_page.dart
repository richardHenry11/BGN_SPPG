import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/screens/dashboard/dashboard_screen.dart';
import 'package:bgn/distribusi/screens/pengiriman/pengiriman_screen.dart';
import 'package:bgn/distribusi/screens/tracking/tracking_screen.dart';
import 'package:bgn/login.dart' as bgn;
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:provider/provider.dart';

class DistribusiHomePage extends StatefulWidget {
  const DistribusiHomePage({super.key});

  @override
  State<DistribusiHomePage> createState() => _DistribusiHomePageState();
}

class _DistribusiHomePageState extends State<DistribusiHomePage> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    PengirimanScreen(),
    TrackingScreen(),
  ];

  static const _navItems = <_NavItem>[
    _NavItem(icon: TablerIcons.home, label: 'Beranda'),
    _NavItem(icon: TablerIcons.package, label: 'Kirim'),
    _NavItem(icon: TablerIcons.truck, label: 'Tracking'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: BGNColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: AppBar(
          backgroundColor: BGNColors.primary,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.activeRole.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFBFDBFE),
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                auth.activeUser.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                auth.activeUser.unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFBFDBFE),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const bgn.MyHomePageMyWidget(),
                  ),
                );
              },
              icon: const Icon(TablerIcons.logout, color: Colors.white, size: 16),
              label: const Text(
                'Logout',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: BGNColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: List.generate(_navItems.length, (i) {
            final isActive = i == _currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _navItems[i].icon,
                        size: 22,
                        color: isActive
                            ? BGNColors.primary
                            : BGNColors.textSecondary,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _navItems[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w500 : FontWeight.normal,
                          color: isActive
                              ? BGNColors.primary
                              : BGNColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
