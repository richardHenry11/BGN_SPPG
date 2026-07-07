import 'dart:convert';
import 'dart:typed_data';
import 'api_client.dart';

class PackagingService {
  final ApiClient _client;

  PackagingService(this._client);

  Future<List<dynamic>> getList({Map<String, String>? headers}) async {
    final res = await _client.get('/api/production/packaging', headers: headers);
    if (res.statusCode != 200) {
      try {
        final err = jsonDecode(res.body);
        throw Exception((err['error'] ?? err['message'] ?? err).toString());
      } catch (_) {
        throw Exception('HTTP ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body);
    if (decoded == null) return [];
    if (decoded is Map && decoded['data'] is List) return decoded['data'] as List<dynamic>;
    return decoded as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDetail(String id, {Map<String, String>? headers}) async {
    final res = await _client.get('/api/production/packaging/$id', headers: headers);
    if (res.statusCode != 200) {
      try {
        final err = jsonDecode(res.body);
        throw Exception((err['error'] ?? err['message'] ?? err).toString());
      } catch (_) {
        throw Exception('HTTP ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body);
    if (decoded == null) return {};
    return decoded as Map<String, dynamic>;
  }

  Future<void> update(String id, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    final res = await _client.put(
      '/api/production/packaging/$id',
      body: data,
      headers: headers,
    );
    if (res.statusCode != 200) {
      String msg;
      try {
        final json = jsonDecode(res.body);
        msg = (json['error'] ?? json['message'] ?? json).toString();
      } catch (_) {
        msg = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      }
      throw Exception(msg);
    }
  }

  Future<String> uploadPhoto(String filePath, {Map<String, String>? headers, Uint8List? bytes}) async {
    final streamed = await _client.uploadPhoto(
      '/api/distribution/upload',
      filePath,
      headers: headers,
      bytes: bytes,
    );
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      try {
        final err = jsonDecode(body);
        throw Exception((err['error'] ?? err['message'] ?? err).toString());
      } catch (_) {
        throw Exception('Upload gagal (${streamed.statusCode})');
      }
    }
    final result = jsonDecode(body) as Map<String, dynamic>;
    return (result['url'] ?? result['compliance_photo_url'] ?? result['path'] ?? '').toString();
  }

  // ── Simpan rute & asisten (PUT) ─────────────────────────

  Future<void> updateValidasiKeluar({
    required Map<String, dynamic> existingData,
    required String deliveryStatus,
    required String deliveryRoute,
    required String fieldAssistant,
    required String proofPhotoUrl,
    String photoField = 'proof_photo_url',
    Map<String, String>? headers,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
  }) async {
    final id = existingData['id'];
    if (id == null) throw Exception('ID data tidak ditemukan');

    num? toNum(dynamic v) => (v as num?)?.toDouble();
    int? toInt(dynamic v) => (v as num?)?.toInt();
    String toStr(dynamic v) => (v as String?) ?? '';
    bool toBool(dynamic v) => v == true;

    final body = <String, dynamic>{
      'id': id,
      'sppg_id': existingData['sppg_id'] ?? toInt(headers?['X-User-Sppg-Id']),
      'production_plan_id': toInt(existingData['production_plan_id']) ?? 0,
      'menu_name': toStr(existingData['menu_name']),
      'beneficiary_name': toStr(existingData['beneficiary_name']),
      'target_portions': toInt(existingData['target_portions']) ?? 0,
      'actual_portions': toInt(existingData['actual_portions']) ?? 0,
      'discrepancy': toInt(existingData['discrepancy']) ?? 0,
      'cctv_link': toStr(existingData['cctv_link']),
      'effectiveness': toNum(existingData['effectiveness']) ?? 0.0,
      'fallen_broken_qty': toInt(existingData['fallen_broken_qty']) ?? 0,
      'missing_qty': toInt(existingData['missing_qty']) ?? 0,
      'damaged_label_check': toBool(existingData['damaged_label_check']),
      'damaged_seal_check': toBool(existingData['damaged_seal_check']),
      'timestamp': (existingData['timestamp'] as String?) ?? DateTime.now().toIso8601String(),
      'delivery_status': deliveryStatus,
      'delivery_route': deliveryRoute,
      'field_assistant': fieldAssistant,
      'compliance_photo_url': toStr(existingData['compliance_photo_url']),
    };
    body[photoField] = proofPhotoUrl;
    if (startLat != null) body['start_latitude'] = startLat;
    if (startLng != null) body['start_longitude'] = startLng;
    if (endLat != null) body['end_latitude'] = endLat;
    if (endLng != null) body['end_longitude'] = endLng;
    await update(id.toString(), body, headers: headers);
  }
}
