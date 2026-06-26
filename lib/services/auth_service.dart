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
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
