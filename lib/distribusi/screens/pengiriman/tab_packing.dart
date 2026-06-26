// lib/screens/pengiriman/tab_packing.dart
//
// Mirrors Vue ValidasiPacking.vue + PackingList.vue:
//   List (expandable cards → status grid → "Buat laporan kondisi")
//   Form (counter inputs → checkboxes → foto → submit)

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/widgets/common/foto_bukti_widget.dart';
import 'package:bgn/distribusi/widgets/common/car_loading.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';

enum _ViewMode { list, form }

class TabPacking extends StatefulWidget {
  const TabPacking({super.key});

  @override
  State<TabPacking> createState() => _TabPackingState();
}

class _TabPackingState extends State<TabPacking> {
  final PackagingService _packagingService = PackagingService(ApiClient());
  _ViewMode _viewMode = _ViewMode.list;

  // ── List data ────────────────────────────────────────────

  List<dynamic> _packingList = [];
  bool _loading = false;
  String? _error;
  int? _expandedId;

  // ── Form data ────────────────────────────────────────────

  Map<String, dynamic>? _formPacking;
  int? _formPackingId;

  // ── Form loading states ──────────────────────────────────

  bool _isSubmitting = false;
  bool _isUploadingFoto = false;
  bool _submitSuccess = false;
  String? _errorMsg;

  // ── Form fields ──────────────────────────────────────────

  int _fallenBrokenQty = 0;
  int _missingQty = 0;
  bool _damagedLabelCheck = false;
  bool _damagedSealCheck = false;
  String _compliancePhotoUrl = '';
  bool _fotoSudahUpload = false;

  // ── Computed ─────────────────────────────────────────────

  int get _totalSelesai =>
      _packingList.where((p) => p['delivery_status'] == 'Selesai').length;

  int get _totalBelum =>
      _packingList.where((p) => p['delivery_status'] != 'Selesai').length;

  bool get _siapLoading => _totalBelum == 0 && _packingList.isNotEmpty;

  bool get _adaMasalah =>
      _fallenBrokenQty > 0 ||
      _missingQty > 0 ||
      _damagedLabelCheck ||
      _damagedSealCheck;

  String get _ringkasanMasalah {
    final parts = <String>[];
    if (_fallenBrokenQty > 0) parts.add('$_fallenBrokenQty ompreng rusak');
    if (_missingQty > 0) parts.add('$_missingQty ompreng kurang');
    if (_damagedLabelCheck) parts.add('label rusak');
    if (_damagedSealCheck) parts.add('segel rusak');
    return parts.join(', ');
  }

  // ── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchPackingList();
  }

  // ── API: Fetch list ──────────────────────────────────────

  Future<void> _fetchPackingList() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _packagingService.getList();
      if (!mounted) return;
      setState(() {
      _packingList = data..sort((a, b) {
        final ta = DateTime.tryParse(a['timestamp'] ?? '');
        final tb = DateTime.tryParse(b['timestamp'] ?? '');
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Navigation: list ↔ form ──────────────────────────────

  void _openForm(Map<String, dynamic> packing) {
    setState(() {
      _formPacking = packing;
      _formPackingId = packing['id'] as int;
      _viewMode = _ViewMode.form;
      _resetForm();
      _fallenBrokenQty = packing['fallen_broken_qty'] ?? 0;
      _missingQty = packing['missing_qty'] ?? 0;
      _damagedLabelCheck = packing['damaged_label_check'] ?? false;
      _damagedSealCheck = packing['damaged_seal_check'] ?? false;
      _compliancePhotoUrl = packing['compliance_photo_url'] ?? '';
      _fotoSudahUpload = _compliancePhotoUrl.isNotEmpty;
    });
  }

  void _closeForm() {
    setState(() {
      _viewMode = _ViewMode.list;
      _formPacking = null;
      _formPackingId = null;
    });
  }

  void _resetForm() {
    _fallenBrokenQty = 0;
    _missingQty = 0;
    _damagedLabelCheck = false;
    _damagedSealCheck = false;
    _compliancePhotoUrl = '';
    _fotoSudahUpload = false;
    _submitSuccess = false;
    _errorMsg = null;
    _isUploadingFoto = false;
  }

  // ── Counter helpers ──────────────────────────────────────

  void _increment(String field) {
    setState(() {
      if (field == 'fallen_broken_qty') _fallenBrokenQty++;
      if (field == 'missing_qty') _missingQty++;
    });
  }

  void _decrement(String field) {
    setState(() {
      if (field == 'fallen_broken_qty' && _fallenBrokenQty > 0) _fallenBrokenQty--;
      if (field == 'missing_qty' && _missingQty > 0) _missingQty--;
    });
  }

  // ── Foto handling ────────────────────────────────────────

  void _handleFotoUpdate(FotoBuktiData? data) {
    if (data == null) {
      setState(() {
        _compliancePhotoUrl = '';
        _fotoSudahUpload = false;
      });
      return;
    }
    _uploadFoto(data.filePath);
  }

  Future<void> _uploadFoto(String filePath) async {
    setState(() {
      _isUploadingFoto = true;
      _fotoSudahUpload = false;
      _errorMsg = null;
    });
    try {
      final url = await _packagingService.uploadPhoto(filePath);
      if (!mounted) return;
      setState(() {
        _compliancePhotoUrl = url;
        _fotoSudahUpload = url.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _compliancePhotoUrl = '';
      });
    } finally {
      if (mounted) setState(() => _isUploadingFoto = false);
    }
  }

  // ── Submit ───────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (_formPacking == null || _formPackingId == null) return;
    setState(() {
      _errorMsg = null;
      _isSubmitting = true;
    });
    try {
      final payload = {
        ..._formPacking!,
        'fallen_broken_qty': _fallenBrokenQty,
        'missing_qty': _missingQty,
        'damaged_label_check': _damagedLabelCheck,
        'damaged_seal_check': _damagedSealCheck,
        'compliance_photo_url': _compliancePhotoUrl,
      };

      await _packagingService.update(_formPackingId.toString(), payload);

      if (!mounted) return;
      setState(() => _submitSuccess = true);
      // Update item di list lokal — tidak perlu re-fetch seluruh list
      final idx = _packingList.indexWhere((p) => (p['id'] as int) == _formPackingId);
      if (idx != -1) {
        _packingList[idx] = payload;
      }
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _closeForm();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Format helpers ───────────────────────────────────────

  String _formatTanggal(String? ts) {
    if (ts == null) return '-';
    final date = DateTime.tryParse(ts);
    if (date == null) return '-';
    const bulan = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${bulan[date.month]} ${date.year}';
  }

  String _formatJam(String? ts) {
    if (ts == null) return '-';
    final date = DateTime.tryParse(ts);
    if (date == null) return '-';
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_viewMode == _ViewMode.form) return _buildFormView();
    return _buildListView();
  }

  // ── List View (ValidasiPacking) ──────────────────────────

  Widget _buildListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BGNColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Validasi & Check Packing',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BGNColors.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: BGNColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Alur 3',
                      style:
                          TextStyle(fontSize: 9, color: BGNColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pastikan semua packing sudah sesuai sebelum loading ke kendaraan',
                style: TextStyle(fontSize: 10, color: BGNColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Loading ──
        if (_loading)
          ...List.generate(3, (_) => _LoadingSkeleton())

        // ── Error ──
        else if (_error != null)
          _ErrorCard(
            message: _error!,
            onRetry: _fetchPackingList,
          )

        // ── List ──
        else if (_packingList.isEmpty)
          _EmptyState()

        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _packingList.length,
            itemBuilder: (_, i) => _buildPackingCard(i),
          ),

        // ── Summary ──
        if (!_loading && _error == null && _packingList.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSummary(),
        ],
      ],
    );
  }

  Widget _buildPackingCard(int index) {
    final packing = _packingList[index];
    final id = packing['id'] as int;
    final isExpanded = _expandedId == id;
    final statusSelesai = packing['delivery_status'] == 'Selesai';
    final route =
        packing['delivery_route'] as String? ?? 'Rute belum ditentukan';
    final target = (packing['target_portions'] as num?)?.toInt() ?? 0;
    final actual = (packing['actual_portions'] as num?)?.toInt() ?? 0;
    final effectiveness =
        (packing['effectiveness'] as num?)?.toDouble() ?? 0.0;
    final fbQty = (packing['fallen_broken_qty'] as num?)?.toInt() ?? 0;
    final missQty = (packing['missing_qty'] as num?)?.toInt() ?? 0;
    final labelRusak = packing['damaged_label_check'] ?? false;
    final segelRusak = packing['damaged_seal_check'] ?? false;
    final aslab =
        packing['field_assistant'] as String? ?? '-';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: BGNColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? BGNColors.primary.withValues(alpha: 0.3)
              : BGNColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header (clickable) ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() {
                _expandedId = isExpanded ? null : id;
              }),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: isExpanded ? Radius.zero : const Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: statusSelesai
                            ? BGNColors.primaryLight
                            : BGNColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        statusSelesai
                            ? TablerIcons.circle_check
                            : TablerIcons.package,
                        size: 16,
                        color: statusSelesai
                            ? BGNColors.primary
                            : BGNColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Route + info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: BGNColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$target porsi · ${_formatTanggal(packing['timestamp'] as String?)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: BGNColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusSelesai
                            ? BGNColors.primaryLight
                            : BGNColors.background,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusSelesai ? 'Selesai' : 'Belum',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: statusSelesai
                              ? BGNColors.primary
                              : BGNColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: isExpanded ? 0.5 : 0.0,
                      child: const Icon(
                        TablerIcons.chevron_down,
                        size: 16,
                        color: BGNColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expanded detail ──
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, color: BGNColors.border),
                      _ExpandedDetail(
                        packing: packing,
                        target: target,
                        actual: actual,
                        effectiveness: effectiveness,
                        fbQty: fbQty,
                        missQty: missQty,
                        labelRusak: labelRusak,
                        segelRusak: segelRusak,
                        aslab: aslab,
                        statusSelesai: statusSelesai,
                        formatJam: _formatJam,
                        onOpenForm: _openForm,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BGNColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan packing',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: BGNColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryBox(
                label: 'Selesai',
                value: '$_totalSelesai',
                bgColor: BGNColors.primaryLight,
                textColor: BGNColors.primary,
              ),
              const SizedBox(width: 8),
              _SummaryBox(
                label: 'Belum',
                value: '$_totalBelum',
                bgColor: BGNColors.background,
                textColor: BGNColors.textSecondary,
              ),
              const SizedBox(width: 8),
              _SummaryBox(
                label: 'Total',
                value: '${_packingList.length}',
                bgColor: BGNColors.background,
                textColor: BGNColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Ready to load indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _siapLoading
                  ? BGNColors.primaryLight
                  : BGNColors.warningLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _siapLoading
                      ? TablerIcons.truck
                      : TablerIcons.alert_triangle,
                  size: 16,
                  color: _siapLoading
                      ? BGNColors.primary
                      : BGNColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _siapLoading
                        ? 'Semua packing selesai — siap loading ke kendaraan'
                        : '$_totalBelum packing belum selesai',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _siapLoading
                          ? BGNColors.primary
                          : BGNColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Form View (PackingList) ──────────────────────────────

  Widget _buildFormView() {
    final targetPortions =
        (_formPacking?['target_portions'] as num?)?.toInt() ?? 0;
    final route =
        _formPacking?['delivery_route'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Back button ──
        GestureDetector(
          onTap: _closeForm,
          child: const Row(
            children: [
              Icon(TablerIcons.arrow_left,
                  size: 18, color: BGNColors.textSecondary),
              SizedBox(width: 4),
              Text(
                'Kembali',
                style: TextStyle(
                  fontSize: 12,
                  color: BGNColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Form container ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BGNColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BGNColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              _HeaderInfo(
                route: route,
                targetPortions: targetPortions,
                packingId: _formPackingId ?? 0,
              ),
              const SizedBox(height: 16),

              // Kondisi section
              _KondisiSection(
                fallenBrokenQty: _fallenBrokenQty,
                missingQty: _missingQty,
                damagedLabelCheck: _damagedLabelCheck,
                damagedSealCheck: _damagedSealCheck,
                onIncrement: _increment,
                onDecrement: _decrement,
                onDamagedLabelToggle: () =>
                    setState(() => _damagedLabelCheck = !_damagedLabelCheck),
                onDamagedSealToggle: () =>
                    setState(() => _damagedSealCheck = !_damagedSealCheck),
              ),
              const SizedBox(height: 16),

              // Foto
              _FotoSection(
                  onFotoUpdate: _handleFotoUpdate,
                  isUploadingFoto: _isUploadingFoto,
                  fotoSudahUpload: _fotoSudahUpload,
                ),
                const SizedBox(height: 16),

                // Condition indicator
                _ConditionIndicator(
                  adaMasalah: _adaMasalah,
                  ringkasanMasalah: _ringkasanMasalah,
                ),

                // Error
                if (_errorMsg != null) ...[
                  const SizedBox(height: 10),
                  _ErrorBanner(message: _errorMsg!),
                ],

                // Success
                if (_submitSuccess) ...[
                  const SizedBox(height: 10),
                  _SuccessBanner(),
                ],

                const SizedBox(height: 14),

                // Submit
                _SubmitButton(
                  isSubmitting: _isSubmitting,
                  submitSuccess: _submitSuccess,
                  isUploadingFoto: _isUploadingFoto,
                  onSubmit: _handleSubmit,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Mini stat box (target / actual / effectiveness)
// ═══════════════════════════════════════════════════════════

class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color? bgColor;

  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.textColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor ?? BGNColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 9, color: BGNColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Status grid item (2x2: jatuh/rusak, jumlah, label, segel)
// ═══════════════════════════════════════════════════════════

class _StatusGridItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final bool isProblem;

  const _StatusGridItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.isProblem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isProblem ? BGNColors.dangerLight : BGNColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: iconColor,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            sublabel,
            style: const TextStyle(
                fontSize: 9, color: BGNColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Summary box (selesai / belum / total)
// ═══════════════════════════════════════════════════════════

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;

  const _SummaryBox({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Header info (form view)
// ═══════════════════════════════════════════════════════════

class _HeaderInfo extends StatelessWidget {
  final String route;
  final int targetPortions;
  final int packingId;

  const _HeaderInfo({
    required this.route,
    required this.targetPortions,
    required this.packingId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BGNColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  route.isNotEmpty ? route : 'Rute belum ditentukan',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: BGNColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Laporan Kondisi',
                  style: TextStyle(fontSize: 9, color: BGNColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BGNColors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target porsi',
                        style: TextStyle(
                          fontSize: 9,
                          color: BGNColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$targetPortions',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: BGNColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BGNColors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Packaging ID',
                        style: TextStyle(
                          fontSize: 9,
                          color: BGNColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#$packingId',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: BGNColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Kondisi section (form view)
// ═══════════════════════════════════════════════════════════

class _KondisiSection extends StatelessWidget {
  final int fallenBrokenQty;
  final int missingQty;
  final bool damagedLabelCheck;
  final bool damagedSealCheck;
  final Function(String) onIncrement;
  final Function(String) onDecrement;
  final VoidCallback onDamagedLabelToggle;
  final VoidCallback onDamagedSealToggle;

  const _KondisiSection({
    required this.fallenBrokenQty,
    required this.missingQty,
    required this.damagedLabelCheck,
    required this.damagedSealCheck,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDamagedLabelToggle,
    required this.onDamagedSealToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kondisi packing',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: BGNColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        _CounterField(
          label: 'Ompreng jatuh / rusak',
          icon: TablerIcons.box_seam,
          value: fallenBrokenQty,
          hasProblem: fallenBrokenQty > 0,
          hint: 'Isi 0 jika tidak ada ompreng yang jatuh atau rusak',
          onIncrement: () => onIncrement('fallen_broken_qty'),
          onDecrement: () => onDecrement('fallen_broken_qty'),
        ),
        const SizedBox(height: 14),
        _CounterField(
          label: 'Ompreng kurang / hilang',
          icon: TablerIcons.clipboard_x,
          value: missingQty,
          hasProblem: missingQty > 0,
          hint: 'Isi 0 jika jumlah ompreng sesuai target',
          onIncrement: () => onIncrement('missing_qty'),
          onDecrement: () => onDecrement('missing_qty'),
        ),
        const SizedBox(height: 14),
        _CheckboxRow(
          checked: damagedLabelCheck,
          label: 'Label rusak / lepas',
          description: 'Label tujuan tidak terbaca atau terlepas dari kemasan',
          onToggle: onDamagedLabelToggle,
        ),
        const SizedBox(height: 10),
        _CheckboxRow(
          checked: damagedSealCheck,
          label: 'Segel / kemasan rusak',
          description: 'Kemasan tidak rapat, bocor, atau segel terlepas',
          onToggle: onDamagedSealToggle,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Counter field (- / input / +)
// ═══════════════════════════════════════════════════════════

class _CounterField extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final bool hasProblem;
  final String hint;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CounterField({
    required this.label,
    required this.icon,
    required this.value,
    required this.hasProblem,
    required this.hint,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: BGNColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: onDecrement,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BGNColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(TablerIcons.minus,
                    size: 14, color: BGNColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: hasProblem ? BGNColors.dangerLight : BGNColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasProblem
                        ? const Color(0xFFFCA5A5)
                        : BGNColors.border,
                  ),
                ),
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: hasProblem
                        ? BGNColors.danger
                        : BGNColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onIncrement,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BGNColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(TablerIcons.plus,
                    size: 14, color: BGNColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(hint,
              style: const TextStyle(
                  fontSize: 9, color: BGNColors.textHint)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Custom checkbox row
// ═══════════════════════════════════════════════════════════

class _CheckboxRow extends StatelessWidget {
  final bool checked;
  final String label;
  final String description;
  final VoidCallback onToggle;

  const _CheckboxRow({
    required this.checked,
    required this.label,
    required this.description,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: checked ? BGNColors.dangerLight : BGNColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: checked ? const Color(0xFFFCA5A5) : BGNColors.border,
            width: checked ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: checked ? BGNColors.danger : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: checked ? BGNColors.danger : BGNColors.border,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(TablerIcons.check,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: checked
                              ? BGNColors.danger
                              : BGNColors.textPrimary)),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 9, color: BGNColors.textHint)),
                ],
              ),
            ),
            Icon(
              checked
                  ? TablerIcons.alert_triangle
                  : TablerIcons.circle_dashed,
              size: 18,
              color: checked ? BGNColors.danger : BGNColors.border,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Foto section
// ═══════════════════════════════════════════════════════════

class _FotoSection extends StatelessWidget {
  final Function(FotoBuktiData?) onFotoUpdate;
  final bool isUploadingFoto;
  final bool fotoSudahUpload;

  const _FotoSection({
    required this.onFotoUpdate,
    required this.isUploadingFoto,
    required this.fotoSudahUpload,
  });

  @override
  Widget build(BuildContext context) {
    final petugas = context.watch<AuthProvider>().activeUser.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FotoBuktiWidget(
          title: 'Foto kondisi packing',
          petugas: petugas,
          onUpdate: onFotoUpdate,
        ),
        const SizedBox(height: 6),
        if (isUploadingFoto)
          const Row(
            children: [
              InlineCarLoading(size: 10),
              SizedBox(width: 6),
              Text('Mengupload foto...',
                  style:
                      TextStyle(fontSize: 10, color: BGNColors.primary)),
            ],
          )
        else if (fotoSudahUpload)
          const Row(
            children: [
              Icon(TablerIcons.circle_check,
                  size: 14, color: BGNColors.primary),
              SizedBox(width: 4),
              Text('Foto berhasil diupload',
                  style:
                      TextStyle(fontSize: 10, color: BGNColors.primary)),
            ],
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Condition indicator
// ═══════════════════════════════════════════════════════════

class _ConditionIndicator extends StatelessWidget {
  final bool adaMasalah;
  final String ringkasanMasalah;

  const _ConditionIndicator({
    required this.adaMasalah,
    required this.ringkasanMasalah,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        adaMasalah ? BGNColors.dangerLight : BGNColors.primaryLight;
    final iconColor = adaMasalah ? BGNColors.danger : BGNColors.primary;
    final textColor = adaMasalah ? BGNColors.danger : BGNColors.primary;
    final icon = adaMasalah
        ? TablerIcons.alert_triangle
        : TablerIcons.circle_check;
    final text =
        adaMasalah ? ringkasanMasalah : 'Kondisi packing baik';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textColor)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Error / Success banners
// ═══════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BGNColors.dangerLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(TablerIcons.alert_circle,
              size: 14, color: BGNColors.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 10, color: BGNColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BGNColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(TablerIcons.circle_check,
              size: 18, color: BGNColors.primary),
          SizedBox(width: 8),
          Text('Laporan berhasil dikirim',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: BGNColors.primary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Submit button
// ═══════════════════════════════════════════════════════════

class _SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final bool submitSuccess;
  final bool isUploadingFoto;
  final VoidCallback onSubmit;

  const _SubmitButton({
    required this.isSubmitting,
    required this.submitSuccess,
    required this.isUploadingFoto,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isSubmitting || submitSuccess || isUploadingFoto;

    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    if (submitSuccess) {
      bgColor = BGNColors.primaryLight;
      textColor = BGNColors.primary;
      label = 'Laporan terkirim';
      icon = TablerIcons.circle_check;
    } else if (isSubmitting) {
      bgColor = BGNColors.primary;
      textColor = Colors.white;
      label = 'Mengirim...';
      icon = TablerIcons.loader_2;
    } else {
      bgColor = BGNColors.primary;
      textColor = Colors.white;
      label = 'Kirim laporan kondisi';
      icon = TablerIcons.send;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : onSubmit,
        icon: isSubmitting
            ? const ButtonCarLoading()
            : Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          disabledBackgroundColor: bgColor,
          disabledForegroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Loading skeleton
// ═══════════════════════════════════════════════════════════

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BGNColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: double.infinity,
            color: BGNColors.background,
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            width: 120,
            color: BGNColors.background,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Error card
// ═══════════════════════════════════════════════════════════

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BGNColors.dangerLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(TablerIcons.alert_circle,
              size: 18, color: BGNColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gagal memuat data',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: BGNColors.danger)),
                Text(message,
                    style: const TextStyle(
                        fontSize: 10, color: BGNColors.danger)),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Coba lagi',
                style: TextStyle(fontSize: 11, color: BGNColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Empty state
// ═══════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: const [
            Icon(TablerIcons.inbox, size: 48, color: BGNColors.border),
            SizedBox(height: 12),
              Text('Belum ada data packing',
                  style: TextStyle(
                      fontSize: 13, color: BGNColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Expanded detail (animasi smooth saat expand)
// ═══════════════════════════════════════════════════════════

class _ExpandedDetail extends StatelessWidget {
  final Map<String, dynamic> packing;
  final int target;
  final int actual;
  final double effectiveness;
  final int fbQty;
  final int missQty;
  final bool labelRusak;
  final bool segelRusak;
  final String aslab;
  final bool statusSelesai;
  final String Function(String?) formatJam;
  final void Function(Map<String, dynamic>) onOpenForm;

  const _ExpandedDetail({
    required this.packing,
    required this.target,
    required this.actual,
    required this.effectiveness,
    required this.fbQty,
    required this.missQty,
    required this.labelRusak,
    required this.segelRusak,
    required this.aslab,
    required this.statusSelesai,
    required this.formatJam,
    required this.onOpenForm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-col: target, actual, effectiveness
          Row(
            children: [
              _MiniStatBox(
                label: 'Target porsi',
                value: '$target',
                textColor: BGNColors.textPrimary,
              ),
              const SizedBox(width: 8),
              _MiniStatBox(
                label: 'Aktual porsi',
                value: '$actual',
                textColor: BGNColors.textPrimary,
              ),
              const SizedBox(width: 8),
              _MiniStatBox(
                label: 'Efektivitas',
                value: '${effectiveness.toStringAsFixed(0)}%',
                textColor: effectiveness >= 95
                    ? BGNColors.primary
                    : BGNColors.warning,
                bgColor: effectiveness >= 95
                    ? BGNColors.primaryLight
                    : BGNColors.warningLight,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status checklist 2x2 grid
          const Text(
            'Status checklist',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: BGNColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _StatusGridItem(
                icon: fbQty > 0
                    ? TablerIcons.alert_triangle
                    : TablerIcons.circle_check,
                iconColor: fbQty > 0
                    ? BGNColors.danger
                    : BGNColors.primary,
                label: fbQty > 0 ? '$fbQty rusak' : 'Tidak rusak',
                sublabel: 'Jatuh/Rusak',
                isProblem: fbQty > 0,
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatusGridItem(
                icon: missQty > 0
                    ? TablerIcons.alert_triangle
                    : TablerIcons.circle_check,
                iconColor: missQty > 0
                    ? BGNColors.danger
                    : BGNColors.primary,
                label: missQty > 0 ? '$missQty kurang' : 'Sesuai',
                sublabel: 'Jumlah',
                isProblem: missQty > 0,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _StatusGridItem(
                icon: labelRusak == true
                    ? TablerIcons.circle_x
                    : TablerIcons.circle_check,
                iconColor: labelRusak == true
                    ? BGNColors.danger
                    : BGNColors.primary,
                label: labelRusak == true ? 'Rusak' : 'Baik',
                sublabel: 'Label',
                isProblem: labelRusak == true,
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatusGridItem(
                icon: segelRusak == true
                    ? TablerIcons.circle_x
                    : TablerIcons.circle_check,
                iconColor: segelRusak == true
                    ? BGNColors.danger
                    : BGNColors.primary,
                label: segelRusak == true ? 'Rusak' : 'Baik',
                sublabel: 'Segel',
                isProblem: segelRusak == true,
              )),
            ],
          ),
          const SizedBox(height: 12),

          // Field assistant + timestamp
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: BGNColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(TablerIcons.user,
                        size: 12,
                        color: BGNColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      aslab,
                      style: const TextStyle(
                        fontSize: 11,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(TablerIcons.clock,
                        size: 12,
                        color: BGNColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      formatJam(packing['timestamp'] as String?),
                      style: const TextStyle(
                        fontSize: 11,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Buat laporan button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  statusSelesai ? null : () => onOpenForm(packing),
              icon: Icon(
                statusSelesai
                    ? TablerIcons.circle_check
                    : TablerIcons.clipboard_list,
                size: 16,
              ),
              label: Text(
                statusSelesai
                    ? 'Laporan sudah dibuat'
                    : 'Buat laporan kondisi',
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusSelesai
                    ? BGNColors.background
                    : BGNColors.primary,
                foregroundColor: statusSelesai
                    ? BGNColors.textHint
                    : BGNColors.white,
                disabledBackgroundColor: BGNColors.background,
                disabledForegroundColor: BGNColors.textHint,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
