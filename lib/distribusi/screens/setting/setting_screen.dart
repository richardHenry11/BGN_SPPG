import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/school_service.dart';
import 'package:bgn/distribusi/widgets/common/car_refresh_indicator.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final SchoolService _schoolService = SchoolService(ApiClient());
  List<dynamic> _schools = [];
  bool _loading = false;
  String? _error;

  Map<String, String> _authHeaders() {
    final auth = context.read<AuthProvider>();
    final h = <String, String>{
      'X-User-Role': auth.apiRole,
    };
    if (auth.token != null) h['Authorization'] = 'Bearer ${auth.token}';
    if (auth.sppgId != null) h['X-User-Sppg-Id'] = auth.sppgId.toString();
    return h;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _schoolService.getSchools(headers: _authHeaders());
      if (!mounted) return;
      setState(() => _schools = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(int index, Map<String, dynamic> updated) async {
    final school = _schools[index];
    final id = school['id'] as int;
    try {
      await _schoolService.updateSchool(id, updated, headers: _authHeaders());
      if (!mounted) return;
      setState(() => _schools[index] = updated);
      if (mounted) _showSnack('Sekolah berhasil diperbarui');
    } catch (e) {
      if (mounted) _showSnack('Gagal: ${e.toString()}');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openEdit(int index) {
    final school = Map<String, dynamic>.from(_schools[index]);
    _SchoolEditSheet.show(context, school, (updated) => _save(index, updated));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _schools.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _schools.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(TablerIcons.alert_circle, size: 36, color: BGNColors.danger),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12, color: BGNColors.danger)),
            const SizedBox(height: 8),
            TextButton(onPressed: _fetch, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    return CarRefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _schools.length,
        itemBuilder: (context, index) {
          final s = _schools[index];
          final name = s['name'] as String? ?? '';
          final level = s['level'] as String? ?? '';
          final location = s['location'] as String? ?? '';
          final students = s['total_students'] as int? ?? 0;
          final calories = s['target_calories'] as int? ?? 0;
          final deliveryTime = s['delivery_time_target'] as String? ?? '-';
          final pics = s['pics'] as List<dynamic>? ?? [];

          return GestureDetector(
            onTap: () => _openEdit(index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BGNColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BGNColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: BGNColors.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(level, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: BGNColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(TablerIcons.map_pin, size: 12, color: BGNColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(location, style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip('$students siswa', TablerIcons.users),
                      const SizedBox(width: 8),
                      _chip('$calories kkal', TablerIcons.flame),
                      const SizedBox(width: 8),
                      _chip(deliveryTime, TablerIcons.clock),
                    ],
                  ),
                  if (pics.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...pics.map((pic) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          const Icon(TablerIcons.user, size: 11, color: BGNColors.textHint),
                          const SizedBox(width: 4),
                          Text('${pic['name'] ?? '-'} (${pic['phone'] ?? '-'})', style: const TextStyle(fontSize: 10, color: BGNColors.textHint)),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: BGNColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: BGNColors.textSecondary),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Edit bottom sheet
// ═══════════════════════════════════════════════════════════

class _SchoolEditSheet extends StatefulWidget {
  final Map<String, dynamic> school;
  final void Function(Map<String, dynamic>) onSave;

  const _SchoolEditSheet({required this.school, required this.onSave});

  static void show(BuildContext context, Map<String, dynamic> school, void Function(Map<String, dynamic>) onSave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _SchoolEditSheet(school: school, onSave: onSave),
      ),
    );
  }

  @override
  State<_SchoolEditSheet> createState() => _SchoolEditSheetState();
}

class _SchoolEditSheetState extends State<_SchoolEditSheet> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _locationCtl;
  late final TextEditingController _studentsCtl;
  late final TextEditingController _caloriesCtl;
  late final TextEditingController _latCtl;
  late final TextEditingController _lngCtl;
  late final TextEditingController _timeCtl;
  late final TextEditingController _levelCtl;

  @override
  void initState() {
    super.initState();
    final s = widget.school;
    _nameCtl = TextEditingController(text: s['name'] as String? ?? '');
    _locationCtl = TextEditingController(text: s['location'] as String? ?? '');
    _studentsCtl = TextEditingController(text: (s['total_students'] as int? ?? 0).toString());
    _caloriesCtl = TextEditingController(text: (s['target_calories'] as int? ?? 0).toString());
    _latCtl = TextEditingController(text: (s['latitude'] as num?)?.toStringAsFixed(6) ?? '');
    _lngCtl = TextEditingController(text: (s['longitude'] as num?)?.toStringAsFixed(6) ?? '');
    _timeCtl = TextEditingController(text: s['delivery_time_target'] as String? ?? '');
    _levelCtl = TextEditingController(text: s['level'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _locationCtl.dispose();
    _studentsCtl.dispose();
    _caloriesCtl.dispose();
    _latCtl.dispose();
    _lngCtl.dispose();
    _timeCtl.dispose();
    _levelCtl.dispose();
    super.dispose();
  }

  void _handleSave() {
    final updated = Map<String, dynamic>.from(widget.school)
      ..['name'] = _nameCtl.text
      ..['location'] = _locationCtl.text
      ..['total_students'] = int.tryParse(_studentsCtl.text) ?? 0
      ..['target_calories'] = int.tryParse(_caloriesCtl.text) ?? 0
      ..['latitude'] = double.tryParse(_latCtl.text) ?? 0
      ..['longitude'] = double.tryParse(_lngCtl.text) ?? 0
      ..['delivery_time_target'] = _timeCtl.text
      ..['level'] = _levelCtl.text;
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(TablerIcons.school, size: 20, color: BGNColors.primary),
                const SizedBox(width: 8),
                const Text('Edit Sekolah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: BGNColors.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(TablerIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field('Nama Sekolah', _nameCtl),
            const SizedBox(height: 10),
            _field('Level', _levelCtl),
            const SizedBox(height: 10),
            _field('Alamat', _locationCtl, maxLines: 2),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _field('Total Siswa', _studentsCtl, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('Target Kalori', _caloriesCtl, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _field('Latitude', _latCtl, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('Longitude', _lngCtl, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 10),
            _field('Waktu Kirim', _timeCtl, hint: 'e.g. 11:00'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BGNColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Simpan', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl, {int maxLines = 1, TextInputType? keyboardType, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BGNColors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: ctl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: BGNColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: BGNColors.border)),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
