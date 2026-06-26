import 'package:flutter/material.dart';
import 'draft_store.dart';

class ToRatePage extends StatelessWidget {
  const ToRatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = DraftStore.ratedOrders;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Belum Di-rating',
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
          Icon(Icons.star_outline, size: 80, color: const Color.fromARGB(255, 60, 60, 60)),
          const SizedBox(height: 16),
          const Text(
            'Belum ada pesanan',
            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pesanan yang sudah diterima akan muncul di sini',
            style: TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final item = order['item'] as String? ?? '';
    final supplier = order['supplier'] as String? ?? '';
    final qty = order['qty'] as String? ?? '';
    final total = order['total'] as String? ?? '';
    final imageUrl = order['imageUrl'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFFD4A843), width: 5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color.fromARGB(255, 40, 40, 40),
                              child: const Icon(Icons.image, color: Colors.grey, size: 28),
                            ))
                        : Container(
                            color: const Color.fromARGB(255, 40, 40, 40),
                            child: const Icon(Icons.eco, color: Colors.grey, size: 28),
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
                        supplier,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$qty • $total',
                        style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
                      SizedBox(width: 4),
                      Text('Diterima', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4A843), Color(0xFFE6B800)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur rating akan segera tersedia'),
                          backgroundColor: Color(0xFF1A8FCC),
                        ),
                      );
                    },
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Beri Rating',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
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
