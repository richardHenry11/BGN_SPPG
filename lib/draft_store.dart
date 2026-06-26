import 'package:flutter/material.dart';

class DraftStore {
  static String loggedInUser = '';
  static String loggedInRole = '';
  static int loggedInSupplierId = 1;
  static String loggedInSupplierName = 'UD. Sumber Makmur';
  static final List<Map<String, dynamic>> pendingPayments = [];
  static final List<Map<String, dynamic>> paidOrders = [];
  static final List<Map<String, dynamic>> incomingOrders = [];
  static final List<Map<String, dynamic>> readyOrders = [];
  static final List<Map<String, dynamic>> ratedOrders = [];
  static final ValueNotifier<int> paymentNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> shippingNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> incomingNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> receiveNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> rateNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> stockNotifier = ValueNotifier<int>(0);
  static final List<Map<String, dynamic>> stockLedger = [];
  static int _nextLedgerId = 0;
  static bool _stockScheduled = false;
  static bool _paymentScheduled = false;
  static bool _shippingScheduled = false;
  static bool _incomingScheduled = false;
  static bool _receiveScheduled = false;
  static bool _rateScheduled = false;
  static int _nextId = 0;

  static void _notifyPayment() {
    if (_paymentScheduled) return;
    _paymentScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paymentScheduled = false;
      paymentNotifier.value++;
    });
  }

  static void _notifyShipping() {
    if (_shippingScheduled) return;
    _shippingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shippingScheduled = false;
      shippingNotifier.value++;
    });
  }

  static void _notifyIncoming() {
    if (_incomingScheduled) return;
    _incomingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _incomingScheduled = false;
      incomingNotifier.value++;
    });
  }

  static void _notifyReceive() {
    if (_receiveScheduled) return;
    _receiveScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _receiveScheduled = false;
      receiveNotifier.value++;
    });
  }

  static void _notifyRate() {
    if (_rateScheduled) return;
    _rateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rateScheduled = false;
      rateNotifier.value++;
    });
  }

  static void _notifyStock() {
    if (_stockScheduled) return;
    _stockScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stockScheduled = false;
      stockNotifier.value++;
    });
  }

  static String _now() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year} ${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  static void addDraft(Map<String, dynamic> item) {
    final exists = pendingPayments.any((d) =>
      d['item'] == item['item'] && d['name'] == item['name']);
    if (!exists) {
      pendingPayments.add(Map.from(item));
      _notifyPayment();
    }
  }

  static void removeDraft(String itemName, String supplierName) {
    pendingPayments.removeWhere((d) =>
      d['item'] == itemName && d['name'] == supplierName);
    _notifyPayment();
  }

  static void addPaidOrder(Map<String, dynamic> order) {
    final id = _nextId++;
    order['_orderId'] = id;
    paidOrders.insert(0, Map.from(order));
    _notifyShipping();

    final incoming = {
      '_orderId': id,
      'item': order['item'],
      'supplier': order['name'],
      'qty': '${order['quantity'] ?? 1} ${order['unit'] ?? 'kg'}',
      'date': order['deliveryDate'] ?? '',
      'time': order['deliveryTime'] ?? '',
      'total': order['totalFormatted'] ?? '',
      'address': order['address'] ?? '',
      'notes': order['notes'] ?? '',
      'imageUrl': order['imageUrl'] ?? '',
      'price': order['price'] ?? '',
      'paymentMethod': order['paymentMethod'] ?? '',
      'status': 'Baru',
    };
    incomingOrders.insert(0, incoming);
    _notifyIncoming();
  }

  static void markReady(Map<String, dynamic> order) {
    final id = order['_orderId'];

    final idx = incomingOrders.indexWhere((o) => o['_orderId'] == id);
    if (idx >= 0) {
      incomingOrders[idx]['status'] = 'Siap';
      incomingNotifier.value++;
    }

    paidOrders.removeWhere((o) => o['_orderId'] == id);
    _notifyShipping();

    final ready = Map<String, dynamic>.from(order);
    ready['status'] = 'Siap Dikirim';
    readyOrders.insert(0, ready);
    _notifyReceive();
  }

  static void markReceived(Map<String, dynamic> order) {
    final id = order['_orderId'];
    final idx = readyOrders.indexWhere((o) => o['_orderId'] == id);
    if (idx < 0) return;
    readyOrders.removeAt(idx);
    _notifyReceive();

    final incomingIdx = incomingOrders.indexWhere((o) => o['_orderId'] == id);
    if (incomingIdx >= 0) {
      incomingOrders[incomingIdx]['status'] = 'Selesai';
      incomingNotifier.value++;
    }

    final rated = Map<String, dynamic>.from(order);
    rated['status'] = 'Diterima';
    ratedOrders.insert(0, rated);
    _notifyRate();

    addStockIn(
      itemName: order['item'] ?? order['itemName'] ?? '',
      qty: int.tryParse('${order['quantity'] ?? 1}') ?? 1,
      unit: order['unit'] ?? 'kg',
      reference: 'Pesanan #${order['_orderId']}',
      price: int.tryParse('${order['price'] ?? 0}') ?? 0,
    );
  }



  static void addStockIn({required String itemName, required int qty, required String unit, String reference = '', int price = 0, String date = ''}) {
    if (itemName.isEmpty) return;
    final id = _nextLedgerId++;
    stockLedger.insert(0, {
      'id': id,
      'itemName': itemName,
      'type': 'masuk',
      'qty': qty,
      'unit': unit,
      'date': date.isEmpty ? _now() : date,
      'reference': reference,
      'price': price,
    });
    _notifyStock();
  }

  static void addStockOut({required String itemName, required int qty, required String unit, String reference = '', String date = ''}) {
    if (itemName.isEmpty) return;
    final id = _nextLedgerId++;

    final batches = stockLedger
        .where((e) =>
            e['itemName'] == itemName &&
            e['type'] == 'masuk' &&
            ((e['remaining'] ?? e['qty']) as int) > 0)
        .toList()
      ..sort((a, b) => a['date'].compareTo(b['date']));

    int remaining = qty;
    final fifoDetails = <Map<String, dynamic>>[];
    for (final batch in batches) {
      if (remaining <= 0) break;
      final available = (batch['remaining'] ?? batch['qty']) as int;
      final used = remaining < available ? remaining : available;
      batch['remaining'] = available - used;
      remaining -= used;
      fifoDetails.add({'batchId': batch['id'], 'used': used, 'remaining': batch['remaining']});
    }

    stockLedger.insert(0, {
      'id': id,
      'itemName': itemName,
      'type': 'keluar',
      'qty': qty,
      'unit': unit,
      'date': date.isEmpty ? _now() : date,
      'reference': reference,
      'fifoDetails': fifoDetails,
    });
    _notifyStock();
  }

  static int getStock(String itemName) {
    int masuk = 0, keluar = 0;
    for (final e in stockLedger) {
      if (e['itemName'] != itemName) { continue; }
      if (e['type'] == 'masuk') { masuk += e['qty'] as int; }
      else { keluar += e['qty'] as int; }
    }
    return masuk - keluar;
  }

  static int getItemRemaining(String itemName) {
    int total = 0;
    for (final e in stockLedger) {
      if (e['itemName'] != itemName) continue;
      if (e['type'] == 'masuk') total += (e['remaining'] ?? e['qty']) as int;
    }
    return total;
  }
}
