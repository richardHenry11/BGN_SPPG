import 'dart:convert';
import 'api_client.dart';

class PackagingService {
  final ApiClient _client;

  PackagingService(this._client);

  Future<List<dynamic>> getList() async {
    final res = await _client.get('/api/production/packaging');
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDetail(String id) async {
    final res = await _client.get('/api/production/packaging/$id');
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    final res = await _client.put(
      '/api/production/packaging/$id',
      body: data,
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'HTTP ${res.statusCode}');
    }
  }

  Future<String> uploadPhoto(String filePath) async {
    final streamed = await _client.uploadPhoto(
      '/api/distribution/upload',
      filePath,
    );
    if (streamed.statusCode != 200) {
      throw Exception('Upload gagal: HTTP ${streamed.statusCode}');
    }
    final body = await streamed.stream.bytesToString();
    final result = jsonDecode(body) as Map<String, dynamic>;
    return (result['compliance_photo_url'] ??
            result['url'] ??
            result['path'] ??
            '')
        as String;
  }
}
