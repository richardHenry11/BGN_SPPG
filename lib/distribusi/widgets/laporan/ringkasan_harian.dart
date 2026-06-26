import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/distribusi_provider.dart';
import 'package:bgn/distribusi/providers/jadwal_provider.dart';

class RingkasanHarian extends StatelessWidget {
  const RingkasanHarian({super.key});

  @override
  Widget build(BuildContext context) {
    final distribusi = context.watch<DistribusiProvider>();
    final jadwal = context.watch<JadwalProvider>();
    final stats = distribusi.statHarian;
    final totalPorsi = jadwal.totalPorsi;

    return Column(
      children: [
        _StatGrid(stats: stats),
        const SizedBox(height: 12),
        _ArmadaProgress(),
        const SizedBox(height: 12),
        _KategoriDistribution(totalPorsi: totalPorsi),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        value: '${stats['totalPengiriman']}',
        label: 'Total pengiriman',
        icon: TablerIcons.truck,
        color: BGNColors.primary,
        bgColor: BGNColors.primaryLight,
      ),
      _StatItem(
        value: '${stats['tepatWaktu']}',
        label: 'Tepat waktu',
        icon: TablerIcons.clock,
        color: BGNColors.success,
        bgColor: BGNColors.successLight,
      ),
      _StatItem(
        value: '${stats['tepatSasaran']}%',
        label: 'Tepat sasaran',
        icon: TablerIcons.target,
        color: BGNColors.primary,
        bgColor: BGNColors.primaryLight,
      ),
      _StatItem(
        value: '${stats['komplain']}',
        label: 'Komplain masuk',
        icon: TablerIcons.message_circle,
        color: BGNColors.danger,
        bgColor: BGNColors.dangerLight,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: BGNColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: BGNColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Armada Progress ───────────────────────────────────────

class _ArmadaProgress extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final armadaList = [
      _ArmadaData(nama: 'BGN-01 (Driver 01)', selesai: 2, total: 3),
      _ArmadaData(nama: 'BGN-02 (Driver 02)', selesai: 0, total: 2),
      _ArmadaData(nama: 'BGN-03 (Driver 03)', selesai: 0, total: 2),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengiriman per armada',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ...armadaList.map((armada) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(TablerIcons.truck, size: 14, color: BGNColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(armada.nama,
                                style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
                          ],
                        ),
                        Text('${armada.selesai}/${armada.total}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: armada.total > 0 ? armada.selesai / armada.total : 0,
                        backgroundColor: BGNColors.border,
                        valueColor: const AlwaysStoppedAnimation(BGNColors.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${armada.total > 0 ? ((armada.selesai / armada.total) * 100).round() : 0}% selesai',
                      style: const TextStyle(fontSize: 10, color: BGNColors.textHint),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ArmadaData {
  final String nama;
  final int selesai;
  final int total;

  const _ArmadaData({required this.nama, required this.selesai, required this.total});
}

// ── Kategori Distribution ─────────────────────────────────

class _KategoriDistribution extends StatelessWidget {
  final int totalPorsi;

  const _KategoriDistribution({required this.totalPorsi});

  @override
  Widget build(BuildContext context) {
    final kategoriList = [
      _KategoriData(nama: 'Peserta Didik', porsi: 470, color: BGNColors.primary),
      _KategoriData(nama: 'Balita', porsi: 75, color: BGNColors.success),
      _KategoriData(nama: 'Ibu Hamil', porsi: 45, color: BGNColors.warning),
      _KategoriData(nama: 'Ibu Menyusui', porsi: 60, color: BGNColors.danger),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribusi porsi per kategori',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ...kategoriList.map((k) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(k.nama,
                            style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
                        Text('${k.porsi} porsi',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: k.color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: totalPorsi > 0 ? k.porsi / totalPorsi : 0,
                        backgroundColor: BGNColors.border,
                        valueColor: AlwaysStoppedAnimation(k.color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _KategoriData {
  final String nama;
  final int porsi;
  final Color color;

  const _KategoriData({required this.nama, required this.porsi, required this.color});
}
