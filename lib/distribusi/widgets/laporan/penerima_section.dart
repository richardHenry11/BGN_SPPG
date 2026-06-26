import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bgn/distribusi/theme/colors.dart';

class PenerimaSection extends StatefulWidget {
  const PenerimaSection({super.key});

  @override
  State<PenerimaSection> createState() => _PenerimaSectionState();
}

class _PenerimaSectionState extends State<PenerimaSection> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _activeLevel = 'semua';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _levelFilters = [
    _LevelFilter(id: 'semua', label: 'Semua'),
    _LevelFilter(id: 'Sekolah', label: 'Sekolah'),
    _LevelFilter(id: 'Kader/Posyandu', label: 'Posyandu/Kader'),
  ];

  // Mock data
  final List<Map<String, dynamic>> _penerimaList = [
    {
      'id': 1,
      'name': 'SDN 01 Bandung',
      'location': 'Jl. Merdeka No. 1, Bandung',
      'level': 'Sekolah',
      'total_students': 320,
      'target_calories': 700,
      'delivery_time_target': '07:00',
      'pics': [
        {'id': 1, 'name': 'Budi Santoso', 'phone': '081234567890'},
        {'id': 2, 'name': 'Siti Rahmawati', 'phone': '081234567891'},
      ],
    },
    {
      'id': 2,
      'name': 'Posyandu Melati',
      'location': 'Jl. Melati No. 5, Bandung',
      'level': 'Kader/Posyandu',
      'total_students': 75,
      'target_calories': 500,
      'delivery_time_target': '08:30',
      'pics': [
        {'id': 3, 'name': 'Aminah', 'phone': '081234567892'},
      ],
    },
    {
      'id': 3,
      'name': 'SMP 01 Cimahi',
      'location': 'Jl. Cimahi Raya No. 12',
      'level': 'Sekolah',
      'total_students': 450,
      'target_calories': 700,
      'delivery_time_target': '10:00',
      'pics': [
        {'id': 4, 'name': 'Dedi Kusnadi', 'phone': '081234567893'},
        {'id': 5, 'name': 'Rina Marlina', 'phone': '081234567894'},
      ],
    },
    {
      'id': 4,
      'name': 'Posyandu Anggrek',
      'location': 'Jl. Anggrek No. 3, Bandung',
      'level': 'Kader/Posyandu',
      'total_students': 60,
      'target_calories': 500,
      'delivery_time_target': '11:30',
      'pics': [
        {'id': 6, 'name': 'Yuni', 'phone': '081234567895'},
      ],
    },
  ];

  List<Map<String, dynamic>> get _filteredList {
    var list = _penerimaList;
    if (_activeLevel != 'semua') {
      list = list.where((p) => p['level'] == _activeLevel).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
          (p['name'] as String).toLowerCase().contains(q) ||
          (p['location'] as String).toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int get _totalSiswa => _filteredList.fold(0, (sum, p) => sum + (p['total_students'] as int));
  int get _totalPIC => _filteredList.fold(0, (sum, p) => sum + ((p['pics'] as List).length));

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BGNColors.border),
          ),
          child: Row(
            children: [
              const Icon(TablerIcons.search, size: 18, color: BGNColors.textHint),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama sekolah / posyandu...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Level filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _levelFilters.map((f) {
              final isActive = f.id == _activeLevel;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _activeLevel = f.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? BGNColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? BGNColors.primary : BGNColors.border,
                      ),
                    ),
                    child: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.white : BGNColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Summary
        Row(
          children: [
            _SummaryBox(label: 'Total lokasi', value: '${filtered.length}', color: BGNColors.primary, bg: BGNColors.primaryLight),
            const SizedBox(width: 8),
            _SummaryBox(label: 'Total penerima', value: _totalSiswa.toString(), color: BGNColors.success, bg: BGNColors.successLight),
            const SizedBox(width: 8),
            _SummaryBox(label: 'Total PIC', value: '$_totalPIC', color: BGNColors.warning, bg: BGNColors.warningLight),
          ],
        ),
        const SizedBox(height: 12),

        // Empty state
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                const Icon(TablerIcons.search_off, size: 32, color: BGNColors.textHint),
                const SizedBox(height: 8),
                const Text('Data tidak ditemukan',
                    style: TextStyle(fontSize: 12, color: BGNColors.textSecondary)),
              ],
            ),
          )
        else
          ...filtered.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PenerimaCard(item: item),
              )),
      ],
    );
  }
}

class _LevelFilter {
  final String id;
  final String label;

  const _LevelFilter({required this.id, required this.label});
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _SummaryBox({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Penerima Card ─────────────────────────────────────────

class _PenerimaCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _PenerimaCard({required this.item});

  bool get _isSekolah => item['level'] == 'Sekolah';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isSekolah ? BGNColors.primaryLight : BGNColors.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isSekolah ? TablerIcons.school : TablerIcons.heart,
                        size: 18,
                        color: _isSekolah ? BGNColors.primary : BGNColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'],
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(item['location'],
                              style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isSekolah ? BGNColors.primaryLight : BGNColors.successLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item['level'],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _isSekolah ? BGNColors.primary : BGNColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoItem(label: 'Penerima', value: '${item['total_students']}'),
                    _InfoItem(label: 'Target kalori', value: '${item['target_calories']} kkal'),
                    _InfoItem(label: 'Jam antar', value: item['delivery_time_target'], isHighlight: true),
                  ],
                ),
              ],
            ),
          ),

          // PIC list
          if (item['pics'] != null && (item['pics'] as List).isNotEmpty)
            ...(item['pics'] as List).map((pic) => _PICCard(pic: pic)),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _InfoItem({required this.label, required this.value, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isHighlight ? BGNColors.primary : BGNColors.textPrimary,
              )),
          const SizedBox(height: 1),
          Text(label,
              style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── PIC Card ──────────────────────────────────────────────

class _PICCard extends StatelessWidget {
  final Map<String, dynamic> pic;

  const _PICCard({required this.pic});

  String get _phone => (pic['phone'] as String).trim();

  Future<void> _openWhatsApp() async {
    final phone = _phone.startsWith('0')
        ? '62${_phone.substring(1)}'
        : _phone;
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openTelegram() async {
    final phone = _phone.startsWith('0')
        ? '62${_phone.substring(1)}'
        : _phone;
    final uri = Uri.parse('https://t.me/send?phone=$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone() async {
    final uri = Uri.parse('tel:$_phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendSms() async {
    final uri = Uri.parse('sms:$_phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BGNColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(TablerIcons.user_circle, size: 16, color: BGNColors.textHint),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pic['name'],
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BGNColors.textPrimary)),
                  Text(pic['phone'],
                      style: const TextStyle(fontSize: 10, color: BGNColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionButton(
                label: 'WA',
                icon: TablerIcons.brand_whatsapp,
                color: BGNColors.success,
                bg: BGNColors.successLight,
                onTap: _openWhatsApp,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                label: 'Telegram',
                icon: TablerIcons.brand_telegram,
                color: BGNColors.primary,
                bg: BGNColors.primaryLight,
                onTap: _openTelegram,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                label: 'Telepon',
                icon: TablerIcons.phone,
                color: BGNColors.primary,
                bg: BGNColors.primaryLight,
                onTap: _callPhone,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                label: 'SMS',
                icon: TablerIcons.message,
                color: BGNColors.warning,
                bg: BGNColors.warningLight,
                onTap: _sendSms,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
