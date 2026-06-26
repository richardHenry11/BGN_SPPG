import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'draft_store.dart';
import 'distribusi/providers/auth_provider.dart';

class SupplierProductsPage extends StatefulWidget {
  const SupplierProductsPage({super.key});

  @override
  State<SupplierProductsPage> createState() => _SupplierProductsPageState();
}

class _SupplierProductsPageState extends State<SupplierProductsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  bool _posting = false;

  static const _baseUrl = 'https://sppg.cbinstrument.com/api/procurement/supplier-products';

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
        Uri.parse(_baseUrl),
        headers: {
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _products = data
              .map((e) => e as Map<String, dynamic>)
              .where((p) => p['supplier_id'] == DraftStore.loggedInSupplierId)
              .toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Gagal memuat data (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Gagal terhubung ke server'; _loading = false; });
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp0';
    final num val = (price is num) ? price : double.tryParse(price.toString()) ?? 0;
    return 'Rp${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'kering': return Icons.inventory_2_rounded;
      case 'chiller': return Icons.ac_unit_rounded;
      case 'freezer': return Icons.ac_unit_rounded;
      default: return Icons.category_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'kering': return const Color(0xFFD4A843);
      case 'chiller': return const Color(0xFF498CC8);
      case 'freezer': return const Color(0xFF4CAF50);
      default: return Colors.grey;
    }
  }

  Future<void> _addProduct(Map<String, dynamic> body) async {
    setState(() => _posting = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
        body: json.encode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil ditambahkan'), backgroundColor: Color(0xFF4CAF50)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menambahkan produk (${res.statusCode})'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal terhubung ke server'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _updateProduct(int id, Map<String, dynamic> body) async {
    setState(() => _posting = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.put(
        Uri.parse('$_baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
        body: json.encode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil diupdate'), backgroundColor: Color(0xFF4CAF50)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengupdate produk (${res.statusCode})'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal terhubung ke server'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _deleteProduct(int id) async {
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.delete(
        Uri.parse('$_baseUrl/$id'),
        headers: {
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil dihapus'), backgroundColor: Color(0xFF4CAF50)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus produk (${res.statusCode})'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal terhubung ke server'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _confirmDelete(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 35, 35, 35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Produk', style: TextStyle(color: Colors.white)),
        content: Text(
          'Yakin ingin menghapus "${product['name']}"?',
          style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProduct(product['id']);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showProductForm({Map<String, dynamic>? product}) {
    final isEdit = product != null;
    final nameCtl = TextEditingController(text: isEdit ? product['name'] as String? ?? '' : '');
    final priceCtl = TextEditingController(text: isEdit ? '${product['price']}' : '');
    final unitCtl = TextEditingController(text: isEdit ? product['unit'] as String? ?? '' : '');
    final imageCtl = TextEditingController(text: isEdit ? product['image_url'] as String? ?? '' : '');
    final materialCtl = TextEditingController(text: isEdit ? '${product['material_id']}' : '');

    final categories = ['Kering', 'Chiller', 'Freezer'];
    String selectedCategory = isEdit ? (product['category'] as String? ?? 'Kering') : 'Kering';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 30, 30, 30),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 80, 80, 80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Produk' : 'Tambah Produk',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_posting)
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF498CC8)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _field('Nama Produk', nameCtl, hint: 'Beras Premium Cianjur'),
                  const SizedBox(height: 14),
                  _field('ID Material', materialCtl, hint: '1', keyboardType: TextInputType.number),
                  const SizedBox(height: 14),
                  _field('Harga', priceCtl, hint: '75000', keyboardType: TextInputType.number),
                  const SizedBox(height: 14),
                  _field('Satuan', unitCtl, hint: 'Kg / Pcs'),
                  const SizedBox(height: 14),
                  _field('URL Gambar', imageCtl, hint: 'https://...'),
                  const SizedBox(height: 14),
                  const Text(
                    'Kategori',
                    style: TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 25, 25, 25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        dropdownColor: const Color.fromARGB(255, 40, 40, 40),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: categories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedCategory = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _posting ? null : () {
                            if (nameCtl.text.trim().isEmpty || priceCtl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Nama dan harga harus diisi')),
                              );
                              return;
                            }
                            final body = {
                              'supplier_id': DraftStore.loggedInSupplierId,
                              'material_id': int.tryParse(materialCtl.text.trim()) ?? 0,
                              'name': nameCtl.text.trim(),
                              'price': int.tryParse(priceCtl.text.trim()) ?? 0,
                              'unit': unitCtl.text.trim(),
                              'category': selectedCategory,
                              'image_url': imageCtl.text.trim(),
                            };
                            if (isEdit) {
                              body['id'] = product['id'];
                              body['supplier_name'] = product['supplier_name'];
                              body['supplier_rating'] = product['supplier_rating'];
                              body['supplier_distance'] = product['supplier_distance'];
                              body['supplier_contact'] = product['supplier_contact'];
                              body['supplier_phone'] = product['supplier_phone'];
                              body['supplier_address'] = product['supplier_address'];
                            }
                            Navigator.pop(ctx);
                            if (isEdit) {
                              _updateProduct(product['id'], body);
                            } else {
                              _addProduct(body);
                            }
                          },
                          child: Center(
                            child: _posting
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    isEdit ? 'Simpan Perubahan' : 'Tambah Produk',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl, {String? hint, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: ctl,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 14),
            filled: true,
            fillColor: const Color.fromARGB(255, 25, 25, 25),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color.fromARGB(255, 60, 60, 60)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF498CC8), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Produk Saya', style: TextStyle(color: Colors.white)),
      ),
      body: _buildBody(),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showProductForm(),
              backgroundColor: const Color(0xFF1A8FCC),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tambah Produk', style: TextStyle(color: Colors.white)),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF498CC8)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color.fromARGB(255, 80, 80, 80), size: 56),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 14)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchProducts,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF498CC8)),
              label: const Text('Coba Lagi', style: TextStyle(color: Color(0xFF498CC8))),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
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
              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF498CC8), size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada produk',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol + untuk menambahkan\nproduk pertama Anda',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A2640), Color(0xFF135B92)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DraftStore.loggedInSupplierName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_products.length} produk terdaftar',
                      style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchProducts,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final p = _products[index];
                return _buildProductCard(p);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final name = p['name'] as String? ?? '';
    final category = p['category'] as String? ?? '';
    final price = _formatPrice(p['price']);
    final unit = p['unit'] as String? ?? '';
    final imageUrl = p['image_url'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showProductForm(product: p),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color.fromARGB(255, 35, 35, 35),
                        child: Icon(_categoryIcon(category), color: _categoryColor(category), size: 32),
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
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _categoryColor(category).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_categoryIcon(category), size: 10, color: _categoryColor(category)),
                                const SizedBox(width: 4),
                                Text(
                                  category,
                                  style: TextStyle(color: _categoryColor(category), fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          if (unit.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 40, 40, 40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
                              ),
                              child: Text(
                                unit,
                                style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              color: Color(0xFFD4A843),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              _miniIcon(Icons.edit_outlined, const Color(0xFF498CC8), () => _showProductForm(product: p)),
                              const SizedBox(width: 6),
                              _miniIcon(Icons.delete_outline, Colors.redAccent, () => _confirmDelete(p)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
