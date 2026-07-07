// lib/screens/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';
import 'package:bgn/distribusi/providers/jadwal_provider.dart';
import 'package:bgn/distribusi/widgets/common/car_refresh_indicator.dart';
import 'package:bgn/distribusi/widgets/common/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isMasyarakat) return _MasyarakatDashboard();

    return CarRefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          context.read<DistribusiProvider>().refresh(),
          context.read<JadwalProvider>().refresh(),
        ]);
      },
      child: Consumer2<DistribusiProvider, JadwalProvider>(
        builder: (context, distribusi, jadwal, _) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Stat cards
          Wrap(
            runSpacing: 12,
            spacing: 12,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 44) / 2,
                child: StatCard(
                  label: 'Pengiriman hari ini',
                  value: '${distribusi.statHarian['totalPengiriman']}',
                  icon: TablerIcons.truck,
                  color: BGNColors.primary,
                  bgColor: BGNColors.primaryLight,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 44) / 2,
                child: StatCard(
                  label: 'Tepat waktu',
                  value: '${distribusi.statHarian['tepatWaktu']}',
                  icon: TablerIcons.clock,
                  color: BGNColors.success,
                  bgColor: BGNColors.successLight,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 44) / 2,
                child: StatCard(
                  label: 'Tepat sasaran',
                  value: '${distribusi.statHarian['tepatSasaran']}%',
                  icon: TablerIcons.current_location,
                  color: BGNColors.primary,
                  bgColor: BGNColors.primaryLight,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 44) / 2,
                child: StatCard(
                  label: 'Komplain masuk',
                  value: '${distribusi.statHarian['komplain']}',
                  icon: TablerIcons.message,
                  color: BGNColors.danger,
                  bgColor: BGNColors.dangerLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status pengiriman
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BGNColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BGNColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status pengiriman hari ini',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Progress bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progress pengiriman',
                      style: TextStyle(
                        fontSize: 11,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${jadwal.totalSelesai}/${jadwal.jadwalList.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: jadwal.jadwalList.isEmpty
                        ? 0
                        : jadwal.totalSelesai / jadwal.jadwalList.length,
                    backgroundColor: BGNColors.border,
                    valueColor: const AlwaysStoppedAnimation(BGNColors.primary),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${((jadwal.totalSelesai / jadwal.jadwalList.length) * 100).toStringAsFixed(0)}% selesai',
                  style: const TextStyle(
                    fontSize: 11,
                    color: BGNColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 16),

                // Status breakdown
                Row(
                  children: [
                    _StatusChip(
                      label: 'Selesai',
                      count: jadwal.totalSelesai,
                      color: BGNColors.primary,
                      bgColor: BGNColors.primaryLight,
                      icon: TablerIcons.circle_check,
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: 'Berjalan',
                      count: jadwal.totalDalamPerjalanan,
                      color: BGNColors.warning,
                      bgColor: BGNColors.warningLight,
                      icon: TablerIcons.truck,
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: 'Belum',
                      count: jadwal.totalBelumBerangkat,
                      color: BGNColors.textSecondary,
                      bgColor: BGNColors.background,
                      icon: TablerIcons.clock,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Aktivitas terbaru
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BGNColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BGNColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktivitas terbaru',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...distribusi.aktivitasTerbaru.map(
                  (item) => _AktivitasItem(item: item),
                ),
              ],
            ),
          ),

        ],
      ),
    ),
    ),
  );
  }
}

// ── Widget helpers ─────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AktivitasItem extends StatelessWidget {
  final AktivitasModel item;

  const _AktivitasItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final config = _tipeConfig(item.tipe);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: config['bgColor'] as Color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              config['icon'] as IconData,
              color: config['color'] as Color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.pesan,
              style: const TextStyle(
                fontSize: 12,
                color: BGNColors.textPrimary,
              ),
            ),
          ),
          Text(
            item.waktu,
            style: const TextStyle(
              fontSize: 10,
              color: BGNColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _tipeConfig(String tipe) {
    switch (tipe) {
      case 'sukses':
        return {
          'icon': TablerIcons.circle_check,
          'color': BGNColors.primary,
          'bgColor': BGNColors.primaryLight,
        };
      case 'proses':
        return {
          'icon': TablerIcons.truck,
          'color': BGNColors.warning,
          'bgColor': BGNColors.warningLight,
        };
      case 'warning':
        return {
          'icon': TablerIcons.alert_triangle,
          'color': BGNColors.danger,
          'bgColor': BGNColors.dangerLight,
        };
      default:
        return {
          'icon': TablerIcons.info_circle,
          'color': BGNColors.textSecondary,
          'bgColor': BGNColors.background,
        };
    }
  }
}

// ── Masyarakat Dashboard ───────────────────────────────────

class _MasyarakatDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: BGNColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              TablerIcons.heart_handshake,
              color: BGNColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            auth.activeUser.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: BGNColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            auth.activeUser.unit,
            style: const TextStyle(
              fontSize: 13,
              color: BGNColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beri Ulasan Penerimaan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sampaikan pendapat Anda tentang kualitas makanan yang diterima',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/ulasan'),
                    icon: const Icon(TablerIcons.edit, size: 18),
                    label: const Text('Beri Ulasan Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BGNColors.surface,
                      foregroundColor: const Color(0xFF1A73E8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BGNColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BGNColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: TablerIcons.clock,
                  text: 'Pengiriman hari ini: 12 sekolah',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: TablerIcons.truck,
                  text: 'Armada beroperasi: 4 unit',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: TablerIcons.school,
                  text: 'Total penerima: 2.400 porsi',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: BGNColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: BGNColors.textSecondary,
          ),
        ),
      ],
    );
  }
}