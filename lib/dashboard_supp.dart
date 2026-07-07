import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'chat_inbox_page.dart';
import 'distribusi/providers/auth_provider.dart';
import 'draft_store.dart';
import 'inspection.dart';
import 'login.dart';
import 'marketplace.dart';
import 'order_supplier.dart';
import 'prepare_order_page.dart';
import 'supplier_products_page.dart';
import 'profile_supplier.dart';
import 'services/procurement_api.dart';

class DashboardSuppPage extends StatefulWidget {
  const DashboardSuppPage({super.key});

  @override
  State<DashboardSuppPage> createState() => _DashboardSuppPageState();
}

class _DashboardSuppPageState extends State<DashboardSuppPage> {
  int _newOrders = 0;
  List<Map<String, dynamic>> _apiOrders = [];
  List<Map<String, dynamic>> _supplierProducts = [];
  List<Map<String, dynamic>> get _approvedOrders => _apiOrders.where((o) => (o['status'] as String?) == 'Approved' && (o['payment_status'] as String?) == 'Paid').toList();
  List<Map<String, dynamic>> get _shippedOrders => _apiOrders.where((o) => (o['status'] as String?) == 'Shipped').toList();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    DraftStore.incomingNotifier.addListener(_refresh);
    _refresh();
    _fetchOrders();
    _fetchSupplierProducts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchOrders();
        _fetchSupplierProducts();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    DraftStore.incomingNotifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _newOrders = DraftStore.incomingOrders.where((o) => o['status'] == 'Baru').length;
    });
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.get(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/orders'),
        headers: {
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
        final sId = auth.supplierId;
        _apiOrders = data
            .cast<Map<String, dynamic>>()
            .where((o) => o['supplier_id'].toString() == sId)
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _fetchSupplierProducts() async {
    if (!mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.get(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/supplier-products'),
        headers: {
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
        final sId = auth.supplierId;
        _supplierProducts = data
            .cast<Map<String, dynamic>>()
            .where((p) => p['supplier_id'].toString() == sId)
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS tidak aktif. Aktifkan lokasi di pengaturan.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi diblokir permanen. Buka pengaturan aplikasi.');
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ),
    );
  }

  Future<String> _getAlamat(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return 'Alamat tidak ditemukan';
      final p = placemarks.first;
      final parts = [
        if (p.street != null && p.street!.isNotEmpty) p.street,
        if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
        if (p.locality != null && p.locality!.isNotEmpty) p.locality,
        if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) p.subAdministrativeArea,
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea,
      ];
      return parts.take(3).join(', ');
    } catch (_) {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
  }

  String _formatKoordinat(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(5)}° $latDir, ${lng.abs().toStringAsFixed(5)}° $lngDir';
  }

  Future<String> _addWatermark({
    required String imagePath,
    required String date,
    required String time,
    required double latitude,
    required double longitude,
    required String address,
    required String supplier,
  }) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;
    final w = original.width;
    final h = original.height;
    final s = w / 1920;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    canvas.drawImage(original, Offset.zero, Paint());

    final barH = 280.0 * s.clamp(0.5, 2.0);
    final barPaint = Paint()..color = const Color.fromARGB(180, 0, 0, 0);
    canvas.drawRect(Rect.fromLTWH(0, h - barH, w.toDouble(), barH), barPaint);

    final fSize = 48.0 * s.clamp(0.5, 2.0);
    final padX = 18.0 * s.clamp(0.5, 2.0);
    final padY = 14.0 * s.clamp(0.5, 2.0);
    double y = h - barH + padY;

    void drawLine(String text, {double? size, bool mono = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontSize: size ?? fSize,
            fontWeight: FontWeight.w500,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout(maxWidth: w * 0.7);
      tp.paint(canvas, Offset(padX, y));
      y += tp.height + 4;
    }

    drawLine('$date  $time');
    drawLine(_formatKoordinat(latitude, longitude), size: fSize * 0.85, mono: true);
    drawLine(address, size: fSize * 0.85);
    drawLine('Supplier: $supplier', size: fSize * 0.85);

    final badgeTp = TextPainter(
      text: const TextSpan(
        text: 'BGN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    badgeTp.layout();
    badgeTp.paint(canvas, Offset(w - badgeTp.width - padX, h - barH + padY));

    final picture = recorder.endRecording();
    final watermarked = await picture.toImage(w, h);
    final rawPixels = await watermarked.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (rawPixels == null) throw Exception('Gagal encode foto watermark');
    final img.Image decoded = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: rawPixels.buffer,
      numChannels: 4,
    );
    final jpegBytes = img.encodeJpg(decoded, quality: 85);
    final outPath = imagePath.replaceFirst(RegExp(r'\.\w+$'), '_watermarked.jpg');
    await File(outPath).writeAsBytes(jpegBytes);
    try { await file.delete(); } catch (_) {}

    return outPath;
  }

  Future<void> _markAsReceived(Map<String, dynamic> order) async {
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
    if (picked == null) return;

    try {
      await initializeDateFormatting('id_ID');
      final position = await _getLocation();
      final alamat = await _getAlamat(position.latitude, position.longitude);
      final now = DateTime.now();
      final tanggal = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
      final jam = DateFormat('HH:mm').format(now);
      final supplier = order['supplier_name'] as String? ?? 'Supplier';
      final wmPath = await _addWatermark(
        imagePath: picked.path,
        date: tanggal,
        time: jam,
        latitude: position.latitude,
        longitude: position.longitude,
        address: alamat,
        supplier: supplier,
      );

      final auth = context.read<AuthProvider>();
      final photoUrl = await ProcurementApi.uploadPhoto(wmPath, sppgId: auth.sppgId, role: auth.currentRole);

      final poId = order['id'];
      final res = await http.post(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/orders/$poId/supplier-status'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
        body: jsonEncode({
          'supplier_status': 'Diterima',
          'photo_before_shipping': photoUrl,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang telah diterima'), backgroundColor: Color(0xFF4CAF50)),
        );
        _fetchOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal (${res.statusCode})'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.redAccent,
        ));
      }
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

  int get _notifCount => _newOrders + _approvedOrders.length;

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 35, 35, 35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: Color(0xFF498CC8), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Notifikasi',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _notifItem(
              Icons.receipt_long,
              'Pesanan Masuk',
              '${_newOrders + _approvedOrders.length} pesanan baru',
              _newOrders + _approvedOrders.length,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderSupplierPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifItem(IconData icon, String title, String subtitle, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 47, 47, 47),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF498CC8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF498CC8), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Supplier',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('Portal', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatInboxPage()),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: _showNotifications,
              ),
              if (_notifCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$_notifCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: DraftStore.incomingNotifier,
              builder: (_, __) => _buildStatsRow(),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Produk Saya'),
            const SizedBox(height: 8),
            _buildProductList(),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: DraftStore.incomingNotifier,
              builder: (_, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Pesanan Masuk', onLihatSemua: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrderSupplierPage()),
                    ).then((_) => _fetchOrders());
                  }),
                  const SizedBox(height: 8),
                  _buildOrderList(),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 35, 35, 35),
        selectedItemColor: const Color(0xFF1A8FCC),
        unselectedItemColor: const Color.fromARGB(255, 133, 133, 133),
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MarketplacePage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Marketplace'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color.fromARGB(255, 35, 35, 35),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2640), Color(0xFF135B92)],
              ),
            ),
            accountName: Text(context.read<AuthProvider>().activeUser.unit, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            accountEmail: Text(context.read<AuthProvider>().activeUser.name, style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176))),
            currentAccountPicture: CircleAvatar(
              backgroundColor: const Color.fromARGB(255, 40, 40, 40),
              child: const Icon(Icons.store, color: Colors.white, size: 32),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Color(0xFF498CC8)),
            title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
            selected: true,
            selectedTileColor: const Color(0xFF498CC8).withValues(alpha: 0.1),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2, color: Color(0xFF498CC8)),
            title: const Text('Produk Saya', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupplierProductsPage()),
              ).then((_) => _fetchSupplierProducts());
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified, color: Color(0xFF498CC8)),
            title: const Text('Hasil QC', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InspectionPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Color(0xFF498CC8)),
            title: const Text('Pesanan', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderSupplierPage()),
              ).then((_) => _fetchOrders());
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Color(0xFF498CC8)),
            title: const Text('Profil', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSupplierPage()),
              );
            },
          ),
          const Spacer(),
          const Divider(color: Color.fromARGB(255, 60, 60, 60)),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE55555)),
            title: const Text('Logout', style: TextStyle(color: Color(0xFFE55555))),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Tidak'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Ya'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              DraftStore.loggedInUser = '';
              DraftStore.loggedInRole = '';
              if (!context.mounted) return;
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              context.go('/login-legacy');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2640), Color(0xFF135B92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.read<AuthProvider>().activeUser.unit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.read<AuthProvider>().activeUser.name,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 176, 176, 176),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A8FCC).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1A8FCC).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                SizedBox(width: 6),
                Text(
                  'Terverifikasi',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final orderCount = DraftStore.incomingOrders.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.inventory_2, '${_supplierProducts.length}', 'Produk'),
          _statDivider(),
          _statItem(Icons.receipt_long, '$orderCount', 'Pesanan'),
          _statDivider(),
          _statItem(Icons.attach_money, 'Rp4,2jt', 'Pendapatan'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF498CC8), size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color.fromARGB(255, 133, 133, 133),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 40,
      color: const Color.fromARGB(255, 60, 60, 60),
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onLihatSemua}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onLihatSemua ?? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupplierProductsPage()),
              ).then((_) => _fetchSupplierProducts());
            },
            child: const Text(
              'Lihat Semua',
              style: TextStyle(
                color: Color(0xFF498CC8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp0';
    final num val = (price is num) ? price : double.tryParse(price.toString()) ?? 0;
    return 'Rp${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _stockStatus(dynamic stock) {
    final s = (stock is num) ? stock.toInt() : int.tryParse(stock.toString()) ?? 0;
    if (s <= 0) return 'Habis';
    if (s <= 20) return 'Terbatas';
    return 'Tersedia';
  }

  Widget _buildProductList() {
    final preview = _supplierProducts.take(3).toList();

    if (preview.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 47, 47, 47),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Belum ada produk',
            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 14),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(preview.length, (i) {
          final p = preview[i];
          return _productItem(p, i < preview.length - 1);
        }),
      ),
    );
  }

  Widget _productItem(Map<String, dynamic> p, bool showBorder) {
    final name = p['name'] as String? ?? '';
    final stock = p['stock'];
    final unit = p['unit'] as String? ?? '';
    final price = _formatPrice(p['price']);
    final status = _stockStatus(stock);
    final stockLabel = '${stock ?? 0} $unit';

    final statusColor = status == 'Tersedia'
        ? const Color(0xFF4CAF50)
        : status == 'Terbatas'
            ? Colors.orange
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(bottom: BorderSide(color: Color.fromARGB(255, 60, 60, 60)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 40, 40, 40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.eco, color: Color(0xFF498CC8), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$stockLabel • $price',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 133, 133, 133),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    final local = DraftStore.incomingOrders.toList();
    final hasAny = local.isNotEmpty || _approvedOrders.isNotEmpty || _shippedOrders.isNotEmpty;

    if (!hasAny) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 47, 47, 47),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Belum ada pesanan masuk',
            style: TextStyle(
              color: Color.fromARGB(255, 133, 133, 133),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (local.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 47, 47, 47),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: List.generate(local.length, (i) {
                return _orderItem(local[i], i < local.length - 1);
              }),
            ),
          ),
        if (_approvedOrders.isNotEmpty) ...[
          if (local.isNotEmpty) const SizedBox(height: 16),
          ...List.generate(_approvedOrders.length, (i) {
            return _buildApiOrderCard(_approvedOrders[i], i < _approvedOrders.length - 1, false);
          }),
        ],
        if (_shippedOrders.isNotEmpty) ...[
          if (local.isNotEmpty || _approvedOrders.isNotEmpty) const SizedBox(height: 16),
          ...List.generate(_shippedOrders.length, (i) {
            return _buildApiOrderCard(_shippedOrders[i], i < _shippedOrders.length - 1, true);
          }),
        ],
      ],
    );
  }

  Widget _buildApiOrderCard(Map<String, dynamic> order, bool showBorder, bool isShipped) {
    final items = order['items'] as List<dynamic>? ?? [];
    final supplierName = order['supplier_name'] as String? ?? '-';
    final isShippedValue = isShipped;
    String date = '';
    try {
      final dt = DateTime.parse(order['order_date'] as String).toLocal();
      date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {}

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, showBorder ? 8 : 0),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(
          color: isShippedValue ? const Color(0xFFFFA726) : const Color(0xFF1A8FCC), width: 4,
        )),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 40, 40, 40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(MaterialCommunityIcons.truck, color: Color(0xFF498CC8), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PO #${order['id']}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text('$supplierName • $date',
                        style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isShippedValue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Shipped',
                      style: TextStyle(color: Color(0xFFFFA726), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const Divider(color: Color.fromARGB(255, 60, 60, 60), height: 20),
              ...items.asMap().entries.map((entry) {
                final item = entry.value as Map<String, dynamic>;
                final qty = (item['quantity'] ?? 0).toDouble();
                return Padding(
                  padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 40, 40, 40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: Color.fromARGB(255, 120, 120, 120), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item['name'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text('${qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1)} kg',
                        style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (isShippedValue) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsReceived(order),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Barang Sampai', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final items = order['items'] as List<dynamic>? ?? [];
                    final first = items.isNotEmpty ? items[0] as Map<String, dynamic> : null;
                    final adapted = <String, dynamic>{
                      '_orderId': order['id'],
                      'item': first != null ? '${first['name']}' : 'PO #${order['id']}',
                      'supplier': order['supplier_name'] ?? '-',
                      'qty': first != null ? '${(first['quantity'] ?? 0).toDouble()} kg' : '',
                      'date': date,
                      'status': 'Baru',
                    };
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrepareOrderPage(order: adapted),
                      ),
                    );
                    _fetchOrders();
                  },
                  icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                  label: const Text('Siapkan Pesanan', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A8FCC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _orderItem(Map<String, dynamic> order, bool showBorder) {
    final item = order['item'] as String? ?? '';
    final qty = order['qty'] as String? ?? '';
    final date = order['date'] as String? ?? '';
    final status = order['status'] as String? ?? 'Baru';
    final displayDate = date.isEmpty ? 'Segera' : date;
    final statusColor = status == 'Baru'
        ? const Color(0xFF1A8FCC)
        : status == 'Selesai'
            ? const Color(0xFF4CAF50)
            : const Color(0xFFD4A843);
    final statusBg = status == 'Baru'
        ? const Color(0xFF1A8FCC).withValues(alpha: 0.12)
        : status == 'Selesai'
            ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
            : const Color(0xFFD4A843).withValues(alpha: 0.12);

    return Builder(
      builder: (ctx) => GestureDetector(
        onTap: status == 'Selesai'
            ? null
            : () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (context) => PrepareOrderPage(order: order),
                  ),
                );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: showBorder
                ? Border(
                    bottom: const BorderSide(color: Color.fromARGB(255, 60, 60, 60)),
                    left: status == 'Selesai'
                        ? const BorderSide(color: Color(0xFF4CAF50), width: 4)
                        : BorderSide.none,
                  )
                : status == 'Selesai'
                    ? const Border(left: BorderSide(color: Color(0xFF4CAF50), width: 4))
                    : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 40, 40, 40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(MaterialCommunityIcons.truck, color: Color(0xFF498CC8), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qty • $displayDate',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 133, 133, 133),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
