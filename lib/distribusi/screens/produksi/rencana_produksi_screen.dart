import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:provider/provider.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/production_plan_service.dart';

const _bg = Color.fromARGB(255, 7, 32, 52);
const _cardBg = Color.fromARGB(255, 30, 30, 30);
const _border = Color.fromARGB(255, 50, 50, 50);
const _textPrimary = Colors.white;
const _textSecondary = Color.fromARGB(255, 140, 140, 140);
const _textHint = Color.fromARGB(255, 80, 80, 80);
const _primary = Color(0xFF1A8FCC);
const _success = Color(0xFF4CAF50);
const _danger = Color(0xFFE53935);

const _radius = 12.0;
const _radiusSm = 8.0;

class RencanaProduksiScreen extends StatefulWidget {
  const RencanaProduksiScreen({super.key});

  @override
  State<RencanaProduksiScreen> createState() => _RencanaProduksiScreenState();
}

class _RencanaProduksiScreenState extends State<RencanaProduksiScreen> {
  final ApiClient _apiClient = ApiClient();
  late final ProductionPlanService _service = ProductionPlanService(_apiClient);

  List<Map<String, dynamic>> _plans = [];
  bool _loadingPlans = true;
  String? _plansError;
  final Set<int> _selectedPlanIds = {};

  bool _scanning = false;
  bool _executing = false;
  List<Map<String, dynamic>> _bomItems = [];
  List<Map<String, dynamic>> _materials = [];
  String? _scanError;

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

