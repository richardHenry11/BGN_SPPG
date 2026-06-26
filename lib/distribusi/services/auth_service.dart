import 'dart:convert';
import 'api_client.dart';

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['message'] as String? ?? 'Email atau password salah');
    }
    return data;
  }
}
