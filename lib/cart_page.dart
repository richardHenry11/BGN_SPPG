import 'package:flutter/material.dart';
import 'draft_store.dart';
import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selected = {};

  bool get _allSelected {
    final drafts = DraftStore.pendingPayments;
    return drafts.isNotEmpty && drafts.every((d) => _selected.contains('${d['item']}|${d['name']}'));
  }

  void _toggleItem(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(DraftStore.pendingPayments.map((d) => '${d['item']}|${d['name']}'));
      }
    });
  }

  List<Map<String, dynamic>> get _selectedItems {
    return DraftStore.pendingPayments
        .where((d) => _selected.contains('${d['item']}|${d['name']}'))
        .toList();
  }
  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp0';
    final str = price.toString().replaceAll(RegExp(r'[^0-9]'), '');
    final num val = int.tryParse(str) ?? 0;
    return 'Rp${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  int _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is int) return price;
    if (price is double) return price.toInt();
    final str = price.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(str) ?? 0;
  }

  int _itemTotal(Map<String, dynamic> item) {
    final price = _parsePrice(item['price']);
    final qty = item['quantity'] as int? ?? 1;
    return price * qty;
  }

  int _grandTotal() {
    int total = 0;
    for (final item in _selectedItems) {
      total += _itemTotal(item);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final drafts = DraftStore.pendingPayments;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Keranjang', style: TextStyle(color: Colors.white)),
      ),
      body: drafts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF498CC8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF498CC8), size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Keranjang kosong',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tambahkan produk dari marketplace\nuntuk mulai berbelanja',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                AnimatedBuilder(
                  animation: DraftStore.paymentNotifier,
                  builder: (_, __) => Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: drafts.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSelectAllHeader(drafts);
                        }
                        final item = drafts[index - 1];
                        return _cartItemCard(context, item, index - 1);
                      },
                    ),
                  ),
                ),
                _buildBottomBar(context),
              ],
            ),
    );
  }

  Widget _buildSelectAllHeader(List<Map<String, dynamic>> drafts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Checkbox(
              value: _allSelected,
              onChanged: (_) => _toggleSelectAll(),
              activeColor: const Color(0xFF1A8FCC),
              checkColor: Colors.white,
              side: const BorderSide(color: Color.fromARGB(255, 100, 100, 100)),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Pilih Semua',
            style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13),
          ),
          const Spacer(),
          Text(
            '${_selected.length} dipilih',
            style: const TextStyle(color: const Color(0xFF1A8FCC), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _cartItemCard(BuildContext context, Map<String, dynamic> item, int index) {
    final name = item['name'] as String? ?? '';
    final itemName = item['item'] as String? ?? '';
    final priceStr = item['price'] as String? ?? '';
    final imageUrl = item['imageUrl'] as String? ?? '';
    final qty = item['quantity'] as int? ?? 1;
    final unit = item['unit'] as String? ?? '';
    final total = _itemTotal(item);
    final key = '$itemName|$name';
    final isSelected = _selected.contains(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleItem(key),
                activeColor: const Color(0xFF1A8FCC),
                checkColor: Colors.white,
                side: const BorderSide(color: Color.fromARGB(255, 80, 80, 80)),
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64, height: 64,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color.fromARGB(255, 35, 35, 35),
                    child: const Icon(Icons.image, color: Color.fromARGB(255, 80, 80, 80), size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: const TextStyle(color: Color.fromARGB(255, 73, 143, 200), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceStr,
                    style: const TextStyle(color: Color(0xFFD4A843), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      '$qty x $unit',
                      style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    DraftStore.removeDraft(itemName, name);
                    setState(() {});
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatPrice(total),
                    style: const TextStyle(color: Color(0xFF1A8FCC), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return AnimatedBuilder(
      animation: DraftStore.paymentNotifier,
      builder: (_, __) {
        final total = _grandTotal();
        final count = _selected.length;
        final hasSelection = count > 0;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 35, 35, 35),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasSelection ? 'Total ($count item)' : 'Total',
                        style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(total),
                        style: const TextStyle(color: Color(0xFFD4A843), fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: hasSelection
                          ? const LinearGradient(colors: [Color(0xFF135B92), Color(0xFF1A8FCC)])
                          : null,
                      color: hasSelection ? null : const Color.fromARGB(255, 50, 50, 50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: hasSelection
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CheckoutPage(items: _selectedItems),
                                  ),
                                );
                              }
                            : null,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Center(
                            child: Text(
                              'Bayar Sekarang',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
      },
    );
  }
}
