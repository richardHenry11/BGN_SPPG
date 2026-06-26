// lib/screens/pengiriman/tab_ringkasan.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/pengiriman_provider.dart';

class TabRingkasan extends StatefulWidget {
  const TabRingkasan({super.key});

  @override
  State<TabRingkasan> createState() => _TabRingkasanState();
}

class _TabRingkasanState extends State<TabRingkasan> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PengirimanProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status penerimaan',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: BGNColors.textPrimary)),
        const SizedBox(height: 12),

        ...provider.pengirimanList.map((item) {
          final isSelected = _selectedId == item.id;
          final badge = _statusConfig(item.status);
          return GestureDetector(
            onTap: () => setState(
                () => _selectedId = isSelected ? null : item.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected ? BGNColors.primaryLight : BGNColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? BGNColors.primary
                      : BGNColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.alamat,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: BGNColors.textPrimary)),
                        Text('${item.penerima} · ${item.waktu}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: BGNColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badge['bg'] as Color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(badge['label'] as String,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: badge['color'] as Color)),
                  ),
                ],
              ),
            ),
          );
        }),

        if (_selectedId != null) ...[
          const SizedBox(height: 12),
          _RingkasanDetail(pengirimanId: _selectedId!),
        ],
      ],
    );
  }

  Map<String, dynamic> _statusConfig(String status) {
    switch (status) {
      case 'selesai':
        return {'label': 'Selesai', 'color': BGNColors.primary, 'bg': BGNColors.primaryLight};
      case 'dalam_perjalanan':
        return {'label': 'Dalam Perjalanan', 'color': BGNColors.warning, 'bg': BGNColors.warningLight};
      default:
        return {'label': 'Belum Berangkat', 'color': BGNColors.textSecondary, 'bg': BGNColors.background};
    }
  }
}

class _RingkasanDetail extends StatelessWidget {
  final int pengirimanId;
  const _RingkasanDetail({required this.pengirimanId});

  @override
  Widget build(BuildContext context) {
    final pengiriman = context
        .read<PengirimanProvider>()
        .getPengirimanById(pengirimanId);
    if (pengiriman == null) return const SizedBox();

    final selisih = pengiriman.selisih ?? 0;
    final sudahMasuk = pengiriman.validasiMasuk != null;

    // Status config
    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    String statusLabel;
    String statusDesc;

    if (!sudahMasuk) {
      statusColor = BGNColors.textSecondary;
      statusBg = BGNColors.background;
      statusIcon = TablerIcons.clock;
      statusLabel = 'Menunggu penerimaan';
      statusDesc = 'Barang belum diterima di lokasi';
    } else if (selisih == 0) {
      statusColor = BGNColors.primary;
      statusBg = BGNColors.primaryLight;
      statusIcon = TablerIcons.circle_check;
      statusLabel = 'Penerimaan sesuai';
      statusDesc = 'Jumlah barang diterima sesuai rencana';
    } else {
      statusColor = BGNColors.warning;
      statusBg = BGNColors.warningLight;
      statusIcon = TablerIcons.alert_triangle;
      statusLabel = 'Ada selisih penerimaan';
      statusDesc = 'Terdapat selisih ${selisih.abs()} porsi';
    }

    return Column(
      children: [
        // Status banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: statusColor)),
                  Text(statusDesc,
                      style: TextStyle(
                          fontSize: 11,
                          color: statusColor.withOpacity(0.7))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Ringkasan angka
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BGNColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BGNColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ringkasan penerimaan',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BGNColors.textPrimary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatBox('Rencana',
                      '${pengiriman.porsiRencana}', BGNColors.textSecondary,
                      BGNColors.background),
                  const SizedBox(width: 8),
                  _StatBox('Dikirim',
                      '${pengiriman.validasiKeluar?.jumlah ?? '-'}',
                      BGNColors.primary, BGNColors.primaryLight),
                  const SizedBox(width: 8),
                  _StatBox(
                    'Diterima',
                    '${pengiriman.validasiMasuk?.jumlah ?? '-'}',
                    selisih == 0 ? BGNColors.primary : BGNColors.warning,
                    selisih == 0 ? BGNColors.primaryLight : BGNColors.warningLight,
                  ),
                ],
              ),
              if (pengiriman.selisih != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selisih == 0
                        ? BGNColors.primaryLight
                        : BGNColors.warningLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            selisih == 0
                                ? TablerIcons.circle_check
                                : TablerIcons.alert_triangle,
                            size: 14,
                            color: selisih == 0
                                ? BGNColors.primary
                                : BGNColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selisih == 0 ? 'Tidak ada selisih' : 'Ada selisih',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selisih == 0
                                  ? BGNColors.primary
                                  : BGNColors.warning,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${selisih > 0 ? '+' : ''}$selisih porsi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selisih == 0
                              ? BGNColors.primary
                              : BGNColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Detail info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BGNColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BGNColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detail pengiriman',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BGNColors.textPrimary)),
              const SizedBox(height: 10),
              _DetailRow(TablerIcons.map_pin,  'Lokasi',    pengiriman.alamat),
              _DetailRow(TablerIcons.clock,    'Waktu kirim', pengiriman.waktu),
              _DetailRow(TablerIcons.package,  'Pengantar', pengiriman.pengantar),
              _DetailRow(TablerIcons.user,     'Penerima',  pengiriman.penerima),
              _DetailRow(TablerIcons.box,      'Kondisi',
                  pengiriman.validasiMasuk?.kondisi ?? '-',
                  isLast: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatBox(this.label, this.value, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: BGNColors.textSecondary)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: color)),
            Text('porsi',
                style: const TextStyle(
                    fontSize: 9, color: BGNColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _DetailRow(this.icon, this.label, this.value,
      {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: BGNColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: BGNColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: BGNColors.textSecondary)),
            ],
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: BGNColors.textPrimary)),
        ],
      ),
    );
  }
}