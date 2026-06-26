import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://sppg.cbinstrument.com';

  String? _sppgId;
  String? _role;

  void setAuthData(String? sppgId, String? role) {
    _sppgId = sppgId;
    _role = role;
  }

  Map<String, String> get _authHeaders {
    final headers = <String, String>{};
    if (_sppgId != null) headers['x-user-Sppg-id'] = _sppgId!;
    if (_role != null) headers['x-user-Role'] = _role!;
    return headers;
  }

  Future<http.Response> get(String path) async {
    return await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _authHeaders,
    );
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    return await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders,
      },
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    return await http.put(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders,
      },
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.StreamedResponse> uploadPhoto(String path, String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$path'),
    );
    request.files.add(await http.MultipartFile.fromPath('photo', filePath));
    if (_sppgId != null) request.headers['x-user-Sppg-id'] = _sppgId!;
    if (_role != null) request.headers['x-user-Role'] = _role!;
    return await request.send();
  }
}
