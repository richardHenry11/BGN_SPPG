import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'distribusi/providers/auth_provider.dart';

class InspectionPage extends StatefulWidget {
  const InspectionPage({super.key});

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _list = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.get(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/inspections'),
        headers: {
          'Accept': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _list = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        throw Exception('Gagal memuat (${res.statusCode})');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Hasil QC',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A8FCC)))
          : _error != null
              ? _buildError()
              : _list.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: const Color(0xFF1A8FCC),
                      backgroundColor: const Color.fromARGB(255, 47, 47, 47),
                      onRefresh: _fetch,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _buildCard(_list[i]),
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Color.fromARGB(255, 80, 80, 80)),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat data',
              style: TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A8FCC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 72, color: const Color.fromARGB(255, 60, 60, 60)),
          const SizedBox(height: 16),
          const Text(
            'Belum ada hasil QC',
            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hasil inspeksi dari SPPG akan muncul di sini',
            style: TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> data) {
    final grade = data['quality_grade'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final inspector = data['inspector_name'] as String? ?? '';
    final qtyExpected = data['quantity_expected'] ?? 0;
    final qtyReceived = data['quantity_received'] ?? 0;
    final storage = data['storage_condition'] as String? ?? '';
    final notes = data['notes'] as String? ?? '';
    final photoUrl = data['photo_url'] as String? ?? '';
    final poId = data['po_id'] ?? 0;
    final sppgId = data['sppg_id'] ?? '';
    final date = data['inspection_date'] as String? ?? '';

    final dateStr = date.length >= 10 ? date.substring(0, 10) : date;

    final gradeColor = grade == 'A'
        ? const Color(0xFF4CAF50)
        : grade == 'B'
            ? const Color(0xFFD4A843)
            : const Color(0xFFE53935);

    final statusColor = status == 'Approved'
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE53935);

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: statusColor, width: 5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Grade $grade',
                    style: TextStyle(color: gradeColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  'PO #$poId',
                  style: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow(Icons.person_outline, 'Inspektur', inspector),
            const SizedBox(height: 8),
            _infoRow(Icons.calendar_today, 'Tanggal', dateStr),
            const SizedBox(height: 8),
            _infoRow(Icons.inventory_2, 'Diharapkan', '$qtyExpected'),
            const SizedBox(height: 8),
            _infoRow(Icons.check_circle_outline, 'Diterima', '$qtyReceived'),
            if (storage.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.store, 'Kondisi', storage),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.notes, 'Catatan', notes),
            ],
            if (photoUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color.fromARGB(255, 30, 30, 30),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Color.fromARGB(255, 80, 80, 80), size: 36),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.business, color: const Color.fromARGB(255, 100, 100, 100), size: 13),
                const SizedBox(width: 4),
                Text(
                  'SPPG #$sppgId',
                  style: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF498CC8), size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
