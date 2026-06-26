import 'dart:convert';
import 'package:bgn/distribusi/services/api_client.dart';

class ProductionPlanService {
  final ApiClient _client;

  ProductionPlanService(this._client);

  Future<List<Map<String, dynamic>>> fetchPlans() async {
    final res = await _client.get('/api/production/plans');
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return (jsonDecode(res.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchBom(int planId) async {
    final res = await _client.get('/api/production/plans/$planId/bom');
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return (jsonDecode(res.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchMaterials() async {
    final res = await _client.get('/api/procurement/materials');
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return (jsonDecode(res.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async {
    final res = await _client.post('/api/procurement/orders', body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] as String? ?? 'Gagal membuat PO');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
