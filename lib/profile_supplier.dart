import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'distribusi/providers/auth_provider.dart';

class ProfileSupplierPage extends StatefulWidget {
  const ProfileSupplierPage({super.key});

  @override
  State<ProfileSupplierPage> createState() => _ProfileSupplierPageState();
}

class _ProfileSupplierPageState extends State<ProfileSupplierPage> {
  Map<String, dynamic>? _supplier;
  bool _loading = true;
  String? _error;
  int _productCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final supplierId = auth.supplierId;
      if (supplierId == null || supplierId.isEmpty) {
        setState(() { _error = 'Data supplier tidak ditemukan'; _loading = false; });
        return;
      }
      final res = await http.get(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/suppliers/$supplierId'),
        headers: {
          'Accept': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode != 200) {
        setState(() { _error = 'Gagal memuat profil (${res.statusCode})'; _loading = false; });
        return;
      }
      _supplier = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() => _loading = false);
      _fetchProductCount();
    } catch (e) {
      setState(() { _error = 'Gagal terhubung ke server'; _loading = false; });
    }
  }

  Future<void> _fetchProductCount() async {
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
        _productCount = data
            .cast<Map<String, dynamic>>()
            .where((p) => p['supplier_id'].toString() == sId)
            .length;
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A8FCC)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Color.fromARGB(255, 80, 80, 80), size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 15)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _fetchProfile,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A8FCC),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchProfile,
                  color: const Color(0xFF1A8FCC),
                  backgroundColor: const Color.fromARGB(255, 40, 40, 40),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildCoverSection(h),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          child: Column(
                            children: [
                              _buildStatsRow(),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _showEditForm,
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  label: const Text('Edit Profil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A8FCC),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildGlassCard(
                                icon: Icons.business_rounded,
                                title: 'Informasi Perusahaan',
                                children: [
                                  _infoRow(Icons.store_rounded, 'Nama Perusahaan', _supplier?['name'] as String? ?? '-'),
                                  _infoRow(Icons.person_rounded, 'Kontak Person', _supplier?['contact_name'] as String? ?? '-'),
                                  _infoRow(Icons.phone_rounded, 'Telepon', _supplier?['phone'] as String? ?? '-'),
                                  _infoRow(Icons.email_rounded, 'Email', _supplier?['email'] as String? ?? '-'),
                                  _infoRow(Icons.location_on_rounded, 'Alamat', _supplier?['address'] as String? ?? '-'),
                                  _infoRow(Icons.agriculture_rounded, 'Bahan Baku', _supplier?['raw_materials'] as String? ?? '-'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  void _showEditForm() {
    final nameCtrl = TextEditingController(text: _supplier?['name'] as String? ?? '');
    final contactCtrl = TextEditingController(text: _supplier?['contact_name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: _supplier?['phone'] as String? ?? '');
    final addressCtrl = TextEditingController(text: _supplier?['address'] as String? ?? '');
    final materialsCtrl = TextEditingController(text: _supplier?['raw_materials'] as String? ?? '');
    final ratingCtrl = TextEditingController(text: '${_supplier?['rating'] ?? ''}');
    final distanceCtrl = TextEditingController(text: _supplier?['distance'] != null ? (_supplier!['distance'] as num).toStringAsFixed(1) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 30, 30, 30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 80, 80, 80),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Edit Profil Supplier', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _editField('Nama Perusahaan', nameCtrl),
                    const SizedBox(height: 14),
                    _editField('Kontak Person', contactCtrl),
                    const SizedBox(height: 14),
                    _editField('Telepon', phoneCtrl, keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    _editField('Alamat', addressCtrl, maxLines: 2),
                    const SizedBox(height: 14),
                    _editField('Bahan Baku', materialsCtrl),
                    const SizedBox(height: 14),
                    _editField('Rating', ratingCtrl, keyboardType: TextInputType.number),
                    const SizedBox(height: 14),
                    _editField('Jarak (km)', distanceCtrl, keyboardType: TextInputType.number),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setSheetState(() => saving = true);
                                try {
                                  final auth = context.read<AuthProvider>();
                                  final supplierId = auth.supplierId;
                                  if (supplierId == null || supplierId.isEmpty) throw Exception('ID supplier tidak ditemukan');
                                  final body = {
                                    'name': nameCtrl.text.trim(),
                                    'contact_name': contactCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'address': addressCtrl.text.trim(),
                                    'raw_materials': materialsCtrl.text.trim(),
                                    'status': 'Active',
                                    'rating': int.tryParse(ratingCtrl.text.trim()) ?? 5,
                                    'distance': double.tryParse(distanceCtrl.text.trim()) ?? 0,
                                  };
                                  final res = await http.put(
                                    Uri.parse('https://sppg.cbinstrument.com/api/procurement/suppliers/$supplierId'),
                                    headers: {
                                      'Content-Type': 'application/json',
                                      'x-user-Sppg-id': auth.sppgId ?? '',
                                      'x-user-Role': auth.currentRole,
                                    },
                                    body: jsonEncode(body),
                                  );
                                  if (res.statusCode != 200 && res.statusCode != 201) {
                                    throw Exception('Gagal update (${res.statusCode})');
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Profil berhasil diperbarui'), backgroundColor: Color(0xFF1B5E20)),
                                  );
                                  _fetchProfile();
                                } catch (e) {
                                  setSheetState(() => saving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFB71C1C)),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A8FCC),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _editField(String label, TextEditingController controller, {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 40, 40, 40),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverSection(double h) {
    final name = _supplier?['name'] as String? ?? 'Supplier';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Container(
      height: h * 0.32,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D2B4A), Color(0xFF135B92), Color(0xFF1A8FCC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, color: Color(0xFF4CAF50), size: 14),
                        SizedBox(width: 4),
                        Text('Supplier Aktif', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF1A8FCC),
                      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _supplier?['phone'] as String? ?? '',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 35, 35, 35),
              const Color.fromARGB(255, 45, 45, 45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            _statItem(Icons.star_rounded, 'Rating', '${_supplier?['rating'] ?? '-'}', const Color(0xFFFFB74D)),
            _statDivider(),
            _statItem(Icons.inventory_2_rounded, 'Produk', '$_productCount', const Color(0xFF60B0FF)),
            _statDivider(),
            _statItem(Icons.map_rounded, 'Jarak', (_supplier?['distance'] as num?) != null ? '${(_supplier!['distance'] as num).toStringAsFixed(1)} km' : '-', const Color(0xFF81C784)),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 36, color: const Color.fromARGB(255, 60, 60, 60));
  }

  Widget _buildGlassCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 40, 40, 40).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A8FCC).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF60B0FF), size: 18),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 50, 50, 50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color.fromARGB(255, 133, 133, 133), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
