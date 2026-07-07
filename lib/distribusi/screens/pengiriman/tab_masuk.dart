// lib/screens/pengiriman/tab_masuk.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/pengiriman_provider.dart';

class TabMasuk extends StatefulWidget {
  const TabMasuk({super.key});

  @override
  State<TabMasuk> createState() => _TabMasukState();
}

class _TabMasukState extends State<TabMasuk> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PengirimanProvider>();
    final belumMasuk = provider.pengirimanList
        .where((p) => p.validasiKeluar != null && p.validasiMasuk == null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Validasi barang masuk',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: BGNColors.textPrimary)),
        const SizedBox(height: 12),

        if (belumMasuk.isEmpty)
          _emptyState('Semua barang sudah diterima')
        else
          ...belumMasuk.map((item) {
            final isSelected = _selectedId == item.id;
            return GestureDetector(
              onTap: () => setState(() =>
                  _selectedId = isSelected ? null : item.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? BGNColors.primaryLight
                      : BGNColors.surface,
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
                          Text(
                              'Keluar: ${item.validasiKeluar?.jumlah ?? '-'} porsi · ${item.waktu}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: BGNColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(TablerIcons.chevron_right,
                        size: 16,
                        color: isSelected
                            ? BGNColors.primary
                            : BGNColors.border),
                  ],
                ),
              ),
            );
          }),

        if (_selectedId != null) ...[
          const SizedBox(height: 12),
          _FormValidasiMasuk(
            pengirimanId: _selectedId!,
            onBerhasil: () => setState(() => _selectedId = null),
          ),
        ],
      ],
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(TablerIcons.circle_check,
                size: 36, color: BGNColors.primaryLight),
            const SizedBox(height: 8),
            Text(msg,
                style: const TextStyle(
                    fontSize: 12, color: BGNColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _FormValidasiMasuk extends StatefulWidget {
  final int pengirimanId;
  final VoidCallback onBerhasil;
  const _FormValidasiMasuk(
      {required this.pengirimanId, required this.onBerhasil});

  @override
  State<_FormValidasiMasuk> createState() => _FormValidasiMasukState();
}

class _FormValidasiMasukState extends State<_FormValidasiMasuk> {
  final _jumlahCtrl  = TextEditingController();
  final _petugasCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  String _kondisi    = 'baik';
  String _errorMsg   = '';

  final _kondisiList = [
    {'id': 'baik',  'label': 'Baik',  'icon': TablerIcons.circle_check},
    {'id': 'cukup', 'label': 'Cukup', 'icon': TablerIcons.alert_circle},
    {'id': 'rusak', 'label': 'Rusak', 'icon': TablerIcons.circle_x},
  ];

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _petugasCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  void _handleKonfirmasi() {
    final jumlah = int.tryParse(_jumlahCtrl.text);
    if (jumlah == null) {
      setState(() => _errorMsg = 'Jumlah barang masuk wajib diisi');
      return;
    }
    if (_petugasCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Nama petugas wajib diisi');
      return;
    }
    context.read<PengirimanProvider>().inputValidasiMasuk(
          widget.pengirimanId,
          ValidasiData(
            jumlah: jumlah,
            kondisi: _kondisi,
            catatan: _catatanCtrl.text,
            petugas: _petugasCtrl.text,
            timestamp: TimeOfDay.now().format(context),
          ),
        );
    widget.onBerhasil();
  }

  @override
  Widget build(BuildContext context) {
    final pengiriman = context
        .read<PengirimanProvider>()
        .getPengirimanById(widget.pengirimanId);
    if (pengiriman == null) return const SizedBox();

    final jumlahInput = int.tryParse(_jumlahCtrl.text);
    final jumlahKeluar = pengiriman.validasiKeluar?.jumlah ?? 0;
    final selisihRealtime =
        jumlahInput != null ? jumlahInput - jumlahKeluar : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BGNColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(pengiriman.alamat,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: BGNColors.primary)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: BGNColors.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(pengiriman.waktu,
                          style: const TextStyle(
                              fontSize: 10, color: BGNColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MiniStat('Rencana',
                        '${pengiriman.porsiRencana}', BGNColors.textSecondary),
                    const SizedBox(width: 8),
                    _MiniStat('Keluar', '$jumlahKeluar', BGNColors.primary),
                    const SizedBox(width: 8),
                    _MiniStat(
                        'Masuk',
                        jumlahInput != null ? '$jumlahInput' : '-',
                        BGNColors.warning),
                  ],
                ),
                if (selisihRealtime != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selisihRealtime == 0
                          ? BGNColors.primaryLight
                          : BGNColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selisihRealtime == 0
                              ? TablerIcons.circle_check
                              : TablerIcons.alert_triangle,
                          size: 14,
                          color: selisihRealtime == 0
                              ? BGNColors.primary
                              : BGNColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          selisihRealtime == 0
                              ? 'Jumlah sesuai dengan barang keluar'
                              : 'Selisih ${selisihRealtime.abs()} porsi dari barang keluar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: selisihRealtime == 0
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
          const SizedBox(height: 14),

          // Title
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: BGNColors.warningLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(TablerIcons.arrow_down,
                    size: 14, color: BGNColors.warning),
              ),
              const SizedBox(width: 8),
              const Text('Validasi barang masuk',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BGNColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),

          // Jumlah
          const Text('Jumlah barang diterima (porsi)',
              style:
                  TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: _jumlahCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Keluar: $jumlahKeluar',
              hintStyle: const TextStyle(
                  fontSize: 12, color: BGNColors.textHint),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: BGNColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: BGNColors.border)),
            ),
          ),
          const SizedBox(height: 12),

          // Kondisi
          const Text('Kondisi barang diterima',
              style:
                  TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: _kondisiList.map((k) {
              final isActive = _kondisi == k['id'];
              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _kondisi = k['id'] as String),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: k == _kondisiList.last ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? BGNColors.primaryLight
                          : BGNColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? BGNColors.primary
                            : BGNColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(k['icon'] as IconData,
                            size: 18,
                            color: isActive
                                ? BGNColors.primary
                                : BGNColors.textSecondary),
                        const SizedBox(height: 2),
                        Text(k['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive
                                  ? BGNColors.primary
                                  : BGNColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Petugas
          const Text('Nama petugas',
              style:
                  TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: _petugasCtrl,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Nama aslab / pengantar',
              hintStyle: const TextStyle(
                  fontSize: 12, color: BGNColors.textHint),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: BGNColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: BGNColors.border)),
            ),
          ),
          const SizedBox(height: 12),

          // Catatan
          const Text('Catatan (opsional)',
              style:
                  TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: _catatanCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Tambahkan catatan jika ada...',
              hintStyle: const TextStyle(
                  fontSize: 12, color: BGNColors.textHint),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: BGNColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: BGNColors.border)),
            ),
          ),

          if (_errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(TablerIcons.alert_circle,
                      size: 14, color: BGNColors.danger),
                  const SizedBox(width: 4),
                  Text(_errorMsg,
                      style: const TextStyle(
                          fontSize: 11, color: BGNColors.danger)),
                ],
              ),
            ),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleKonfirmasi,
              icon: const Icon(TablerIcons.arrow_down, size: 16),
              label: const Text('Konfirmasi barang masuk'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BGNColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: BGNColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }
}