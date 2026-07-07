// lib/screens/pengiriman/tab_selesai.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/widgets/common/foto_bukti_widget.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';

class TabSelesai extends StatefulWidget {
  const TabSelesai({super.key});

  @override
  State<TabSelesai> createState() => _TabSelesaiState();
}

class _TabSelesaiState extends State<TabSelesai> {
  final PackagingService _packagingService = PackagingService(ApiClient());
  List<dynamic> _list = [];
  bool _loading = false;
  String? _error;
  int? _expandedId;
  String _filterStatus = 'semua';

  List<dynamic>? _cachedFilteredList;
  String _cachedFilterStatus = 'semua';

  static const List<Map<String, String>> _filterOptions = [
    {'value': 'semua',    'label': 'Semua'    },
    {'value': 'Dikirim',  'label': 'Dikirim'  },
    {'value': 'Selesai',  'label': 'Selesai'  },
  ];

  List<dynamic> get _filteredList {
    if (_cachedFilterStatus == _filterStatus && _cachedFilteredList != null) {
      return _cachedFilteredList!;
    }
    _cachedFilterStatus = _filterStatus;
    _cachedFilteredList = _filterStatus == 'semua'
        ? _list
        : _list.where((i) => i['delivery_status'] == _filterStatus).toList(growable: false);
    return _cachedFilteredList!;
  }

  void _invalidateFilterCache() => _cachedFilteredList = null;

