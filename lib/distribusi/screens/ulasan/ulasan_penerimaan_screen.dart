// lib/screens/ulasan/ulasan_penerimaan_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/providers/pengiriman_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/community_receipt_service.dart';
import 'package:bgn/distribusi/theme/colors.dart';

class UlasanPenerimaanScreen extends StatefulWidget {
  const UlasanPenerimaanScreen({super.key});

  @override
  State<UlasanPenerimaanScreen> createState() => _UlasanPenerimaanScreenState();
}

class _UlasanPenerimaanScreenState extends State<UlasanPenerimaanScreen> {
  final Map<int, String> _answers = {};
  final _feedbackCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];
  final List<Offset> _signaturePoints = [];
  final _service = CommunityReceiptService(ApiClient());
  PengirimanModel? _selectedPackaging;
  bool _isSigning = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PengirimanProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _selectAnswer(int question, String value) {
    setState(() => _answers[question] = value);
  }

  void _clearSignature() {
    setState(() {
      _signaturePoints.clear();
      _isSigning = false;
    });
  }

  Future<void> _pickFromCamera() async {
    if (_photos.length >= 5) { _showMaxAlert(); return; }
    final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;
    final XFile? foto = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
      maxHeight: 960,
    );
    if (foto != null) setState(() => _photos.add(foto));
  }

  Future<void> _pickFromGallery() async {
    if (_photos.length >= 5) {
      _showMaxAlert();
      return;
    }
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1280,
      maxHeight: 960,
    );
    if (foto != null) setState(() => _photos.add(foto));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _showMaxAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Maksimal 5 foto'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _allAnswered =>
      List.generate(6, (i) => i + 1).every((q) => _answers.containsKey(q));

  bool get _canSubmit =>
      _selectedPackaging != null &&
      _allAnswered &&
      _signaturePoints.isNotEmpty &&
      !_isLoading;

  Widget _buildPackagingDropdown() {
    final pengiriman = context.watch<PengirimanProvider>().pengirimanList;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BGNColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Pengiriman',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BGNColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: BGNColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BGNColors.border),
            ),
            child: PopupMenuButton<PengirimanModel>(
              initialValue: _selectedPackaging,
              onSelected: (val) {
                setState(() => _selectedPackaging = val);
              },
              itemBuilder: (context) => pengiriman.map((p) {
                return PopupMenuItem<PengirimanModel>(
                  value: p,
                  child: Text(
                    '#${p.id} — ${p.alamat} (${p.kategori})',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      TablerIcons.package,
                      size: 18,
                      color: BGNColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedPackaging != null
                            ? '#${_selectedPackaging!.id} — ${_selectedPackaging!.alamat}'
                            : '-- Pilih pengiriman --',
                        style: TextStyle(
                          fontSize: 13,
                          color: _selectedPackaging != null
                              ? BGNColors.textPrimary
                              : BGNColors.textHint,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      TablerIcons.chevron_down,
                      size: 16,
                      color: BGNColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _signatureToBase64() async {
    if (_signaturePoints.isEmpty) return '';
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < _signaturePoints.length - 1; i++) {
      canvas.drawLine(_signaturePoints[i], _signaturePoints[i + 1], paint);
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(400, 100);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return '';
    final base64Str = base64Encode(byteData.buffer.asUint8List());
    return 'data:image/png;base64,$base64Str';
  }

  Future<String> _uploadPhotos() async {
    final urls = <String>[];
    for (final photo in _photos) {
      try {
        Uint8List? bytes;
        if (kIsWeb) bytes = await photo.readAsBytes();
        final url = await _service.uploadPhoto(photo.path, bytes: bytes);
        if (url.isNotEmpty) urls.add(url);
      } catch (_) {
        // skip failed upload
      }
    }
    return urls.join(',');
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final digitalSignature = await _signatureToBase64();
      final photoUrls = await _uploadPhotos();

      final answerLabels = {
        1: {'positif': 'Lengkap', 'negatif': 'Kurang Lengkap'},
        2: {'positif': 'Utuh', 'negatif': 'Cacat/Tumpah'},
        3: {'positif': 'Bersih', 'negatif': 'Kotor'},
        4: {'positif': 'Segar/Harum', 'negatif': 'Berbau/Basi'},
        5: {'positif': 'Tidak Ada', 'negatif': 'Ada'},
        6: {'positif': 'Enak', 'negatif': 'Tidak Enak'},
      };

      await _service.submit(
        packagingLogId: _selectedPackaging!.id,
        email: auth.email,
        reviewerName: auth.email == null ? auth.activeUser.name : null,
        reviewerSchool: auth.email == null ? auth.activeUser.unit : null,
        kelengkapan: answerLabels[1]![_answers[1]]!,
        keutuhan: answerLabels[2]![_answers[2]]!,
        kebersihan: answerLabels[3]![_answers[3]]!,
        bau: answerLabels[4]![_answers[4]]!,
        bendaAsing: answerLabels[5]![_answers[5]]!,
        rasa: answerLabels[6]![_answers[6]]!,
        keterangan: _feedbackCtrl.text,
        reviewPhotoUrl: photoUrls.isNotEmpty ? photoUrls : null,
        digitalSignature: digitalSignature.isNotEmpty ? digitalSignature : null,
        sppgId: int.tryParse(auth.sppgId ?? ''),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ulasan berhasil dikirim'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim: ${e.toString()}'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _buildHeader(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(color: Color(0xFF0F172A)),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  TablerIcons.heart_handshake,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SI-GIZI MOBILE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Suara Masyarakat & Wali Murid',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Text(
                  'PM PORTAL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildPackagingDropdown(),
                const SizedBox(height: 12),
                _QuestionCard(
                  number: 1,
                  question: 'Kelengkapan Menu Makanan',
                  positifLabel: 'Lengkap',
                  negatifLabel: 'Kurang Lengkap',
                  positifIcon: TablerIcons.circle_check,
                  negatifIcon: TablerIcons.alert_triangle,
                  selected: _answers[1],
                  onSelect: (v) => _selectAnswer(1, v),
                ),
                const SizedBox(height: 10),
                _QuestionCard(
                  number: 2,
                  question: 'Keutuhan Makanan & Kemasan',
                  positifLabel: 'Utuh / Rapi',
                  negatifLabel: 'Cacat / Tumpah',
                  positifIcon: TablerIcons.circle_check,
                  negatifIcon: TablerIcons.alert_triangle,
                  selected: _answers[2],
                  onSelect: (v) => _selectAnswer(2, v),
                ),
                const SizedBox(height: 10),
                _QuestionCard(
                  number: 3,
                  question: 'Kebersihan wadah & makanan',
                  positifLabel: 'Higienis & Bersih',
                  negatifLabel: 'Kotor / Berdebu',
                  positifIcon: TablerIcons.sparkles,
                  negatifIcon: TablerIcons.alert_triangle,
                  selected: _answers[3],
                  onSelect: (v) => _selectAnswer(3, v),
                ),
                const SizedBox(height: 10),
                _QuestionCard(
                  number: 4,
                  question: 'Aroma / Bau Makanan',
                  positifLabel: 'Segar / Harum',
                  negatifLabel: 'Basi / Asam',
                  positifIcon: TablerIcons.circle_check,
                  negatifIcon: TablerIcons.alert_triangle,
                  selected: _answers[4],
                  onSelect: (v) => _selectAnswer(4, v),
                ),
                const SizedBox(height: 10),
                _QuestionCard(
                  number: 5,
                  question: 'Ada Benda Asing / Binatang',
                  positifLabel: 'Tidak Ada',
                  negatifLabel: 'Ada (Ulat/Lalat/dll)',
                  positifIcon: TablerIcons.circle_check,
                  negatifIcon: TablerIcons.alert_triangle,
                  selected: _answers[5],
                  onSelect: (v) => _selectAnswer(5, v),
                ),
                const SizedBox(height: 10),
                _QuestionCard(
                  number: 6,
                  question: 'Rasa Makanan',
                  positifLabel: 'Lezat / Enak',
                  negatifLabel: 'Hambar / Kurang Pas',
                  positifIcon: TablerIcons.thumb_up,
                  negatifIcon: TablerIcons.alert_triangle,
                  selected: _answers[6],
                  onSelect: (v) => _selectAnswer(6, v),
                ),
                const SizedBox(height: 10),
                _FeedbackCard(controller: _feedbackCtrl),
                const SizedBox(height: 16),
                _SectionLabel(
                  label: '3. FOTO BUKTI PENERIMAAN (${_photos.length}/5)',
                ),
                const SizedBox(height: 8),
                _PhotoUploadCard(
                  photos: _photos,
                  onCamera: _pickFromCamera,
                  onGallery: _pickFromGallery,
                  onRemove: _removePhoto,
                ),
                const SizedBox(height: 16),
                const _SectionLabel(
                  label: '4. TANDA TANGAN PENERIMA / WALI MURID',
                ),
                const SizedBox(height: 8),
                _SignatureCard(
                  points: _signaturePoints,
                  isSigning: _isSigning,
                  onPanStart: (details) {
                    setState(() {
                      _isSigning = true;
                      _signaturePoints.add(details.localPosition);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() => _signaturePoints.add(details.localPosition));
                  },
                  onPanEnd: (_) {
                    setState(() => _isSigning = false);
                  },
                  onClear: _clearSignature,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _canSubmit ? const Color(0xFF22C55E) : const Color(0xFF374151),
            disabledBackgroundColor: const Color(0xFF374151),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'KIRIM ULASAN MASYARAKAT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(TablerIcons.send, color: Colors.white, size: 16),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Question Card Widget ────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final int number;
  final String question;
  final String positifLabel;
  final String negatifLabel;
  final String? selected;
  final ValueChanged<String> onSelect;
  final IconData positifIcon;
  final IconData negatifIcon;

  const _QuestionCard({
    required this.number,
    required this.question,
    required this.positifLabel,
    required this.negatifLabel,
    required this.selected,
    required this.onSelect,
    required this.positifIcon,
    required this.negatifIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number) $question',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  label: positifLabel,
                  icon: positifIcon,
                  isSelected: selected == 'positif',
                  backgroundColor: selected == 'positif'
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF22C55E).withValues(alpha: 0.3),
                  onTap: () => onSelect('positif'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillButton(
                  label: negatifLabel,
                  icon: negatifIcon,
                  isSelected: selected == 'negatif',
                  backgroundColor: selected == 'negatif'
                      ? BGNColors.danger
                      : BGNColors.danger.withOpacity(0.3),
                  onTap: () => onSelect('negatif'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color backgroundColor;
  final VoidCallback onTap;
  final IconData? icon;

  const _PillButton({
    required this.label,
    required this.isSelected,
    required this.backgroundColor,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feedback Card (Textarea) ───────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final TextEditingController controller;

  const _FeedbackCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7) Keterangan Lainnya / Feedback',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText:
                  'Contoh: Sayur kurang garam, buah jeruk sangat manis, dll.',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ──────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Photo Upload Card ──────────────────────────────────────

Widget _buildPhotoThumb(XFile photo) {
  if (kIsWeb) {
    return FutureBuilder<Uint8List>(
      future: photo.readAsBytes(),
      builder: (_, snap) {
        if (snap.data == null) return const SizedBox(width: 80, height: 80);
        return Image.memory(
          snap.data!,
          width: 80, height: 80, fit: BoxFit.cover,
          cacheWidth: 160,
        );
      },
    );
  }
  return Image.file(
    File(photo.path),
    width: 80, height: 80, fit: BoxFit.cover,
    cacheWidth: 160,
  );
}

class _PhotoUploadCard extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final void Function(int) onRemove;

  const _PhotoUploadCard({
    required this.photos,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          if (photos.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          _buildPhotoThumb(photos[index]),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => onRemove(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                TablerIcons.x,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (photos.isNotEmpty) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PhotoButton(
                  label: 'Kamera',
                  icon: TablerIcons.camera,
                  onTap: onCamera,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PhotoButton(
                  label: 'Galeri',
                  icon: TablerIcons.photo,
                  onTap: onGallery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PhotoButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Signature Card ─────────────────────────────────────────

class _SignatureCard extends StatelessWidget {
  final List<Offset> points;
  final bool isSigning;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onClear;

  const _SignatureCard({
    required this.points,
    required this.isSigning,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Silakan coret di bawah:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              GestureDetector(
                onTap: onClear,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bersihkan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(TablerIcons.eraser, color: Color(0xFFEF4444), size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onPanStart: onPanStart,
              onPanUpdate: onPanUpdate,
              onPanEnd: onPanEnd,
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF000000),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: CustomPaint(
                  painter: _SignaturePainter(points: points),
                  size: const Size(double.infinity, 100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset> points;

  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}
