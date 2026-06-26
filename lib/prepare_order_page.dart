import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'draft_store.dart';
import 'distribusi/providers/auth_provider.dart';
import 'services/procurement_api.dart';

class PrepareOrderPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const PrepareOrderPage({super.key, required this.order});

  @override
  State<PrepareOrderPage> createState() => _PrepareOrderPageState();
}

class _PrepareOrderPageState extends State<PrepareOrderPage> {
  late String _status;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _status = widget.order['status'] as String? ?? 'Baru';
  }

  void _updateStatus(String newStatus, {String? photoPath}) {
    if (photoPath != null) {
      _photoPath = photoPath;
    }
    final id = widget.order['_orderId'];
    final idx = DraftStore.incomingOrders.indexWhere((o) => o['_orderId'] == id);
    if (idx >= 0) {
      DraftStore.incomingOrders[idx]['status'] = newStatus;
      if (photoPath != null) {
        DraftStore.incomingOrders[idx]['supplierPhoto'] = photoPath;
      }
      DraftStore.incomingNotifier.value++;
    }
    setState(() => _status = newStatus);
  }

  Future<String?> _pickImage() async {
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
    if (source == null) return null;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1920,
    );
    return picked?.path;
  }

  Future<void> _acceptWithPhoto() async {
    String? photoUrl;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PhotoDialog(
        onPick: () async {
          final path = await _pickImage();
          if (path != null) photoUrl = path;
          return path;
        },
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed == true && photoUrl != null) {
      _photoPath = photoUrl;
      _updateStatus('Diproses', photoPath: photoUrl);
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
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final item = o['item'] as String? ?? '';
    final supplier = o['supplier'] as String? ?? '';
    final qty = o['qty'] as String? ?? '';
    final date = o['date'] as String? ?? '';
    final time = o['time'] as String? ?? '';
    final address = o['address'] as String? ?? '';
    final notes = o['notes'] as String? ?? '';
    final imageUrl = o['imageUrl'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Siapkan Pesanan',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBanner(),
            const SizedBox(height: 20),
            _buildProductCard(item, qty, imageUrl),
            const SizedBox(height: 16),
            _buildInfoCard(item, supplier, qty, date, time, address, notes),
            const SizedBox(height: 20),
            _buildSectionTitle('Catatan Pembeli'),
            const SizedBox(height: 8),
            _buildNotes(notes),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color bgColor;
    String label;
    IconData icon;

    switch (_status) {
      case 'Diproses':
        bgColor = const Color(0xFFD4A843).withValues(alpha: 0.15);
        label = 'Pesanan sedang disiapkan';
        icon = Icons.inventory_2;
        break;
      case 'Siap':
        bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.15);
        label = 'Pesanan siap dikirim';
        icon = Icons.check_circle;
        break;
      default:
        bgColor = const Color(0xFF1A8FCC).withValues(alpha: 0.15);
        label = 'Pesanan baru, perlu diproses';
        icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _status == 'Diproses'
              ? const Color(0xFFD4A843).withValues(alpha: 0.3)
              : _status == 'Siap'
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                  : const Color(0xFF1A8FCC).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: _status == 'Diproses' ? const Color(0xFFD4A843) : _status == 'Siap' ? const Color(0xFF4CAF50) : const Color(0xFF1A8FCC), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status == 'Baru' ? 'Pesanan Baru' : _status,
                  style: TextStyle(
                    color: _status == 'Diproses' ? const Color(0xFFD4A843) : _status == 'Siap' ? const Color(0xFF4CAF50) : const Color(0xFF1A8FCC),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 176, 176, 176),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(String item, String qty, String imageUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFF1A8FCC), width: 5),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _productPlaceholder(item),
                    )
                  : _productPlaceholder(item),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 73, 143, 200),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  qty,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productPlaceholder(String item) {
    return Container(
      color: const Color.fromARGB(255, 40, 40, 40),
      child: const Icon(Icons.eco, color: Colors.grey, size: 32),
    );
  }

  Widget _buildInfoCard(String item, String supplier, String qty, String date, String time,
      String address, String notes) {
    final displayDate = date.isEmpty ? 'Belum ditentukan' : date;
    final displayTime = time.isEmpty ? '-' : time;
    final jadwal = date.isEmpty ? displayDate : '$displayDate • $displayTime';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _detailRow(Icons.store, 'Dari', 'SPPG Jakarta Pusat'),
          const Divider(color: Color.fromARGB(255, 60, 60, 60), height: 20),
          _detailRow(Icons.calendar_today, 'Jadwal Kirim', jadwal),
          if (address.isNotEmpty) ...[
            const Divider(color: Color.fromARGB(255, 60, 60, 60), height: 20),
            _detailRow(Icons.location_on_outlined, 'Lokasi Tujuan', address),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF498CC8), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color.fromARGB(255, 133, 133, 133),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildNotes(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        notes.isEmpty ? 'Tidak ada catatan' : notes,
        style: TextStyle(
          color: notes.isEmpty ? const Color.fromARGB(255, 133, 133, 133) : Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_status == 'Siap') {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final scaffold = ScaffoldMessenger.of(context);
                final orderId = widget.order['_orderId'];
                if (orderId is! int) {
                  scaffold.showSnackBar(const SnackBar(
                    content: Text('ID pesanan tidak valid'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                if (_photoPath == null) {
                  scaffold.showSnackBar(const SnackBar(
                    content: Text('Foto barang belum tersedia'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                try {
                  final auth = context.read<AuthProvider>();
                  scaffold.showSnackBar(const SnackBar(
                    content: Text('Mengirim foto...'),
                    backgroundColor: Color(0xFF1A8FCC),
                    duration: Duration(seconds: 1),
                  ));
                  final photoUrl =
                      await ProcurementApi.uploadPhoto(_photoPath!, sppgId: auth.sppgId, role: auth.currentRole);
                  await ProcurementApi.updateSupplierStatus(
                      orderId, photoUrl, sppgId: auth.sppgId, role: auth.currentRole);
                  final idx = DraftStore.incomingOrders
                      .indexWhere((o) => o['_orderId'] == orderId);
                  if (idx >= 0) {
                    DraftStore.incomingOrders[idx]['status'] = 'Siap';
                    DraftStore.incomingNotifier.value++;
                  }
                  DraftStore.markReady(widget.order);
                  if (!mounted) return;
                  scaffold.showSnackBar(const SnackBar(
                    content: Text('Pesanan sudah siap dikirim ke SPPG'),
                    backgroundColor: Color(0xFF1B5E20),
                  ));
                  Navigator.pop(context);
                } catch (e) {
                  if (!mounted) return;
                  scaffold.showSnackBar(SnackBar(
                    content: Text('Gagal: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              child: const Center(
                child: Text(
                  'Tandai Terkirim',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _status == 'Baru'
                    ? _acceptWithPhoto
                    : () => _updateStatus('Siap'),
                child: Center(
                  child: Text(
                    _status == 'Baru' ? 'Terima Pesanan' : 'Tandai Siap',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_status == 'Diproses') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => _updateStatus('Siap'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4CAF50)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Langsung Tandai Siap',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoDialog extends StatefulWidget {
  final Future<String?> Function() onPick;
  final VoidCallback onConfirm;

  const _PhotoDialog({required this.onPick, required this.onConfirm});

  @override
  State<_PhotoDialog> createState() => _PhotoDialogState();
}

class _PhotoDialogState extends State<_PhotoDialog> {
  String? _photoUrl;

  Future<void> _pick() async {
    final path = await widget.onPick();
    if (path != null) {
      setState(() => _photoUrl = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color.fromARGB(255, 47, 47, 47),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Upload Foto Barang',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ambil foto barang yang sudah disiapkan sebelum menerima pesanan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_photoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: Image.file(
                    File(_photoUrl!),
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
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.refresh, color: Color(0xFF498CC8), size: 18),
                label: const Text('Ganti Foto', style: TextStyle(color: Color(0xFF498CC8))),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 30, 30, 30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF498CC8).withValues(alpha: 0.3)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pick,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo, color: Color(0xFF498CC8), size: 36),
                          SizedBox(height: 6),
                          Text(
                            'Upload Foto',
                            style: TextStyle(color: Color(0xFF498CC8), fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kamera atau Galeri',
                            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color.fromARGB(255, 100, 100, 100)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Batal', style: TextStyle(color: Color.fromARGB(255, 176, 176, 176))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _photoUrl != null
                          ? const LinearGradient(colors: [Color(0xFF135B92), Color(0xFF1A8FCC)])
                          : null,
                      color: _photoUrl == null ? const Color.fromARGB(255, 60, 60, 60) : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _photoUrl != null ? widget.onConfirm : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: Text(
                            'Konfirmasi',
                            style: TextStyle(
                              color: _photoUrl != null ? Colors.white : const Color.fromARGB(255, 100, 100, 100),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
