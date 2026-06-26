import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://sppg.cbinstrument.com';

  Future<http.Response> get(String path) async {
    return await http.get(Uri.parse('$baseUrl$path'));
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    return await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    return await http.put(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.StreamedResponse> uploadPhoto(String path, String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$path'),
    );
    request.files.add(await http.MultipartFile.fromPath('photo', filePath));
    return await request.send();
  }
}
