import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bgn/distribusi/widgets/layout/main_layout.dart';
import 'package:bgn/distribusi/screens/dashboard/dashboard_screen.dart';
import 'package:bgn/distribusi/screens/pengiriman/pengiriman_screen.dart';
import 'package:bgn/distribusi/screens/rute/rute_screen.dart';
import 'package:bgn/distribusi/screens/tracking/tracking_screen.dart';
import 'package:bgn/distribusi/screens/validasi/validasi_screen.dart';
import 'package:bgn/distribusi/screens/laporan/laporan_screen.dart';
import 'package:bgn/distribusi/screens/login/login_screen.dart';
import 'package:bgn/distribusi/screens/produksi/rencana_produksi_screen.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final branchPaths = ['/', '/pengiriman', '/rute', '/tracking', '/laporan'];

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainLayout(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pengiriman',
                name: 'pengiriman',
                builder: (context, state) => const PengirimanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rute',
                name: 'rute',
                builder: (context, state) => const RuteScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tracking',
                name: 'tracking',
                builder: (context, state) => const TrackingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/laporan',
                name: 'laporan',
                builder: (context, state) => const LaporanScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/validasi',
        name: 'validasi',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            backgroundColor: BGNColors.primary,
            title: const Text('Validasi'),
            leading: IconButton(
              icon: const Icon(TablerIcons.arrow_left, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          body: const ValidasiScreen(),
        ),
      ),
      GoRoute(
        path: '/rencana-produksi',
        name: 'rencanaProduksi',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RencanaProduksiScreen(),
      ),
    ],
  );
}
