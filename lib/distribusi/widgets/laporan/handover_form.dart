// lib/widgets/laporan/handover_form.dart
//
// Form konfirmasi penerimaan untuk pm / pic_sekolah.
// Mirip tab_packing.dart (dari sisi aslap) tapi dari sisi penerima:
//   - Validasi kondisi fisik (pm_broken/missing/label/segel)
//   - Foto bukti serah terima (upload ke /api/distribution/upload)
//   - Rating kurir (overall, ketepatan waktu, kepatuhan)
//   - Review / komentar
//   - Tanda tangan digital (canvas → base64)
//   - Submit PUT /api/production/packaging/:id → only PM review fields

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/packaging_service.dart';
import 'package:bgn/distribusi/widgets/common/foto_bukti_widget.dart';
import 'package:bgn/distribusi/widgets/common/car_loading.dart';

class HandoverForm extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const HandoverForm({
    super.key,
    required this.delivery,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<HandoverForm> createState() => _HandoverFormState();
}

class _HandoverFormState extends State<HandoverForm> {
  final PackagingService _packagingService = PackagingService(ApiClient());
  final _reviewCtrl = TextEditingController();
  final _signatureKey = GlobalKey();

  // ── Kondisi fisik ────────────────────────────────────────
  int _brokenQty = 0;
  int _missingQty = 0;
  bool _damagedLabel = false;
  bool _damagedSeal = false;

  // ── Rating ───────────────────────────────────────────────
  int _ratingLateness = 5;
  int _ratingCompliance = 5;

  // ── Foto ─────────────────────────────────────────────────
  String _reviewPhotoUrl = '';
  bool _isUploadingFoto = false;
  bool _fotoUploaded = false;

  // ── Tanda tangan ─────────────────────────────────────────
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  bool _hasSigned = false;

  // ── Submit state ─────────────────────────────────────────
  bool _isSubmitting = false;
  bool _submitSuccess = false;
  String? _errorMsg;

  // ── Expanded sections ────────────────────────────────────
  bool _expandedKondisi = true;
  bool _expandedRating = true;
  bool _expandedFoto = false;
  bool _expandedTTD = true;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _authHeaders() {
    final auth = context.read<AuthProvider>();
    final h = <String, String>{'X-User-Role': auth.apiRole};
    if (auth.token != null) h['Authorization'] = 'Bearer ${auth.token}';
    if (auth.sppgId != null) h['X-User-Sppg-Id'] = auth.sppgId.toString();
    return h;
  }

  // ── Counter ──────────────────────────────────────────────
  void _inc(String f) => setState(() {
        if (f == 'broken') _brokenQty++;
        if (f == 'missing') _missingQty++;
      });

  void _dec(String f) => setState(() {
        if (f == 'broken' && _brokenQty > 0) _brokenQty--;
        if (f == 'missing' && _missingQty > 0) _missingQty--;
      });

  // ── Foto ─────────────────────────────────────────────────
  void _handleFotoUpdate(FotoBuktiData? data) {
    if (data == null) {
      setState(() {
        _reviewPhotoUrl = '';
        _fotoUploaded = false;
      });
      return;
    }
    _uploadFoto(data.filePath, bytes: data.bytes);
  }

  Future<void> _uploadFoto(String filePath, {Uint8List? bytes}) async {
    setState(() {
      _isUploadingFoto = true;
      _fotoUploaded = false;
      _errorMsg = null;
    });
    try {
      final url =
          await _packagingService.uploadPhoto(filePath, headers: _authHeaders(), bytes: bytes);
      if (!mounted) return;
      setState(() {
        _reviewPhotoUrl = url;
        _fotoUploaded = url.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isUploadingFoto = false);
    }
  }

  // ── Tanda tangan canvas ──────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    _currentStroke = [d.localPosition];
    setState(() {
      _strokes.add(_currentStroke);
      _hasSigned = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentStroke.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _currentStroke.add(null));
  }

  void _clearSignature() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _hasSigned = false;
    });
  }

  Future<String?> _captureSignatureBase64() async {
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();
      final b64 = _uint8ListToBase64(bytes);
      return 'data:image/png;base64,$b64';
    } catch (_) {
      return null;
    }
  }

  String _uint8ListToBase64(Uint8List bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      result.write(chars[(b0 >> 2) & 0x3F]);
      result.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      result.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      result.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return result.toString();
  }

  // ── Submit ───────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (!_hasSigned) {
      setState(() => _errorMsg = 'Tanda tangan digital wajib diisi.');
      return;
    }

    setState(() {
      _errorMsg = null;
      _isSubmitting = true;
    });

    try {
      final signature = await _captureSignatureBase64();
      if (signature == null) throw Exception('Gagal mengambil tanda tangan.');

      final id = (widget.delivery['id'] as num?)?.toInt();
      if (id == null) throw Exception('ID pengiriman tidak valid.');

      final payload = {
        'delivery_status': 'Selesai',
        'rating': ((_ratingLateness + _ratingCompliance) / 2).round(),
        'rating_lateness': _ratingLateness,
        'rating_compliance': _ratingCompliance,
        'pm_broken_qty': _brokenQty,
        'pm_missing_qty': _missingQty,
        'pm_damaged_label': _damagedLabel,
        'pm_damaged_seal': _damagedSeal,
        'review_comment': _reviewCtrl.text.trim(),
        'review_photo_url': _reviewPhotoUrl,
        'digital_signature': signature,
      };

      // Merge dengan data existing supaya field lain tidak hilang
      final merged = Map<String, dynamic>.from(widget.delivery);
      merged.addAll(payload);

      await _packagingService.update(id.toString(), merged,
          headers: _authHeaders());

      if (!mounted) return;
      setState(() => _submitSuccess = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final delivery = widget.delivery;
    final lokasi = delivery['beneficiary_name'] as String? ??
        delivery['delivery_route'] as String? ?? '-';
    final menu = delivery['menu_name'] as String? ?? '-';
    final target = (delivery['target_portions'] as num?)?.toInt() ?? 0;
    final actual = (delivery['actual_portions'] as num?)?.toInt() ?? 0;
    final aslab = delivery['field_assistant'] as String? ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header info ──
          _buildHeader(lokasi, menu, target, actual, aslab),

          // ── Kondisi fisik ──
          _buildSection(
            title: 'Kondisi fisik saat diterima',
            icon: TablerIcons.package,
            expanded: _expandedKondisi,
            onToggle: () =>
                setState(() => _expandedKondisi = !_expandedKondisi),
            child: _buildKondisiSection(),
          ),

          // ── Rating ──
          _buildSection(
            title: 'Penilaian kurir',
            icon: TablerIcons.star,
            expanded: _expandedRating,
            onToggle: () =>
                setState(() => _expandedRating = !_expandedRating),
            child: _buildRatingSection(),
          ),

          // ── Foto bukti ──
          _buildSection(
            title: 'Foto bukti penerimaan',
            icon: TablerIcons.camera,
            expanded: _expandedFoto,
            onToggle: () =>
                setState(() => _expandedFoto = !_expandedFoto),
            child: _buildFotoSection(),
          ),

          // ── Komentar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _buildKomentarSection(),
          ),

          // ── Tanda tangan ──
          _buildSection(
            title: 'Tanda tangan digital',
            icon: TablerIcons.signature,
            expanded: _expandedTTD,
            onToggle: () => setState(() => _expandedTTD = !_expandedTTD),
            child: _buildTandaTanganSection(),
          ),

          // ── Error / Success / Submit ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Column(
              children: [
                if (_errorMsg != null) ...[
                  _ErrorBanner(message: _errorMsg!),
                  const SizedBox(height: 10),
                ],
                if (_submitSuccess) ...[
                  _SuccessBanner(),
                  const SizedBox(height: 10),
                ],
                _SubmitButton(
                  isSubmitting: _isSubmitting,
                  submitSuccess: _submitSuccess,
                  onSubmit: _handleSubmit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader(
      String lokasi, String menu, int target, int actual, String aslab) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: BGNColors.primaryLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: BGNColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(TablerIcons.truck_delivery,
                    size: 16, color: BGNColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lokasi,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BGNColors.primary)),
                    Text(menu,
                        style: const TextStyle(
                            fontSize: 10, color: BGNColors.primary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BGNColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Konfirmasi Terima',
                    style:
                        TextStyle(fontSize: 9, color: BGNColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(label: 'Target', value: '$target porsi'),
              const SizedBox(width: 8),
              _MiniStat(label: 'Dikirim', value: '$actual porsi'),
              const SizedBox(width: 8),
              _MiniStat(
                  label: 'Asisten lapangan',
                  value: aslab,
                  flex: 2),
            ],
          ),
        ],
      ),
    );
  }

  // ── Collapsible section wrapper ───────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 14, color: BGNColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: BGNColors.textPrimary)),
                ),
                Transform.rotate(
                  angle: expanded ? math.pi : 0,
                  child: const Icon(TablerIcons.chevron_down,
                      size: 16, color: BGNColors.textHint),
                ),
              ],
            ),
          ),
        ),
        if (expanded) Padding(
                  padding:
                      const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: child,
                ),
        const Divider(height: 1, color: BGNColors.border),
      ],
    );
  }

  // ── Kondisi fisik ─────────────────────────────────────────
  Widget _buildKondisiSection() {
    return Column(
      children: [
        _CounterField(
          label: 'Kemasan pecah / tumpah',
          icon: TablerIcons.box_seam,
          value: _brokenQty,
          hasProblem: _brokenQty > 0,
          hint: 'Isi 0 jika tidak ada kemasan yang pecah atau tumpah',
          onIncrement: () => _inc('broken'),
          onDecrement: () => _dec('broken'),
        ),
        const SizedBox(height: 12),
        _CounterField(
          label: 'Kemasan kurang / hilang',
          icon: TablerIcons.clipboard_x,
          value: _missingQty,
          hasProblem: _missingQty > 0,
          hint: 'Isi 0 jika jumlah kemasan sesuai',
          onIncrement: () => _inc('missing'),
          onDecrement: () => _dec('missing'),
        ),
        const SizedBox(height: 12),
        _CheckboxRow(
          checked: _damagedLabel,
          label: 'Label nutrisi rusak / sobek',
          description: 'Label nutrisi tidak terbaca atau terlepas dari kemasan',
          onToggle: () => setState(() => _damagedLabel = !_damagedLabel),
        ),
        const SizedBox(height: 8),
        _CheckboxRow(
          checked: _damagedSeal,
          label: 'Segel kemasan rusak / terbuka',
          description:
              'Kemasan tidak rapat, bocor, atau segel sudah terbuka',
          onToggle: () => setState(() => _damagedSeal = !_damagedSeal),
        ),
        const SizedBox(height: 10),
        _ConditionIndicator(
          adaMasalah: _brokenQty > 0 ||
              _missingQty > 0 ||
              _damagedLabel ||
              _damagedSeal,
          ringkasan: [
            if (_brokenQty > 0) '$_brokenQty kemasan pecah',
            if (_missingQty > 0) '$_missingQty kemasan kurang',
            if (_damagedLabel) 'label rusak',
            if (_damagedSeal) 'segel rusak',
          ].join(', '),
        ),
      ],
    );
  }

  // ── Rating ────────────────────────────────────────────────
  Widget _buildRatingSection() {
    return Column(
      children: [
        _RatingRow(
          label: 'Ketepatan waktu',
          value: _ratingLateness,
          onChanged: (v) => setState(() => _ratingLateness = v),
        ),
        const SizedBox(height: 10),
        _RatingRow(
          label: 'Kepatuhan & sopan santun',
          value: _ratingCompliance,
          onChanged: (v) => setState(() => _ratingCompliance = v),
        ),
        const SizedBox(height: 8),
        _AutoRatingDisplay(
          lateness: _ratingLateness,
          compliance: _ratingCompliance,
        ),
      ],
    );
  }

  // ── Foto ──────────────────────────────────────────────────
  Widget _buildFotoSection() {
    final petugas = context.read<AuthProvider>().activeUser.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FotoBuktiWidget(
          title: 'Foto bukti serah terima',
          petugas: petugas,
          onUpdate: _handleFotoUpdate,
        ),
        const SizedBox(height: 6),
        if (_isUploadingFoto)
          const Row(children: [
            InlineCarLoading(size: 10),
            SizedBox(width: 6),
            Text('Mengupload foto...',
                style:
                    TextStyle(fontSize: 10, color: BGNColors.primary)),
          ])
        else if (_fotoUploaded)
          const Row(children: [
            Icon(TablerIcons.circle_check,
                size: 14, color: BGNColors.primary),
            SizedBox(width: 4),
            Text('Foto berhasil diupload',
                style:
                    TextStyle(fontSize: 10, color: BGNColors.primary)),
          ]),
      ],
    );
  }

  // ── Komentar ──────────────────────────────────────────────
  Widget _buildKomentarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(TablerIcons.message_circle,
                size: 14, color: BGNColors.textSecondary),
            SizedBox(width: 8),
            Text('Masukan / kritik & saran',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: BGNColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reviewCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Contoh: Makanan hangat, sayur masih segar...',
            hintStyle: const TextStyle(
                fontSize: 11, color: BGNColors.textHint),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: BGNColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: BGNColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: BGNColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tanda tangan ──────────────────────────────────────────
  Widget _buildTandaTanganSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _hasSigned ? BGNColors.primary : BGNColors.border,
              width: _hasSigned ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: BGNColors.background,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                // Canvas
                RepaintBoundary(
                  key: _signatureKey,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: SizedBox(
                      width: double.infinity,
                      height: 140,
                      child: CustomPaint(
                        painter: _SignaturePainter(_strokes),
                      ),
                    ),
                  ),
                ),
                // Placeholder
                if (!_hasSigned)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(TablerIcons.signature,
                                size: 28, color: BGNColors.border),
                            SizedBox(height: 4),
                            Text('Tanda tangan di sini',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: BGNColors.textHint)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_hasSigned)
              Row(
                children: const [
                  Icon(TablerIcons.circle_check,
                      size: 14, color: BGNColors.primary),
                  SizedBox(width: 4),
                  Text('Tanda tangan tersimpan',
                      style: TextStyle(
                          fontSize: 10, color: BGNColors.primary)),
                ],
              )
            else
              const Text('Wajib ditandatangani',
                  style: TextStyle(
                      fontSize: 10, color: BGNColors.textHint)),
            GestureDetector(
              onTap: _clearSignature,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BGNColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(TablerIcons.trash,
                        size: 12, color: BGNColors.danger),
                    SizedBox(width: 4),
                    Text('Hapus',
                        style: TextStyle(
                            fontSize: 10, color: BGNColors.danger)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Signature painter
// ═══════════════════════════════════════════════════════════

class _SignaturePainter extends CustomPainter {
  final List<List<Offset?>> strokes;

  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BGNColors.primary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        if (stroke[i] != null && stroke[i + 1] != null) {
          canvas.drawLine(stroke[i]!, stroke[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

// ═══════════════════════════════════════════════════════════
// Mini stat (header)
// ═══════════════════════════════════════════════════════════

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final int flex;

  const _MiniStat(
      {required this.label, required this.value, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: BGNColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: BGNColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BGNColors.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Counter field (sama pola dengan tab_packing)
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
        Row(children: [
          Icon(icon, size: 14, color: BGNColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: BGNColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
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
                color: hasProblem ? BGNColors.dangerLight : BGNColors.surface,
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
        ]),
        const SizedBox(height: 4),
        Text(hint,
            style: const TextStyle(fontSize: 9, color: BGNColors.textHint)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Checkbox row (sama pola dengan tab_packing)
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
           color: checked ? BGNColors.dangerLight : BGNColors.surface,
           borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: checked
                ? const Color(0xFFFCA5A5)
                : BGNColors.border,
          ),
        ),
        child: Row(children: [
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
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Rating row (bintang 1–5)
// ═══════════════════════════════════════════════════════════

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, color: BGNColors.textSecondary)),
      ),
      Row(
        children: List.generate(5, (i) {
          final star = i + 1;
          final filled = star <= value;
          return GestureDetector(
            onTap: () => onChanged(star),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                filled ? TablerIcons.star_filled : TablerIcons.star,
                size: 22,
                color: filled ? BGNColors.warning : BGNColors.border,
              ),
            ),
          );
        }),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// Auto rating display (rata-rata dari 2 rating)
// ═══════════════════════════════════════════════════════════

class _AutoRatingDisplay extends StatelessWidget {
  final int lateness;
  final int compliance;

  const _AutoRatingDisplay({
    required this.lateness,
    required this.compliance,
  });

  @override
  Widget build(BuildContext context) {
    final avg = ((lateness + compliance) / 2).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BGNColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(TablerIcons.calculator,
              size: 14, color: BGNColors.textSecondary),
          const SizedBox(width: 8),
          const Text('Rata-rata rating',
              style: TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
          const Spacer(),
          Row(
            children: List.generate(5, (i) {
              final filled = i < avg;
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  filled ? TablerIcons.star_filled : TablerIcons.star,
                  size: 16,
                  color: filled ? BGNColors.warning : BGNColors.border,
                ),
              );
            }),
          ),
          const SizedBox(width: 6),
          Text('$avg/5',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: BGNColors.textPrimary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Condition indicator
// ═══════════════════════════════════════════════════════════

class _ConditionIndicator extends StatelessWidget {
  final bool adaMasalah;
  final String ringkasan;

  const _ConditionIndicator(
      {required this.adaMasalah, required this.ringkasan});

  @override
  Widget build(BuildContext context) {
    final bg = adaMasalah ? BGNColors.dangerLight : BGNColors.primaryLight;
    final color = adaMasalah ? BGNColors.danger : BGNColors.primary;
    final icon =
        adaMasalah ? TablerIcons.alert_triangle : TablerIcons.circle_check;
    final text = adaMasalah ? ringkasan : 'Kondisi kemasan baik';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Error banner
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(TablerIcons.alert_circle,
            size: 14, color: BGNColors.danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message,
              style:
                  const TextStyle(fontSize: 10, color: BGNColors.danger)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Success banner
// ═══════════════════════════════════════════════════════════

class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BGNColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(children: [
        Icon(TablerIcons.circle_check, size: 18, color: BGNColors.primary),
        SizedBox(width: 8),
        Text('Penerimaan berhasil dikonfirmasi',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: BGNColors.primary)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Submit button
// ═══════════════════════════════════════════════════════════

class _SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final bool submitSuccess;
  final VoidCallback onSubmit;

  const _SubmitButton({
    required this.isSubmitting,
    required this.submitSuccess,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isSubmitting || submitSuccess;

    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (submitSuccess) {
      bg = BGNColors.primaryLight;
      fg = BGNColors.primary;
      label = 'Penerimaan terkonfirmasi';
      icon = TablerIcons.circle_check;
    } else if (isSubmitting) {
      bg = BGNColors.primary;
      fg = Colors.white;
      label = 'Menyimpan...';
      icon = TablerIcons.loader_2;
    } else {
      bg = BGNColors.primary;
      fg = Colors.white;
      label = 'Konfirmasi penerimaan';
      icon = TablerIcons.clipboard_check;
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
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}