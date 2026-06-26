import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'draft_store.dart';
import 'distribusi/providers/auth_provider.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategory = 0;
  String _selectedTab = 'stok';

  List<Map<String, dynamic>> _materials = [];
  List<String> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMaterials() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.get(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/materials'),
        headers: {
          'Accept': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode != 200) {
        setState(() {
          _error = 'Gagal memuat data (${res.statusCode})';
          _loading = false;
        });
        return;
      }
      final List<dynamic> data = jsonDecode(res.body);
      _materials = data.cast<Map<String, dynamic>>();

      final cats = <String>{};
      for (final m in _materials) {
        final c = m['category'] as String? ?? '';
        if (c.isNotEmpty) cats.add(c);
      }
      _categories = cats.toList()..sort();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Gagal terhubung ke server';
        _loading = false;
      });
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'kering': return Icons.inventory_2_rounded;
      case 'chiller': return Icons.ac_unit_rounded;
      case 'freezer': return Icons.ac_unit_rounded;
      default: return Icons.category_rounded;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
      if (diff.inDays < 1) return '${diff.inHours} jam lalu';
      if (diff.inDays == 1) return 'Kemarin';
      return '${diff.inDays} hari lalu';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _materials.where((item) {
      if (_searchQuery.isNotEmpty) {
        final name = (item['name'] as String).toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }
      if (_selectedCategory != 0) {
        final cats = _categories;
        if (_selectedCategory - 1 < cats.length) {
          final catName = cats[_selectedCategory - 1];
          if ((item['category'] as String? ?? '') != catName) return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Inventori',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color.fromARGB(255, 176, 176, 176)),
              onPressed: _fetchMaterials,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A8FCC)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Color.fromARGB(255, 80, 80, 80), size: 48),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 15)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _fetchMaterials,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A8FCC),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_selectedTab == 'stok') ...[
                      _buildSearchBar(),
                      _buildCategoryFilter(),
                    ],
                    _buildActionTabs(),
                    if (_selectedTab == 'stok') _buildStockHeader(),
                    Expanded(child: _buildTabContent()),
                  ],
                ),
      floatingActionButton: _selectedTab != 'stok'
          ? FloatingActionButton.extended(
              onPressed: () => _showMovementDialog(),
              backgroundColor: const Color(0xFF1A8FCC),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                _selectedTab == 'masuk' ? 'Tambah Masuk' : 'Tambah Keluar',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 30, 30, 30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A8FCC).withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A8FCC).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: 'Cari barang...',
          hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 14, fontWeight: FontWeight.w400),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 4),
            child: const Icon(Icons.search_rounded, color: Color.fromARGB(255, 100, 100, 100), size: 22),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color.fromARGB(255, 100, 100, 100), size: 20),
                    splashRadius: 20,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final allCats = [{'name': 'Semua', 'icon': Icons.all_inclusive}];
    for (final c in _categories) {
      allCats.add({'name': c, 'icon': _categoryIcon(c)});
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: allCats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final isSelected = _selectedCategory == index;
          final cat = allCats[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isSelected ? null : const Color.fromARGB(255, 30, 30, 30),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1A8FCC).withValues(alpha: 0.6)
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
              child: Row(
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    color: isSelected ? Colors.white : const Color.fromARGB(255, 120, 120, 120),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cat['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color.fromARGB(255, 140, 140, 140),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(child: _actionTab(Icons.inventory_2_rounded, 'Stok', 'stok')),
          const SizedBox(width: 8),
          Expanded(child: _actionTab(Icons.arrow_downward_rounded, 'Barang Masuk', 'masuk')),
          const SizedBox(width: 8),
          Expanded(child: _actionTab(Icons.arrow_upward_rounded, 'Barang Keluar', 'keluar')),
        ],
      ),
    );
  }

  Widget _actionTab(IconData icon, String label, String tab) {
    final isActive = _selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    const Color(0xFF135B92).withValues(alpha: 0.35),
                    const Color(0xFF1A8FCC).withValues(alpha: 0.15),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isActive ? null : const Color.fromARGB(255, 30, 30, 30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFF1A8FCC).withValues(alpha: 0.35)
                : const Color.fromARGB(255, 50, 50, 50),
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A8FCC).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF60B0FF) : const Color.fromARGB(255, 120, 120, 120),
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color.fromARGB(255, 140, 140, 140),
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockHeader() {
    final total = _filteredItems.length;
    final aman = _filteredItems.where((i) {
      final stock = (i['current_stock'] as num?)?.toDouble() ?? 0;
      final alert = (i['min_stock_alert'] as num?)?.toDouble() ?? 0;
      return alert <= 0 || stock >= alert;
    }).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A8FCC).withValues(alpha: 0.08),
              const Color(0xFF135B92).withValues(alpha: 0.04),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1A8FCC).withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A8FCC).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warehouse_rounded, color: Color(0xFF498CC8), size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stok Gudang',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total item tersedia',
                      style: const TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF4CAF50), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '$aman/$total aman',
                    style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTab == 'masuk') return _buildBarangMasuk();
    if (_selectedTab == 'keluar') return _buildBarangKeluar();
    return _buildStockList();
  }

  Widget _buildStockList() {
    final items = _filteredItems;
    if (items.isEmpty) {
      return Center(
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
              child: const Icon(Icons.inventory_2_outlined, size: 36, color: Color.fromARGB(255, 80, 80, 80)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada barang ditemukan',
              style: TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _buildStockCard(items[i]),
    );
  }

  Widget _buildBarangMasuk() {
    final entries = DraftStore.stockLedger.where((e) => e['type'] == 'masuk').toList();
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 30, 30, 30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.download_rounded, size: 36, color: Color.fromARGB(255, 80, 80, 80)),
            ),
            const SizedBox(height: 16),
            const Text('Belum ada barang masuk', style: TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text('Tekan + untuk mencatat barang masuk', style: TextStyle(color: Color.fromARGB(255, 80, 80, 80), fontSize: 12)),
          ],
        ),
      );
    }
    return AnimatedBuilder(
      animation: DraftStore.stockNotifier,
      builder: (_, __) => _buildLedgerList(entries, Colors.green),
    );
  }

  Widget _buildBarangKeluar() {
    final entries = DraftStore.stockLedger.where((e) => e['type'] == 'keluar').toList();
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 30, 30, 30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.upload_rounded, size: 36, color: Color.fromARGB(255, 80, 80, 80)),
            ),
            const SizedBox(height: 16),
            const Text('Belum ada barang keluar', style: TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text('Tekan + untuk mencatat barang keluar', style: TextStyle(color: Color.fromARGB(255, 80, 80, 80), fontSize: 12)),
          ],
        ),
      );
    }
    return AnimatedBuilder(
      animation: DraftStore.stockNotifier,
      builder: (_, __) => _buildLedgerList(entries, const Color(0xFFE53935)),
    );
  }

  Widget _buildLedgerList(List<Map<String, dynamic>> entries, Color accentColor) {
    final filtered = entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return (e['itemName'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    if (filtered.isEmpty) {
      return const Center(
        child: Text('Tidak ada hasil', style: TextStyle(color: Color.fromARGB(255, 120, 120, 120))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildLedgerCard(filtered[i], accentColor),
    );
  }

  Widget _buildLedgerCard(Map<String, dynamic> entry, Color accentColor) {
    final isMasuk = entry['type'] == 'masuk';
    final itemName = entry['itemName'] as String;
    final qty = entry['qty'] as int;
    final unit = entry['unit'] as String;
    final date = entry['date'] as String;
    final reference = entry['reference'] as String;
    final price = entry['price'] as int? ?? 0;
    final fifoDetails = entry['fifoDetails'] as List<dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 35, 35, 35),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: accentColor, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isMasuk ? 'MASUK' : 'KELUAR',
                            style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$qty $unit',
                          style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 13, color: const Color.fromARGB(255, 100, 100, 100)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reference.isNotEmpty ? reference : '-',
                  style: const TextStyle(color: Color.fromARGB(255, 160, 160, 160), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 13, color: const Color.fromARGB(255, 100, 100, 100)),
              const SizedBox(width: 6),
              Text(
                date,
                style: const TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 12),
              ),
            ],
          ),
          if (isMasuk && price > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.monetization_on_outlined, size: 13, color: const Color.fromARGB(255, 100, 100, 100)),
                const SizedBox(width: 6),
                Text(
                  'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                  style: const TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 12),
                ),
              ],
            ),
          ],
          if (!isMasuk && fifoDetails != null && fifoDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 25, 25, 25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color.fromARGB(255, 50, 50, 50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.compare_arrows_rounded, size: 14, color: const Color(0xFFD4A843)),
                      const SizedBox(width: 6),
                      Text(
                        'FIFO — Mengambil dari batch:',
                        style: TextStyle(color: const Color(0xFFD4A843), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...fifoDetails.map((d) {
                    final detail = d as Map<String, dynamic>;
                    final used = detail['used'] as int;
                    final remaining = detail['remaining'] as int;
                    final batchId = detail['batchId'] as int;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF60B0FF), shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Batch #$batchId — ambil $used $unit',
                            style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 11),
                          ),
                          const Spacer(),
                          Text(
                            'sisa $remaining $unit',
                            style: TextStyle(
                              color: remaining > 0 ? const Color(0xFF4CAF50) : const Color.fromARGB(255, 80, 80, 80),
                              fontSize: 11, fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMovementDialog() {
    final isMasuk = _selectedTab == 'masuk';
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String selectedUnit = 'kg';
    final units = ['kg', 'liter', 'pcs', 'ikat', 'karung', 'karton'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 30, 30, 30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isKeyboardOpen = MediaQuery.of(ctx).viewInsets.bottom > 0;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, isKeyboardOpen ? 20 : MediaQuery.of(ctx).padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Text(
                  isMasuk ? 'Catat Barang Masuk' : 'Catat Barang Keluar',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _fieldDecoration('Nama Barang', 'Cth: Telur Ayam'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _fieldDecoration('Jumlah', '0'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 25, 25, 25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color.fromARGB(255, 50, 50, 50)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedUnit,
                            dropdownColor: const Color.fromARGB(255, 40, 40, 40),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (v) => setDialogState(() => selectedUnit = v ?? 'kg'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: refCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _fieldDecoration('Referensi (opsional)', 'Cth: Nota #123'),
                ),
                if (isMasuk) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _fieldDecoration('Harga (opsional)', '0'),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A8FCC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      if (name.isEmpty || qty <= 0) return;
                      final ref = refCtrl.text.trim();
                      if (isMasuk) {
                        final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                        DraftStore.addStockIn(
                          itemName: name,
                          qty: qty,
                          unit: selectedUnit,
                          reference: ref,
                          price: price,
                        );
                      } else {
                        DraftStore.addStockOut(
                          itemName: name,
                          qty: qty,
                          unit: selectedUnit,
                          reference: ref,
                        );
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      isMasuk ? 'Catat Masuk' : 'Catat Keluar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  InputDecoration _fieldDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Color.fromARGB(255, 80, 80, 80), fontSize: 13),
      filled: true,
      fillColor: const Color.fromARGB(255, 25, 25, 25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color.fromARGB(255, 50, 50, 50)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color.fromARGB(255, 50, 50, 50)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A8FCC)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final stock = (item['current_stock'] as num?)?.toDouble() ?? 0;
    final unit = item['unit'] as String? ?? '';
    final alert = (item['min_stock_alert'] as num?)?.toDouble() ?? 0;
    final lastUpdate = _formatDate(item['last_updated'] as String?);
    final category = item['category'] as String? ?? '';
    final price = (item['price_per_unit'] as num?)?.toDouble() ?? 0;
    final ratio = alert > 0 ? stock / alert : 1.0;
    final pct = (ratio * 100).clamp(0, 100).toInt();
    final isAman = alert <= 0 || stock >= alert;

    Color barColor;
    String statusText;
    IconData statusIcon;
    if (isAman) {
      barColor = const Color(0xFF4CAF50);
      statusText = 'Stock aman';
      statusIcon = Icons.check_circle_rounded;
    } else if (ratio >= 0.7) {
      barColor = const Color(0xFFD4A843);
      statusText = 'Perlu ditambah';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      barColor = const Color(0xFFE53935);
      statusText = 'Stock menipis';
      statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 35, 35, 35),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: barColor, width: 4.5),
        ),
        boxShadow: [
          BoxShadow(
            color: barColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 28, 28, 28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color.fromARGB(255, 50, 50, 50)),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: const Color(0xFF498CC8), size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(color: Color(0xFF60B0FF), fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          unit,
                          style: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 11, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: barColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '${stock.toInt()} $unit',
                  style: TextStyle(color: barColor, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min. alert: ${alert.toInt()} $unit',
                style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 12, fontWeight: FontWeight.w400),
              ),
              if (price > 0)
                Text(
                  'Rp ${price.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} / $unit',
                  style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1),
                  backgroundColor: const Color.fromARGB(255, 25, 25, 25),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 10,
                ),
              ),
              if (ratio > 0)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      '$pct%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: barColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(Icons.access_time_rounded, color: const Color.fromARGB(255, 80, 80, 80), size: 13),
              const SizedBox(width: 4),
              Text(
                lastUpdate,
                style: const TextStyle(color: Color.fromARGB(255, 90, 90, 90), fontSize: 11, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