  Map<String, String> _authHeaders(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final h = <String, String>{
      'X-User-Role': auth.apiRole,
    };
    if (auth.token != null) h['Authorization'] = 'Bearer ${auth.token}';
    if (auth.sppgId != null) h['X-User-Sppg-Id'] = auth.sppgId.toString();
    return h;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchList();
    });
  }

  Future<void> _fetchList() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _packagingService.getList(headers: _authHeaders(context));
      if (!mounted) return;
      setState(() {
        _list = data.where((p) => p['id'] != null).toList();
        _invalidateFilterCache();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleSelesai(int id) {
    setState(() {
      final idx = _list.indexWhere((p) => (p['id'] as num?)?.toInt() == id);
      if (idx >= 0) {
        _list[idx]['delivery_status'] = 'Selesai';
      }
      _expandedId = null;
      _invalidateFilterCache();
    });
  }

  void _setFilter(String value) {
    setState(() => _filterStatus = value);
  }

  void _toggleExpanded(int id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError();
    }
    if (_filteredList.isEmpty) {
      return _emptyState('Tidak ada pengiriman dengan status ini');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredList.length + 2,
      itemBuilder: (_, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Konfirmasi penyelesaian pengiriman',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BGNColors.textPrimary)),
          );
        }
        if (i == 1) {
          return _buildFilterChips();
        }
        final item = _filteredList[i - 2];
        final id = (item['id'] as num?)?.toInt() ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: RepaintBoundary(
            child: _SelesaiCard(
              key: ValueKey(id),
              item: item,
              id: id,
              isExpanded: _expandedId == id,
              packagingService: _packagingService,
              onToggle: _toggleExpanded,
              onSelesai: _handleSelesai,
              onBatal: () => _toggleExpanded(id),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterOptions.map((f) {
          final isActive = _filterStatus == f['value'];
          return GestureDetector(
            onTap: () => _setFilter(f['value']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? BGNColors.primary : BGNColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? BGNColors.primary : BGNColors.border,
                ),
              ),
              child: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? BGNColors.white : BGNColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text('Gagal memuat data — tarik layar untuk memuat ulang',
          style: TextStyle(fontSize: 12, color: BGNColors.danger)),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(TablerIcons.circle_check, size: 36, color: BGNColors.primaryLight),
            const SizedBox(height: 8),
            Text(msg, style: const TextStyle(fontSize: 12, color: BGNColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SelesaiCard
// ═══════════════════════════════════════════════════════════

class _SelesaiCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int id;
  final bool isExpanded;
  final PackagingService packagingService;
  final ValueSetter<int> onToggle;
  final void Function(int id) onSelesai;
  final VoidCallback onBatal;

  const _SelesaiCard({
    super.key,
    required this.item,
    required this.id,
    required this.isExpanded,
    required this.packagingService,
    required this.onToggle,
    required this.onSelesai,
    required this.onBatal,
  });

  @override
  Widget build(BuildContext context) {
    final lokasi = item['beneficiary_name'] as String? ??
        item['delivery_route'] as String? ?? '';
    final menu = item['menu_name'] as String? ?? '';
    final target = (item['target_portions'] as num?)?.toInt() ?? 0;
    final status = item['delivery_status'] as String? ?? 'Menunggu';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? BGNColors.primary.withOpacity(0.3) : BGNColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => onToggle(id),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lokasi.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(lokasi,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        Text(menu,
                            style: TextStyle(
                                fontSize: lokasi.isNotEmpty ? 10 : 12,
                                fontWeight: lokasi.isNotEmpty ? FontWeight.normal : FontWeight.w500,
                                color: lokasi.isNotEmpty ? BGNColors.textHint : BGNColors.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('$target porsi', style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status == 'Menunggu' ? BGNColors.background
                          : status == 'Dikirim' ? BGNColors.warningLight
                          : BGNColors.primaryLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w500,
                            color: status == 'Menunggu' ? BGNColors.textSecondary
                                : status == 'Dikirim' ? BGNColors.warning
                                : BGNColors.primary)),
                  ),
                  const SizedBox(width: 6),
                  Transform.rotate(
                    angle: isExpanded ? math.pi : 0,
                    child: const Icon(TablerIcons.chevron_down, size: 16, color: BGNColors.textHint),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, color: BGNColors.border),
                      _FormSelesai(
                        pengirimanId: id,
                        pengirimanData: item,
                        packagingService: packagingService,
                        onSelesai: onSelesai,
                        onBatal: onBatal,
                      ),
                    ],
                  )
        ],
      ),
    );
  }
}

class _FormSelesai extends StatefulWidget {
  final int pengirimanId;
  final Map<String, dynamic> pengirimanData;
  final PackagingService packagingService;
  final void Function(int id) onSelesai;
  final VoidCallback onBatal;

  const _FormSelesai({
    required this.pengirimanId,
    required this.pengirimanData,
    required this.packagingService,
    required this.onSelesai,
    required this.onBatal,
  });

  @override
  State<_FormSelesai> createState() => _FormSelesaiState();
}

class _FormSelesaiState extends State<_FormSelesai> {
  late final TextEditingController _asistenCtl;
  FotoBuktiData? _fotoData;
  String _fotoUrl = '';
  bool _isLoading = false;
  String _errorMsg = '';
  bool _asistenReadOnly = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _asistenReadOnly = auth.isAsistenLapangan;
    _asistenCtl = TextEditingController(
      text: _asistenReadOnly
          ? auth.activeUser.name
          : (widget.pengirimanData['field_assistant'] as String? ?? ''),
    );
    _fotoUrl = widget.pengirimanData['proof_photo_url'] as String? ?? '';
  }

  @override
  void dispose() {
    _asistenCtl.dispose();
    super.dispose();
  }

  void _showQcRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: BGNColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BGNColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(TablerIcons.alert_triangle, size: 36, color: BGNColors.warning),
              const SizedBox(height: 12),
              const Text(
                'QC Belum Selesai',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: BGNColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Packing untuk pengiriman ini belum di-QC.\nSelesaikan Cek Packing terlebih dahulu\ndi tab Cek Packing, pastikan foto\nkondisi packing sudah diupload.',
                style: TextStyle(fontSize: 12, color: BGNColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSelesai() async {
    final compliancePhoto = widget.pengirimanData['compliance_photo_url'] as String?;
    if (compliancePhoto == null || compliancePhoto.isEmpty) {
      _showQcRequiredDialog();
      return;
    }
    if (_asistenCtl.text.isEmpty) {
      setState(() => _errorMsg = 'Asisten lapangan wajib diisi');
      return;
    }
    if (_fotoData?.filePath == null && _fotoUrl.isEmpty) {
      setState(() => _errorMsg = 'Foto bukti penyelesaian wajib diambil');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = ''; });

    try {
      final auth = context.read<AuthProvider>();
      final headers = <String, String>{
        'X-User-Role': auth.apiRole,
        if (auth.token != null) 'Authorization': 'Bearer ${auth.token}',
        if (auth.sppgId != null) 'X-User-Sppg-Id': auth.sppgId.toString(),
      };

      String proofUrl = _fotoUrl;
      if (_fotoData?.filePath != null) {
        proofUrl = await widget.packagingService.uploadPhoto(
          _fotoData!.filePath,
          headers: headers,
        );
      }

      await widget.packagingService.updateValidasiKeluar(
        existingData: widget.pengirimanData,
        deliveryStatus: 'Selesai',
        deliveryRoute: widget.pengirimanData['delivery_route'] as String? ?? '',
        fieldAssistant: _asistenCtl.text,
        proofPhotoUrl: proofUrl,
        headers: headers,
      );

      if (mounted) widget.onSelesai(widget.pengirimanId);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Gagal menyimpan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelesai = widget.pengirimanData['delivery_status'] == 'Selesai';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STATUS PENGIRIMAN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BGNColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BGNColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BGNColors.border),
            ),
            child: Text(
              widget.pengirimanData['delivery_status'] as String? ?? 'Menunggu',
              style: const TextStyle(fontSize: 13, color: BGNColors.textPrimary),
            ),
          ),
          const SizedBox(height: 16),

          const Text('ASISTEN LAPANGAN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BGNColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _asistenCtl,
            readOnly: _asistenReadOnly,
            style: TextStyle(fontSize: 13, color: _asistenReadOnly ? BGNColors.textHint : BGNColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Asisten Budi Santoso',
              hintStyle: const TextStyle(fontSize: 12, color: BGNColors.textHint),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BGNColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BGNColors.border)),
              filled: _asistenReadOnly,
              fillColor: _asistenReadOnly ? BGNColors.background : null,
            ),
          ),
          const SizedBox(height: 16),

          const Text('FOTO BUKTI PENYELESAIAN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BGNColors.textSecondary)),
          const SizedBox(height: 6),
          FotoBuktiWidget(
            title: '',
            petugas: _asistenCtl.text.isEmpty ? 'Petugas' : _asistenCtl.text,
            onUpdate: (data) => setState(() => _fotoData = data),
            enabled: !isSelesai,
          ),
          if (_fotoUrl.isNotEmpty || (_fotoData?.filePath != null))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _fotoData?.filePath ?? _fotoUrl,
                style: const TextStyle(fontSize: 10, color: BGNColors.textHint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 20),

          if (_errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(TablerIcons.alert_circle, size: 14, color: BGNColors.danger),
                  const SizedBox(width: 4),
                  Expanded(child: Text(_errorMsg, style: const TextStyle(fontSize: 11, color: BGNColors.danger))),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBatal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BGNColors.textSecondary,
                    side: const BorderSide(color: BGNColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Batal', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading || isSelesai ? null : _handleSelesai,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BGNColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: BGNColors.primary.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Selesai', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
