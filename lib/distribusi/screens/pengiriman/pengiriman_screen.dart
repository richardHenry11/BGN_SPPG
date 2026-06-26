// lib/screens/pengiriman/pengiriman_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/widgets/common/car_refresh_indicator.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_jadwal.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_packing.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_keluar.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_masuk.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_ringkasan.dart';

class PengirimanScreen extends StatefulWidget {
  const PengirimanScreen({super.key});

  @override
  State<PengirimanScreen> createState() => _PengirimanScreenState();
}

class _PengirimanScreenState extends State<PengirimanScreen> {
  String _activeTab = 'jadwal';
  int _refreshKey = 0;

  List<Map<String, dynamic>> _tabsForRole(String role) {
    final all = [
      {'id': 'jadwal',    'label': 'Jadwal',   'roles': ['kepala_sppg']},
      {'id': 'packing',   'label': 'Packing',  'roles': ['kepala_sppg', 'aslab']},
      {'id': 'keluar',    'label': 'Keluar',   'roles': ['kepala_sppg', 'aslab']},
      {'id': 'masuk',     'label': 'Masuk',    'roles': ['kepala_sppg', 'aslab']},
      {'id': 'ringkasan', 'label': 'Terima',   'roles': ['pic_sekolah', 'kepala_sppg']},
    ];
    return all
        .where((t) => (t['roles'] as List).contains(role))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tabs = _tabsForRole(auth.currentRole);

    // Reset tab jika role berubah dan tab aktif tidak tersedia
    if (!tabs.any((t) => t['id'] == _activeTab)) {
      _activeTab = tabs.first['id'] as String;
    }

    return Column(
      children: [

        // Tab bar — underline style (beda dengan pill filter di tab_jadwal)
        Container(
          decoration: BoxDecoration(
            color: BGNColors.white,
            border: const Border(bottom: BorderSide(color: BGNColors.border, width: 0.5)),
          ),
          padding: const EdgeInsets.only(left: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.asMap().entries.map((entry) {
                final tab     = entry.value;
                final isActive = _activeTab == tab['id'];

                return GestureDetector(
                  onTap: () => setState(() => _activeTab = tab['id'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? BGNColors.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? BGNColors.primary
                            : BGNColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Tab content
        Expanded(
          child: CarRefreshIndicator(
            onRefresh: () async {
              setState(() => _refreshKey++);
              await Future.delayed(const Duration(milliseconds: 1500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _buildTabContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'jadwal':
        return TabJadwal(key: ValueKey('jadwal_$_refreshKey'));
      case 'packing':
        return TabPacking(key: ValueKey('packing_$_refreshKey'));
      case 'keluar':
        return const TabKeluar();
      case 'masuk':
        return const TabMasuk();
      case 'ringkasan':
        return const TabRingkasan();
      default:
        return const SizedBox();
    }
  }
}