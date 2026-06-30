import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cart_page.dart';
import 'chat_page.dart';
import 'detail_product.dart';
import 'distribusi/providers/auth_provider.dart';
import 'draft_store.dart';

class MarketplacePage extends StatefulWidget {
  final String? selectedItem;
  final Map<String, dynamic>? selectedItemInfo;
  final VoidCallback? onSupplierSelected;

  const MarketplacePage({super.key, this.selectedItem, this.selectedItemInfo, this.onSupplierSelected});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  int _selectedCategory = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];

  bool get _isSelectMode =>
      widget.selectedItemInfo != null &&
      widget.selectedItemInfo!.containsKey('orderId');

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp0';
    final num val = (price is num) ? price : double.tryParse(price.toString()) ?? 0;
    return 'Rp${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _supplierPhone(Map<String, dynamic> s) {
    final phone = s['supplier_phone'] as String?;
    if (phone != null && phone.isNotEmpty) {
      return phone.replaceAll(RegExp(r'[^0-9]'), '');
    }
    final name = s['name'] as String;
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = hash * 31 + name.codeUnitAt(i);
    }
    return '62812${(hash.abs() % 100000000).toString().padLeft(8, '0')}';
  }

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Semua', 'icon': Icons.all_inclusive},
    {'name': 'Chiller', 'icon': Icons.ac_unit_rounded},
    {'name': 'Freezer', 'icon': Icons.ac_unit_rounded},
    {'name': 'Kering', 'icon': Icons.inventory_2_rounded},
  ];

  String _randomTime() {
    final minutes = [5, 10, 15, 20, 25, 30, 35, 40, 45];
    return '${minutes[DateTime.now().millisecond % minutes.length]} menit';
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() { _loading = true; _error = null; });
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
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _products = data.map((e) {
            final api = e as Map<String, dynamic>;
            final category = api['category'] as String? ?? '';
            int catIdx = 0;
            if (category.toLowerCase() == 'chiller') { catIdx = 1; }
            else if (category.toLowerCase() == 'freezer') { catIdx = 2; }
            else if (category.toLowerCase() == 'kering') { catIdx = 3; }
            return {
              'item': api['name'] ?? '',
              'name': api['supplier_name'] ?? '',
              'price': _formatPrice(api['price']),
              'price_raw': api['price'] ?? 0,
              'distance': '${api['supplier_distance'] ?? 0} km',
              'rating': (api['supplier_rating'] ?? 0).toDouble(),
              'imageUrl': api['image_url'] ?? '',
              'cat': catIdx,
              'unit': api['unit'] ?? '',
              'supplier_id': api['supplier_id'] ?? 0,
              'supplier_phone': api['supplier_phone'] ?? '',
              'supplier_contact': api['supplier_contact'] ?? '',
            };
          }).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Gagal memuat data (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Gagal terhubung ke server'; _loading = false; });
    }
  }

  Future<void> _selectSupplier(Map<String, dynamic> product) async {
    final info = widget.selectedItemInfo;
    if (info == null) return;
    final orderId = info['orderId'] as int?;
    final order = info['order'] as Map<String, dynamic>?;
    if (orderId == null || order == null) return;

    final supplierId = product['supplier_id'] as int? ?? 0;
    final supplierName = product['name'] as String? ?? '';
    final newPrice = product['price_raw'] as num? ?? 0;

    final updatedItems = (order['items'] as List<dynamic>?)
            ?.map((item) {
              final mItem = item as Map<String, dynamic>;
              if (mItem['name']?.toString().toLowerCase() ==
                  info['name']?.toString().toLowerCase()) {
                return {
                  'id': mItem['id'] ?? 0,
                  'purchase_order_id': orderId,
                  'material_id': mItem['material_id'] ?? 0,
                  'name': mItem['name'] ?? '',
                  'quantity': (mItem['quantity'] ?? 0).toDouble(),
                  'price': newPrice.toDouble(),
                };
              }
              return {
                'id': mItem['id'] ?? 0,
                'purchase_order_id': orderId,
                'material_id': mItem['material_id'] ?? 0,
                'name': mItem['name'] ?? '',
                'quantity': (mItem['quantity'] ?? 0).toDouble(),
                'price': (mItem['price'] ?? 0).toDouble(),
              };
            })
            .toList() ??
        [];

    final totalAmount = updatedItems.fold<double>(
      0,
      (sum, item) => sum + ((item['quantity'] as double) * (item['price'] as double)),
    );

    final body = {
      'id': orderId,
      'sppg_id': order['sppg_id'] ?? 1,
      'order_date': order['order_date'] ?? '',
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'items': updatedItems,
      'total_amount': totalAmount,
      'status': order['status'] ?? 'Pending',
      'supplier_status': order['supplier_status'] ?? '',
      'photo_before_shipping': order['photo_before_shipping'] ?? '',
      'photo_after_received': order['photo_after_received'] ?? '',
      'created_at': order['created_at'] ?? '',
      'parent_id': order['parent_id'] ?? 0,
      'is_split': order['is_split'] ?? false,
    };

    try {
      final auth = context.read<AuthProvider>();
      final res = await http.put(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
        body: jsonEncode(body),
      );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier "$supplierName" berhasil dipilih'),
            backgroundColor: const Color(0xFF1B5E20),
          ),
        );
        setState(() {
          widget.selectedItemInfo?.remove('orderId');
        });
        widget.onSupplierSelected?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${res.statusCode}'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 40, 40, 40),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color.fromARGB(255, 73, 143, 200), size: 18),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSuppliers = widget.selectedItem == null
        ? <Map<String, dynamic>>[]
        : _products.where((s) {
            final a = (s['item'] as String).toLowerCase();
            final b = (widget.selectedItem ?? '').toLowerCase();
            if (a.contains(b) || b.contains(a)) return true;
            final aWords = a.split(RegExp(r'\s+'));
            final bWords = b.split(RegExp(r'\s+'));
            return aWords.any((w) => w.length > 2 && bWords.contains(w));
          }).toList();

    final searchedSuppliers = _products.where((s) {
      if (_searchQuery.isNotEmpty) {
        final name = (s['name'] as String).toLowerCase();
        final item = (s['item'] as String).toLowerCase();
        if (!name.contains(_searchQuery) && !item.contains(_searchQuery)) {
          return false;
        }
      }
      if (_selectedCategory != 0 && s['cat'] != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Marketplace",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          AnimatedBuilder(
            animation: DraftStore.paymentNotifier,
            builder: (_, __) {
              final count = DraftStore.pendingPayments.length;
              return IconButton(
                icon: count > 0
                    ? Badge(
                        label: Text('$count', style: const TextStyle(fontSize: 10)),
                        child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                      )
                    : const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Cari supplier atau bahan pangan",
                hintStyle: const TextStyle(
                  color: Color.fromARGB(255, 133, 133, 133),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color.fromARGB(255, 40, 40, 40),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color.fromARGB(255, 133, 133, 133),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color.fromARGB(255, 47, 157, 246),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color.fromARGB(255, 73, 143, 200),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = _selectedCategory == index;
                final cat = _categories[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF135B92)
                          : const Color.fromARGB(255, 40, 40, 40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF135B92)
                            : const Color.fromARGB(255, 60, 60, 60),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          color: isSelected
                              ? Colors.white
                              : const Color.fromARGB(255, 176, 176, 176),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat['name'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color.fromARGB(255, 176, 176, 176),
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator()),
          ] else if (_error != null) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Colors.red[300], fontSize: 14)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _fetchProducts,
                    icon: const Icon(Icons.refresh, color: Color.fromARGB(255, 73, 143, 200)),
                    label: const Text('Coba Lagi', style: TextStyle(color: Color.fromARGB(255, 73, 143, 200))),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (widget.selectedItem != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 20,
                      decoration: BoxDecoration(color: const Color(0xFF135B92), borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    const Text("Supplier UMKM terdekat", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: _isSelectMode ? 330 : 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSuppliers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final s = filteredSuppliers[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailProductPage(supplier: s))),
                      child: SizedBox(
                        width: 200, height: _isSelectMode ? 330 : 260,
                        child: Container(
                          decoration: BoxDecoration(color: const Color.fromARGB(255, 47, 47, 47), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: SizedBox(
                                  width: double.infinity, height: 80,
                                  child: Image.network(s['imageUrl'] as String, fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 110, color: const Color.fromARGB(255, 40, 40, 40),
                                      child: const Icon(Icons.image, color: Colors.grey, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['item'] as String, style: const TextStyle(color: Color.fromARGB(255, 73, 143, 200), fontSize: 11, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(color: const Color.fromARGB(255, 40, 40, 40), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color.fromARGB(255, 60, 60, 60))),
                                        child: Text(_categories[s['cat']]['name'] as String, style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 9)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(s['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(s['price'] as String, style: const TextStyle(color: Color(0xFFD4A843), fontSize: 13, fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(children: [
                                            const Icon(Icons.location_on_outlined, color: Color.fromARGB(255, 133, 133, 133), size: 11),
                                            const SizedBox(width: 2),
                                            Text(s['distance'] as String, style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 10)),
                                          ]),
                                          Row(children: [
                                            const Icon(Icons.star, color: Color(0xFFD4A843), size: 11),
                                            const SizedBox(width: 2),
                                            Text(s['rating'].toString(), style: const TextStyle(color: Color(0xFFD4A843), fontSize: 10, fontWeight: FontWeight.bold)),
                                          ]),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _iconButton(Icons.chat_bubble_outline, () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(supplier: s)))),
                                          _iconButton(Icons.call_outlined, () { final p = _supplierPhone(s); launchUrl(Uri.parse('tel:$p')).catchError((_) => false); }),
                                          _iconButton(MaterialCommunityIcons.whatsapp, () { final p = _supplierPhone(s); launchUrl(Uri.parse('https://wa.me/$p')).catchError((_) => false); }),
                                          _iconButton(Icons.telegram, () { final p = _supplierPhone(s); launchUrl(Uri.parse('tg://resolve?phone=$p')).catchError((_) => false); }),
                                        ],
                                      ),
                                      if (_isSelectMode)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () => _selectSupplier(s),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1A8FCC),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: Text(
                                                'Pilih ${s['name']}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 20,
                    decoration: BoxDecoration(color: const Color(0xFF135B92), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  const Text("Semua Supplier", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: searchedSuppliers.length,
              itemBuilder: (context, index) {
                final s = searchedSuppliers[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailProductPage(supplier: s))),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      decoration: BoxDecoration(color: const Color.fromARGB(255, 47, 47, 47), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100, height: 160,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              child: Image.network(s['imageUrl'] as String, fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color.fromARGB(255, 40, 40, 40),
                                  child: const Icon(Icons.image, color: Colors.grey, size: 30),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['item'] as String, style: const TextStyle(color: Color.fromARGB(255, 73, 143, 200), fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(color: const Color.fromARGB(255, 40, 40, 40), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color.fromARGB(255, 60, 60, 60))),
                                    child: Text(_categories[s['cat']]['name'] as String, style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 9)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(s['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(s['price'] as String, style: const TextStyle(color: Color(0xFFD4A843), fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, color: Color.fromARGB(255, 133, 133, 133), size: 12),
                                          const SizedBox(width: 2),
                                          Text(s['distance'] as String, style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 10)),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.access_time, color: Color.fromARGB(255, 133, 133, 133), size: 12),
                                          const SizedBox(width: 2),
                                          Text(_randomTime(), style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 10)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Color(0xFFD4A843), size: 12),
                                          const SizedBox(width: 2),
                                          Text(s['rating'].toString(), style: const TextStyle(color: Color(0xFFD4A843), fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _iconButton(Icons.chat_bubble_outline, () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(supplier: s)))),
                                      _iconButton(Icons.call_outlined, () { final p = _supplierPhone(s); launchUrl(Uri.parse('tel:$p')).catchError((_) => false); }),
                                      _iconButton(MaterialCommunityIcons.whatsapp, () { final p = _supplierPhone(s); launchUrl(Uri.parse('https://wa.me/$p')).catchError((_) => false); }),
                                      _iconButton(Icons.telegram, () { final p = _supplierPhone(s); launchUrl(Uri.parse('tg://resolve?phone=$p')).catchError((_) => false); }),
                                    ],
                                  ),
                                  if (_isSelectMode)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _selectSupplier(s),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1A8FCC),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            'Pilih ${s['name']}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }
}
