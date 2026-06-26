import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'draft_store.dart';

class ToShipPage extends StatelessWidget {
  const ToShipPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = DraftStore.paidOrders;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Pesanan Diproses',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: orders.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) => _buildOrderCard(context, orders[i]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2, size: 80, color: const Color.fromARGB(255, 60, 60, 60)),
          const SizedBox(height: 16),
          const Text(
            'Belum ada pesanan',
            style: TextStyle(
              color: Color.fromARGB(255, 133, 133, 133),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pesanan yang sudah dibayar akan muncul di sini',
            style: TextStyle(
              color: Color.fromARGB(255, 100, 100, 100),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final item = order['item'] as String;
    final name = order['name'] as String;
    final price = order['price'] as String;
    final imageUrl = order['imageUrl'] as String;
    final quantity = order['quantity'] as int;
    final total = order['totalFormatted'] as String;
    final address = order['address'] as String? ?? '';
    final deliveryDate = order['deliveryDate'] as String? ?? '';
    final deliveryTime = order['deliveryTime'] as String? ?? '';
    final paymentMethod = order['paymentMethod'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color.fromARGB(255, 40, 40, 40),
                            child: const Icon(Icons.image, color: Colors.grey, size: 28),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$price x $quantity',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 176, 176, 176),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Dibayar',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color.fromARGB(255, 60, 60, 60)),
                const SizedBox(height: 14),
                _detailRow(context, Icons.location_on_outlined, 'Alamat Pengiriman', address),
                if (deliveryDate.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailRow(context, Icons.calendar_today, 'Jadwal', '$deliveryDate • $deliveryTime'),
                ],
                const SizedBox(height: 10),
                _detailRow(context, MaterialCommunityIcons.credit_card, 'Pembayaran', _paymentName(paymentMethod)),
                const SizedBox(height: 14),
                const Divider(color: Color.fromARGB(255, 60, 60, 60)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Pembayaran',
                      style: TextStyle(
                        color: Color(0xFFD4A843),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      total,
                      style: const TextStyle(
                        color: Color(0xFFD4A843),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF498CC8), size: 18),
        const SizedBox(width: 10),
        Column(
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
            SizedBox(
              width: MediaQuery.of(context).size.width - 100,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _paymentName(String id) {
    switch (id) {
      case 'bca': return 'BCA Virtual Account';
      case 'mandiri': return 'Mandiri Virtual Account';
      case 'bni': return 'BNI Virtual Account';
      case 'bri': return 'BRI Virtual Account';
      case 'gopay': return 'GoPay';
      case 'ovo': return 'OVO';
      case 'dana': return 'DANA';
      case 'qris': return 'QRIS';
      default: return id;
    }
  }
}
