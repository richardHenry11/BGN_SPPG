import 'dart:convert';
import 'api_client.dart';

class SchoolService {
  final ApiClient _client;

  SchoolService(this._client);

  Future<List<dynamic>> getSchools({Map<String, String>? headers}) async {
    final sppgId = headers?['X-User-Sppg-Id'] ?? '1';
    final res = await _client.get('/api/distribution/schools?sppg_id=$sppgId', headers: headers);
    if (res.statusCode != 200) {
      try {
        final err = jsonDecode(res.body);
        throw Exception((err['error'] ?? err['message'] ?? err).toString());
      } catch (_) {
        throw Exception('HTTP ${res.statusCode}');
      }
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) return decoded['data'] as List<dynamic>;
    return [];
  }

  Future<void> updateSchool(int id, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    final res = await _client.put(
      '/api/distribution/schools/$id',
      body: data,
      headers: headers,
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        throw Exception((body['error'] ?? body['message'] ?? body).toString());
      } catch (_) {
        throw Exception('HTTP ${res.statusCode}');
      }
    }
  }
}
