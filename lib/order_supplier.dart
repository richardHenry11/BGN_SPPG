import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'distribusi/providers/auth_provider.dart';

class OrderSupplierPage extends StatefulWidget {
  const OrderSupplierPage({super.key});

  @override
  State<OrderSupplierPage> createState() => _OrderSupplierPageState();
}

class _OrderSupplierPageState extends State<OrderSupplierPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  List<Map<String, dynamic>> get _approvedPaid =>
      _orders.where((o) => o['status'] == 'Approved' && o['payment_status'] == 'Paid').toList();

  List<Map<String, dynamic>> get _shipped =>
      _orders.where((o) => o['status'] == 'Shipped').toList();

  List<Map<String, dynamic>> get _others =>
      _orders.where((o) => !(o['status'] == 'Approved' && o['payment_status'] == 'Paid') && o['status'] != 'Shipped').toList();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() { _loading = true; _error = null; });
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
        _orders = data
            .cast<Map<String, dynamic>>()
            .where((o) => o['supplier_id'].toString() == sId)
            .toList();
        setState(() => _loading = false);
      } else {
        setState(() { _error = 'Gagal memuat pesanan (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Gagal terhubung ke server'; _loading = false; });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '-';
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp0';
    final num val = (price is num) ? price : double.tryParse(price.toString()) ?? 0;
    return 'Rp${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Pesanan', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF498CC8)))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  color: const Color(0xFF1A8FCC),
                  backgroundColor: const Color.fromARGB(255, 40, 40, 40),
                  child: _orders.isEmpty ? _buildEmpty() : _buildList(),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color.fromARGB(255, 80, 80, 80), size: 56),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 14)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _fetchOrders,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF498CC8)),
            label: const Text('Coba Lagi', style: TextStyle(color: Color(0xFF498CC8))),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF498CC8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF498CC8), size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum ada pesanan',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pesanan akan muncul di sini\nsetelah ada pembelian',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final hasApproved = _approvedPaid.isNotEmpty;
    final hasShipped = _shipped.isNotEmpty;
    final hasOthers = _others.isNotEmpty;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Perlu Diproses', _approvedPaid.length),
          const SizedBox(height: 8),
          if (hasApproved)
            ...List.generate(_approvedPaid.length, (i) => _buildOrderCard(_approvedPaid[i], i < _approvedPaid.length - 1, false))
          else
            _buildEmptyHint('Tidak ada pesanan yang perlu diproses'),

          if (hasShipped || hasOthers) const SizedBox(height: 20),
          if (hasShipped) _buildSectionHeader('Dikirim', _shipped.length),
          if (hasShipped) const SizedBox(height: 8),
          if (hasShipped)
            ...List.generate(_shipped.length, (i) => _buildOrderCard(_shipped[i], i < _shipped.length - 1, true)),

          if (hasOthers) const SizedBox(height: 20),
          if (hasOthers) _buildSectionHeader('Lainnya', _others.length),
          if (hasOthers) const SizedBox(height: 8),
          if (hasOthers)
            ...List.generate(_others.length, (i) => _buildOrderCard(_others[i], i < _others.length - 1, false)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF498CC8).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: Color(0xFF498CC8), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool showBorder, bool isShipped) {
    final items = order['items'] as List<dynamic>? ?? [];
    final date = _formatDate(order['order_date'] as String?);
    final status = order['status'] as String? ?? '';
    final paymentStatus = order['payment_status'] as String? ?? '';

    Color borderColor;
    String statusBadge;
    Color statusColor;

    if (isShipped || status == 'Shipped') {
      borderColor = const Color(0xFFFFA726);
      statusBadge = 'Dikirim';
      statusColor = const Color(0xFFFFA726);
    } else if (status == 'Approved' && paymentStatus == 'Paid') {
      borderColor = const Color(0xFF1A8FCC);
      statusBadge = 'Siap Diproses';
      statusColor = const Color(0xFF1A8FCC);
    } else if (status == 'Completed') {
      borderColor = const Color(0xFF4CAF50);
      statusBadge = 'Selesai';
      statusColor = const Color(0xFF4CAF50);
    } else {
      borderColor = const Color.fromARGB(255, 80, 80, 80);
      statusBadge = status.isNotEmpty ? status : paymentStatus;
      statusColor = const Color.fromARGB(255, 133, 133, 133);
    }

    return Container(
      margin: EdgeInsets.only(bottom: showBorder ? 8 : 0),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
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
                  child: Icon(
                    isShipped ? MaterialCommunityIcons.package_variant : MaterialCommunityIcons.truck,
                    color: const Color(0xFF498CC8), size: 22,
                  ),
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
                      Text('${order['supplier_name'] ?? '-'} • $date',
                        style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
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
                    statusBadge,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const Divider(color: Color.fromARGB(255, 60, 60, 60), height: 20),
              ...items.asMap().entries.map((entry) {
                final item = entry.value as Map<String, dynamic>;
                final qty = (item['quantity'] ?? 0).toDouble();
                final itemPrice = _formatPrice(item['price']);
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
                      const SizedBox(width: 8),
                      Text(itemPrice,
                        style: const TextStyle(color: Color(0xFFD4A843), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
              if (order['total_amount'] != null) ...[
                const Divider(color: Color.fromARGB(255, 60, 60, 60), height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Total: ', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 13)),
                    Text(
                      _formatPrice(order['total_amount']),
                      style: const TextStyle(color: Color(0xFFD4A843), fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
