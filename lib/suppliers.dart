import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'distribusi/providers/auth_provider.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.get(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/suppliers'),
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
      _suppliers = data.cast<Map<String, dynamic>>();
      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _error = 'Gagal terhubung ke server';
        _loading = false;
      });
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active': return Icons.check_circle_rounded;
      case 'inactive': return Icons.cancel_rounded;
      default: return Icons.help_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return const Color(0xFF4CAF50);
      case 'inactive': return const Color(0xFFE53935);
      default: return const Color.fromARGB(255, 120, 120, 120);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_search_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Supplier', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color.fromARGB(255, 176, 176, 176)),
              onPressed: _fetchSuppliers,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1A8FCC)),
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
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 30, 30, 30),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.cloud_off_rounded, color: Color.fromARGB(255, 80, 80, 80), size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 15)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _fetchSuppliers,
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
              : _suppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 30, 30, 30),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.people_outline_rounded, color: Color.fromARGB(255, 80, 80, 80), size: 32),
                          ),
                          const SizedBox(height: 16),
                          const Text('Belum ada supplier', style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 15)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchSuppliers,
                      color: const Color(0xFF1A8FCC),
                      backgroundColor: const Color.fromARGB(255, 40, 40, 40),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _suppliers.length,
                        itemBuilder: (_, i) => _buildSupplierCard(_suppliers[i]),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF1A8FCC),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showAddDialog() => _showSupplierForm();

  void _showEditDialog(Map<String, dynamic> supplier) {
    final id = supplier['id'];
    _showSupplierForm(supplier: supplier, id: id);
  }

  void _showSupplierForm({Map<String, dynamic>? supplier, int? id}) {
    final isEdit = supplier != null;
    final nameCtrl = TextEditingController(text: isEdit ? supplier['name'] as String? ?? '' : '');
    final contactCtrl = TextEditingController(text: isEdit ? supplier['contact_name'] as String? ?? '' : '');
    final phoneCtrl = TextEditingController(text: isEdit ? supplier['phone'] as String? ?? '' : '');
    final addressCtrl = TextEditingController(text: isEdit ? supplier['address'] as String? ?? '' : '');
    final materialsCtrl = TextEditingController(text: isEdit ? supplier['raw_materials'] as String? ?? '' : '');
    final distanceCtrl = TextEditingController(text: isEdit ? '${supplier['distance'] ?? ''}' : '');
    bool posting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 30, 30, 30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(isEdit ? Icons.edit_rounded : Icons.person_add_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(isEdit ? 'Edit Supplier' : 'Tambah Supplier',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _field(nameCtrl, 'Nama Supplier', 'Cth: CV Coki Makmur'),
                const SizedBox(height: 12),
                _field(contactCtrl, 'Nama Kontak', 'Cth: Budi'),
                const SizedBox(height: 12),
                _field(phoneCtrl, 'Nomor Telepon', 'Cth: 08123456789', keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(addressCtrl, 'Alamat', 'Cth: Cianjur'),
                const SizedBox(height: 12),
                _field(materialsCtrl, 'Bahan Baku', 'Cth: Beras, Kentang'),
                const SizedBox(height: 12),
                _field(distanceCtrl, 'Jarak (km)', 'Cth: 12.5', keyboardType: TextInputType.number),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A8FCC),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: posting
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final contact = contactCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            final address = addressCtrl.text.trim();
                            final materials = materialsCtrl.text.trim();
                            final distance = double.tryParse(distanceCtrl.text.trim()) ?? 0;
                            if (name.isEmpty || contact.isEmpty || phone.isEmpty) return;
                            setDialogState(() => posting = true);
                            if (isEdit && id != null) {
                              await _updateSupplier(id, name, contact, phone, address, materials, distance);
                            } else {
                              await _addSupplier(name, contact, phone, address, materials, distance);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: posting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? 'Simpan Perubahan' : 'Simpan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
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
      ),
    );
  }

  Future<void> _addSupplier(String name, String contact, String phone, String address, String materials, double distance) async {
    try {
      final body = {
        'name': name,
        'contact_name': contact,
        'phone': phone,
        'address': address,
        'raw_materials': materials,
        'distance': distance,
      };
      final auth = context.read<AuthProvider>();
      final res = await http.post(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/suppliers'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _fetchSuppliers();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal simpan (${res.statusCode})'),
              backgroundColor: const Color(0xFFE53935),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server'),
            backgroundColor: Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateSupplier(int id, String name, String contact, String phone, String address, String materials, double distance) async {
    try {
      final body = {
        'name': name,
        'contact_name': contact,
        'phone': phone,
        'address': address,
        'raw_materials': materials,
        'distance': distance,
      };
      final auth = context.read<AuthProvider>();
      final res = await http.put(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/suppliers/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _fetchSuppliers();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal update (${res.statusCode})'),
              backgroundColor: const Color(0xFFE53935),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server'),
            backgroundColor: Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmDelete(Map<String, dynamic> supplier) {
    final id = supplier['id'];
    final name = supplier['name'] as String? ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 40, 40, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935), size: 16),
            ),
            const SizedBox(width: 10),
            const Text('Hapus Supplier', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus "$name"?',
          style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color.fromARGB(255, 120, 120, 120))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSupplier(id);
            },
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSupplier(int id) async {
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.delete(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/suppliers/$id'),
        headers: {
          'Accept': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _fetchSuppliers();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal hapus (${res.statusCode})'),
              backgroundColor: const Color(0xFFE53935),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server'),
            backgroundColor: Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    final name = supplier['name'] as String? ?? '';
    final contact = supplier['contact_name'] as String? ?? '';
    final phone = supplier['phone'] as String? ?? '';
    final address = supplier['address'] as String? ?? '';
    final rawMaterials = supplier['raw_materials'] as String? ?? '';
    final status = supplier['status'] as String? ?? '';
    final rating = (supplier['rating'] as num?)?.toDouble() ?? 0;

    return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 35, 35, 35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color.fromARGB(255, 50, 50, 50)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon(status), color: _statusColor(status), size: 10),
                                  const SizedBox(width: 4),
                                  Text(status,
                                    style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            if (rating > 0) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.star_rounded, color: const Color(0xFFD4A843), size: 14),
                              const SizedBox(width: 3),
                              Text(rating.toStringAsFixed(1),
                                style: const TextStyle(color: Color(0xFFD4A843), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _showEditDialog(supplier),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A8FCC).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.edit_rounded, color: Color(0xFF60B0FF), size: 15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _confirmDelete(supplier),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935), size: 15),
                        ),
                      ),
                    ],
                  ),
                ],
            ),
            const SizedBox(height: 14),
            _infoRow(Icons.person_outline_rounded, contact),
            const SizedBox(height: 6),
            _infoRow(Icons.phone_rounded, phone),
            const SizedBox(height: 6),
            _infoRow(Icons.location_on_rounded, address),
            const SizedBox(height: 6),
            _infoRow(Icons.inventory_2_rounded, rawMaterials),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF1A8FCC).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, color: const Color.fromARGB(255, 130, 130, 130), size: 12),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
            style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