  Future<void> _fetchPlans() async {
    if (!mounted) return;
    setState(() {
      _loadingPlans = true;
      _plansError = null;
    });
    try {
      final data = await _service.fetchPlans();
      if (!mounted) return;
      final filtered = data.where((p) {
        final status = (p['status'] as String? ?? '');
        return status == 'Scheduled' || status == 'Draft';
      }).toList();
      setState(() {
        _plans = filtered;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _plansError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  Future<void> _scanBahan() async {
    if (_selectedPlanIds.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _scanning = true;
      _scanError = null;
      _bomItems = [];
      _materials = [];
    });
    try {
      final futures = <Future<dynamic>>[
        ..._selectedPlanIds.map((id) => _service.fetchBom(id)),
        _service.fetchMaterials(),
      ];
      final results = await Future.wait(futures);
      if (!mounted) return;

      final merged = <int, Map<String, dynamic>>{};
      for (var i = 0; i < results.length - 1; i++) {
        final bomList = results[i] as List<dynamic>;
        for (final bom in bomList) {
          final map = bom as Map<String, dynamic>;
          final materialId = map['material_id'] as int;
          if (merged.containsKey(materialId)) {
            final existing = merged[materialId]!;
            final currentWeight = (map['total_required_weight'] as num?)?.toDouble() ?? 0;
            final existingWeight = (existing['total_required_weight'] as num?)?.toDouble() ?? 0;
            existing['total_required_weight'] = currentWeight + existingWeight;
          } else {
            merged[materialId] = Map<String, dynamic>.from(map);
          }
        }
      }

      setState(() {
        _bomItems = merged.values.toList();
        _materials = (results.last as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanError = e.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _executePo() async {
    if (_executing) return;
    if (!mounted) return;
    setState(() => _executing = true);
    try {
      final materialMap = _materialMap;
      final items = _computePoItems(materialMap);
      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada bahan yang perlu dipesan')),
          );
        }
        return;
      }

      final body = {
        'supplier_id': 0,
        'supplier_name': 'Belum Ditentukan',
        'items': items.map((item) => {
          'material_id': item['material_id'],
          'name': item['nama'],
          'quantity': (item['defisit'] as double),
          'price': item['price'],
        }).toList(),
        'status': 'Pending',
      };

      await _service.createOrder(body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase Order berhasil dibuat'),
          backgroundColor: _success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _executing = false);
    }
  }

  Map<int, Map<String, dynamic>> get _materialMap {
    final map = <int, Map<String, dynamic>>{};
    for (final m in _materials) {
      map[m['id'] as int] = m;
    }
    return map;
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num n = value is num ? value : double.tryParse(value.toString()) ?? 0;
    if (n == n.roundToDouble()) {
      return n.toInt().toString();
    }
    return n.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: _bg,
        leading: IconButton(
          icon: const Icon(TablerIcons.arrow_left, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rencana Produksi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            Text(
              'Pilih & proses kebutuhan bahan',
              style: TextStyle(fontSize: 11, color: _textSecondary),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 0.5),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          final bodyHeight = constraints.maxHeight - 32;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: isWide
                ? _buildWideLayout(bodyHeight)
                : SingleChildScrollView(
                    child: _buildNarrowLayout(),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(double height) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildColumn1()),
          const SizedBox(width: 16),
          Expanded(child: _buildColumn2()),
          const SizedBox(width: 16),
          Expanded(child: _buildColumn3()),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColumn1Narrow(),
        const SizedBox(height: 16),
        _buildColumn2Narrow(),
        const SizedBox(height: 16),
        _buildColumn3Narrow(),
      ],
    );
  }

  Widget _buildColumn1Narrow() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(TablerIcons.clipboard_list, 'Pilih Rencana Produksi', 'Pilih rencana yang akan diproses'),
          if (_loadingPlans)
            ...List.generate(2, (_) => _PlanSkeleton())
          else if (_plansError != null)
            _ErrorBanner(
              message: _plansError!,
              onRetry: _fetchPlans,
            )
          else if (_plans.isEmpty)
            _EmptyState(
              icon: TablerIcons.inbox,
              title: 'Tidak ada rencana produksi',
              subtitle: 'Belum ada rencana produksi untuk hari ini',
            )
          else ...[
            if (_plans.length > 1)
              _SelectAllRow(
                allSelected: _selectedPlanIds.length == _plans.length,
                selectedCount: _selectedPlanIds.length,
                onToggle: () {
                  setState(() {
                    if (_selectedPlanIds.length == _plans.length) {
                      _selectedPlanIds.clear();
                    } else {
                      _selectedPlanIds.addAll(_plans.map((p) => p['id'] as int));
                    }
                  });
                },
              ),
            ..._plans.map((plan) => _PlanCard(
                  plan: plan,
                  selected: _selectedPlanIds.contains(plan['id'] as int),
                  onTap: () {
                    final id = plan['id'] as int;
                    setState(() {
                      if (_selectedPlanIds.contains(id)) {
                        _selectedPlanIds.remove(id);
                      } else {
                        _selectedPlanIds.add(id);
                      }
                    });
                  },
                )),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedPlanIds.isNotEmpty && !_scanning
                  ? _scanBahan
                  : null,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(TablerIcons.search, size: 18),
              label: Text(
                _scanning ? 'Memindai...' : 'Pindai Kebutuhan Bahan',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primary.withOpacity(0.3),
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn2Narrow() {
    final materialMap = _materialMap;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(TablerIcons.chart_bar, 'Analisis Kebutuhan & Defisit', 'Hasil perhitungan kebutuhan bahan'),
          if (_scanError != null)
            _ErrorBanner(
              message: _scanError!,
              onRetry: _scanBahan,
            )
          else if (_bomItems.isEmpty && _materials.isEmpty)
            _EmptyState(
              icon: TablerIcons.eye_off,
              title: 'Belum ada data',
              subtitle: 'Pilih rencana & tekan tombol Pindai',
            )
          else
            _buildTable(materialMap),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(_radiusSm),
            ),
            child: Icon(icon, size: 16, color: _primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumn1() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(TablerIcons.clipboard_list, 'Pilih Rencana Produksi', 'Pilih rencana yang akan diproses'),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadingPlans)
                    ...List.generate(2, (_) => _PlanSkeleton())
                  else if (_plansError != null)
                    _ErrorBanner(
                      message: _plansError!,
                      onRetry: _fetchPlans,
                    )
                  else if (_plans.isEmpty)
                    _EmptyState(
                      icon: TablerIcons.inbox,
                      title: 'Tidak ada rencana produksi',
                      subtitle: 'Belum ada rencana produksi untuk hari ini',
                    )
                  else ...[
                    if (_plans.length > 1)
                      _SelectAllRow(
                        allSelected: _selectedPlanIds.length == _plans.length,
                        selectedCount: _selectedPlanIds.length,
                        onToggle: () {
                          setState(() {
                            if (_selectedPlanIds.length == _plans.length) {
                              _selectedPlanIds.clear();
                            } else {
                              _selectedPlanIds.addAll(_plans.map((p) => p['id'] as int));
                            }
                          });
                        },
                      ),
                    ..._plans.map((plan) => _PlanCard(
                          plan: plan,
                          selected: _selectedPlanIds.contains(plan['id'] as int),
                          onTap: () {
                            final id = plan['id'] as int;
                            setState(() {
                              if (_selectedPlanIds.contains(id)) {
                                _selectedPlanIds.remove(id);
                              } else {
                                _selectedPlanIds.add(id);
                              }
                            });
                          },
                        )),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedPlanIds.isNotEmpty && !_scanning
                          ? _scanBahan
                          : null,
                      icon: _scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(TablerIcons.search, size: 18),
                      label: Text(
                        _scanning ? 'Memindai...' : 'Pindai Kebutuhan Bahan',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _primary.withOpacity(0.3),
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_radius),
                        ),
                        elevation: 0,
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

  Widget _buildColumn2() {
    final materialMap = _materialMap;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(TablerIcons.chart_bar, 'Analisis Kebutuhan & Defisit', 'Hasil perhitungan kebutuhan bahan'),
          Expanded(
            child: SingleChildScrollView(
              child: _scanError != null
                  ? _ErrorBanner(
                      message: _scanError!,
                      onRetry: _scanBahan,
                    )
                  : _bomItems.isEmpty && _materials.isEmpty
                      ? _EmptyState(
                          icon: TablerIcons.eye_off,
                          title: 'Belum ada data',
                          subtitle: 'Pilih rencana & tekan tombol Pindai',
                        )
                      : _buildTable(materialMap),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn3Narrow() {
    final materialMap = _materialMap;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(TablerIcons.shopping_cart, 'Rencana Pembuatan PO', 'Bahan yang akan dipesan'),
          if (_bomItems.isEmpty && _materials.isEmpty)
            const _EmptyState(
              icon: TablerIcons.eye_off,
              title: 'Belum ada data',
              subtitle: 'Pilih rencana & tekan tombol Pindai',
            )
          else ...[
            _buildPoListContent(materialMap),
            const SizedBox(height: 16),
            _buildPoButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildColumn3() {
    final materialMap = _materialMap;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(TablerIcons.shopping_cart, 'Rencana Pembuatan PO', 'Bahan yang akan dipesan'),
          if (_bomItems.isEmpty && _materials.isEmpty)
            const Expanded(
              child: _EmptyState(
                icon: TablerIcons.eye_off,
                title: 'Belum ada data',
                subtitle: 'Pilih rencana & tekan tombol Pindai',
              ),
            )
          else ...[
            Expanded(
              child: SingleChildScrollView(
                child: _buildPoListContent(materialMap),
              ),
            ),
            const SizedBox(height: 16),
            _buildPoButton(),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _computePoItems(Map<int, Map<String, dynamic>> materialMap) {
    return _bomItems.map((bom) {
      final materialId = bom['material_id'] as int?;
      final material = materialMap[materialId];
      final nama = bom['material_name'] as String? ?? '-';
      final dibutuhkan = (bom['total_required_weight'] as num?)?.toDouble() ?? 0;
      final stok = (material?['current_stock'] as num?)?.toDouble() ?? 0;
      final unit = material?['unit'] as String? ?? '';
      final price = (material?['price_per_unit'] as num?)?.toDouble() ?? 0;
      final defisit = (dibutuhkan - stok).clamp(0, double.infinity).toDouble();
      final estimasi = defisit * 10000;
      return <String, dynamic>{
        'material_id': materialId ?? 0,
        'nama': nama,
        'defisit': defisit,
        'unit': unit,
        'price': price,
        'estimasi': estimasi,
      };
    }).where((item) => (item['defisit'] as double) > 0).toList();
  }

  Widget _buildPoListContent(Map<int, Map<String, dynamic>> materialMap) {
    final items = _computePoItems(materialMap);
    final totalEstimasi = items.fold<double>(0, (sum, item) => sum + (item['estimasi'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primary.withOpacity(0.15),
                _primary.withOpacity(0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(_radiusSm),
            border: Border.all(color: _primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(TablerIcons.report_money, size: 14, color: _primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Total Estimasi Belanja',
                  style: TextStyle(fontSize: 10, color: _textSecondary),
                ),
              ),
              Text(
                'Rp ${_formatCurrency(totalEstimasi)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Daftar bahan (${items.length})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Icon(TablerIcons.circle_check, size: 14, color: _success),
                SizedBox(width: 6),
                Text(
                  'Semua bahan sudah tercukupi',
                  style: TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final nama = item['nama'] as String;
            final defisit = item['defisit'] as double;
            final unit = item['unit'] as String;
            final estimasi = item['estimasi'] as double;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _bg.withOpacity(0.3),
                borderRadius: BorderRadius.circular(_radiusSm),
                border: Border.all(color: _border.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatNumber(defisit)} $unit',
                          style: TextStyle(fontSize: 10, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rp ${_formatCurrency(estimasi)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPoButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _executing ? null : _executePo,
        icon: _executing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(TablerIcons.shopping_cart_plus, size: 18),
        label: Text(
          _executing ? 'Membuat PO...' : 'Eksekusi Buat PO Otomatis',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _success,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _success.withOpacity(0.3),
          disabledForegroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildTable(Map<int, Map<String, dynamic>> materialMap) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(_radiusSm),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radiusSm),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_primary.withOpacity(0.1)),
                dataRowMinHeight: 36,
                dataRowMaxHeight: 48,
                columnSpacing: 20,
                border: TableBorder.symmetric(
                  inside: BorderSide(color: _border.withOpacity(0.4), width: 0.5),
                ),
                columns: [
                  const DataColumn(label: Text('Nama Bahan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: _textPrimary))),
                  const DataColumn(label: Text('Dibutuhkan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: _textPrimary))),
                  const DataColumn(label: Text('Stok', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: _textPrimary))),
                  const DataColumn(label: Text('Defisit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: _textPrimary))),
                  const DataColumn(label: Text('Estimasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: _textPrimary))),
                ],
                rows: _bomItems.map((bom) {
                  final materialId = bom['material_id'] as int?;
                  final material = materialMap[materialId];
                  final nama = bom['material_name'] as String? ?? '-';
                  final dibutuhkan = (bom['total_required_weight'] as num?)?.toDouble() ?? 0;
                  final stok = (material?['current_stock'] as num?)?.toDouble() ?? 0;
                  final unit = material?['unit'] as String? ?? '';
                  final defisit = (dibutuhkan - stok).clamp(0, double.infinity).toDouble();
                  final estimasi = defisit * 10000;

                  return DataRow(cells: [
                    DataCell(SizedBox(
                      width: 120,
                      child: Text(nama, style: const TextStyle(fontSize: 11, color: _textPrimary)),
                    )),
                    DataCell(Text('${_formatNumber(dibutuhkan)} $unit', style: const TextStyle(fontSize: 11, color: _textPrimary))),
                    DataCell(Text('${_formatNumber(stok)} $unit', style: const TextStyle(fontSize: 11, color: _textPrimary))),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (defisit > 0)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              color: _danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          '${_formatNumber(defisit)} $unit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: defisit > 0 ? _danger : _success,
                          ),
                        ),
                      ],
                    )),
                    DataCell(Text(
                      'Rp ${_formatCurrency(estimasi)}',
                      style: const TextStyle(fontSize: 11, color: _primary),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final intVal = value.round().abs();
    if (intVal == 0) return '0';
    var str = intVal.toString();
    final parts = <String>[];
    while (str.length > 3) {
      parts.insert(0, str.substring(str.length - 3));
      str = str.substring(0, str.length - 3);
    }
    parts.insert(0, str);
    return parts.join('.');
  }
}

class _SelectAllRow extends StatelessWidget {
  final bool allSelected;
  final VoidCallback onToggle;
  final int selectedCount;

  const _SelectAllRow({
    required this.allSelected,
    required this.onToggle,
    this.selectedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radiusSm),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(_radiusSm),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: allSelected ? _primary.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(_radiusSm),
              border: Border.all(
                color: allSelected ? _primary.withOpacity(0.3) : _border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: allSelected ? _primary : _textHint,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pilih Semua',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: allSelected ? _primary : _textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  allSelected ? 'Batalkan' : '$selectedCount terpilih',
                  style: TextStyle(fontSize: 10, color: _textHint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final menuName = plan['menu_name'] as String? ?? '-';
    final targetDate = plan['target_date'] as String? ?? '-';
    final targetLarge = (plan['target_portions_large'] as num?)?.toInt() ?? 0;
    final targetSmall = (plan['target_portions_small'] as num?)?.toInt() ?? 0;
    final total = (plan['target_portions'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radiusSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? _primary.withOpacity(0.08) : _cardBg,
              borderRadius: BorderRadius.circular(_radiusSm),
              border: Border.all(
                color: selected ? _primary.withOpacity(0.5) : _border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: selected ? _primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: selected ? _primary : _textHint,
                      width: selected ? 0 : 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menuName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: _textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(TablerIcons.users, size: 10, color: _textHint),
                          const SizedBox(width: 4),
                          Text(
                            '$targetLarge besar + $targetSmall kecil',
                            style: const TextStyle(fontSize: 9, color: _textHint),
                          ),
                          const SizedBox(width: 8),
                          Icon(TablerIcons.arrows_right_left, size: 10, color: _textHint),
                          const SizedBox(width: 4),
                          Text(
                            '$total porsi',
                            style: const TextStyle(fontSize: 9, color: _textHint),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(TablerIcons.calendar, size: 10, color: _textHint),
                          const SizedBox(width: 4),
                          Text(
                            targetDate,
                            style: const TextStyle(fontSize: 9, color: _textHint),
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
}

class _PlanSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(_radiusSm),
          border: Border.all(color: _border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBar(width: double.infinity, height: 12),
            SizedBox(height: 10),
            _ShimmerBar(width: 160, height: 10),
            SizedBox(height: 6),
            _ShimmerBar(width: 100, height: 10),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;

  const _ShimmerBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: _textHint),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: _textHint),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: _danger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(TablerIcons.alert_circle, color: _danger, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gagal memuat data',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 10, color: _danger.withOpacity(0.8)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _danger.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Coba lagi',
                style: TextStyle(fontSize: 10, color: _danger, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
