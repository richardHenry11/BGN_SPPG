import 'dart:convert';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PlanningDapurPage extends StatefulWidget {
  const PlanningDapurPage({super.key});

  @override
  State<PlanningDapurPage> createState() => _PlanningDapurPageState();
}

class _PlanningDapurPageState extends State<PlanningDapurPage> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _plans = [];
  // List<Map<String, dynamic>> _recipes = [];
  bool _loading = false;
  bool _showCalendar = true;
  DateTime _currentMonth = DateTime.now();

  final _searchCtrl = TextEditingController();
  String _filterStatus = 'Semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      _apiClient.setAuthData(auth.sppgId, auth.currentRole);
      _fetchPlans();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPlans() async {
    setState(() => _loading = true);
    try {
      final res = await _apiClient.get('/api/production/plans');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _plans = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> get _plansByDate {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final plan in _plans) {
      final date = plan['target_date'] as String?;
      if (date != null) {
        map.putIfAbsent(date, () => []).add(plan);
      }
    }
    return map;
  }

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Jadwal Produksi Dapur Gizi',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Kalender & Rencana Masak',
                  style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Kelola Seluruh Agenda masak harian, pantau status porsi dapur, dan lakukan audit Formula Bahan Baku',
            style: TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Hapus Semua', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showAddScheduleForm(),
                        child: const Center(
                          child: Text('Jadwalkan Menu Baru',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _toggleButton('Tampilan Kalender Bulanan', true),
              const SizedBox(width: 12),
              _toggleButton('Tampilan Daftar Table & Filter', false),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_showCalendar)
            _buildCalendar()
          else
            _buildTableView(),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool isCalendar) {
    final selected = _showCalendar == isCalendar;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showCalendar = isCalendar),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A8FCC) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF1A8FCC) : Colors.white24,
            ),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : const Color.fromARGB(255, 180, 180, 180),
                fontSize: 12, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
              onPressed: () => setState(() => _currentMonth = DateTime(year, month - 1, 1)),
            ),
            Text(
              '${_monthNames[month - 1]} $year',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
              onPressed: () => setState(() => _currentMonth = DateTime(year, month + 1, 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].map((d) =>
            Expanded(
              child: Center(
                child: Text(d,
                  style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ).toList(),
        ),
        const SizedBox(height: 4),
        ..._buildCalendarGrid(year, month, firstWeekday, daysInMonth),
      ],
    );
  }

  List<Widget> _buildCalendarGrid(int year, int month, int firstWeekday, int daysInMonth) {
    final today = DateTime.now();
    final weeks = <List<int?>>[];
    var day = 1;
    final offset = firstWeekday - 1;

    for (var row = 0; row < 6; row++) {
      final week = <int?>[];
      for (var col = 0; col < 7; col++) {
        if (row == 0 && col < offset) {
          week.add(null);
        } else if (day > daysInMonth) {
          week.add(null);
        } else {
          week.add(day);
          day++;
        }
      }
      weeks.add(week);
      if (day > daysInMonth) break;
    }

    return weeks.map((week) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: week.map((d) {
          if (d == null) {
            return const Expanded(child: SizedBox(height: 90));
          }
          final dateStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
          final dayPlans = _plansByDate[dateStr] ?? [];
          final isToday = today.year == year && today.month == month && today.day == d;

          return Expanded(
            child: Container(
              height: 120,
              margin: const EdgeInsets.all(1.5),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isToday ? const Color(0xFF1A8FCC).withValues(alpha: 0.15) : const Color.fromARGB(255, 22, 22, 22),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isToday ? const Color(0xFF1A8FCC) : Colors.white.withOpacity(0.06),
                  width: isToday ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$d',
                    style: TextStyle(
                      color: isToday ? const Color(0xFF1A8FCC) : Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (dayPlans.isNotEmpty)
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: dayPlans.map((plan) {
                          final name = plan['menu_name'] as String? ?? '';
                          return GestureDetector(
                            onTap: () => _showPlanDetail(context, plan),
                            child: Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A8FCC).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 9),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    )).toList();
  }

  Widget _buildTableView() {
    final filtered = _plans.where((p) {
      final status = p['status'] as String? ?? '';
      if (_filterStatus != 'Semua' && status != _filterStatus) return false;
      final name = p['menu_name'] as String? ?? '';
      final query = _searchCtrl.text.toLowerCase();
      if (query.isNotEmpty && !name.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Cari menu...',
                  hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color.fromARGB(255, 100, 100, 100), size: 20),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 22, 22, 22),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 22, 22, 22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterStatus,
                  dropdownColor: const Color.fromARGB(255, 22, 22, 22),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1A8FCC), size: 20),
                  items: ['Semua', 'Scheduled', 'Active', 'Completed', 'Cancelled'].map((s) {
                    return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _filterStatus = v);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Tidak ada data', style: TextStyle(color: Color.fromARGB(255, 100, 100, 100))),
          )
        else
          ...filtered.map((plan) => _buildPlanCard(plan)),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['menu_name'] as String? ?? '';
    final date = plan['target_date'] as String? ?? '';
    final status = plan['status'] as String? ?? '';
    final large = plan['target_portions_large'] ?? 0;
    final small = plan['target_portions_small'] ?? 0;

    Color statusColor;
    switch (status) {
      case 'Active':
        statusColor = const Color(0xFF4CAF50);
        break;
      case 'Completed':
        statusColor = const Color(0xFF2196F3);
        break;
      case 'Cancelled':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = const Color(0xFFFF9800);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 22, 22, 22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('$date | Porsi Besar: $large | Porsi Kecil: $small',
                  style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status,
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _showPlanDetail(context, plan),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A8FCC).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.edit_rounded, color: Color(0xFF1A8FCC), size: 16),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _deletePlan(plan),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _deletePlan(Map<String, dynamic> plan) async {
    final planId = plan['id'];
    if (planId == null) return;
    try {
      final res = await _apiClient.delete('/api/production/plans/$planId');
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchPlans();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil dihapus'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal menghapus';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPlanDetail(BuildContext context, Map<String, dynamic> plan) {
    final planId = plan['id'];
    final name = plan['menu_name'] as String? ?? '';
    final date = plan['target_date'] as String? ?? '';
    final status = plan['status'] as String? ?? '';
    final targetLarge = (plan['target_portions_large'] as num?)?.toDouble() ?? 0;
    final targetSmall = (plan['target_portions_small'] as num?)?.toDouble() ?? 0;
    final calL = (plan['calories_large'] as num?)?.toDouble() ?? 0;
    final protL = (plan['protein_large'] as num?)?.toDouble() ?? 0;
    final fatL = (plan['fat_large'] as num?)?.toDouble() ?? 0;
    final carbsL = (plan['carbs_large'] as num?)?.toDouble() ?? 0;
    final fiberL = (plan['fiber_large'] as num?)?.toDouble() ?? 0;
    final calS = (plan['calories_small'] as num?)?.toDouble() ?? 0;
    final protS = (plan['protein_small'] as num?)?.toDouble() ?? 0;
    final fatS = (plan['fat_small'] as num?)?.toDouble() ?? 0;
    final carbsS = (plan['carbs_small'] as num?)?.toDouble() ?? 0;
    final fiberS = (plan['fiber_small'] as num?)?.toDouble() ?? 0;
    final messenger = ScaffoldMessenger.of(context);

    _fetchBom(planId).then((bomList) {
      if (!mounted) return;
      final largeCtrls = <int, TextEditingController>{};
      final smallCtrls = <int, TextEditingController>{};
      for (final bom in bomList) {
        final id = bom['id'] as int? ?? 0;
        largeCtrls[id] = TextEditingController(text: '${bom['weight_large'] ?? 0}');
        smallCtrls[id] = TextEditingController(text: '${bom['weight_small'] ?? 0}');
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color.fromARGB(255, 22, 22, 22),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(name,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _detailRow('Tanggal', date),
                      _detailRow('Status', status),
                      _detailRow('Porsi Besar', '${targetLarge.toInt()}'),
                      _detailRow('Porsi Kecil', '${targetSmall.toInt()}'),
                      const SizedBox(height: 12),
                      const Text('Komposisi Bahan Baku',
                        style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...bomList.map((bom) {
                        final id = bom['id'] as int? ?? 0;
                        final matName = bom['material_name'] as String? ?? '';
                        final besarCtrl = largeCtrls[id]!;
                        final kecilCtrl = smallCtrls[id]!;
                        final besarVal = num.tryParse(besarCtrl.text)?.toDouble() ?? 0;
                        final kecilVal = num.tryParse(kecilCtrl.text)?.toDouble() ?? 0;
                        final total = ((targetLarge * besarVal) + (targetSmall * kecilVal)) / 1000;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 30, 30, 30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(matName,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _detailInputField('Porsi Besar (g)', besarCtrl, setSheetState),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _detailInputField('Porsi Kecil (g)', kecilCtrl, setSheetState),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Total: ${total.toStringAsFixed(1)} Kg',
                                style: const TextStyle(color: Color(0xFF1A8FCC), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      const Text('Nilai Gizi - Porsi Besar',
                        style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      _detailRow('Kalori', '${calL}kcal'),
                      _detailRow('Protein', '${protL}g'),
                      _detailRow('Lemak', '${fatL}g'),
                      _detailRow('Karbohidrat', '${carbsL}g'),
                      _detailRow('Serat', '${fiberL}g'),
                      const SizedBox(height: 12),
                      const Text('Nilai Gizi - Porsi Kecil',
                        style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      _detailRow('Kalori', '${calS}kcal'),
                      _detailRow('Protein', '${protS}g'),
                      _detailRow('Lemak', '${fatS}g'),
                      _detailRow('Karbohidrat', '${carbsS}g'),
                      _detailRow('Serat', '${fiberS}g'),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _updatePlan(
                                ctx, plan, bomList, largeCtrls, smallCtrls,
                                targetLarge, targetSmall, messenger,
                              ),
                              child: const Center(
                                child: Text('Simpan Perubahan',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
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
        },
      );
    });
  }

  Future<List<Map<String, dynamic>>> _fetchBom(dynamic planId) async {
    if (planId == null) return [];
    try {
      final res = await _apiClient.get('/api/production/plans/$planId/bom');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _updatePlan(
    BuildContext ctx,
    Map<String, dynamic> plan,
    List<Map<String, dynamic>> bomList,
    Map<int, TextEditingController> largeCtrls,
    Map<int, TextEditingController> smallCtrls,
    double targetLarge,
    double targetSmall,
    ScaffoldMessengerState messenger,
  ) async {
    final planId = plan['id'];
    if (planId == null) return;

    final bom = bomList.map((b) {
      final id = b['id'] as int? ?? 0;
      final besarVal = num.tryParse(largeCtrls[id]?.text ?? '')?.toDouble() ?? 0;
      final kecilVal = num.tryParse(smallCtrls[id]?.text ?? '')?.toDouble() ?? 0;
      final total = ((targetLarge * besarVal) + (targetSmall * kecilVal)) / 1000;
      return {
        'id': id,
        'production_plan_id': b['production_plan_id'],
        'material_id': b['material_id'],
        'material_name': b['material_name'],
        'standard_weight_per_portion': b['standard_weight_per_portion'],
        'weight_large': besarVal,
        'weight_small': kecilVal,
        'total_required_weight': total,
      };
    }).toList();

    final body = {
      'menu_name': plan['menu_name'],
      'target_date': plan['target_date'],
      'target_portions': plan['target_portions'],
      'target_portions_large': plan['target_portions_large'],
      'target_portions_small': plan['target_portions_small'],
      'status': plan['status'],
      'sppg_id': plan['sppg_id'] ?? 1,
      'calories_large': plan['calories_large'],
      'protein_large': plan['protein_large'],
      'fat_large': plan['fat_large'],
      'carbs_large': plan['carbs_large'],
      'fiber_large': plan['fiber_large'],
      'calories_small': plan['calories_small'],
      'protein_small': plan['protein_small'],
      'fat_small': plan['fat_small'],
      'carbs_small': plan['carbs_small'],
      'fiber_small': plan['fiber_small'],
      'bom': bom,
    };

    try {
      final res = await _apiClient.put('/api/production/plans/$planId', body: body);
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pop(ctx);
        messenger.showSnackBar(
          const SnackBar(content: Text('Berhasil diperbarui'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal memperbarui';
        messenger.showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _detailInputField(String label, TextEditingController controller, void Function(void Function()) setSheetState) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setSheetState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 11),
        filled: true,
        fillColor: const Color.fromARGB(255, 22, 22, 22),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
        ),
      ),
    );
  }

  void _showAddScheduleForm() {
    _fetchRecipes().then((recipes) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final nameCtrl = TextEditingController();
      final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
      final porsiCtrl = TextEditingController();
      var selectedRecipe = -1;
      var selectedDate = DateTime.now();
      List<Map<String, dynamic>> bomItems = [];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color.fromARGB(255, 22, 22, 22),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final totalPorsi = num.tryParse(porsiCtrl.text)?.toDouble() ?? 0;
              final bomsPreview = bomItems.map((b) {
                final stdW = (b['standard_weight_per_portion'] as num?)?.toDouble() ?? 0;
                final totalW = (totalPorsi * stdW) / 1000;
                return {
                  'material_name': b['material_name'],
                  'total_required_weight': totalW,
                };
              }).toList();

              return Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 32,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Jadwalkan Produksi Dapur Masak',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 20),
                      const Text('Pilih Resep', style: TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      _recipeDropdown(recipes, selectedRecipe, (id) {
                        setSheetState(() {
                          selectedRecipe = id;
                          final recipe = recipes.cast<Map<String, dynamic>?>().firstWhere(
                            (r) => r?['id'] == id, orElse: () => null,
                          );
                          if (recipe != null) {
                            nameCtrl.text = '${recipe['name'] ?? ''}';
                            bomItems = (recipe['bom'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                          }
                        });
                      }),
                      const SizedBox(height: 16),
                      const Text('Nama Menu', style: TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      _formTextField(nameCtrl, 'Nama menu otomatis dari resep'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(dateCtrl, selectedDate, (d) {
                              setSheetState(() {
                                selectedDate = d;
                                dateCtrl.text = d.toIso8601String().split('T')[0];
                              });
                            }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _formTextField(porsiCtrl, 'Porsi Produksi', keyboardType: TextInputType.number),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (bomsPreview.isNotEmpty) ...[
                        const Text('Ringkasan Bahan Baku', style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...bomsPreview.map((b) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 30, 30, 30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${b['material_name']}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              Text('${(b['total_required_weight'] as num).toStringAsFixed(2)} Kg',
                                style: const TextStyle(color: Color(0xFF1A8FCC), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final porsiVal = num.tryParse(porsiCtrl.text)?.toDouble() ?? 0;
                                final menuName = nameCtrl.text.trim();
                                if (menuName.isEmpty || selectedRecipe == -1 || porsiVal <= 0) return;
                                final body = {
                                  'menu_name': menuName,
                                  'target_date': dateCtrl.text.trim(),
                                  'target_portions': porsiVal.toInt(),
                                  'bom': bomItems.map((b) {
                                    final stdW = (b['standard_weight_per_portion'] as num?)?.toDouble() ?? 0;
                                    final totalW = (porsiVal * stdW) / 1000;
                                    return {
                                      'material_id': b['material_id'],
                                      'material_name': b['material_name'],
                                      'standard_weight_per_portion': stdW,
                                      'weight_large': (b['weight_large'] as num?)?.toDouble() ?? 0,
                                      'weight_small': (b['weight_small'] as num?)?.toDouble() ?? 0,
                                      'total_required_weight': totalW,
                                    };
                                  }).toList(),
                                };
                                try {
                                  final res = await _apiClient.post('/api/production/plans', body: body);
                                  if (!mounted) return;
                                  if (res.statusCode == 200 || res.statusCode == 201) {
                                    Navigator.pop(ctx);
                                    _fetchPlans();
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Berhasil dijadwalkan'), backgroundColor: Color(0xFF4CAF50)),
                                    );
                                  } else {
                                    final data = jsonDecode(res.body);
                                    final msg = data['message'] as String? ?? 'Gagal';
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(msg), backgroundColor: Colors.red),
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: const Center(
                                child: Text('Jadwalkan',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
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
        },
      );
    });
  }

  Future<List<Map<String, dynamic>>> _fetchRecipes() async {
    try {
      final res = await _apiClient.get('/api/production/recipes');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Widget _recipeDropdown(List<Map<String, dynamic>> items, int selected, void Function(int) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 30, 30, 30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected == -1 ? null : selected,
          isExpanded: true,
          hint: const Text('Pilih resep...', style: TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 14)),
          dropdownColor: const Color.fromARGB(255, 30, 30, 30),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1A8FCC)),
          items: items.map((r) {
            final id = r['id'] as int? ?? 0;
            final name = '${r['name'] ?? ''}';
            return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _formTextField(TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 14),
        filled: true,
        fillColor: const Color.fromARGB(255, 30, 30, 30),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, DateTime currentDate, void Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF1A8FCC),
                  onPrimary: Colors.white,
                  surface: const Color.fromARGB(255, 30, 30, 30),
                  onSurface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 30, 30, 30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Text(controller.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Spacer(),
            const Icon(Icons.calendar_month_rounded, color: Color(0xFF1A8FCC), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
              style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
