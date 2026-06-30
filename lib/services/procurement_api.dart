import 'dart:convert';
import 'package:http/http.dart' as http;

class ProcurementApi {
  static const String _baseUrl = 'https://sppg.cbinstrument.com/api/procurement';
  static const String _distributionBaseUrl = 'https://sppg.cbinstrument.com/api/distribution';

  static Map<String, String> _headers({String? sppgId, String? role}) {
    final h = <String, String>{};
    if (sppgId != null) h['x-user-Sppg-id'] = sppgId;
    if (role != null) h['x-user-Role'] = role;
    return h;
  }

  static Future<List<Map<String, dynamic>>> fetchOrders({String? sppgId, String? role}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/orders'),
      headers: {'Accept': 'application/json', ..._headers(sppgId: sppgId, role: role)},
    );
    if (res.statusCode != 200) {
      throw Exception('Gagal memuat data (${res.statusCode})');
    }
    final List<dynamic>? data = jsonDecode(res.body) as List<dynamic>?;
    return data?.cast<Map<String, dynamic>>() ?? [];
  }

  static Future<Map<String, dynamic>> checkHealth({String? sppgId, String? role}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/health'),
      headers: {'Accept': 'application/json', ..._headers(sppgId: sppgId, role: role)},
    );
    if (res.statusCode != 200) {
      throw Exception('Health check gagal (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> updateOrderStatus(int orderId, String status, {String? sppgId, String? role}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/orders/$orderId/status'),
      headers: {'Content-Type': 'application/json', ..._headers(sppgId: sppgId, role: role)},
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) {
      throw Exception('Gagal update status (${res.statusCode})');
    }
  }

  static Future<void> splitOrder(int orderId, {String? sppgId, String? role}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/orders/$orderId/split'),
      headers: {'Accept': 'application/json', ..._headers(sppgId: sppgId, role: role)},
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Gagal memecah PO (${res.statusCode})');
    }
  }

  static Future<String> uploadPhoto(String photoPath, {String? sppgId, String? role}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_distributionBaseUrl/upload'),
    );
    if (sppgId != null) request.headers['x-user-Sppg-id'] = sppgId;
    if (role != null) request.headers['x-user-Role'] = role;
    request.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Gagal upload foto (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final relativeUrl = data['url'] as String? ?? '';
    return 'https://sppg.cbinstrument.com$relativeUrl';
  }

  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order, {String? sppgId, String? role}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/orders'),
      headers: {'Content-Type': 'application/json', ..._headers(sppgId: sppgId, role: role)},
      body: jsonEncode(order),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Gagal membuat PO (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchInspections({String? sppgId, String? role}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/inspections'),
      headers: {'Accept': 'application/json', ..._headers(sppgId: sppgId, role: role)},
    );
    if (res.statusCode != 200) {
      throw Exception('Gagal memuat QC (${res.statusCode})');
    }
    final List<dynamic>? data = jsonDecode(res.body) as List<dynamic>?;
    return data?.cast<Map<String, dynamic>>() ?? [];
  }

  static Future<void> updateSupplierStatus(int orderId, String photoUrl, {String? sppgId, String? role}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/orders/$orderId/supplier-status'),
      headers: {'Content-Type': 'application/json', ..._headers(sppgId: sppgId, role: role)},
      body: jsonEncode({
        'supplier_status': 'Dikirim',
        'photo_before_shipping': photoUrl,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] as String? ?? 'Gagal kirim status (${res.statusCode})');
    }
  }
}
