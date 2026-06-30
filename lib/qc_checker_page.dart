import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'distribusi/providers/auth_provider.dart';
import 'services/procurement_api.dart';

class QcCheckerPage extends StatefulWidget {
  const QcCheckerPage({super.key});

  @override
  State<QcCheckerPage> createState() => _QcCheckerPageState();
}

class _QcCheckerPageState extends State<QcCheckerPage> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      _data = await ProcurementApi.fetchInspections(sppgId: auth.sppgId, role: auth.currentRole);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() { _loading = false; });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved': return const Color(0xFF4CAF50);
      case 'Rejected': return const Color(0xFFE53935);
      case 'Pending': return const Color(0xFFFFA726);
      default: return Colors.grey;
    }
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A': return const Color(0xFF4CAF50);
      case 'B': return const Color(0xFFFFA726);
      case 'C': return const Color(0xFFE53935);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('QC Checker', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1A8FCC)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Color.fromARGB(255, 80, 80, 80), size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 14), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetch,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A8FCC), foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : _data.isEmpty
                  ? const Center(child: Text('Tidak ada data QC', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133))))
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      color: const Color(0xFF1A8FCC),
                      backgroundColor: const Color.fromARGB(255, 40, 40, 40),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _data.length,
                        itemBuilder: (_, i) => _buildCard(_data[i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = item['status'] as String? ?? '';
    final grade = item['quality_grade'] as String? ?? '';
    final date = _formatDate(item['inspection_date'] as String?);
    final photoUrl = item['photo_url'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 37, 37, 37),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Text('PO #${item['po_id']}', style: const TextStyle(color: Color(0xFF498CC8), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row('Inspektor', item['inspector_name'] as String? ?? '-'),
                const SizedBox(height: 8),
                _row('Tanggal', date),
                const SizedBox(height: 8),
                _row('Qty Diterima', '${item['quantity_received'] ?? '-'} / ${item['quantity_expected'] ?? '-'}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text('Grade', style: TextStyle(color: _gradeColor(grade), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: _gradeColor(grade).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(grade, style: TextStyle(color: _gradeColor(grade), fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Text('Penyimpanan: ', style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 13)),
                    Text(item['storage_condition'] as String? ?? '-', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
                if ((item['notes'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _row('Catatan', item['notes'] as String? ?? ''),
                ],
                if (photoUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(photoUrl, height: 140, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 140, color: const Color.fromARGB(255, 30, 30, 30),
                        child: const Icon(Icons.broken_image, color: Colors.grey, size: 36))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ],
    );
  }
}
