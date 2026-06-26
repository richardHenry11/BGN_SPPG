import 'package:flutter/material.dart';
import 'draft_store.dart';

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const CheckoutPage({super.key, required this.items});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedPayment = '';
  String _selectedDate = '';
  String _selectedTime = '';
  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'bca', 'name': 'BCA Virtual Account', 'icon': Icons.account_balance, 'color': Color(0xFF004481)},
    {'id': 'mandiri', 'name': 'Mandiri Virtual Account', 'icon': Icons.account_balance, 'color': Color(0xFF003A70)},
    {'id': 'bni', 'name': 'BNI Virtual Account', 'icon': Icons.account_balance, 'color': Color(0xFF004A8F)},
    {'id': 'bri', 'name': 'BRI Virtual Account', 'icon': Icons.account_balance, 'color': Color(0xFF005DAA)},
    {'id': 'gopay', 'name': 'GoPay', 'icon': Icons.account_balance_wallet, 'color': Color(0xFF00A441)},
    {'id': 'ovo', 'name': 'OVO', 'icon': Icons.account_balance_wallet, 'color': Color(0xFF522B8C)},
    {'id': 'dana', 'name': 'DANA', 'icon': Icons.account_balance_wallet, 'color': Color(0xFF007BFF)},
    {'id': 'qris', 'name': 'QRIS', 'icon': Icons.qr_code, 'color': Color(0xFF000000)},
  ];

  int _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is int) return price;
    if (price is double) return price.toInt();
    final cleaned = price.toString().replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  int _itemTotal(Map<String, dynamic> item) {
    final price = _parsePrice(item['price']);
    final qty = item['quantity'] as int? ?? 1;
    return price * qty;
  }

  int get _grandTotal {
    int total = 0;
    for (final item in widget.items) {
      total += _itemTotal(item);
    }
    return total;
  }

  String _formatPrice(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp$formatted';
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _grandTotal;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Checkout Pembayaran',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildItemsSummary(),
              const SizedBox(height: 20),
              _buildSectionTitle('Jadwal Pengiriman'),
              const SizedBox(height: 8),
              _buildDeliverySchedule(),
              const SizedBox(height: 20),
              _buildSectionTitle('Alamat Pengiriman'),
              const SizedBox(height: 8),
              _buildAddressField(),
              const SizedBox(height: 20),
              _buildSectionTitle('Catatan (opsional)'),
              const SizedBox(height: 8),
              _buildNotesField(),
              const SizedBox(height: 24),
              _buildOrderSummary(),
              const SizedBox(height: 24),
              _buildSectionTitle('Metode Pembayaran'),
              const SizedBox(height: 8),
              _buildPaymentMethods(),
              const SizedBox(height: 28),
              _buildPayButton(total),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Ringkasan Belanja (${widget.items.length} item)'),
        const SizedBox(height: 10),
        ...widget.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildItemCard(item),
        )),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemName = item['item'] as String? ?? '';
    final name = item['name'] as String? ?? '';
    final priceStr = item['price'] as String? ?? '';
    final imageUrl = item['imageUrl'] as String? ?? '';
    final qty = item['quantity'] as int? ?? 1;
    final unit = item['unit'] as String? ?? '';
    final total = _itemTotal(item);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56, height: 56,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color.fromARGB(255, 40, 40, 40),
                  child: const Icon(Icons.image, color: Colors.grey, size: 28),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName,
                  style: const TextStyle(color: Color.fromARGB(255, 73, 143, 200), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 1),
                Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(priceStr,
                  style: const TextStyle(color: Color(0xFFD4A843), fontSize: 13, fontWeight: FontWeight.bold),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text('$qty x $unit',
                    style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A8FCC).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatPrice(total),
              style: const TextStyle(color: Color(0xFF1A8FCC), fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySchedule() {
    final dates = ['Senin, 15 Jun', 'Selasa, 16 Jun', 'Rabu, 17 Jun', 'Kamis, 18 Jun', 'Jumat, 19 Jun'];
    final times = ['08:00 - 10:00', '10:00 - 12:00', '12:00 - 14:00', '14:00 - 16:00'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pilih Tanggal',
            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = dates[i];
                final selected = _selectedDate == d;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF135B92) : const Color.fromARGB(255, 40, 40, 40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? const Color(0xFF1A8FCC) : const Color.fromARGB(255, 60, 60, 60),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(d,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color.fromARGB(255, 176, 176, 176),
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          const Text('Pilih Waktu',
            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: times.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = times[i];
                final selected = _selectedTime == t;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTime = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF135B92) : const Color.fromARGB(255, 40, 40, 40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? const Color(0xFF1A8FCC) : const Color.fromARGB(255, 60, 60, 60),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(t,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color.fromARGB(255, 176, 176, 176),
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      maxLines: 3,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Masukkan alamat lengkap pengiriman',
        hintStyle: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 14),
        filled: true,
        fillColor: const Color.fromARGB(255, 40, 40, 40),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color.fromARGB(255, 19, 89, 146)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color.fromARGB(255, 19, 89, 146)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Alamat pengiriman harus diisi';
        }
        return null;
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Contoh: antar sebelum jam 12 siang',
        hintStyle: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 14),
        filled: true,
        fillColor: const Color.fromARGB(255, 40, 40, 40),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color.fromARGB(255, 19, 89, 146)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color.fromARGB(255, 19, 89, 146)),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final total = _grandTotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF1A8FCC), width: 5),
        ),
      ),
      child: Column(
        children: [
          ...widget.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final price = _parsePrice(item['price']);
            final qty = item['quantity'] as int? ?? 1;
            final subtotal = price * qty;
            return Column(
              children: [
                if (i > 0) const SizedBox(height: 8),
                _summaryRow(item['item'] ?? '', '${item['name']} x$qty', _formatPrice(subtotal)),
              ],
            );
          }),
          const SizedBox(height: 8),
          const Divider(color: Color.fromARGB(255, 60, 60, 60)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pembayaran',
                style: TextStyle(color: Color(0xFFD4A843), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(_formatPrice(total),
                style: const TextStyle(color: Color(0xFFD4A843), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _paymentMethods.map((pm) {
          final selected = _selectedPayment == pm['id'];
          return InkWell(
            borderRadius: selected ? BorderRadius.circular(12) : BorderRadius.zero,
            onTap: () => setState(() => _selectedPayment = pm['id']),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color.fromARGB(255, 60, 60, 60),
                    width: pm == _paymentMethods.last ? 0 : 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: (pm['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(pm['icon'] as IconData, color: pm['color'], size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(pm['name'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? const Color(0xFF1A8FCC) : const Color.fromARGB(255, 100, 100, 100),
                          width: 2,
                        ),
                        color: selected ? const Color(0xFF1A8FCC) : Colors.transparent,
                      ),
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPayButton(int total) {
    return SizedBox(
      width: double.infinity,
      height: 52,
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
            onTap: () {
              if (_formKey.currentState!.validate()) {
                if (_selectedPayment.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pilih metode pembayaran terlebih dahulu'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                _showPaymentGateway(context, total);
              }
            },
            child: const Center(
              child: Text('Bayar Sekarang',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, String? price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
            style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(value,
            style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 12),
          ),
        ],
        if (price != null) ...[
          const SizedBox(width: 8),
          Text(price,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  String _paymentName(String id) {
    return _paymentMethods.firstWhere((p) => p['id'] == id)['name'] as String;
  }

  Future<void> _showPaymentGateway(BuildContext context, int total) async {
    final totalFormatted = _formatPrice(total);
    final methodName = _paymentName(_selectedPayment);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _PaymentGatewayPage(
          totalFormatted: totalFormatted,
          methodName: methodName,
          methodId: _selectedPayment,
        ),
      ),
    );

    if (result == true && context.mounted) {
      _showPaymentSuccess(context, totalFormatted);
    }
  }

  void _showPaymentSuccess(BuildContext context, String totalFormatted) {
    for (final item in widget.items) {
      DraftStore.removeDraft(item['item'] as String, item['name'] as String);
    }

    for (final item in widget.items) {
      final paidOrder = Map<String, dynamic>.from(item);
      paidOrder['quantity'] = item['quantity'] as int? ?? 1;
      paidOrder['address'] = _addressController.text.trim();
      paidOrder['notes'] = _notesController.text.trim();
      paidOrder['deliveryDate'] = _selectedDate;
      paidOrder['deliveryTime'] = _selectedTime;
      paidOrder['paymentMethod'] = _selectedPayment;
      paidOrder['totalFormatted'] = totalFormatted;
      DraftStore.addPaidOrder(paidOrder);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color.fromARGB(255, 47, 47, 47),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B5E20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Pembayaran Berhasil!',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Pembayaran $totalFormatted berhasil diproses. '
                '${widget.items.length} pesanan akan segera diproses.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
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
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Center(
                        child: Text('Kembali',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentGatewayPage extends StatefulWidget {
  final String totalFormatted;
  final String methodName;
  final String methodId;

  const _PaymentGatewayPage({
    required this.totalFormatted,
    required this.methodName,
    required this.methodId,
  });

  @override
  State<_PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<_PaymentGatewayPage> {
  bool _loading = true;
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    _simulateProcessing();
  }

  Future<void> _simulateProcessing() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _loading = false);
  }

  String _generateVaNumber() {
    final now = DateTime.now();
    final seed = now.millisecondsSinceEpoch % 100000000;
    return '${widget.methodId == 'bca' ? '880' : widget.methodId == 'mandiri' ? '886' : widget.methodId == 'bni' ? '881' : '888'}${seed.toString().padLeft(10, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 32, 52),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 32, 52),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Pembayaran',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: _loading ? _buildLoadingState() : _buildPaymentDetail(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64, height: 64,
            child: CircularProgressIndicator(color: Color(0xFF1A8FCC), strokeWidth: 4),
          ),
          const SizedBox(height: 24),
          const Text('Memproses Pembayaran...',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text('Menyiapkan ${widget.methodName}',
            style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetail() {
    final isVa = ['bca', 'mandiri', 'bni', 'bri'].contains(widget.methodId);
    final isEwallet = ['gopay', 'ovo', 'dana'].contains(widget.methodId);
    final isQris = widget.methodId == 'qris';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!_paid) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 47, 47, 47),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color.fromARGB(255, 60, 60, 60)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (widget.methodId == 'bca' ? const Color(0xFF004481) :
                              widget.methodId == 'mandiri' ? const Color(0xFF003A70) :
                              widget.methodId == 'bni' ? const Color(0xFF004A8F) :
                              widget.methodId == 'bri' ? const Color(0xFF005DAA) :
                              widget.methodId == 'gopay' ? const Color(0xFF00A441) :
                              widget.methodId == 'ovo' ? const Color(0xFF522B8C) :
                              widget.methodId == 'dana' ? const Color(0xFF007BFF) :
                              const Color(0xFF333333))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isVa ? Icons.account_balance :
                      isEwallet ? Icons.account_balance_wallet :
                      Icons.qr_code,
                      color: widget.methodId == 'bca' ? const Color(0xFF004481) :
                             widget.methodId == 'mandiri' ? const Color(0xFF003A70) :
                             widget.methodId == 'bni' ? const Color(0xFF004A8F) :
                             widget.methodId == 'bri' ? const Color(0xFF005DAA) :
                             widget.methodId == 'gopay' ? const Color(0xFF00A441) :
                             widget.methodId == 'ovo' ? const Color(0xFF522B8C) :
                             widget.methodId == 'dana' ? const Color(0xFF007BFF) :
                             Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.methodName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.totalFormatted,
                    style: const TextStyle(color: Color(0xFFD4A843), fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (isVa) _buildVaDetail(),
            if (isEwallet) _buildEwalletDetail(),
            if (isQris) _buildQrisDetail(),
            const SizedBox(height: 24),
            _buildCopyButton(),
            const SizedBox(height: 12),
            _buildConfirmButton(),
          ] else
            _buildPaidState(),
        ],
      ),
    );
  }

  Widget _buildVaDetail() {
    final vaNumber = _generateVaNumber();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFF1A8FCC), width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nomor Virtual Account',
            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 35, 45, 55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(vaNumber,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 16),
          _instructionRow('1', 'Buka aplikasi bank ${widget.methodName.split(' ')[0]}'),
          const SizedBox(height: 10),
          _instructionRow('2', 'Pilih menu Pembayaran / Transfer'),
          const SizedBox(height: 10),
          _instructionRow('3', 'Masukkan nomor Virtual Account di atas'),
          const SizedBox(height: 10),
          _instructionRow('4', 'Konfirmasi jumlah pembayaran ${widget.totalFormatted}'),
          const SizedBox(height: 10),
          _instructionRow('5', 'Masukkan PIN dan selesaikan pembayaran'),
        ],
      ),
    );
  }

  Widget _buildEwalletDetail() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFF1A8FCC), width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Menunggu pembayaran melalui $widget.methodName',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _instructionRow('1', 'Buka aplikasi ${widget.methodName}'),
          const SizedBox(height: 10),
          _instructionRow('2', 'Pilih menu Bayar / Scan QR'),
          const SizedBox(height: 10),
          _instructionRow('3', 'Masukkan jumlah ${widget.totalFormatted}'),
          const SizedBox(height: 10),
          _instructionRow('4', 'Masukkan PIN untuk konfirmasi'),
        ],
      ),
    );
  }

  Widget _buildQrisDetail() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 47, 47, 47),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFF1A8FCC), width: 5)),
      ),
      child: Column(
        children: [
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(Icons.qr_code, size: 160, color: Colors.black),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Scan QRIS dengan aplikasi e-wallet atau mobile banking',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 13),
          ),
          const SizedBox(height: 16),
          _instructionRow('1', 'Buka aplikasi pembayaran (GoPay, OVO, DANA, dll)'),
          const SizedBox(height: 10),
          _instructionRow('2', 'Pilih menu Scan QR / QRIS'),
          const SizedBox(height: 10),
          _instructionRow('3', 'Scan kode QR di atas'),
          const SizedBox(height: 10),
          _instructionRow('4', 'Konfirmasi pembayaran ${widget.totalFormatted}'),
        ],
      ),
    );
  }

  Widget _instructionRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF1A8FCC),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
            style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyButton() {
    if (!['bca', 'mandiri', 'bni', 'bri'].contains(widget.methodId)) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nomor Virtual Account berhasil disalin'),
              backgroundColor: Color(0xFF1B5E20),
              duration: Duration(seconds: 2),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF1A8FCC)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.copy, color: Color(0xFF1A8FCC), size: 18),
            SizedBox(width: 8),
            Text('Salin Nomor VA',
              style: TextStyle(color: Color(0xFF1A8FCC), fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
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
            onTap: () {
              setState(() => _loading = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _loading = false;
                    _paid = true;
                  });
                }
              });
            },
            child: const Center(
              child: Text('Saya Sudah Bayar',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaidState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1B5E20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 24),
        const Text('Pembayaran Diproses',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Pembayaran $widget.totalFormatted melalui ${widget.methodName} sedang diverifikasi.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color.fromARGB(255, 176, 176, 176), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
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
                onTap: () => Navigator.of(context).pop(true),
                child: const Center(
                  child: Text('Selesai',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
