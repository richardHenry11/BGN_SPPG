// lib/screens/pengiriman/pengiriman_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_jadwal.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_packing.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_kirim.dart';
import 'package:bgn/distribusi/screens/pengiriman/tab_selesai.dart';

class PengirimanScreen extends StatefulWidget {
  const PengirimanScreen({super.key});

  @override
  State<PengirimanScreen> createState() => _PengirimanScreenState();
}

class _PengirimanScreenState extends State<PengirimanScreen> {
  String _activeTab = 'jadwal';

  List<Map<String, dynamic>> _tabsForRole(String role) {
    final all = [
      {'id': 'jadwal',    'label': 'Jadwal',   'roles': ['kepala_sppg', 'aslab', 'asisten_lapangan', 'superadmin']},
      {'id': 'packing',   'label': 'Cek Packing',  'roles': ['kepala_sppg', 'aslab', 'asisten_lapangan', 'superadmin']},
      {'id': 'keluar',    'label': 'Kirim',   'roles': ['kepala_sppg', 'aslab', 'asisten_lapangan', 'superadmin']},
      {'id': 'ringkasan', 'label': 'Selesai',  'roles': ['kepala_sppg', 'aslab', 'asisten_lapangan', 'pic_sekolah', 'superadmin']},
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        Container(
          decoration: BoxDecoration(
            color: BGNColors.surface,
            border: const Border(bottom: BorderSide(color: BGNColors.border, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: tabs.asMap().entries.map((entry) {
                    final tab = entry.value;
                    final isActive = _activeTab == tab['id'];

                    return GestureDetector(
                      onTap: () => setState(() => _activeTab = tab['id'] as String),
                      child: Container(
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
          ),
        ),

        // Tab content
        Expanded(
          child: _buildTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'jadwal':
        return const TabJadwal();
      case 'packing':
        return const TabPacking();
      case 'keluar':
        return const TabKirim();
      case 'ringkasan':
        return const TabSelesai();
      default:
        return const SizedBox();
    }
  }
}