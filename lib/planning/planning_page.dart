import 'dart:convert';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/pilih_menu.dart';
import 'package:bgn/planning/planning_dapur.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  final _porsiBesarCtrl = TextEditingController();
  final _porsiKecilCtrl = TextEditingController();
  final _biayaCtrl = TextEditingController();
  DateTime? _tanggalMulai;
  String _durasi = 'Harian (1 Hari)';
  final _apiClient = ApiClient();

  final _durasiItems = [
    'Harian (1 Hari)',
    'Mingguan (7 Hari)',
    'Bulanan (30 Hari tanpa minggu)',
    '1 Tahun (365 Hari tanpa minggu)',
  ];

  List<Map<String, dynamic>>? _generatedPlans;
  bool _generatingPlans = false;
  final Map<int, TextEditingController> _editPorsiBesar = {};
  final Map<int, TextEditingController> _editPorsiKecil = {};

  int? _selectedExplorer;
  List<Map<String, dynamic>> _ingredients = [];
  bool _loadingIngredients = false;
  List<Map<String, dynamic>> _recipes = [];
  bool _loadingRecipes = false;
  List<Map<String, dynamic>> _akgData = [];
  bool _loadingAkg = false;
  List<Map<String, dynamic>> _existingPlans = [];
  bool _loadingExistingPlans = false;

  int? _selectedForbiddenSub;
  List<Map<String, dynamic>> _forbiddenMenus = [];
  bool _loadingForbiddenMenus = false;
  List<Map<String, dynamic>> _forbiddenIngredients = [];
  bool _loadingForbiddenIngredients = false;

  int _currentTab = 0;

  bool _showIngredientForm = false;
  final _ingNameCtrl = TextEditingController();
  final _ingKaloriCtrl = TextEditingController();
  final _ingProteinCtrl = TextEditingController();
  final _ingLemakCtrl = TextEditingController();
  final _ingKarboCtrl = TextEditingController();
  final _ingHargaCtrl = TextEditingController();
  String _ingKategori = 'Karbohidrat';
  String _ingUnit = 'Kilogram (Kg)';
  final _ingKategoriItems = ['Karbohidrat', 'Protein', 'Sayuran', 'Susu', 'Buah-Buahan'];
  final _ingUnitItems = ['Kilogram (Kg)', 'pcs/Butir/Unit'];

  bool _showRecipeForm = false;
  final _recipeNameCtrl = TextEditingController();
  final _recipePopularityCtrl = TextEditingController(text: '10');
  String _recipeCategory = 'Porsi Besar';
  String _recipeMonth = 'Semua Bulan';
  final _recipeCategoryItems = ['Porsi Besar', 'Porsi Kecil'];
  final _recipeMonthItems = ['Semua Bulan', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  List<Map<String, dynamic>> _recipeIngredientRows = [];
  int? _editingRecipeId;

  bool _showAkgForm = false;
  final _akgAgeGroupCtrl = TextEditingController();
  final _akgKaloriCtrl = TextEditingController();
  final _akgProteinCtrl = TextEditingController();
  final _akgLemakCtrl = TextEditingController();
  final _akgKarboCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      _apiClient.setAuthData(auth.sppgId, auth.currentRole);
    });
  }

  @override
  void dispose() {
    _porsiBesarCtrl.dispose();
    _porsiKecilCtrl.dispose();
    _biayaCtrl.dispose();
    _ingNameCtrl.dispose();
    _ingKaloriCtrl.dispose();
    _ingProteinCtrl.dispose();
    _ingLemakCtrl.dispose();
    _ingKarboCtrl.dispose();
    _ingHargaCtrl.dispose();
    _recipeNameCtrl.dispose();
    _recipePopularityCtrl.dispose();
    _akgAgeGroupCtrl.dispose();
    _akgKaloriCtrl.dispose();
    _akgProteinCtrl.dispose();
    _akgLemakCtrl.dispose();
    _akgKarboCtrl.dispose();
    for (final row in _recipeIngredientRows) {
      (row['ctrl'] as TextEditingController).dispose();
    }
    for (final c in _editPorsiBesar.values) c.dispose();
    for (final c in _editPorsiKecil.values) c.dispose();
    super.dispose();
  }

  void _initEditControllers(List<Map<String, dynamic>> plans) {
    for (final c in _editPorsiBesar.values) c.dispose();
    for (final c in _editPorsiKecil.values) c.dispose();
    _editPorsiBesar.clear();
    _editPorsiKecil.clear();
    for (final plan in plans) {
      final day = plan['day'] as int;
      _editPorsiBesar[day] = TextEditingController(text: '${plan['portions_large'] ?? ''}');
      _editPorsiKecil[day] = TextEditingController(text: '${plan['portions_small'] ?? ''}');
    }
  }

  Map<String, dynamic> _recalcPlan(Map<String, dynamic> plan, int newLarge, int newSmall) {
    final origLarge = (plan['portions_large'] as num?)?.toDouble() ?? 0;
    final origSmall = (plan['portions_small'] as num?)?.toDouble() ?? 0;
    if (origLarge == 0 && origSmall == 0) return plan;
    final newTotal = newLarge + newSmall;
    final scaleLarge = origLarge > 0 ? newLarge / origLarge : 0.0;
    final scaleSmall = origSmall > 0 ? newSmall / origSmall : 0.0;

    final newPlan = Map<String, dynamic>.from(plan);
    newPlan['portions_large'] = newLarge;
    newPlan['portions_small'] = newSmall;
    newPlan['target_portions'] = newTotal;

    final origIngredients = (plan['ingredients'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final newIngredients = <Map<String, dynamic>>[];
    double newTotalCost = 0;

    for (final ing in origIngredients) {
      final newIng = Map<String, dynamic>.from(ing);
      final wLarge = (ing['weight_large'] as num?)?.toDouble() ?? 0;
      final wSmall = (ing['weight_small'] as num?)?.toDouble() ?? 0;
      if (wLarge > 0 || wSmall > 0) {
        final newTotalWeight = (wLarge * newLarge + wSmall * newSmall) / 1000;
        newIng['total_weight'] = newTotalWeight;
        final origTotalWeight = (ing['total_weight'] as num?)?.toDouble() ?? 0;
        if (origTotalWeight > 0) {
          final costScale = newTotalWeight / origTotalWeight;
          final origCost = (ing['total_cost'] as num?)?.toDouble() ?? 0;
          final newCost = origCost * costScale;
          newIng['total_cost'] = newCost;
          newIng['cost_per_portion'] = newTotal > 0 ? newCost / newTotal : 0;
          newTotalCost += newCost;
        }
      }
      newIngredients.add(newIng);
    }

    newPlan['ingredients'] = newIngredients;
    newPlan['total_cost'] = newTotalCost;
    newPlan['cost_per_portion'] = newTotal > 0 ? newTotalCost / newTotal : 0;

    return newPlan;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1A8FCC),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _tanggalMulai = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/pilih-menu'),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('SPPG',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(_currentTab == 0 ? 'Planning' : 'Jadwal Dapur',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: _currentTab == 0 ? _buildDashboard() : const PlanningDapurPage(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 35, 35, 35),
        selectedItemColor: const Color(0xFF1A8FCC),
        unselectedItemColor: const Color.fromARGB(255, 133, 133, 133),
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Jadwal Dapur'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Perencanaan Menu & Gizi',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildMenuGeneratorCard(),
          const SizedBox(height: 20),
          _buildGeneratedPlansCard(),
          const SizedBox(height: 20),
          _buildMasterDataCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMenuGeneratorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 30, 30, 30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFFF9800), size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Menu Generator',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStandarGiziCard(),
          const SizedBox(height: 20),
          _buildFormSection(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStandarGiziCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 22, 22, 22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Standar Gizi Penerima',
            style: TextStyle(color: Color(0xFFFF9800), fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _giziRow('Porsi Besar (SD-SMA)', '1.900 KCal'),
          const SizedBox(height: 8),
          _giziRow('Porsi Kecil (PAUD-TK)', '1.400 KCal'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.15)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '* Menghasilkan 1 Menu dengan takaran porsi digabungkan',
                    style: TextStyle(color: Color(0xFFFF9800), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _giziRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 14),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A8FCC).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value,
            style: const TextStyle(color: Color(0xFF1A8FCC), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 20),
        const Text('Parameter Perencanaan',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
          _buildInputField(
            controller: _porsiBesarCtrl,
            label: 'Jumlah Porsi Besar (1.900 KCal)',
            hint: '0',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _porsiKecilCtrl,
            label: 'Jumlah Porsi Kecil (1.400 KCal)',
            hint: '0',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _biayaCtrl,
            label: 'Batas Biaya per Porsi',
            hint: '0',
            prefix: 'Rp ',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 16),
          _buildDropdown(),
        ],
      );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 15),
            filled: true,
            fillColor: const Color.fromARGB(255, 22, 22, 22),
            prefixText: prefix,
            prefixStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 15),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pilih Tanggal Mulai',
          style: TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 22, 22, 22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tanggalMulai != null
                      ? '${_tanggalMulai!.day} ${_getMonth(_tanggalMulai!.month)} ${_tanggalMulai!.year}'
                      : 'Pilih tanggal',
                  style: TextStyle(
                    color: _tanggalMulai != null ? Colors.white : const Color.fromARGB(255, 100, 100, 100),
                    fontSize: 15,
                  ),
                ),
                const Icon(Icons.calendar_month_rounded, color: Color(0xFF1A8FCC), size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Durasi Perencanaan',
          style: TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 22, 22, 22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _durasi,
              isExpanded: true,
              dropdownColor: const Color.fromARGB(255, 22, 22, 22),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1A8FCC)),
              items: _durasiItems.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _durasi = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _generateMenu,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Generate Rencana Menu',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _showTambahRencanaForm,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tambah Rencana Menu',
                style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generateMenu() async {
    if (_generatingPlans) return;

    final porsiBesar = int.tryParse(_porsiBesarCtrl.text);
    final porsiKecil = int.tryParse(_porsiKecilCtrl.text);
    final biaya = double.tryParse(_biayaCtrl.text);

    if (porsiBesar == null || porsiKecil == null || biaya == null || _tanggalMulai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi semua parameter perencanaan terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _generatingPlans = true;
      _generatedPlans = null;
    });

    final startDate =
        '${_tanggalMulai!.year}-${_tanggalMulai!.month.toString().padLeft(2, '0')}-${_tanggalMulai!.day.toString().padLeft(2, '0')}';

    final durasiMatch = RegExp(r'(\d+)').firstMatch(_durasi);
    final duration = durasiMatch != null ? int.parse(durasiMatch.group(1)!) : 1;

    final body = {
      'portions_large': porsiBesar,
      'portions_small': porsiKecil,
      'budget': biaya,
      'duration': duration,
      'start_date': startDate,
    };

    debugPrint('=== GENERATE MENU REQUEST ===');
    debugPrint('URL: /api/production/menu-generator');
    debugPrint('Body: $body');

    try {
      final res = await _apiClient.post('/api/production/menu-generator', body: body);
      if (!mounted) return;

      debugPrint('=== GENERATE MENU RESPONSE ===');
      debugPrint('Status: ${res.statusCode}');
      debugPrint('Body: ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final plans = (data['plans'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>();
        setState(() {
          _generatedPlans = plans;
          _generatingPlans = false;
          _initEditControllers(plans ?? []);
        });
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal generate rencana menu';
        setState(() => _generatingPlans = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$msg\n\nReq: $body\nRes: ${res.body}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingPlans = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildGeneratedPlansCard() {
    if (_generatedPlans == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 30, 30, 30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: _generatingPlans
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A8FCC)),
                  ),
                  SizedBox(width: 12),
                  Text('Menghasilkan rencana menu...',
                    style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 14),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color.fromARGB(255, 100, 100, 100), size: 22),
                  SizedBox(width: 10),
                  Text('Belum ada rencana',
                    style: TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 15),
                  ),
                ],
              ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4CAF50), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Hasil Generate Rencana',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._generatedPlans!.map((plan) => _buildPlanCard(plan)),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final day = plan['day'] as int;
    final porsiBesarCtrl = _editPorsiBesar[day] ?? TextEditingController();
    final porsiKecilCtrl = _editPorsiKecil[day] ?? TextEditingController();

    final newLarge = int.tryParse(porsiBesarCtrl.text) ?? 0;
    final newSmall = int.tryParse(porsiKecilCtrl.text) ?? 0;
    final displayPlan = _recalcPlan(plan, newLarge, newSmall);

    final ingredients = (displayPlan['ingredients'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 30, 30, 30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A8FCC).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Hari ${day}',
                  style: const TextStyle(color: Color(0xFF1A8FCC), fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${plan['date']}',
                  style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${plan['recipient_type']}',
                  style: const TextStyle(color: Color(0xFFFF9800), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _editPorsiField(porsiBesarCtrl, 'Porsi Besar'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _editPorsiField(porsiKecilCtrl, 'Porsi Kecil'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('${plan['recipe_name']}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildNutritionCard('Porsi Besar (1.900 KCal)',
                _fmtDec(plan['calories_large']), _fmtDec(plan['protein_large']),
                _fmtDec(plan['fat_large']), _fmtDec(plan['carbs_large']),
                const Color(0xFF1A8FCC),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildNutritionCard('Porsi Kecil (1.400 KCal)',
                _fmtDec(plan['calories_small']), _fmtDec(plan['protein_small']),
                _fmtDec(plan['fat_small']), _fmtDec(plan['carbs_small']),
                const Color(0xFFFF9800),
              )),
            ],
          ),
          const SizedBox(height: 12),
          _buildCostCard(displayPlan),
          const SizedBox(height: 12),
          _buildNotesCard(plan),
          const SizedBox(height: 20),
          const Text('KOMPOSISI FORMULA BAHAN BAKU (BOM)',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildIngredientsTable(ingredients, displayPlan),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
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
                      onTap: () => _scheduleGeneratedPlan(plan, displayPlan, newLarge, newSmall),
                      child: const Center(
                        child: Text('Jadwalkan\nProduksi',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniButton('Ubah', const Color(0xFF1A8FCC), () => _editGeneratedPlan(plan, displayPlan, day)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniButton('Hapus', Colors.red, () => _deleteGeneratedPlan(plan)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniButton(String label, Color color, VoidCallback onTap) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: Text(label,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleGeneratedPlan(Map<String, dynamic> plan, Map<String, dynamic> displayPlan, int newLarge, int newSmall) async {
    final ingredients = (displayPlan['ingredients'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final targetDate = plan['date'] as String? ?? DateTime.now().toIso8601String().split('T')[0];
    final recipeName = plan['recipe_name'] as String? ?? '';

    final body = {
      'menu_name': '[Porsi Besar & Kecil] $recipeName',
      'target_date': targetDate,
      'target_portions': newLarge + newSmall,
      'target_portions_large': newLarge,
      'target_portions_small': newSmall,
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
      'bom': ingredients.map((ing) {
        final wLarge = (ing['weight_large'] as num?)?.toDouble() ?? 0;
        final wSmall = (ing['weight_small'] as num?)?.toDouble() ?? 0;
        final totalW = ((wLarge * newLarge) + (wSmall * newSmall)) / 1000;
        return {
          'material_id': ing['id'],
          'material_name': ing['name'],
          'standard_weight_per_portion': wLarge,
          'weight_large': wLarge,
          'weight_small': wSmall,
          'total_required_weight': totalW,
        };
      }).toList(),
    };

    try {
      final res = await _apiClient.post('/api/production/plans', body: body);
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil dijadwalkan'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal';
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

  void _editGeneratedPlan(Map<String, dynamic> plan, Map<String, dynamic> displayPlan, int day) async {
    final nameCtrl = TextEditingController(text: plan['recipe_name'] as String? ?? '');
    final dateCtrl = TextEditingController(text: plan['date'] as String? ?? '');
    final porsiBesarCtrl = TextEditingController(text: '${plan['portions_large'] ?? 0}');
    final porsiKecilCtrl = TextEditingController(text: '${plan['portions_small'] ?? 0}');
    final calLCtrl = TextEditingController(text: '${plan['calories_large'] ?? 0}');
    final protLCtrl = TextEditingController(text: '${plan['protein_large'] ?? 0}');
    final fatLCtrl = TextEditingController(text: '${plan['fat_large'] ?? 0}');
    final carbsLCtrl = TextEditingController(text: '${plan['carbs_large'] ?? 0}');
    final fiberLCtrl = TextEditingController(text: '${plan['fiber_large'] ?? 0}');
    final calSCtrl = TextEditingController(text: '${plan['calories_small'] ?? 0}');
    final protSCtrl = TextEditingController(text: '${plan['protein_small'] ?? 0}');
    final fatSCtrl = TextEditingController(text: '${plan['fat_small'] ?? 0}');
    final carbsSCtrl = TextEditingController(text: '${plan['carbs_small'] ?? 0}');
    final fiberSCtrl = TextEditingController(text: '${plan['fiber_small'] ?? 0}');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 22, 22, 22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),
                const Text('Ubah Rencana Generate',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                _planField(nameCtrl, 'Nama Menu', ''),
                const SizedBox(height: 10),
                _planField(dateCtrl, 'Tanggal Target', ''),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _planField(porsiBesarCtrl, 'Porsi Besar', '0')),
                  const SizedBox(width: 8),
                  Expanded(child: _planField(porsiKecilCtrl, 'Porsi Kecil', '0')),
                ]),
                const SizedBox(height: 14),
                const Text('Gizi Porsi Besar', style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _planField(calLCtrl, 'Kalori', '0')),
                  const SizedBox(width: 8),
                  Expanded(child: _planField(protLCtrl, 'Protein', '0')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _planField(fatLCtrl, 'Lemak', '0')),
                  const SizedBox(width: 8),
                  Expanded(child: _planField(carbsLCtrl, 'Karbo', '0')),
                ]),
                const SizedBox(height: 8),
                _planField(fiberLCtrl, 'Serat', '0'),
                const SizedBox(height: 14),
                const Text('Gizi Porsi Kecil', style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _planField(calSCtrl, 'Kalori', '0')),
                  const SizedBox(width: 8),
                  Expanded(child: _planField(protSCtrl, 'Protein', '0')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _planField(fatSCtrl, 'Lemak', '0')),
                  const SizedBox(width: 8),
                  Expanded(child: _planField(carbsSCtrl, 'Karbo', '0')),
                ]),
                const SizedBox(height: 8),
                _planField(fiberSCtrl, 'Serat', '0'),
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
                        onTap: () {
                          plan['recipe_name'] = nameCtrl.text;
                          plan['date'] = dateCtrl.text;
                          plan['portions_large'] = int.tryParse(porsiBesarCtrl.text) ?? 0;
                          plan['portions_small'] = int.tryParse(porsiKecilCtrl.text) ?? 0;
                          plan['calories_large'] = double.tryParse(calLCtrl.text) ?? 0;
                          plan['protein_large'] = double.tryParse(protLCtrl.text) ?? 0;
                          plan['fat_large'] = double.tryParse(fatLCtrl.text) ?? 0;
                          plan['carbs_large'] = double.tryParse(carbsLCtrl.text) ?? 0;
                          plan['fiber_large'] = double.tryParse(fiberLCtrl.text) ?? 0;
                          plan['calories_small'] = double.tryParse(calSCtrl.text) ?? 0;
                          plan['protein_small'] = double.tryParse(protSCtrl.text) ?? 0;
                          plan['fat_small'] = double.tryParse(fatSCtrl.text) ?? 0;
                          plan['carbs_small'] = double.tryParse(carbsSCtrl.text) ?? 0;
                          plan['fiber_small'] = double.tryParse(fiberSCtrl.text) ?? 0;
                          setState(() {});
                          Navigator.pop(ctx, true);
                        },
                        child: const Center(
                          child: Text('Simpan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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

    nameCtrl.dispose();
    dateCtrl.dispose();
    porsiBesarCtrl.dispose();
    porsiKecilCtrl.dispose();
    calLCtrl.dispose();
    protLCtrl.dispose();
    fatLCtrl.dispose();
    carbsLCtrl.dispose();
    fiberLCtrl.dispose();
    calSCtrl.dispose();
    protSCtrl.dispose();
    fatSCtrl.dispose();
    carbsSCtrl.dispose();
    fiberSCtrl.dispose();

    if (result == true && mounted) {
      _initEditControllers(_generatedPlans ?? []);
    }
  }

  void _deleteGeneratedPlan(Map<String, dynamic> plan) {
    setState(() {
      _generatedPlans?.remove(plan);
    });
  }

  Widget _editPorsiField(TextEditingController controller, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color.fromARGB(255, 22, 22, 22),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: const Color(0xFF1A8FCC).withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildNutritionCard(String header, String cal, String protein, String fat, String carbs, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 22, 22, 22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(header,
            style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _nutrientRow('Kalori', cal, accent),
          const SizedBox(height: 6),
          _nutrientRow('Protein', protein, accent),
          const SizedBox(height: 6),
          _nutrientRow('Lemak', fat, accent),
          const SizedBox(height: 6),
          _nutrientRow('Karbo', carbs, accent),
        ],
      ),
    );
  }

  Widget _nutrientRow(String label, String value, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 12),
        ),
        Text('$value',
          style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCostCard(Map<String, dynamic> plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 22, 22, 22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rata-Rata Biaya/Porsi',
                  style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text('Rp ${_formatNum(plan['cost_per_portion'])}',
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total',
                  style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 10),
                ),
                Text('Rp ${_formatNum(plan['total_cost'])}',
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(Map<String, dynamic> plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${plan['notes'] ?? ''}',
              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsTable(List<Map<String, dynamic>> ingredients, Map<String, dynamic> plan) {
    // final targetPortions = plan['target_portions'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 22, 22, 22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Nama Bahan',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                )),
                Expanded(flex: 2, child: Text('Kategori',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                )),
                Expanded(flex: 2, child: Text('Porsi Besar',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                )),
                Expanded(flex: 2, child: Text('Porsi Kecil',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                )),
                Expanded(flex: 2, child: Text('Kebutuhan Total',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                )),
                Expanded(flex: 2, child: Text('Biaya Porsi',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                )),
                Expanded(flex: 2, child: Text('Status',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                )),
              ],
            ),
          ),
          ...ingredients.asMap().entries.map((entry) {
            final i = entry.key;
            final ing = entry.value;
            final isLast = i == ingredients.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('${ing['name'] ?? ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  )),
                  Expanded(flex: 2, child: _categoryBadge('${ing['category'] ?? ''}')),
                  Expanded(flex: 2, child: Text(_fmtW(ing['weight_large']),
                    style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 11),
                  )),
                  Expanded(flex: 2, child: Text(_fmtW(ing['weight_small']),
                    style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 11),
                  )),
                  Expanded(flex: 2, child: Text('${_fmtW(ing['total_weight'])} ${ing['unit'] ?? ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  )),
                  Expanded(flex: 2, child: Text('${_fmtCost(ing['cost_per_portion'])}',
                    style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
                  )),
                  Expanded(flex: 2, child: _statusBadge()),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _categoryBadge(String category) {
    Color color;
    switch (category.toLowerCase()) {
      case 'karbo':
        color = const Color(0xFF1A8FCC);
        break;
      case 'protein':
        color = const Color(0xFFE53935);
        break;
      case 'sayur':
        color = const Color(0xFF4CAF50);
        break;
      case 'buah':
        color = const Color(0xFFFF9800);
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(category,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('Tersedia',
        style: TextStyle(color: Color(0xFF4CAF50), fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _fmtDec(dynamic val) {
    if (val == null) return '0';
    final n = val is double ? val : double.tryParse(val.toString()) ?? 0;
    final s = n.toStringAsFixed(3);
    return s.contains('.') ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : s;
  }

  String _fmtW(dynamic val) {
    if (val == null) return '0';
    final n = val is double ? val : double.tryParse(val.toString()) ?? 0;
    return n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
  }

  String _fmtCost(dynamic val) {
    if (val == null) return '0';
    final n = val is double ? val : double.tryParse(val.toString()) ?? 0;
    return n.toStringAsFixed(0);
  }

  String _formatNum(dynamic val) {
    if (val == null) return '0';
    final n = val is double ? val : double.tryParse(val.toString()) ?? 0;
    final parts = n.toStringAsFixed(0).split('');
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
      buf.write(parts[i]);
    }
    return buf.toString();
  }

  Widget _buildMasterDataCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 30, 30, 30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storage_rounded, color: Color(0xFF9C27B0), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Master Data Explorer (Fondasi Sistem)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Akses langsung ke database bahan gizi, template resep standard, dan standard gizi penerima',
            style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 12),
          ),
          const SizedBox(height: 16),
          ..._buildExplorerOptions(),
        ],
      ),
    );
  }

  List<Widget> _buildExplorerOptions() {
    const options = [
      (1, 'Database Bahan Baku', Icons.inventory_2_rounded),
      (2, 'Template Resep (BOM)', Icons.menu_book_rounded),
      (3, 'Standar Gizi Penerima', Icons.bar_chart_rounded),
      (4, 'Menu Yang Sudah Digunakan', Icons.history_rounded),
      (5, 'Aturan Larangan BGN', Icons.gavel_rounded),
    ];

    return [
      ...options.map((opt) => _explorerOptionTile(opt.$1, opt.$2, opt.$3)),
      if (_selectedExplorer == 1) ...[
        const SizedBox(height: 16),
        _buildDatabaseBahanBaku(),
      ],
      if (_selectedExplorer == 2) ...[
        const SizedBox(height: 16),
        _buildTemplateResep(),
      ],
      if (_selectedExplorer == 3) ...[
        const SizedBox(height: 16),
        _buildStandarGizi(),
      ],
      if (_selectedExplorer == 4) ...[
        const SizedBox(height: 16),
        _buildExistingPlans(),
      ],
      if (_selectedExplorer == 5) ...[
        const SizedBox(height: 16),
        _buildAturanLarangan(),
      ],
    ];
  }

  Widget _explorerOptionTile(int index, String title, IconData icon) {
    final selected = _selectedExplorer == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedExplorer = selected ? null : index;
            if (index == 1) _fetchIngredients();
            if (index == 2) _fetchRecipes();
            if (index == 3) _fetchAkg();
            if (index == 4) _fetchExistingPlans();
            if (index == 5) _selectedForbiddenSub = null;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF9C27B0).withValues(alpha: 0.1)
                : const Color.fromARGB(255, 22, 22, 22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9C27B0).withValues(alpha: 0.3)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                color: selected ? const Color(0xFF9C27B0) : const Color.fromARGB(255, 140, 140, 140),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                  style: TextStyle(
                    color: selected ? const Color(0xFF9C27B0) : Colors.white,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                color: selected ? const Color(0xFF9C27B0) : const Color.fromARGB(255, 100, 100, 100),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchIngredientsNoCache() async {
    setState(() => _loadingIngredients = true);
    try {
      final res = await _apiClient.get('/api/production/ingredients');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _ingredients = data.cast<Map<String, dynamic>>();
          _loadingIngredients = false;
        });
      } else {
        setState(() => _loadingIngredients = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingIngredients = false);
    }
  }

  Future<void> _fetchIngredients() async {
    if (_ingredients.isNotEmpty) return;
    setState(() => _loadingIngredients = true);
    try {
      final res = await _apiClient.get('/api/production/ingredients');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _ingredients = data.cast<Map<String, dynamic>>();
          _loadingIngredients = false;
        });
      } else {
        setState(() => _loadingIngredients = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingIngredients = false);
    }
  }

  String _getIngredientName(int id) {
    final ing = _ingredients.cast<Map<String, dynamic>?>().firstWhere(
      (i) => i?['id'] == id,
      orElse: () => null,
    );
    return ing?['name'] as String? ?? 'Bahan #$id';
  }

  Future<void> _fetchRecipes({bool force = false}) async {
    if (_recipes.isNotEmpty && !force) return;
    if (_ingredients.isEmpty) await _fetchIngredientsNoCache();
    setState(() => _loadingRecipes = true);
    try {
      final res = await _apiClient.get('/api/production/recipes');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _recipes = data.cast<Map<String, dynamic>>();
          _loadingRecipes = false;
        });
      } else {
        setState(() => _loadingRecipes = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingRecipes = false);
    }
  }

  Future<void> _fetchAkg({bool force = false}) async {
    if (_akgData.isNotEmpty && !force) return;
    setState(() => _loadingAkg = true);
    try {
      final res = await _apiClient.get('/api/production/akg');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _akgData = data.cast<Map<String, dynamic>>();
          _loadingAkg = false;
        });
      } else {
        setState(() => _loadingAkg = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAkg = false);
    }
  }

  Future<void> _fetchExistingPlans({bool force = false}) async {
    if (_existingPlans.isNotEmpty && !force) return;
    setState(() => _loadingExistingPlans = true);
    try {
      final res = await _apiClient.get('/api/production/plans');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _existingPlans = data.cast<Map<String, dynamic>>();
          _loadingExistingPlans = false;
        });
      } else {
        setState(() => _loadingExistingPlans = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingExistingPlans = false);
    }
  }

  void _syncRecipeIngredientRows() {
    final name = _recipeNameCtrl.text.trim();
    final parts = name.split('+').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

    while (_recipeIngredientRows.length < parts.length) {
      final ctrl = TextEditingController();
      final idx = _recipeIngredientRows.length;
      final matched = _matchIngredientId(parts[idx]);
      _recipeIngredientRows.add({
        'ingredient_id': matched,
        'ctrl': ctrl,
        'label': parts[idx],
        'matchedLabel': parts[idx].toLowerCase(),
      });
    }
    while (_recipeIngredientRows.length > parts.length) {
      final removed = _recipeIngredientRows.removeLast();
      (removed['ctrl'] as TextEditingController).dispose();
    }
    for (int i = 0; i < _recipeIngredientRows.length; i++) {
      final oldLabel = (_recipeIngredientRows[i]['matchedLabel'] as String?) ?? '';
      _recipeIngredientRows[i]['label'] = parts[i];
      if (oldLabel != parts[i].toLowerCase()) {
        _recipeIngredientRows[i]['ingredient_id'] = _matchIngredientId(parts[i]);
        _recipeIngredientRows[i]['matchedLabel'] = parts[i].toLowerCase();
      }
    }
  }

  int? _matchIngredientId(String label) {
    final lower = label.toLowerCase().trim();
    if (lower.isEmpty) return null;
    for (final ing in _ingredients) {
      final name = '${ing['name'] ?? ''}'.toLowerCase().trim();
      if (name == lower) return ing['id'] as int;
    }
    for (final ing in _ingredients) {
      final name = '${ing['name'] ?? ''}'.toLowerCase().trim();
      if (lower.startsWith(name)) return ing['id'] as int;
      if (lower.length >= 3 && name.startsWith(lower)) return ing['id'] as int;
    }
    for (final word in lower.split(' ')) {
      if (word.length < 3) continue;
      for (final ing in _ingredients) {
        final name = '${ing['name'] ?? ''}'.toLowerCase().trim();
        if (name.contains(word) || word.contains(name)) return ing['id'] as int;
      }
    }
    final labelWords = lower.split(' ').where((w) => w.length >= 3).toSet();
    if (labelWords.isEmpty) return null;
    for (final ing in _ingredients) {
      final name = '${ing['name'] ?? ''}'.toLowerCase().trim();
      final ingWords = name.split(' ').where((w) => w.length >= 3).toSet();
      if (labelWords.intersection(ingWords).isNotEmpty) return ing['id'] as int;
    }
    return null;
  }

  Widget _buildRecipeForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF9C27B0).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Input Resep Baru',
            style: TextStyle(color: Color(0xFF9C27B0), fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recipeNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (_) => setState(() => _syncRecipeIngredientRows()),
            decoration: InputDecoration(
              labelText: 'Nama Menu Resep',
              labelStyle: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 13),
              hintText: 'Nasi Putih+Telur+Daging Sapi',
              hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 13),
              filled: true,
              fillColor: const Color.fromARGB(255, 22, 22, 22),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _recDropdown('Kategori Penerima', _recipeCategory, _recipeCategoryItems, (v) {
                if (v != null) setState(() => _recipeCategory = v);
              })),
              const SizedBox(width: 10),
              Expanded(child: _recDropdown('Rekomendasi Bulan', _recipeMonth, _recipeMonthItems, (v) {
                if (v != null) setState(() => _recipeMonth = v);
              })),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _recipePopularityCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Popularitas',
              labelStyle: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 13),
              filled: true,
              fillColor: const Color.fromARGB(255, 22, 22, 22),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Komposisi Bahan Baku',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('Penting: Jika Gramasi Dikosongkan, sistem otomasi menghitung gramasi memenuhi 30% standard AKG.',
            style: TextStyle(color: const Color.fromARGB(255, 140, 140, 140), fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          ...List.generate(_recipeIngredientRows.length, (i) => _buildRecipeIngredientRow(i)),
          if (_recipeIngredientRows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Gunakan tanda "+" untuk memisahkan bahan (contoh: Nasi+Telur+Daging)',
                style: TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFAB47BC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _submitRecipe,
                  child: const Center(
                    child: Text('Submit Resep Baru',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeIngredientRow(int index) {
    final row = _recipeIngredientRows[index];
    final selectedId = row['ingredient_id'] as int?;
    final ctrl = row['ctrl'] as TextEditingController;
    final label = row['label'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('$index.',
              style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 22, 22, 22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedId,
                  isExpanded: true,
                  hint: Text(label, style: const TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 13)),
                  dropdownColor: const Color.fromARGB(255, 22, 22, 22),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF9C27B0)),
                  items: _ingredients.map((ing) => DropdownMenuItem(
                    value: ing['id'] as int,
                    child: Text('${ing['name'] ?? ''}', style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _recipeIngredientRows[index]['ingredient_id'] = v);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Gramasi (g)',
                hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 12),
                filled: true,
                fillColor: const Color.fromARGB(255, 22, 22, 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 22, 22, 22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color.fromARGB(255, 22, 22, 22),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF9C27B0)),
              items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRecipe() async {
    final name = _recipeNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama menu resep harus diisi'), backgroundColor: Colors.orange),
      );
      return;
    }
    final popularity = int.tryParse(_recipePopularityCtrl.text.trim()) ?? 0;

    final items = _recipeIngredientRows.map((row) {
      final ingId = row['ingredient_id'] as int?;
      final ctrl = row['ctrl'] as TextEditingController;
      final weightText = ctrl.text.trim();
      return {
        'ingredient_id': ingId,
        'initial_weight': weightText.isEmpty ? null : (num.tryParse(weightText)?.toDouble()),
      };
    }).toList();

    if (items.any((i) => i['ingredient_id'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih bahan baku untuk semua item'), backgroundColor: Colors.orange),
      );
      return;
    }

    final monthMap = {
      'Semua Bulan': 'Semua',
      'Januari': 'Januari',
      'Februari': 'Februari',
      'Maret': 'Maret',
      'April': 'April',
      'Mei': 'Mei',
      'Juni': 'Juni',
      'Juli': 'Juli',
      'Agustus': 'Agustus',
      'September': 'September',
      'Oktober': 'Oktober',
      'November': 'November',
      'Desember': 'Desember',
    };

    final body = {
      'id': _editingRecipeId,
      'name': name,
      'target_category': _recipeCategory,
      'popularity': popularity,
      'month': monthMap[_recipeMonth] ?? 'Semua',
      'items': items,
    };

    try {
      final http.Response res;
      if (_editingRecipeId != null) {
        res = await _apiClient.put('/api/production/recipes/$_editingRecipeId', body: body);
      } else {
        res = await _apiClient.post('/api/production/recipes', body: body);
      }
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        final wasEditing = _editingRecipeId != null;
        _recipeNameCtrl.clear();
        _recipePopularityCtrl.text = '10';
        setState(() {
          _showRecipeForm = false;
          _editingRecipeId = null;
          _recipeCategory = 'Porsi Besar';
          _recipeMonth = 'Semua Bulan';
          for (final row in _recipeIngredientRows) {
            (row['ctrl'] as TextEditingController).dispose();
          }
          _recipeIngredientRows.clear();
        });
        await _fetchRecipes(force: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasEditing ? 'Resep berhasil diubah' : 'Resep berhasil ditambahkan'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openEditRecipe(Map<String, dynamic> recipe) {
    final id = recipe['id'] as int;
    final items = (recipe['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final monthReverseMap = {
      'Semua': 'Semua Bulan',
      'Januari': 'Januari',
      'Februari': 'Februari',
      'Maret': 'Maret',
      'April': 'April',
      'Mei': 'Mei',
      'Juni': 'Juni',
      'Juli': 'Juli',
      'Agustus': 'Agustus',
      'September': 'September',
      'Oktober': 'Oktober',
      'November': 'November',
      'Desember': 'Desember',
    };

    final nameCtrl = TextEditingController(text: '${recipe['name'] ?? ''}');
    final popularityCtrl = TextEditingController(text: '${recipe['popularity'] ?? 10}');
    String category = '${recipe['target_category'] ?? 'Porsi Besar'}';
    String month = monthReverseMap['${recipe['month'] ?? 'Semua'}'] ?? 'Semua Bulan';

    final editRows = <Map<String, dynamic>>[];
    for (final item in items) {
      final ctrl = TextEditingController();
      final initialW = item['initial_weight'] as num?;
      if (initialW != null) ctrl.text = initialW.toString();
      final ingName = _getIngredientName(item['ingredient_id'] as int? ?? 0);
      editRows.add({
        'ingredient_id': item['ingredient_id'] as int?,
        'ctrl': ctrl,
        'label': ingName,
        'matchedLabel': ingName.toLowerCase(),
        'prepopulated': true,
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Edit Resep',
                          style: TextStyle(color: Color(0xFF9C27B0), fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (val) {
                        final parts = val.split('+').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
                        while (editRows.length < parts.length) {
                          final ctrl = TextEditingController();
                          final idx = editRows.length;
                          final matched = _matchIngredientId(parts[idx]);
                          editRows.add({
                            'ingredient_id': matched,
                            'ctrl': ctrl,
                            'label': parts[idx],
                            'matchedLabel': parts[idx].toLowerCase(),
                          });
                        }
                        while (editRows.length > parts.length) {
                          final removed = editRows.removeLast();
                          (removed['ctrl'] as TextEditingController).dispose();
                        }
                        for (int i = 0; i < editRows.length; i++) {
                          if (editRows[i]['prepopulated'] == true) continue;
                          final oldLabel = (editRows[i]['matchedLabel'] as String?) ?? '';
                          editRows[i]['label'] = parts[i];
                          if (oldLabel != parts[i].toLowerCase()) {
                            editRows[i]['ingredient_id'] = _matchIngredientId(parts[i]);
                            editRows[i]['matchedLabel'] = parts[i].toLowerCase();
                          }
                        }
                        setSheetState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Nama Menu Resep',
                        labelStyle: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 13),
                        filled: true,
                        fillColor: const Color.fromARGB(255, 22, 22, 22),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _recDropdown('Kategori Penerima', category, _recipeCategoryItems, (v) {
                          if (v != null) setSheetState(() => category = v);
                        })),
                        const SizedBox(width: 10),
                        Expanded(child: _recDropdown('Rekomendasi Bulan', month, _recipeMonthItems, (v) {
                          if (v != null) setSheetState(() => month = v);
                        })),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: popularityCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Popularitas',
                        labelStyle: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 13),
                        filled: true,
                        fillColor: const Color.fromARGB(255, 22, 22, 22),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Komposisi Bahan Baku',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Penting: Jika Gramasi Dikosongkan, sistem otomasi menghitung gramasi memenuhi 30% standard AKG.',
                      style: TextStyle(color: const Color.fromARGB(255, 140, 140, 140), fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(editRows.length, (i) {
                      final row = editRows[i];
                      final selectedId = row['ingredient_id'] as int?;
                      final ctrl = row['ctrl'] as TextEditingController;
                      final label = row['label'] as String;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 28,
                              child: Text('${i+1}.',
                                style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 22, 22, 22),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: selectedId,
                                    isExpanded: true,
                                    dropdownColor: const Color.fromARGB(255, 22, 22, 22),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF9C27B0)),
                                    items: _ingredients.map((ing) => DropdownMenuItem(
                                      value: ing['id'] as int,
                                      child: Text('${ing['name'] ?? ''}', style: const TextStyle(fontSize: 13)),
                                    )).toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setSheetState(() => editRows[i]['ingredient_id'] = v);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: ctrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Gramasi (g)',
                                  hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 12),
                                  filled: true,
                                  fillColor: const Color.fromARGB(255, 22, 22, 22),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (editRows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Tidak ada komposisi bahan', style: TextStyle(color: Color.fromARGB(255, 120, 120, 120), fontSize: 12)),
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9C27B0), Color(0xFFAB47BC)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final nameText = nameCtrl.text.trim();
                              if (nameText.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nama menu resep harus diisi'), backgroundColor: Colors.orange),
                                );
                                return;
                              }
                              final popVal = int.tryParse(popularityCtrl.text.trim()) ?? 0;
                              final filteredItems = editRows.map((r) {
                                final ingId = r['ingredient_id'] as int?;
                                final wCtrl = r['ctrl'] as TextEditingController;
                                final wText = wCtrl.text.trim();
                                return {
                                  'ingredient_id': ingId,
                                  'initial_weight': wText.isEmpty ? null : (num.tryParse(wText)?.toDouble()),
                                };
                              }).toList();
                              if (filteredItems.any((i) => i['ingredient_id'] == null)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pilih bahan baku untuk semua item'), backgroundColor: Colors.orange),
                                );
                                return;
                              }
                              final monthMap = {
                                'Semua Bulan': 'Semua',
                                'Januari': 'Januari',
                                'Februari': 'Februari',
                                'Maret': 'Maret',
                                'April': 'April',
                                'Mei': 'Mei',
                                'Juni': 'Juni',
                                'Juli': 'Juli',
                                'Agustus': 'Agustus',
                                'September': 'September',
                                'Oktober': 'Oktober',
                                'November': 'November',
                                'Desember': 'Desember',
                              };
                              final body = {
                                'id': id,
                                'name': nameText,
                                'target_category': category,
                                'popularity': popVal,
                                'month': monthMap[month] ?? 'Semua',
                                'items': filteredItems,
                              };
                              try {
                                final res = await _apiClient.put('/api/production/recipes/$id', body: body);
                                if (!mounted) return;
                                if (res.statusCode == 200 || res.statusCode == 201) {
                                  for (final r in editRows) {
                                    (r['ctrl'] as TextEditingController).dispose();
                                  }
                                  Navigator.pop(ctx);
                                  await _fetchRecipes(force: true);
                                  if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Resep berhasil diubah'), backgroundColor: Color(0xFF4CAF50)),
                                  );
                                } else {
                                  final data = jsonDecode(res.body);
                                  final msg = data['message'] as String? ?? 'Gagal';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            child: const Center(
                              child: Text('Simpan Perubahan',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRecipe(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Hapus Resep', style: TextStyle(color: Colors.white)),
        content: const Text('Yakin ingin menghapus resep ini?', style: TextStyle(color: Color.fromARGB(255, 180, 180, 180))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await _apiClient.delete('/api/production/recipes/$id');
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchRecipes(force: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resep berhasil dihapus'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildTemplateResep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Hapus Semua Resep', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (!_showRecipeForm && _ingredients.isEmpty) {
                      await _fetchIngredientsNoCache();
                      if (!mounted) return;
                    }
                    setState(() {
                      _showRecipeForm = !_showRecipeForm;
                      if (!_showRecipeForm) {
                        _recipeNameCtrl.clear();
                        _recipePopularityCtrl.text = '10';
                        _recipeCategory = 'Porsi Besar';
                        _recipeMonth = 'Semua Bulan';
                        _editingRecipeId = null;
                        for (final row in _recipeIngredientRows) {
                          (row['ctrl'] as TextEditingController).dispose();
                        }
                        _recipeIngredientRows.clear();
                      }
                    });
                  },
                  icon: Icon(_showRecipeForm ? Icons.close_rounded : Icons.add_rounded, size: 16),
                  label: Text(_showRecipeForm ? 'Tutup' : 'Tambah Resep Baru', style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A8FCC),
                    side: const BorderSide(color: Color(0xFF1A8FCC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_showRecipeForm) _buildRecipeForm(),
        if (_showRecipeForm) const SizedBox(height: 16),
        if (_loadingRecipes)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9C27B0)),
              ),
            ),
          )
        else
          ...(_recipes.map((r) => _buildRecipeCard(r))),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final items = (recipe['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 22, 22, 22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _badgeExplorer('${recipe['target_category'] ?? ''}', const Color(0xFFFF9800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('popularity: ${recipe['popularity'] ?? 0}/10',
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${recipe['name'] ?? ''}',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('Bulan: ${recipe['month'] ?? '-'}',
            style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 12),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),
            const Text('Komposisi Bahan:',
              style: TextStyle(color: Color(0xFF9C27B0), fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => _buildRecipeItemRow(item)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionBtn('Ubah', const Color(0xFF1A8FCC), () {
                _openEditRecipe(recipe);
              }),
              const SizedBox(width: 8),
              _actionBtn('Hapus', Colors.redAccent, () {
                _deleteRecipe(recipe['id'] as int);
              }),
            ],
          ),
          ],
        ),
    );
  }

  Widget _buildRecipeItemRow(Map<String, dynamic> item) {
    final ingId = item['ingredient_id'] as int? ?? 0;
    final ingName = _getIngredientName(ingId);
    final finalW = (item['final_weight'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(ingName,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Text('${finalW.toStringAsFixed(finalW == finalW.roundToDouble() ? 0 : 2)} g',
            style: const TextStyle(color: Color(0xFF1A8FCC), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAkgForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF9C27B0).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Input Standar Gizi Baru',
            style: TextStyle(color: Color(0xFF9C27B0), fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _ingField(_akgAgeGroupCtrl, 'Kelompok Usia/Sasaran', 'Contoh: Lansia 70-85'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ingField(_akgKaloriCtrl, 'Kalori (kkal)', '0')),
              const SizedBox(width: 10),
              Expanded(child: _ingField(_akgProteinCtrl, 'Protein (g)', '0')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ingField(_akgLemakCtrl, 'Lemak (g)', '0')),
              const SizedBox(width: 10),
              Expanded(child: _ingField(_akgKarboCtrl, 'Karbohidrat (g)', '0')),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFAB47BC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _submitAkg,
                  child: const Center(
                    child: Text('Submit Standar Gizi',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAkg() async {
    final ageGroup = _akgAgeGroupCtrl.text.trim();
    if (ageGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kelompok usia harus diisi'), backgroundColor: Colors.orange),
      );
      return;
    }
    final body = {
      'age_group': ageGroup,
      'calories': num.tryParse(_akgKaloriCtrl.text.trim())?.toDouble() ?? 0,
      'protein': num.tryParse(_akgProteinCtrl.text.trim())?.toDouble() ?? 0,
      'fat': num.tryParse(_akgLemakCtrl.text.trim())?.toDouble() ?? 0,
      'carbs': num.tryParse(_akgKarboCtrl.text.trim())?.toDouble() ?? 0,
    };
    try {
      final res = await _apiClient.post('/api/production/akg', body: body);
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        _akgAgeGroupCtrl.clear();
        _akgKaloriCtrl.clear();
        _akgProteinCtrl.clear();
        _akgLemakCtrl.clear();
        _akgKarboCtrl.clear();
        setState(() => _showAkgForm = false);
        await Future.microtask(() => _fetchAkg(force: true));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Standar gizi berhasil ditambahkan'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openEditAkg(Map<String, dynamic> row) {
    final ageGroup = '${row['age_group'] ?? ''}';
    final kaloriCtrl = TextEditingController(text: '${row['calories'] ?? 0}');
    final proteinCtrl = TextEditingController(text: '${row['protein'] ?? 0}');
    final lemakCtrl = TextEditingController(text: '${row['fat'] ?? 0}');
    final karboCtrl = TextEditingController(text: '${row['carbs'] ?? 0}');

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Standar Gizi: $ageGroup',
                      style: const TextStyle(color: Color(0xFF9C27B0), fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ingField(kaloriCtrl, 'Kalori (kkal)', '0'),
                const SizedBox(height: 10),
                _ingField(proteinCtrl, 'Protein (g)', '0'),
                const SizedBox(height: 10),
                _ingField(lemakCtrl, 'Lemak (g)', '0'),
                const SizedBox(height: 10),
                _ingField(karboCtrl, 'Karbohidrat (g)', '0'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9C27B0), Color(0xFFAB47BC)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final body = {
                            'age_group': ageGroup,
                            'calories': num.tryParse(kaloriCtrl.text.trim())?.toDouble() ?? 0,
                            'protein': num.tryParse(proteinCtrl.text.trim())?.toDouble() ?? 0,
                            'fat': num.tryParse(lemakCtrl.text.trim())?.toDouble() ?? 0,
                            'carbs': num.tryParse(karboCtrl.text.trim())?.toDouble() ?? 0,
                          };
                          try {
                            final encoded = Uri.encodeComponent(ageGroup);
                            final res = await _apiClient.put('/api/production/akg/$encoded', body: body);
                            if (!mounted) return;
                            if (res.statusCode == 200 || res.statusCode == 201) {
                              if (ctx.mounted) Navigator.pop(ctx, true);
                                } else {
                                  final data = jsonDecode(res.body);
                                  final msg = data['message'] as String? ?? 'Gagal';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                          }
                        },
                        child: const Center(
                          child: Text('Simpan Perubahan',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ).then((saved) {
      if (saved == true) {
        _fetchAkg(force: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Standar gizi berhasil diubah'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    });
  }

  Widget _buildStandarGizi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Hapus Semua Standar', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showAkgForm = !_showAkgForm),
                    icon: Icon(_showAkgForm ? Icons.close_rounded : Icons.add_rounded, size: 16),
                    label: Text(_showAkgForm ? 'Tutup' : 'Tambah Standar Gizi', style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A8FCC),
                      side: const BorderSide(color: Color(0xFF1A8FCC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_showAkgForm) _buildAkgForm(),
        if (_showAkgForm) const SizedBox(height: 16),
        if (_loadingAkg)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9C27B0)),
              ),
            ),
          )
        else
          _buildAkgTable(),
      ],
    );
  }

  Widget _scrollHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back_ios, size: 9, color: Colors.white38),
          const Text(' geser ', style: TextStyle(color: Colors.white38, fontSize: 10)),
          Icon(Icons.arrow_forward_ios, size: 9, color: Colors.white38),
        ],
      ),
    );
  }

  Widget _buildAkgTable() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _scrollHint(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 22, 22, 22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 140, child: Text('Kelompok Usia/Sasaran', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 90, child: Text('Target Kalori/Hari (kkal)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 90, child: Text('Target Protein/Hari (g)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 90, child: Text('Target Lemak/Hari (g)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 90, child: Text('Target Carbo/Hari (g)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 110, child: Text('Target per Porsi (30% AKG)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 120, child: Text('Aksi', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                ..._akgData.map((row) => _akgRow(row)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _akgRow(Map<String, dynamic> row) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          SizedBox(width: 140,
            child: Text('${row['age_group'] ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          SizedBox(width: 90,
            child: Text('${row['calories'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(width: 90,
            child: Text('${row['protein'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(width: 90,
            child: Text('${row['fat'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(width: 90,
            child: Text('${row['carbs'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(width: 110,
            child: Text('${row['calories'] != null ? ((row['calories'] as num) * 0.3).toStringAsFixed(0) : 0}', style: const TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
          ),
          SizedBox(width: 120,
            child: Row(
              children: [
                _actionBtn('Ubah', const Color(0xFF1A8FCC), () => _openEditAkg(row)),
                const SizedBox(width: 6),
                _actionBtn('Hapus', Colors.redAccent, () => _deleteAkg(row)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAkg(Map<String, dynamic> row) async {
    final ageGroup = '${row['age_group'] ?? ''}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Hapus Standar Gizi', style: TextStyle(color: Colors.white)),
        content: Text('Yakin ingin menghapus standar gizi "$ageGroup"?', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final encoded = Uri.encodeComponent(ageGroup);
      final res = await _apiClient.delete('/api/production/akg/$encoded');
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchAkg(force: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Standar gizi berhasil dihapus'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: ${res.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildExistingPlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Hapus Semua Rencana', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () => _openAddPlanSheet(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Tambah Rencana Manual', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A8FCC),
                    side: const BorderSide(color: Color(0xFF1A8FCC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingExistingPlans)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9C27B0)),
              ),
            ),
          )
        else
          _buildExistingPlansTable(),
      ],
    );
  }

  void _openAddPlanSheet() async {
    if (_ingredients.isEmpty) await _fetchIngredientsNoCache();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    final menuNameCtrl = TextEditingController();
    final tglCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final porsiBesarCtrl = TextEditingController();
    final porsiKecilCtrl = TextEditingController();
    final calLgeCtrl = TextEditingController();
    final protLgeCtrl = TextEditingController();
    final fatLgeCtrl = TextEditingController();
    final carbsLgeCtrl = TextEditingController();
    final fiberLgeCtrl = TextEditingController();
    final calSmlCtrl = TextEditingController();
    final protSmlCtrl = TextEditingController();
    final fatSmlCtrl = TextEditingController();
    final carbsSmlCtrl = TextEditingController();
    final fiberSmlCtrl = TextEditingController();
    String statusVal = 'Scheduled';
    final statusItems = ['Scheduled', 'Active', 'Completed', 'Cancelled'];
    DateTime selectedDate = DateTime.now();
    final bomRows = <Map<String, dynamic>>[];

    showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tambah Rencana Menu',
                          style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _planField(menuNameCtrl, 'Nama Menu Rencana', 'Contoh: Nasi Putih+Ikan Nila'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _planField(tglCtrl, 'Tanggal Target', '2026-07-03'),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 42,
                          child: IconButton(
                            icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF1A8FCC)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                selectedDate = picked;
                                tglCtrl.text = picked.toIso8601String().split('T')[0];
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _planField(porsiBesarCtrl, 'Porsi Besar', '0')),
                        const SizedBox(width: 10),
                        Expanded(child: _planField(porsiKecilCtrl, 'Porsi Kecil', '0')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _planDropdown('Status', statusVal, statusItems, (v) {
                      if (v != null) setSheetState(() => statusVal = v);
                    }),
                    const SizedBox(height: 14),
                    const Text('Komposisi Bahan Baku',
                      style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Nama Bahan',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          )),
                          Expanded(flex: 2, child: Text('Porsi Besar',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          )),
                          Expanded(flex: 2, child: Text('Porsi Kecil',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          )),
                          Expanded(flex: 2, child: Text('Total Kebutuhan',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          )),
                          Expanded(flex: 1, child: Text('Aksi',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(bomRows.length, (i) => _buildBomRow(i, bomRows, _ingredients, setSheetState, porsiBesarCtrl, porsiKecilCtrl)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            bomRows.add({
                              'material_id': null,
                              'material_name': '',
                              'porsiBesarCtrl': TextEditingController(),
                              'porsiKecilCtrl': TextEditingController(),
                            });
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Tambah Item', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A8FCC),
                          side: const BorderSide(color: Color(0xFF1A8FCC)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Nilai Gizi Porsi Besar',
                      style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _planField(calLgeCtrl, 'Kalori', '0')),
                      const SizedBox(width: 8), Expanded(child: _planField(protLgeCtrl, 'Protein', '0')),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _planField(fatLgeCtrl, 'Lemak', '0')),
                      const SizedBox(width: 8), Expanded(child: _planField(carbsLgeCtrl, 'Karbo', '0')),
                    ]),
                    const SizedBox(height: 8),
                    _planField(fiberLgeCtrl, 'Serat', '0'),
                    const SizedBox(height: 14),
                    const Text('Nilai Gizi Porsi Kecil',
                      style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _planField(calSmlCtrl, 'Kalori', '0')),
                      const SizedBox(width: 8), Expanded(child: _planField(protSmlCtrl, 'Protein', '0')),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _planField(fatSmlCtrl, 'Lemak', '0')),
                      const SizedBox(width: 8), Expanded(child: _planField(carbsSmlCtrl, 'Karbo', '0')),
                    ]),
                    const SizedBox(height: 8),
                    _planField(fiberSmlCtrl, 'Serat', '0'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A8FCC), Color(0xFF2196F3)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final name = menuNameCtrl.text.trim();
                              if (name.isEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Nama menu harus diisi'), backgroundColor: Colors.orange),
                                );
                                return;
                              }
                              final large = num.tryParse(porsiBesarCtrl.text.trim())?.toInt() ?? 0;
                              final small = num.tryParse(porsiKecilCtrl.text.trim())?.toInt() ?? 0;
                              final total = large + small;
                              final largePortions = num.tryParse(porsiBesarCtrl.text.trim())?.toInt() ?? 0;
                              final smallPortions = num.tryParse(porsiKecilCtrl.text.trim())?.toInt() ?? 0;
                              final bom = bomRows.map((r) {
                                final matId = r['material_id'] as int?;
                                final besarCtrl = r['porsiBesarCtrl'] as TextEditingController;
                                final kecilCtrl = r['porsiKecilCtrl'] as TextEditingController;
                                final perBesar = num.tryParse(besarCtrl.text.trim())?.toInt() ?? 0;
                                final perKecil = num.tryParse(kecilCtrl.text.trim())?.toInt() ?? 0;
                                final totalGrams = (largePortions * perBesar) + (smallPortions * perKecil);
                                final isPcs = matId != null && _ingredients.any(
                                  (i) => i['id'] == matId && '${i['unit']}' == 'Pcs',
                                );
                                final totalWeight = isPcs ? totalGrams : totalGrams ~/ 1000;
                                return {
                                  'material_id': matId,
                                  'material_name': r['material_name'],
                                  'standard_weight_per_portion': perBesar,
                                  'total_required_weight': totalWeight,
                                };
                              }).toList();
                              final body = {
                                'menu_name': name,
                                'target_date': tglCtrl.text.trim(),
                                'target_portions': total,
                                'target_portions_large': large,
                                'target_portions_small': small,
                                'status': statusVal,
                                'bom': bom,
                                'calories_large': num.tryParse(calLgeCtrl.text.trim())?.toInt() ?? 0,
                                'protein_large': num.tryParse(protLgeCtrl.text.trim())?.toInt() ?? 0,
                                'fat_large': num.tryParse(fatLgeCtrl.text.trim())?.toInt() ?? 0,
                                'carbs_large': num.tryParse(carbsLgeCtrl.text.trim())?.toInt() ?? 0,
                                'fiber_large': num.tryParse(fiberLgeCtrl.text.trim())?.toInt() ?? 0,
                                'calories_small': num.tryParse(calSmlCtrl.text.trim())?.toInt() ?? 0,
                                'protein_small': num.tryParse(protSmlCtrl.text.trim())?.toInt() ?? 0,
                                'fat_small': num.tryParse(fatSmlCtrl.text.trim())?.toInt() ?? 0,
                                'carbs_small': num.tryParse(carbsSmlCtrl.text.trim())?.toInt() ?? 0,
                                'fiber_small': num.tryParse(fiberSmlCtrl.text.trim())?.toInt() ?? 0,
                              };
                              try {
                                final res = await _apiClient.post('/api/production/plans', body: body);
                                if (!mounted) return;
                                if (res.statusCode == 200 || res.statusCode == 201) {
                                  Navigator.pop(ctx, true);
                                } else {
                                  final data = jsonDecode(res.body);
                                  Navigator.pop(ctx, data['message'] as String? ?? 'Gagal');
                                }
                              } catch (e) {
                                if (mounted) {
                                  Navigator.pop(ctx, 'Error: $e');
                                }
                              }
                            },
                            child: const Center(
                              child: Text('Buat Rencana Menu',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((result) {
      if (result == true) {
        _fetchExistingPlans(force: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rencana menu berhasil ditambahkan'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else if (result is String) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.red),
        );
      }
    });
  }

  Widget _planField(TextEditingController ctrl, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          keyboardType: hint == '0' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 13),
            filled: true,
            fillColor: const Color.fromARGB(255, 22, 22, 22),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      ],
    );
  }

  Widget _planDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 22, 22, 22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color.fromARGB(255, 22, 22, 22),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1A8FCC)),
              items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBomRow(int index, List<Map<String, dynamic>> rows, List<Map<String, dynamic>> ingredients, StateSetter setSheetState, TextEditingController formPorsiBesarCtrl, TextEditingController formPorsiKecilCtrl) {
    final row = rows[index];
    final selectedId = row['material_id'] as int?;
    final besarCtrl = row['porsiBesarCtrl'] as TextEditingController;
    final kecilCtrl = row['porsiKecilCtrl'] as TextEditingController;

    final largePortions = num.tryParse(formPorsiBesarCtrl.text.trim())?.toDouble() ?? 0;
    final smallPortions = num.tryParse(formPorsiKecilCtrl.text.trim())?.toDouble() ?? 0;
    final perBesar = num.tryParse(besarCtrl.text.trim())?.toDouble() ?? 0;
    final perKecil = num.tryParse(kecilCtrl.text.trim())?.toDouble() ?? 0;
    final totalKebutuhan = (largePortions * perBesar) + (smallPortions * perKecil);

    final isPcs = selectedId != null && ingredients.any(
      (i) => i['id'] == selectedId && '${i['unit']}' == 'Pcs',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return ingredients;
                return ingredients.where((ing) {
                  return '${ing['name'] ?? ''}'.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  );
                });
              },
              displayStringForOption: (ing) => '${ing['name'] ?? ''}',
              onSelected: (ing) {
                setSheetState(() {
                  row['material_id'] = ing['id'];
                  row['material_name'] = '${ing['name'] ?? ''}';
                });
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                if (selectedId != null && textEditingController.text.isEmpty) {
                  final ing = ingredients.cast<Map<String, dynamic>?>().firstWhere(
                    (i) => i?['id'] == selectedId, orElse: () => null,
                  );
                  if (ing != null) {
                    textEditingController.text = '${ing['name'] ?? ''}';
                  }
                }
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setSheetState(() {
                        row['material_id'] = null;
                        row['material_name'] = '';
                      });
                    }
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Cari Bahan...',
                    hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 11),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 22, 22, 22),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Material(
                  elevation: 8,
                  color: const Color.fromARGB(255, 22, 22, 22),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final ing = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(ing),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text('${ing['name'] ?? ''}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: besarCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheetState(() {}),
              decoration: InputDecoration(
                hintText: 'Gram (g)',
                hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 11),
                filled: true,
                fillColor: const Color.fromARGB(255, 22, 22, 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: kecilCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheetState(() {}),
              decoration: InputDecoration(
                hintText: 'Gram (g)',
                hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 11),
                filled: true,
                fillColor: const Color.fromARGB(255, 22, 22, 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF1A8FCC), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(
              isPcs
                  ? '${totalKebutuhan.toStringAsFixed(totalKebutuhan == totalKebutuhan.roundToDouble() ? 0 : 1)} Pcs'
                  : '${(totalKebutuhan / 1000).toStringAsFixed((totalKebutuhan / 1000) == (totalKebutuhan / 1000).roundToDouble() ? 0 : 2)} Kg',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setSheetState(() {
                besarCtrl.dispose();
                kecilCtrl.dispose();
                rows.removeAt(index);
              });
            },
            child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingPlansTable() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _scrollHint(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 22, 22, 22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 40, child: Text('ID', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 200, child: Text('Nama Rencana Menu', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 120, child: Text('Tanggal Target', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 100, child: Text('Target Produksi (Porsi)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 100, child: Text('Status', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 120, child: Text('Aksi', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                ..._existingPlans.map((p) => _existingPlanRow(p)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _existingPlanRow(Map<String, dynamic> plan) {
    final status = '${plan['status'] ?? ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          SizedBox(width: 40,
            child: Text('${plan['id'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          SizedBox(width: 200,
            child: Text('${plan['menu_name'] ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          SizedBox(width: 120,
            child: Text('${plan['target_date'] ?? '-'}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(width: 100,
            child: Text('${plan['target_portions'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(width: 100,
            child: _statusBadgePlan(status),
          ),
          SizedBox(width: 120,
            child: Row(
              children: [
                _actionBtn('Ubah', const Color(0xFF1A8FCC), () {}),
                const SizedBox(width: 6),
                _actionBtn('Hapus', Colors.redAccent, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadgePlan(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'scheduled':
        color = const Color(0xFF1A8FCC);
        break;
      case 'in progress':
        color = const Color(0xFFFF9800);
        break;
      case 'completed':
        color = const Color(0xFF4CAF50);
        break;
      case 'cancelled':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAturanLarangan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _forbiddenSubTile(1, 'Menu Makanan Dilarang', Icons.restaurant_rounded),
        if (_selectedForbiddenSub == 1) ...[
          const SizedBox(height: 12),
          _buildForbiddenMenu(),
        ],
        const SizedBox(height: 8),
        _forbiddenSubTile(2, 'Bahan Baku Dilarang', Icons.shopping_cart_rounded),
        if (_selectedForbiddenSub == 2) ...[
          const SizedBox(height: 12),
          _buildForbiddenIngredient(),
        ],
      ],
    );
  }

  Widget _forbiddenSubTile(int index, String title, IconData icon) {
    final selected = _selectedForbiddenSub == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedForbiddenSub = selected ? null : index;
          if (index == 1) _fetchForbiddenMenus();
          if (index == 2) _fetchForbiddenIngredients();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF5722).withValues(alpha: 0.08)
              : const Color.fromARGB(255, 22, 22, 22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF5722).withValues(alpha: 0.3)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
              color: selected ? const Color(0xFFFF5722) : const Color.fromARGB(255, 140, 140, 140),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(title,
              style: TextStyle(
                color: selected ? const Color(0xFFFF5722) : Colors.white,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            Icon(
              selected ? Icons.expand_less_rounded : Icons.add_rounded,
              color: selected ? const Color(0xFFFF5722) : const Color.fromARGB(255, 100, 100, 100),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForbiddenMenu() {
    final nameCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String category = 'Olahan Protein';
    final categories = ['Olahan Protein', 'Olahan Tepung', 'Bahan Berbau', 'Lainnya'];

    return _ForbiddenForm(
      title: 'Menu Makanan Dilarang',
      apiClient: _apiClient,
      nameCtrl: nameCtrl,
      reasonCtrl: reasonCtrl,
      category: category,
      categories: categories,
      fetchData: _forbiddenMenus,
      loading: _loadingForbiddenMenus,
      onRefresh: () => _fetchForbiddenMenus(force: true),
      onSubmit: (name, cat, reason) => _apiClient.post('/api/production/forbidden-menus', body: {
        'name': name,
        'category': cat,
        'reason': reason,
      }),
      subtitle: 'Daftar Menu Gizi yang dilarang disajikan oleh BGN SPPG Dapur Pusat',
      deleteEndpoint: '/api/production/forbidden-menus',
    );
  }

  Widget _buildForbiddenIngredient() {
    final nameCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String category = 'Penyedap';
    final categories = ['Penyedap', 'Pengawet', 'Zat Aditif', 'Minyak', 'Lainnya'];

    return _ForbiddenForm(
      title: 'Bahan Baku Dilarang',
      apiClient: _apiClient,
      nameCtrl: nameCtrl,
      reasonCtrl: reasonCtrl,
      category: category,
      categories: categories,
      fetchData: _forbiddenIngredients,
      loading: _loadingForbiddenIngredients,
      onRefresh: () => _fetchForbiddenIngredients(force: true),
      onSubmit: (name, cat, reason) => _apiClient.post('/api/production/forbidden-ingredients', body: {
        'name': name,
        'category': cat,
        'reason': reason,
      }),
      subtitle: 'Daftar Bahan Baku yang dilarang digunakan oleh BGN SPPG Dapur Pusat',
      deleteEndpoint: '/api/production/forbidden-ingredients',
    );
  }

  Future<void> _fetchForbiddenMenus({bool force = false}) async {
    if (_forbiddenMenus.isNotEmpty && !force) return;
    setState(() => _loadingForbiddenMenus = true);
    try {
      final res = await _apiClient.get('/api/production/forbidden-menus');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _forbiddenMenus = data.cast<Map<String, dynamic>>();
          _loadingForbiddenMenus = false;
        });
      } else {
        setState(() => _loadingForbiddenMenus = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingForbiddenMenus = false);
    }
  }

  Future<void> _fetchForbiddenIngredients({bool force = false}) async {
    if (_forbiddenIngredients.isNotEmpty && !force) return;
    setState(() => _loadingForbiddenIngredients = true);
    try {
      final res = await _apiClient.get('/api/production/forbidden-ingredients');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _forbiddenIngredients = data.cast<Map<String, dynamic>>();
          _loadingForbiddenIngredients = false;
        });
      } else {
        setState(() => _loadingForbiddenIngredients = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingForbiddenIngredients = false);
    }
  }

  Widget _buildIngredientForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF9C27B0).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Input Bahan Baku Baru',
            style: TextStyle(color: Color(0xFF9C27B0), fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _ingField(_ingNameCtrl, 'Nama Bahan', 'Contoh: Ayam Negri'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ingDropdown('Kategori', _ingKategori, _ingKategoriItems, (v) {
                if (v != null) setState(() => _ingKategori = v);
              })),
              const SizedBox(width: 10),
              Expanded(child: _ingDropdown('Satuan', _ingUnit, _ingUnitItems, (v) {
                if (v != null) setState(() => _ingUnit = v);
              })),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ingField(_ingKaloriCtrl, 'Kalori (KKAL)', '0')),
              const SizedBox(width: 10),
              Expanded(child: _ingField(_ingProteinCtrl, 'Protein (g)', '0')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ingField(_ingLemakCtrl, 'Lemak (G)', '0')),
              const SizedBox(width: 10),
              Expanded(child: _ingField(_ingKarboCtrl, 'Karbohidrat (G)', '0')),
            ],
          ),
          const SizedBox(height: 10),
          _ingField(_ingHargaCtrl, 'Harga Per Unit (RP)', '0'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFAB47BC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _submitIngredient,
                  child: const Center(
                    child: Text('Submit Bahan Baru',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ingField(TextEditingController ctrl, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          keyboardType: hint == '0' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 14),
            filled: true,
            fillColor: const Color.fromARGB(255, 22, 22, 22),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ingDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 22, 22, 22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color.fromARGB(255, 22, 22, 22),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF9C27B0)),
              items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitIngredient() async {
    final name = _ingNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama bahan harus diisi'), backgroundColor: Colors.orange),
      );
      return;
    }

    final body = {
      'id': null,
      'name': name,
      'category': _ingKategori.toLowerCase(),
      'unit': _ingUnit.startsWith('Kilogram') ? 'Kg' : (_ingUnit.startsWith('pcs') ? 'pcs' : _ingUnit),
      'calories': num.tryParse(_ingKaloriCtrl.text.trim())?.toDouble() ?? 0,
      'protein': num.tryParse(_ingProteinCtrl.text.trim())?.toDouble() ?? 0,
      'fat': num.tryParse(_ingLemakCtrl.text.trim())?.toDouble() ?? 0,
      'carbs': num.tryParse(_ingKarboCtrl.text.trim())?.toDouble() ?? 0,
      'price_per_unit': num.tryParse(_ingHargaCtrl.text.trim())?.toDouble() ?? 0,
    };

    try {
      final res = await _apiClient.post('/api/production/ingredients', body: body);
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        _ingNameCtrl.clear();
        _ingKaloriCtrl.clear();
        _ingProteinCtrl.clear();
        _ingLemakCtrl.clear();
        _ingKarboCtrl.clear();
        _ingHargaCtrl.clear();
        setState(() {
          _showIngredientForm = false;
          _ingKategori = 'Karbohidrat';
          _ingUnit = 'Kilogram (Kg)';
        });
        await _fetchIngredients();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bahan berhasil ditambahkan'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDatabaseBahanBaku() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Hapus Semua Bahan', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _showIngredientForm = !_showIngredientForm);
                    },
                    icon: Icon(_showIngredientForm ? Icons.close_rounded : Icons.add_rounded, size: 16),
                    label: Text(_showIngredientForm ? 'Tutup' : 'Tambah Bahan Baru', style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A8FCC),
                    side: const BorderSide(color: Color(0xFF1A8FCC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_showIngredientForm) _buildIngredientForm(),
        if (_showIngredientForm) const SizedBox(height: 16),
        if (_loadingIngredients)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9C27B0)),
              ),
            ),
          )
        else
          _buildIngredientsTableExplorer(),
      ],
    );
  }

  Widget _buildIngredientsTableExplorer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _scrollHint(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 22, 22, 22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 40, child: Text('ID', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 160, child: Text('Nama Bahan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 70, child: Text('Kategori', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 70, child: Text('Kalori', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 70, child: Text('Protein', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 70, child: Text('Lemak', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 70, child: Text('Karbo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 90, child: Text('Harga Unit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 100, child: Text('Aksi', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                ..._ingredients.map((ing) => _ingredientRow(ing)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ingredientRow(Map<String, dynamic> ing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('${ing['id']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          SizedBox(
            width: 160,
            child: Text('${ing['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 70,
            child: _badgeExplorer('${ing['category'] ?? ''}', const Color(0xFF9C27B0)),
          ),
          SizedBox(
            width: 70,
            child: Text('${ing['calories'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(
            width: 70,
            child: Text('${ing['protein'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(
            width: 70,
            child: Text('${ing['fat'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(
            width: 70,
            child: Text('${ing['carbs'] ?? 0}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(
            width: 90,
            child: Text('Rp ${_formatNum(ing['price_per_unit'])}', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                _actionBtn('Ubah', const Color(0xFF1A8FCC), () {}),
                const SizedBox(width: 6),
                _actionBtn('Hapus', Colors.redAccent, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeExplorer(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showTambahRencanaForm() {
    _openAddPlanSheet();
  }

  String _getMonth(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return months[month - 1];
  }
}



class _ForbiddenForm extends StatefulWidget {
  final String title;
  final ApiClient apiClient;
  final TextEditingController nameCtrl;
  final TextEditingController reasonCtrl;
  final String category;
  final List<String> categories;
  final List<Map<String, dynamic>> fetchData;
  final bool loading;
  final Future<void> Function() onRefresh;
  final Future<http.Response> Function(String name, String category, String reason) onSubmit;
  final String subtitle;
  final String deleteEndpoint;

  const _ForbiddenForm({
    required this.title,
    required this.apiClient,
    required this.nameCtrl,
    required this.reasonCtrl,
    required this.category,
    required this.categories,
    required this.fetchData,
    required this.loading,
    required this.onRefresh,
    required this.onSubmit,
    required this.subtitle,
    required this.deleteEndpoint,
  });

  @override
  State<_ForbiddenForm> createState() => _ForbiddenFormState();
}

class _ForbiddenFormState extends State<_ForbiddenForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _reasonCtrl;
  late String _category;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = widget.nameCtrl;
    _reasonCtrl = widget.reasonCtrl;
    _category = widget.category;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final reason = _reasonCtrl.text.trim();
    if (name.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua field'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await widget.onSubmit(name, _category, reason);
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        _nameCtrl.clear();
        _reasonCtrl.clear();
        await widget.onRefresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil ditambahkan'), backgroundColor: Color(0xFF4CAF50)),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['message'] as String? ?? 'Gagal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5722).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tambah Larangan Baru',
            style: TextStyle(color: Color(0xFFFF5722), fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _inputField(_nameCtrl, 'Nama Menu/Bahan', 'Contoh: rendang'),
          const SizedBox(height: 10),
          _dropdownField(),
          const SizedBox(height: 10),
          _reasonField(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFFF7043)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _submitting ? null : _submit,
                  child: Center(
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Larangan',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Daftar Menu Gizi yang dilarang disajikan oleh BGN SPPG Dapur Pusat',
            style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                  label: const Text('Hapus Semua', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${widget.fetchData.length} Menu Dilarang',
                style: const TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9C27B0))),
              ),
            )
          else
            _buildTable(),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 14),
            filled: true,
            fillColor: const Color.fromARGB(255, 22, 22, 22),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kategori Olahan', style: TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 22, 22, 22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              dropdownColor: const Color.fromARGB(255, 22, 22, 22),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFFF5722)),
              items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _reasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alasan Dilarang', style: TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: _reasonCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Contoh: mengandung banyak minyak, santan dan tinggi kolesterol',
            hintStyle: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 14),
            filled: true,
            fillColor: const Color.fromARGB(255, 22, 22, 22),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios, size: 9, color: Colors.white38),
              const Text(' geser ', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Icon(Icons.arrow_forward_ios, size: 9, color: Colors.white38),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 22, 22, 22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 150, child: Text('Nama Menu', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 120, child: Text('Kategori', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 200, child: Text('Alasan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(width: 60, child: Text('Aksi', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                ...widget.fetchData.map((item) => _buildRow(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          SizedBox(width: 150,
            child: Text('${item['name'] ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          SizedBox(width: 120,
            child: _badgeKategori('${item['category'] ?? ''}'),
          ),
          SizedBox(width: 200,
            child: Text('${item['reason'] ?? '-'}', style: const TextStyle(color: Color.fromARGB(255, 180, 180, 180), fontSize: 12)),
          ),
          SizedBox(width: 60,
            child: GestureDetector(
              onTap: () async {
                final id = item['id'];
                if (id == null) return;
                try {
                  final res = await widget.apiClient.delete('${widget.deleteEndpoint}/$id');
                  if (!mounted) return;
                  if (res.statusCode == 200 || res.statusCode == 201) {
                    await widget.onRefresh();
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
              },
              child: Text('Hapus', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeKategori(String category) {
    Color color;
    switch (category.toLowerCase()) {
      case 'olahan protein':
        color = const Color(0xFFE53935);
        break;
      case 'olahan tepung':
        color = const Color(0xFFFF9800);
        break;
      case 'bahan berbau':
        color = const Color(0xFF9C27B0);
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(category,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
