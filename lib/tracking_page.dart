import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'draft_store.dart';
import 'distribusi/providers/auth_provider.dart';
import 'services/procurement_api.dart';

class TrackingPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const TrackingPage({super.key, required this.order});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  String _photoUrl = '';
  final _inspectorNameController = TextEditingController();
  final _quantityReceivedController = TextEditingController();
  String _qualityGrade = '';
  final _storageConditionController = TextEditingController();
  final _qcNotesController = TextEditingController();
  final List<List<Offset>> _signaturePoints = [];
  List<Offset> _currentStroke = [];
  bool _isDrawing = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _inspectorNameController.addListener(_onFieldChanged);
    _quantityReceivedController.addListener(_onFieldChanged);
    _storageConditionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _inspectorNameController.removeListener(_onFieldChanged);
    _quantityReceivedController.removeListener(_onFieldChanged);
    _storageConditionController.removeListener(_onFieldChanged);
    _inspectorNameController.dispose();
    _quantityReceivedController.dispose();
    _storageConditionController.dispose();
    _qcNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color.fromARGB(255, 47, 47, 47),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _sourceButton(Icons.camera_alt, 'Kamera', ImageSource.camera),
            _sourceButton(Icons.photo_library, 'Galeri', ImageSource.gallery),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1920,
    );
    if (picked != null) {
      setState(() => _photoUrl = picked.path);
    }
  }

  Widget _sourceButton(IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1A8FCC).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF498CC8), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final apiItems = o['items'] as List<dynamic>? ?? [];
    final firstItem = apiItems.isNotEmpty ? apiItems[0] as Map<String, dynamic> : null;
    final item = o['item'] as String?
        ?? firstItem?['name'] as String?
        ?? '';
    final supplier = o['supplier'] as String?
        ?? o['supplier_name'] as String?
        ?? '';
    final qty = o['qty'] as String?
        ?? (apiItems.isNotEmpty ? '${apiItems.length} item' : '');
    final totalAmount = o['total_amount'] as num?;
    final total = o['total'] as String?
        ?? (totalAmount != null ? _formatPrice(totalAmount.toDouble()) : '');
    final imageUrl = o['imageUrl'] as String? ?? '';
    final address = o['address'] as String? ?? '';
    final supplierPhoto = o['supplierPhoto'] as String? ?? '';
    final photoBeforeShipping = o['photo_before_shipping'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Lacak Pengiriman', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        physics: _isDrawing ? const NeverScrollableScrollPhysics() : null,
        child: Column(
          children: [
            _buildFakeMap(address),
            _buildOrderSummary(item, supplier, qty, total, imageUrl),
            const SizedBox(height: 16),
            _buildTrackingTimeline(),
            const SizedBox(height: 20),
            if (supplierPhoto.isNotEmpty) _buildSupplierPhoto(supplierPhoto),
            if (supplierPhoto.isNotEmpty) const SizedBox(height: 20),
            if (photoBeforeShipping.isNotEmpty) _buildPhotoBeforeShipping(photoBeforeShipping),
            if (photoBeforeShipping.isNotEmpty) const SizedBox(height: 20),
            _buildPhotoProof(),
            const SizedBox(height: 20),
            _buildQcSection(),
            const SizedBox(height: 20),
            _buildAcceptButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFakeMap(String address) {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: Stack(
          children: [
            CustomPaint(
              size: const Size(double.infinity, 260),
              painter: _FakeMapPainter(),
            ),
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.red.shade700, size: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Lokasi Tujuan',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 10,
                              fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
                ),
              ),
            ),
            Positioned(
              top: 60,
              left: MediaQuery.of(context).size.width * 0.25,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Icon(Icons.local_shipping, color: const Color(0xFF1A8FCC), size: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Kurir', style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 47, 47, 47).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: Color(0xFF4CAF50), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kurir sedang menuju ke tujuan',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          if (address.isNotEmpty)
                            Text(
                              address,
                              style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const Text(
                      '± 15 menit',
                      style: TextStyle(color: Color(0xFFD4A843), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(String item, String supplier, String qty, String total, String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color.fromARGB(255, 40, 40, 40),
                        child: const Icon(Icons.image, color: Colors.grey, size: 24),
                      ))
                  : Container(
                      color: const Color.fromARGB(255, 40, 40, 40),
                      child: const Icon(Icons.eco, color: Colors.grey, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: const TextStyle(color: Color.fromARGB(255, 73, 143, 200), fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('$qty • $total', style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A8FCC).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Dikirim', style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline() {
    const stages = [
      _TrackingStage(icon: Icons.inventory_2, title: 'Diproses Supplier', subtitle: 'Supplier menyiapkan pesanan', time: 'Selesai', done: true),
      _TrackingStage(icon: Icons.local_shipping, title: 'Dalam Pengiriman', subtitle: 'Pesanan dalam perjalanan', time: '30 menit lalu', done: true),
      _TrackingStage(icon: Icons.near_me, title: 'Mendekati Tujuan', subtitle: 'Kurir mendekati lokasi SPPG', time: 'Sekarang', done: false, active: true),
      _TrackingStage(icon: Icons.check_circle_outline, title: 'Sampai Tujuan', subtitle: 'Pesanan telah diterima SPPG', time: '', done: false),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status Pengiriman', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...List.generate(stages.length, (i) {
            final stage = stages[i];
            return _buildStageRow(stage, i == 0, i == stages.length - 1);
          }),
        ],
      ),
    );
  }

  Widget _buildStageRow(_TrackingStage stage, bool isFirst, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(child: Container(width: 2, color: stage.done ? const Color(0xFF4CAF50) : const Color.fromARGB(255, 60, 60, 60))),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: stage.active ? const Color(0xFF1A8FCC) : stage.done ? const Color(0xFF4CAF50) : const Color.fromARGB(255, 60, 60, 60),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(stage.done ? Icons.check : stage.active ? Icons.circle : Icons.circle_outlined, color: Colors.white, size: stage.active ? 12 : 14),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: stage.done ? const Color(0xFF4CAF50) : const Color.fromARGB(255, 60, 60, 60))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: isFirst ? 0 : 4, bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(stage.title, style: TextStyle(color: stage.done || stage.active ? Colors.white : const Color.fromARGB(255, 100, 100, 100), fontSize: 14, fontWeight: FontWeight.w600)),
                      if (stage.time.isNotEmpty)
                        Text(stage.time, style: TextStyle(color: stage.active ? const Color(0xFFD4A843) : const Color.fromARGB(255, 100, 100, 100), fontSize: 11, fontWeight: stage.active ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(stage.subtitle, style: TextStyle(color: stage.done || stage.active ? const Color.fromARGB(255, 176, 176, 176) : const Color.fromARGB(255, 80, 80, 80), fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierPhoto(String photoPath) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFFD4A843), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image, color: Color(0xFFD4A843), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Foto Persiapan Supplier',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Barang yang sudah disiapkan oleh supplier', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: Image.file(
                File(photoPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color.fromARGB(255, 30, 30, 30),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey, size: 40),
                      SizedBox(height: 8),
                      Text('Gagal memuat foto', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBeforeShipping(String url) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFF4CAF50), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Foto Sebelum Dikirim',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Tersedia', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Foto barang sebelum dikirim oleh supplier', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color.fromARGB(255, 30, 30, 30),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey, size: 40),
                      SizedBox(height: 8),
                      Text('Gagal memuat foto', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color.fromARGB(255, 30, 30, 30),
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1A8FCC)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double amount) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp${formatter.format(amount)}';
  }

  Widget _buildPhotoProof() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFFD4A843), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt, color: Color(0xFFD4A843), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Foto Bukti Terima',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              if (_photoUrl.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Tersedia', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Foto barang yang sudah diterima sebagai bukti serah terima', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12)),
          const SizedBox(height: 12),
          if (_photoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: double.infinity,
                height: 160,
                child: Image.file(File(_photoUrl), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color.fromARGB(255, 30, 30, 30),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text('Gagal memuat foto', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: Icon(_photoUrl.isNotEmpty ? Icons.refresh : Icons.add_a_photo, color: const Color(0xFF498CC8), size: 18),
              label: Text(
                _photoUrl.isNotEmpty ? 'Ganti Foto' : 'Upload Foto Bukti',
                style: const TextStyle(color: Color(0xFF498CC8)),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFF498CC8).withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptButton() {
    final canAccept = _inspectorNameController.text.trim().isNotEmpty &&
        _qualityGrade.isNotEmpty &&
        int.tryParse(_quantityReceivedController.text.trim()) != null &&
        !_submitting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Opacity(
          opacity: canAccept ? 1.0 : 0.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: canAccept
                  ? const LinearGradient(colors: [Color(0xFF135B92), Color(0xFF1A8FCC)])
                  : const LinearGradient(colors: [Color(0xFF444444), Color(0xFF555555)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: canAccept
                    ? () async {
                        setState(() => _submitting = true);
                        await _submitOrderStatus();
                        DraftStore.markReceived(widget.order);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pesanan telah diterima'),
                            backgroundColor: Color(0xFF1B5E20),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    : null,
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Terima Barang',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQcSection() {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final qtyStr = items.isNotEmpty
        ? items.map((item) {
            final qty = (item['quantity'] ?? 0).toDouble();
            final unit = item['unit'] as String? ?? '';
            final unitStr = unit.isNotEmpty ? ' $unit' : '';
            return '$qty$unitStr';
          }).join('\n')
        : (widget.order['qty'] as String? ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFF1A8FCC), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF1A8FCC), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'QC Digital',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              if (_qualityGrade.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Lengkap', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Periksa kualitas barang sebelum diterima', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12)),
          const SizedBox(height: 16),

          _buildQcLabel('Nama Inspektur'),
          const SizedBox(height: 8),
          _qcTextField(
            controller: _inspectorNameController,
            hint: 'Masukkan nama inspektur',
          ),
          const SizedBox(height: 20),

          _buildQcLabel('Jumlah Diharapkan'),
          const SizedBox(height: 8),
          _buildReadOnlyField(qtyStr),
          const SizedBox(height: 20),

          _buildQcLabel('Jumlah Diterima'),
          const SizedBox(height: 8),
          _qcTextField(
            controller: _quantityReceivedController,
            hint: 'Masukkan jumlah diterima',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          _buildQcLabel('Grade Kualitas'),
          const SizedBox(height: 8),
          _buildGradeSelector(),
          const SizedBox(height: 20),

          _buildQcLabel('Kondisi Penyimpanan'),
          const SizedBox(height: 8),
          _qcTextField(
            controller: _storageConditionController,
            hint: 'Contoh: Normal, Baik, Rusak',
          ),
          const SizedBox(height: 20),

          _buildQcLabel('Catatan'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 30, 30, 30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _qcNotesController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tambahkan catatan kualitas (opsional)',
                hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildQcLabel('Tanda Tangan Digital'),
          const SizedBox(height: 8),
          _buildSignaturePad(),
        ],
      ),
    );
  }

  Widget _buildSignaturePad() {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 30, 30, 30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Listener(
            onPointerDown: (details) {
              setState(() {
                _isDrawing = true;
                _currentStroke = [details.localPosition];
              });
            },
            onPointerMove: (details) {
              setState(() => _currentStroke.add(details.localPosition));
            },
            onPointerUp: (_) {
              setState(() {
                _isDrawing = false;
                if (_currentStroke.isNotEmpty) {
                  _signaturePoints.add(List.from(_currentStroke));
                  _currentStroke = [];
                }
              });
            },
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 25, 25, 25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _signaturePoints.isNotEmpty
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                      : const Color.fromARGB(255, 60, 60, 60),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _signaturePoints,
                    currentStroke: _currentStroke,
                  ),
                  size: const Size(double.infinity, 120),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _signaturePoints.isNotEmpty ? Icons.check_circle_rounded : Icons.draw_rounded,
                      color: _signaturePoints.isNotEmpty ? const Color(0xFF4CAF50) : const Color.fromARGB(255, 100, 100, 100),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _signaturePoints.isNotEmpty ? 'Tertandatangani' : 'Tanda tangan di sini',
                      style: TextStyle(
                        color: _signaturePoints.isNotEmpty ? const Color(0xFF4CAF50) : const Color.fromARGB(255, 100, 100, 100),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (_signaturePoints.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() {
                      _signaturePoints.clear();
                      _currentStroke = [];
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, color: Color(0xFFE53935), size: 14),
                          SizedBox(width: 4),
                          Text('Ulangi', style: TextStyle(color: Color(0xFFE53935), fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
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

  Widget _buildQcLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color.fromARGB(255, 176, 176, 176),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Future<void> _submitOrderStatus() async {
    final poId = widget.order['_orderId'] as int? ?? widget.order['id'] as int? ?? 0;
    final auth = context.read<AuthProvider>();
    final sppgId = auth.sppgId;
    final role = auth.currentRole;
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final qtyExpected = items.fold<double>(0, (sum, item) => sum + ((item['quantity'] ?? 0).toDouble()));
    final qtyReceived = double.tryParse(_quantityReceivedController.text.trim()) ?? 0;

    String photoUrl = '';
    if (_photoUrl.isNotEmpty && !_photoUrl.startsWith('http')) {
      final file = File(_photoUrl);
      if (await file.exists()) {
        photoUrl = await ProcurementApi.uploadPhoto(_photoUrl, sppgId: sppgId, role: role);
      }
    } else if (_photoUrl.startsWith('http')) {
      photoUrl = _photoUrl;
    }

    final inspectionBody = {
      'po_id': poId,
      'inspector_name': _inspectorNameController.text.trim(),
      'quantity_expected': qtyExpected,
      'quantity_received': qtyReceived,
      'quality_grade': _qualityGrade,
      'storage_condition': _storageConditionController.text.trim(),
      'notes': _qcNotesController.text.trim(),
      'status': 'Approved',
      'photo_url': photoUrl,
    };

    final authHeaders = <String, String>{
      'x-user-Sppg-id': sppgId ?? '',
      'x-user-Role': role,
    };

    try {
      await http.post(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/inspections'),
        headers: {'Content-Type': 'application/json', ...authHeaders},
        body: jsonEncode(inspectionBody),
      );
    } catch (_) {}

    try {
      await http.post(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/orders/$poId/status'),
        headers: {'Content-Type': 'application/json', ...authHeaders},
        body: jsonEncode({'status': 'Received'}),
      );
    } catch (_) {}
  }

  Widget _qcTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 30, 30, 30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 25, 25, 25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromARGB(255, 50, 50, 50)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13),
      ),
    );
  }

  Widget _buildGradeSelector() {
    const grades = ['A', 'B', 'C'];
    return Row(
      children: grades.map((grade) {
        final selected = _qualityGrade == grade;
        final Color fillColor;
        final Color borderColor;
        if (grade == 'A') {
          fillColor = const Color(0xFF4CAF50);
          borderColor = const Color(0xFF4CAF50);
        } else if (grade == 'B') {
          fillColor = const Color(0xFFD4A843);
          borderColor = const Color(0xFFD4A843);
        } else {
          fillColor = const Color(0xFFE53935);
          borderColor = const Color(0xFFE53935);
        }
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: grade == 'A' ? 0 : 8,
              right: grade == 'C' ? 0 : 8,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _qualityGrade = grade),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? fillColor.withValues(alpha: 0.15) : const Color.fromARGB(255, 30, 30, 30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? borderColor.withValues(alpha: 0.6) : const Color.fromARGB(255, 50, 50, 50),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      grade,
                      style: TextStyle(
                        color: selected ? fillColor : const Color.fromARGB(255, 100, 100, 100),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      grade == 'A' ? 'Baik' : grade == 'B' ? 'Cukup' : 'Kurang',
                      style: TextStyle(
                        color: selected ? fillColor : const Color.fromARGB(255, 100, 100, 100),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TrackingStage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool done;
  final bool active;

  const _TrackingStage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.done,
    this.active = false,
  });
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF60B0FF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke.length >= 2) {
      paint.color = const Color(0xFF60B0FF).withValues(alpha: 0.7);
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

class _FakeMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..shader = const LinearGradient(
      colors: [Color(0xFF2E5C3E), Color(0xFF3A7A50), Color(0xFF4A8B5E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = const Color(0xFFB0B0B0).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final roadThick = Paint()
      ..color = const Color(0xFFD0D0D0).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width * 0.55, size.height * 0.45), roadThick);
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.45), Offset(size.width * 0.8, size.height * 0.35), roadThick);
    canvas.drawLine(Offset(size.width * 0.8, size.height * 0.35), Offset(size.width, size.height * 0.38), roadThick);

    canvas.drawLine(Offset(size.width * 0.35, size.height * 0.65), Offset(size.width * 0.55, size.height * 0.45), roadPaint);
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.45), Offset(size.width * 0.3, size.height * 0.25), roadPaint);
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.3, size.height * 0.25), roadPaint);

    final buildingPaint = Paint()
      ..color = const Color(0xFFC8B89A).withValues(alpha: 0.4);
    for (int i = 0; i < 6; i++) {
      final bx = 15.0 + i * (size.width / 6);
      final by = size.height * 0.08 + (i % 3) * 25;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, 20, 16), const Radius.circular(3)), buildingPaint);
    }
    for (int i = 0; i < 4; i++) {
      final bx = size.width * 0.6 + i * 28;
      final by = size.height * 0.55 + (i % 2) * 22;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, 18, 14), const Radius.circular(3)), buildingPaint);
    }

    final greenPaint = Paint()
      ..color = const Color(0xFF2D6A3A).withValues(alpha: 0.4);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.78), 30, greenPaint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 22, greenPaint);

    final routePaint = Paint()
      ..color = const Color(0xFF1A8FCC).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.42);
    path.quadraticBezierTo(size.width * 0.35, size.height * 0.38, size.width * 0.45, size.height * 0.44);
    path.quadraticBezierTo(size.width * 0.52, size.height * 0.48, size.width * 0.62, size.height * 0.40);
    canvas.drawPath(path, routePaint);

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x.toDouble(), 0), Offset(x.toDouble(), size.height), dashPaint);
    }
    for (int y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y.toDouble()), Offset(size.width, y.toDouble()), dashPaint);
    }

    final pulsePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.40), 28, pulsePaint);
    final pulsePaint2 = Paint()
      ..color = Colors.red.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.40), 40, pulsePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
