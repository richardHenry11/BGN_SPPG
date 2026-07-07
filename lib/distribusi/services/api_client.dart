import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://sppg.cbinstrument.com';

  String? _sppgId;
  String? _role;

  void setAuthData(String? sppgId, String? role) {
    _sppgId = sppgId;
    _role = role;
  }

  Map<String, String> get _defaultHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_sppgId != null) headers['x-user-Sppg-id'] = _sppgId!;
    if (_role != null) headers['x-user-role'] = _role!;
    return headers;
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    return await http.get(
      Uri.parse('$baseUrl$path'),
      headers: <String, String>{
        ..._defaultHeaders,
        if (headers != null) ...headers,
      },
    );
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    return await http.post(
      Uri.parse('$baseUrl$path'),
      headers: <String, String>{
        ..._defaultHeaders,
        if (headers != null) ...headers,
      },
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    return await http.put(
      Uri.parse('$baseUrl$path'),
      headers: <String, String>{
        ..._defaultHeaders,
        if (headers != null) ...headers,
      },
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete(String path, {Map<String, String>? headers}) async {
    return await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: <String, String>{
        ..._defaultHeaders,
        if (headers != null) ...headers,
      },
    );
  }

  Future<void> sendLocation(int packagingId, double latitude, double longitude, {Map<String, String>? headers}) async {
    await post(
      '/api/production/packaging/$packagingId/location',
      body: {'latitude': latitude, 'longitude': longitude},
      headers: headers,
    );
  }

  Future<http.StreamedResponse> uploadPhoto(String path, String filePath, {Map<String, String>? headers, Uint8List? bytes}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$path'),
    );
    if (bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('photo', bytes, filename: 'photo.jpg'));
    } else {
      request.files.add(await http.MultipartFile.fromPath('photo', filePath));
    }
    if (_sppgId != null) request.headers['x-user-Sppg-id'] = _sppgId!;
    if (_role != null) request.headers['x-user-role'] = _role!;
    if (headers != null) request.headers.addAll(headers);
    return await request.send();
  }
}
