import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image/image.dart' as img;
import 'package:go_router/go_router.dart';
import 'chat_inbox_page.dart';
import 'login.dart';
import 'services/procurement_api.dart';
import 'distribusi/providers/auth_provider.dart';
import 'tracking_page.dart';
import 'distribusi/screens/produksi/rencana_produksi_screen.dart';
import 'qc_checker_page.dart';

class DashboardPage extends StatefulWidget {
  final void Function(Map<String, dynamic> orderItemInfo)? onOrderItem;

  const DashboardPage({super.key, this.onOrderItem});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  int _selectedDayIndex = DateTime.now().weekday - 1;
  Map<String, dynamic>? _health;
  final Set<int> _expandedOrders = {};
  bool _ready = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _ready = true);
      _fetchOrders();
      _checkHealth();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchOrders();
    });
  }

  Future<void> _checkHealth() async {
    try {
      final auth = context.read<AuthProvider>();
      _health = await ProcurementApi.checkHealth(sppgId: auth.sppgId, role: auth.currentRole);
    } catch (_) {
      _health = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Widget _healthRow(String label, dynamic value) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              color: Color.fromARGB(255, 140, 140, 140),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatHealthTime(dynamic isoTime) {
    if (isoTime == null) return '-';
    try {
      final dt = DateTime.parse(isoTime as String).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m:$s WIB';
    } catch (_) {
      return '$isoTime';
    }
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      _orders = await ProcurementApi.fetchOrders(sppgId: auth.sppgId, role: auth.currentRole);
      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _error = 'Gagal terhubung ke server';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _ordersForSelectedDay {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final selectedDate = monday.add(Duration(days: _selectedDayIndex));
    final dateStr =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    final matched = <Map<String, dynamic>>[];
    for (final order in _orders) {
      final orderDate = order['order_date'] as String? ?? '';
      if (orderDate.startsWith(dateStr)) {
        matched.add(order);
      }
    }
    return matched;
  }

  List<Map<String, dynamic>> get _itemsForSelectedDay {
    final items = <Map<String, dynamic>>[];
    for (final order in _ordersForSelectedDay) {
      final orderItems = order['items'] as List<dynamic>? ?? [];
      for (final item in orderItems) {
        final qty = (item['quantity'] ?? 0).toDouble();
        final price = (item['price'] ?? 0).toDouble();
        items.add({
          'name': item['name'] ?? '',
          'quantity': qty,
          'price': price,
          'subtotal': qty * price,
        });
      }
    }
    return items;
  }

  String _formatCurrency(dynamic amount) {
    final n =
        (amount is double ? amount : (amount is int ? amount.toDouble() : 0.0))
            .round();
    if (n == 0) return 'Rp 0';
    final s = n.toString();
    final parts = <String>[];
    for (int i = s.length; i > 0; i -= 3) {
      parts.insert(0, s.substring(i > 3 ? i - 3 : 0, i));
    }
    return 'Rp ${parts.join('.')}';
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        body: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF1A8FCC),
            ),
          ),
        ),
      );
    }
    final orders = _ordersForSelectedDay;
    final flatItems = _itemsForSelectedDay;
    final totalQty = flatItems.fold<double>(
      0,
      (s, i) => s + (i['quantity'] as double),
    );
    final totalAmount = flatItems.fold<double>(
      0,
      (s, i) => s + (i['subtotal'] as double),
    );
    final orderCount = orders.length;

    final role = context.read<AuthProvider>().currentRole;
    final isAccounting = role == 'accounting';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      floatingActionButton: isAccounting
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RencanaProduksiScreen(),
                  ),
                ).then((_) => _fetchOrders());
              },
              backgroundColor: const Color(0xFF4CAF50),
              icon: const Icon(Icons.factory_outlined, color: Colors.white),
              label: const Text(
                'Rencana Produksi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: Color.fromARGB(255, 176, 176, 176),
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
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
              child: const Text(
                'SPPG',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Portal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (_health != null)
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color.fromARGB(255, 30, 30, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _health!['status'] == 'healthy'
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Health Check',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _healthRow('Service', _health!['service']),
                      const SizedBox(height: 8),
                      _healthRow('Status', _health!['status']),
                      const SizedBox(height: 8),
                      _healthRow('Time', _formatHealthTime(_health!['time'])),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Color(0xFF1A8FCC)),
                      ),
                    ),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _health!['status'] == 'healthy'
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                        : const Color(0xFFE53935).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _health!['status'] == 'healthy'
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _health!['service'] ?? 'unknown',
                        style: TextStyle(
                          color: _health!['status'] == 'healthy'
                              ? const Color(0xFF81C784)
                              : const Color(0xFFEF9A9A),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color.fromARGB(255, 176, 176, 176),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatInboxPage()),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color.fromARGB(255, 30, 30, 30),
        child: Column(
          children: [
            Builder(
              builder: (ctx) {
                final auth = ctx.watch<AuthProvider>();
                final name = auth.activeUser.name;
                final role = auth.activeRole.label;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0A2640), Color(0xFF135B92)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Color(0xFF498CC8),
                  size: 20,
                ),
              ),
              title: const Text(
                "Dashboard",
                style: TextStyle(color: Colors.white),
              ),
              selected: true,
              selectedTileColor: const Color.fromARGB(255, 40, 40, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () => Navigator.pop(context),
            ),
            Builder(
              builder: (ctx) {
                final role = ctx.watch<AuthProvider>().currentRole;
                if (role != 'aslab') return const SizedBox.shrink();
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF4CAF50), size: 20),
                      ),
                      title: const Text('QC Checker', style: TextStyle(color: Colors.white)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const QcCheckerPage()));
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                );
              },
            ),
            const Spacer(),
            const Divider(color: Color.fromARGB(255, 50, 50, 50)),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFE53935),
              ),
              title: const Text(
                "Logout",
                style: TextStyle(color: Color(0xFFE53935)),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
                if (!context.mounted) return;
                await context.read<AuthProvider>().logout();
                if (!context.mounted) return;
                context.go('/login-legacy');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF1A8FCC),
                ),
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 30, 30, 30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        color: Color.fromARGB(255, 80, 80, 80),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 176, 176, 176),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _fetchOrders,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A8FCC),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              color: const Color(0xFF1A8FCC),
              backgroundColor: const Color.fromARGB(255, 40, 40, 40),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  children: [
                    _buildSummaryHeader(
                      orderCount,
                      flatItems.length,
                      totalAmount,
                      totalQty,
                    ),
                    const SizedBox(height: 20),
                    _buildDaySelector(),
                    const SizedBox(height: 20),
                    _buildItemSection(orders, flatItems, totalAmount, role),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryHeader(
    int orderCount,
    int itemCount,
    double totalAmount,
    double totalQty,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF135B92).withValues(alpha: 0.15),
            const Color(0xFF1A8FCC).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1A8FCC).withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ringkasan Pesanan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statBox(
                'Pesanan',
                '$orderCount',
                const Color(0xFF60B0FF),
                Icons.receipt_rounded,
              ),
              const SizedBox(width: 6),
              _statBox(
                'Item',
                '$itemCount',
                const Color(0xFF4CAF50),
                Icons.inventory_2_rounded,
              ),
              const SizedBox(width: 6),
              _statBox(
                'Total',
                _formatCurrency(totalAmount),
                const Color(0xFFD4A843),
                Icons.monetization_on_rounded,
              ),
            ],
          ),
          if (totalQty > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_rounded,
                    color: Color.fromARGB(255, 120, 120, 120),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total ${_formatQty(totalQty)} kg bahan baku',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 160, 160, 160),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 30, 30, 30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 12),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
    final monthNames = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final date = monday.add(Duration(days: index));
          final isSelected = _selectedDayIndex == index;
          final isToday =
              date.day == now.day &&
              date.month == now.month &&
              date.year == now.year;
          final dateStr =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final dayOrderCount = _orders
              .where(
                (o) => (o['order_date'] as String? ?? '').startsWith(dateStr),
              )
              .length;

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: Container(
              width: 80,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : const Color.fromARGB(255, 35, 35, 35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1A8FCC).withValues(alpha: 0.5)
                      : isToday
                      ? const Color(0xFF1A8FCC).withValues(alpha: 0.2)
                      : const Color.fromARGB(255, 50, 50, 50),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1A8FCC).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[index],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color.fromARGB(255, 150, 150, 150),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color.fromARGB(255, 180, 180, 180),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (dayOrderCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$dayOrderCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemSection(
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> flatItems,
    double totalAmount,
    String role,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Color(0xFF60B0FF),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  orders.isEmpty ? 'Tidak ada pesanan' : 'Item Pesanan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (flatItems.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${flatItems.length}',
                      style: const TextStyle(
                        color: Color(0xFF60B0FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (flatItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A843).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD4A843).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  _formatCurrency(totalAmount),
                  style: const TextStyle(
                    color: Color(0xFFD4A843),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 30, 30, 30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color.fromARGB(255, 45, 45, 45)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 35, 35, 35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.event_busy_rounded,
                    size: 28,
                    color: Color.fromARGB(255, 80, 80, 80),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tidak ada pesanan',
                  style: TextStyle(
                    color: Color.fromARGB(255, 140, 140, 140),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pilih hari lain untuk melihat pesanan',
                  style: TextStyle(
                    color: Color.fromARGB(255, 90, 90, 90),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          ...orders.map((order) => _buildOrderGroup(order, role)),
      ],
    );
  }

  PopupMenuItem<String> _statusItem(String label, Color color, IconData icon) {
    return PopupMenuItem(
      value: label,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatusChange(int orderId, String status) async {
    if (status == 'Rejected') {
      final reason = await _showRejectionDialog();
      if (reason == null) return;
    }
    try {
      final auth = context.read<AuthProvider>();
      await ProcurementApi.updateOrderStatus(orderId, status, sppgId: auth.sppgId, role: auth.currentRole);
      if (!mounted) return;
      setState(() {
        for (final order in _orders) {
          if ((order['id'] as int) == orderId) {
            order['status'] = status;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status PO #$orderId berhasil diubah ke $status'),
          backgroundColor: const Color(0xFF1A8FCC),
        ),
      );
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  Future<void> _handleSplitOrder(int orderId) async {
    final currentContext = context;
    final confirm = await showDialog<bool>(
      context: currentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 30, 30, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Split PO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin memecah PO #$orderId?',
          style: const TextStyle(
            color: Color.fromARGB(255, 200, 200, 200),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color.fromARGB(255, 140, 140, 140)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Split',
              style: TextStyle(
                color: Color(0xFF1A8FCC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!currentContext.mounted) return;

    final navigator = Navigator.of(currentContext);
    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A8FCC)),
      ),
    );

    try {
      final auth = context.read<AuthProvider>();
      await ProcurementApi.splitOrder(orderId, sppgId: auth.sppgId, role: auth.currentRole);
      navigator.pop(); // Close loading dialog
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('PO #$orderId berhasil di-split'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      _fetchOrders();
    } catch (e) {
      navigator.pop(); // Close loading dialog
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal melakukan split PO: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  Future<String?> _showRejectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 35, 35, 35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Alasan Pembatalan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Masukkan alasan...',
              hintStyle: const TextStyle(
                color: Color.fromARGB(255, 120, 120, 120),
              ),
              filled: true,
              fillColor: const Color.fromARGB(255, 50, 50, 50),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Batal',
                style: TextStyle(color: Color.fromARGB(255, 140, 140, 140)),
              ),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx, controller.text.trim());
              },
              child: const Text(
                'Submit',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderGroup(Map<String, dynamic> order, String role) {
    final orderId = order['id'] as int;
    final orderItems = order['items'] as List<dynamic>? ?? [];
    final status = order['status'] as String? ?? '';
    final isExpanded = _expandedOrders.contains(orderId);
    final isSplit = order['is_split'] == true;
    final supplierStatus = order['supplier_status'] as String? ?? '';
    final paymentStatus = order['payment_status'] as String? ?? '';
    final needPayment = role == 'accounting' && status.toLowerCase() == 'approved' && (paymentStatus.isEmpty || paymentStatus.toLowerCase() == 'unpaid');

    Color statusColor;
    String statusLabel;
    switch (status.toLowerCase()) {
      case 'received':
        statusColor = const Color(0xFF4CAF50);
        statusLabel = 'Diterima';
        break;
      case 'shipped':
        statusColor = const Color(0xFFFFA726);
        statusLabel = 'Dikirim';
        break;
      case 'approved':
        statusColor = const Color(0xFF60B0FF);
        statusLabel = 'Disetujui';
        break;
      case 'rejected':
        statusColor = const Color(0xFFE53935);
        statusLabel = 'Ditolak';
        break;
      default:
        statusColor = const Color(0xFFD4A843);
        statusLabel = status;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 30, 30, 30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color.fromARGB(255, 50, 50, 50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tappable header
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedOrders.remove(orderId);
                  } else {
                    _expandedOrders.add(orderId);
                  }
                });
              },
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_rounded,
                        color: Color(0xFF60B0FF),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PO #$orderId',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (order['supplier_name'] != null &&
                                (order['supplier_name'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    if ((order['supplier_name'] as String) != 'Belum Ditentukan')
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF4CAF50),
                                          size: 14,
                                        ),
                                      ),
                                    Flexible(
                                      child: Text(
                                        order['supplier_name'] as String,
                                        style: const TextStyle(
                                          color: Color.fromARGB(255, 133, 133, 133),
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (role == 'mitra')
                      PopupMenuButton<String>(
                        onSelected: (value) =>
                            _handleStatusChange(orderId, value),
                        offset: const Offset(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: const Color.fromARGB(255, 40, 40, 40),
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Color.fromARGB(255, 140, 140, 140),
                          size: 20,
                        ),
                        itemBuilder: (_) => [
                          _statusItem(
                            'Approved',
                            const Color(0xFF4CAF50),
                            Icons.check_circle_outline,
                          ),
                          _statusItem(
                            'Received',
                            const Color(0xFF60B0FF),
                            Icons.inventory_2_outlined,
                          ),
                          _statusItem(
                            'Rejected',
                            const Color(0xFFE53935),
                            Icons.cancel_outlined,
                          ),
                        ],
                      ),
                    if (role == 'aslab' && supplierStatus.toLowerCase() == 'dikirim' && status.toLowerCase() != 'received')
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrackingPage(order: order),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFFFFA726),
                          size: 20,
                        ),
                        tooltip: 'Inspeksi',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    Transform.rotate(
                      angle: isExpanded ? 3.14159265 : 0,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color.fromARGB(255, 130, 130, 130),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Collapsible items
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isExpanded) ...[
                    const Divider(
                      color: Color.fromARGB(255, 45, 45, 45),
                      height: 1,
                    ),
                    ...orderItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          i == 0 ? 12 : 0,
                          14,
                          i == orderItems.length - 1 ? 14 : 8,
                        ),
                        child: _buildItemCard({
                          'name': item['name'] ?? '',
                          'quantity': (item['quantity'] ?? 0).toDouble(),
                          'price': (item['price'] ?? 0).toDouble(),
                          'subtotal':
                              (item['quantity'] ?? 0).toDouble() *
                              (item['price'] ?? 0).toDouble(),
                          'orderId': orderId,
                          'order': order,
                        }),
                      );
                    }),
                  ],
                  // Split PO Button if order is not yet split and has more than 1 item
                  if (!isSplit && orderItems.length > 1) ...[
                    const Divider(color: Color.fromARGB(255, 45, 45, 45), height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _handleSplitOrder(orderId),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1A8FCC),
                            backgroundColor: const Color(
                              0xFF1A8FCC,
                            ).withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.call_split_rounded, size: 16),
                          label: const Text(
                            'Split PO',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Bayar Button if payment status is empty/null
                  if (needPayment) ...[
                    const Divider(color: Color.fromARGB(255, 45, 45, 45), height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            final auth = context.read<AuthProvider>();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => PaymentBottomSheet(
                                order: order,
                                sppgId: auth.sppgId,
                                role: auth.currentRole,
                                formatCurrency: _formatCurrency,
                                onSuccess: () {
                                  _fetchOrders();
                                },
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4CAF50),
                            backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.payment, size: 16),
                          label: const Text(
                            'Bayar',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final qty = item['quantity'] as double;
    final price = item['price'] as double;
    final subtotal = item['subtotal'] as double;
    final orderId = item['orderId'] as int?;
    final order = item['order'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: () {
        final supplierName = order?['supplier_name'] as String? ?? '';
        if (supplierName.isNotEmpty && supplierName != 'Belum Ditentukan') {
          return;
        }
        widget.onOrderItem?.call({
          'name': name,
          'qty': qty,
          'price': price,
          'orderId': orderId,
          'order': order,
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 37, 37, 37),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color.fromARGB(255, 50, 50, 50)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A8FCC).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_rounded,
                  color: Color(0xFF498CC8),
                  size: 22,
                ),
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
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF1A8FCC,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_formatQty(qty)} kg',
                        style: const TextStyle(
                          color: Color(0xFF60B0FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@ ${_formatCurrency(price)}',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 130, 130, 130),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A843).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD4A843).withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  _formatCurrency(subtotal),
                  style: const TextStyle(
                    color: Color(0xFFD4A843),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class PaymentBottomSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final String? sppgId;
  final String role;
  final String Function(dynamic) formatCurrency;
  final VoidCallback onSuccess;

  const PaymentBottomSheet({
    super.key,
    required this.order,
    required this.sppgId,
    required this.role,
    required this.formatCurrency,
    required this.onSuccess,
  });

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  String _paymentPhotoPath = '';
  bool _paymentSubmitting = false;

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

  Future<void> _pickPaymentImage() async {
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
      try {
        await initializeDateFormatting('id_ID');
        final position = await _getLocation();
        final alamat = await _getAlamat(position.latitude, position.longitude);
        final now = DateTime.now();
        final tanggal = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
        final jam = DateFormat('HH:mm').format(now);
        final supplier = widget.order['supplier_name'] as String? ?? 'Supplier';
        final wmPath = await _addWatermark(
          imagePath: picked.path,
          date: tanggal,
          time: jam,
          latitude: position.latitude,
          longitude: position.longitude,
          address: alamat,
          supplier: supplier,
        );
        setState(() => _paymentPhotoPath = wmPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ));
        }
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

  Future<void> _submitPayment() async {
    final poId = widget.order['_orderId'] as int? ?? widget.order['id'] as int? ?? 0;
    final auth = context.read<AuthProvider>();
    final sppgId = auth.sppgId;
    final role = auth.currentRole;

    setState(() => _paymentSubmitting = true);

    try {
      String photoUrl = '';
      if (_paymentPhotoPath.isNotEmpty) {
        final file = File(_paymentPhotoPath);
        if (await file.exists()) {
          photoUrl = await ProcurementApi.uploadPhoto(_paymentPhotoPath, sppgId: sppgId, role: role);
        }
      }

      if (photoUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto bukti pembayaran wajib diisi'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _paymentSubmitting = false);
        return;
      }

      final res = await http.post(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/orders/$poId/pay'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-Sppg-id': sppgId ?? '',
          'x-user-Role': role,
        },
        body: jsonEncode({'payment_proof_photo': photoUrl}),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil'),
            backgroundColor: Color(0xFF1B5E20),
          ),
        );
        widget.onSuccess();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses pembayaran (${res.statusCode})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal terhubung ke server: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _paymentSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final totalPayment = (widget.order['total_amount'] as num?)?.toDouble() ??
        items.fold<double>(
          0,
          (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0) * ((item['quantity'] as num?)?.toDouble() ?? 0),
        );
    final canPay = _paymentPhotoPath.isNotEmpty && !_paymentSubmitting;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 30, 30, 30),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment, color: Color(0xFF4CAF50), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Pembayaran PO #${widget.order['id']}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 20, 20, 20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Pembayaran',
                    style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.formatCurrency(totalPayment),
                    style: const TextStyle(
                      color: Color(0xFFD4A843),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFFD4A843), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Foto Bukti Pembayaran',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                if (_paymentPhotoPath.isNotEmpty)
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
            const Text('Upload foto struk bukti pembayaran', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12)),
            const SizedBox(height: 12),
            if (_paymentPhotoPath.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: Image.file(
                    File(_paymentPhotoPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color.fromARGB(255, 20, 20, 20),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _pickPaymentImage,
                icon: Icon(_paymentPhotoPath.isNotEmpty ? Icons.refresh : Icons.add_a_photo, color: const Color(0xFF498CC8), size: 18),
                label: Text(
                  _paymentPhotoPath.isNotEmpty ? 'Ganti Foto' : 'Upload Foto Struk',
                  style: const TextStyle(color: Color(0xFF498CC8)),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF498CC8).withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Opacity(
                opacity: canPay ? 1.0 : 0.4,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: canPay
                        ? const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)])
                        : const LinearGradient(colors: [Color(0xFF444444), Color(0xFF555555)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: canPay ? _submitPayment : null,
                      child: Center(
                        child: _paymentSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.payment, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Bayar Sekarang',
                                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
