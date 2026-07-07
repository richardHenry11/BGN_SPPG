import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/widgets/layout/main_layout.dart';
import 'package:bgn/distribusi/screens/dashboard/dashboard_screen.dart';
import 'package:bgn/distribusi/screens/pengiriman/pengiriman_screen.dart';
import 'package:bgn/distribusi/screens/rute/rute_screen.dart';
import 'package:bgn/distribusi/screens/tracking/tracking_screen.dart';
import 'package:bgn/distribusi/screens/validasi/validasi_screen.dart';
import 'package:bgn/distribusi/screens/laporan/laporan_screen.dart';
import 'package:bgn/distribusi/screens/setting/setting_screen.dart';
import 'package:bgn/distribusi/screens/login/login_screen.dart';
import 'package:bgn/distribusi/screens/ulasan/ulasan_penerimaan_screen.dart';
import 'package:bgn/distribusi/screens/produksi/rencana_produksi_screen.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/pilih_menu.dart';
import 'package:bgn/main_page.dart';
import 'package:bgn/dashboard_supp.dart';
import 'package:bgn/planning/planning_page.dart';
import 'package:bgn/login.dart' as legacy;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final branchPaths = ['/', '/pengiriman', '/rute', '/tracking', '/laporan', '/setting'];

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login-legacy',
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      final loggedIn = auth.isLoggedIn;
      final onLogin = state.matchedLocation == '/login';
      final onLoginLegacy = state.matchedLocation == '/login-legacy';

      if (loggedIn && onLogin) return '/';
      if (loggedIn && onLoginLegacy) {
        final role = auth.currentRole;
        if (role == 'kepala_sppg' || role == 'aslab' || role == 'asisten_lapangan') {
          return '/pilih-menu';
        }
        if (role == 'supplier') return '/supplier-dashboard';
        return '/procurement';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/login-legacy',
        name: 'loginLegacy',
        builder: (context, state) => const legacy.MyHomePageMyWidget(),
      ),
      GoRoute(
        path: '/pilih-menu',
        name: 'pilihMenu',
        builder: (context, state) => const PilihMenuPage(),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/setting',
                name: 'setting',
                builder: (context, state) => const SettingScreen(),
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
        path: '/ulasan',
        name: 'ulasan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UlasanPenerimaanScreen(),
      ),
      GoRoute(
        path: '/rencana-produksi',
        name: 'rencanaProduksi',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RencanaProduksiScreen(),
      ),
      GoRoute(
        path: '/procurement',
        name: 'procurement',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MainPage(),
      ),
      GoRoute(
        path: '/planning',
        name: 'planning',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PlanningPage(),
      ),
      GoRoute(
        path: '/supplier-dashboard',
        name: 'supplierDashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DashboardSuppPage(),
      ),
    ],
  );
}
