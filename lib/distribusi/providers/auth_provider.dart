// lib/providers/auth_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bgn/distribusi/services/api_client.dart';
import 'package:bgn/distribusi/services/auth_service.dart';

class RoleModel {
  final String id;
  final String label;
  final String description;
  final IconData icon;

  RoleModel({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class UserModel {
  final String name;
  final String unit;

  UserModel({required this.name, required this.unit});
}

class AuthProvider extends ChangeNotifier {
  static const _keyUserData = 'user_data';
  static const _keyToken = 'token';

  // ── API auth state ──────────────────────────────────────
  Map<String, dynamic>? _userData;
  String? _token;
  final ApiClient _apiClient = ApiClient();
  late final AuthService _authService = AuthService(_apiClient);
  bool isLoading = false;
  String? loginError;

  bool get isLoggedIn => _userData != null;

  // ── Hardcoded roles + users (fallback / role switcher) ──

  final List<RoleModel> roles = [
    RoleModel(
      id: 'kepala_sppg',
      label: 'Kepala SPPG',
      description: 'Monitoring & kontrol distribusi',
      icon: TablerIcons.building,
    ),
    RoleModel(
      id: 'aslab',
      label: 'Aslab / Pengantar',
      description: 'Validasi barang keluar & masuk',
      icon: TablerIcons.package,
    ),
    RoleModel(
      id: 'driver',
      label: 'Driver',
      description: 'Pengiriman & tracking',
      icon: TablerIcons.truck,
    ),
    RoleModel(
      id: 'pic_sekolah',
      label: 'PIC / Penerima',
      description: 'Penerimaan di lokasi',
      icon: TablerIcons.school,
    ),
    RoleModel(
      id: 'accounting',
      label: 'Accounting',
      description: 'Monitoring keuangan & validasi',
      icon: TablerIcons.report_money,
    ),
  ];

  final Map<String, UserModel> _mockUsers = {
    'kepala_sppg': UserModel(name: 'Petugas 01', unit: 'SPPG Bandung Barat'),
    'aslab':       UserModel(name: 'Aslab 01',   unit: 'Dapur SPPG'),
    'driver':      UserModel(name: 'Driver 01',  unit: 'Armada BGN-01'),
    'pic_sekolah': UserModel(name: 'Penerima 01', unit: 'SDN 01'),
    'accounting': UserModel(name: 'Akuntan 01', unit: 'Keuangan SPPG'),
  };

  String _currentRole = 'kepala_sppg';

  // ── Getters ─────────────────────────────────────────────

  String get currentRole =>
      _userData?['role'] as String? ?? _currentRole;

  String? get sppgId => (_userData?['sppg_id'] ?? _userData?['sppgId'])?.toString();

  RoleModel get activeRole =>
      roles.firstWhere((r) => r.id == currentRole, orElse: () => roles.first);

  UserModel get activeUser {
    if (_userData != null) {
      return UserModel(
        name: _userData!['name'] as String? ?? 'Pengguna',
        unit: _userData!['location'] as String? ?? '-',
      );
    }
    return _mockUsers[_currentRole]!;
  }

  bool get isKepala    => currentRole == 'kepala_sppg';
  bool get isAslab     => currentRole == 'asisten_lapangan';
  bool get isDriver    => currentRole == 'driver';
  bool get isPIC       => currentRole == 'pic_sekolah';

  // ── Persistence ─────────────────────────────────────────

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_keyUserData);
      if (userJson == null) return;

      final data = jsonDecode(userJson) as Map<String, dynamic>;
      _userData = data;
      _token = prefs.getString(_keyToken);
      _currentRole = data['role'] as String? ?? 'kepala_sppg';
      final sppgId = data['sppg_id']?.toString();
      _apiClient.setAuthData(sppgId, _currentRole);
      notifyListeners();
    } catch (_) {
      await _clearSession();
    }
  }

  Future<void> _saveSession() async {
    if (_userData == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, jsonEncode(_userData));
      if (_token != null) {
        await prefs.setString(_keyToken, _token!);
      }
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserData);
      await prefs.remove(_keyToken);
    } catch (_) {}
  }

  // ── Role switcher (untuk demo) ─────────────────────────

  void switchRole(String roleId) {
    final valid = roles.any((r) => r.id == roleId);
    if (!valid) return;
    _currentRole = roleId;
    if (_userData != null) {
      _userData!['role'] = roleId;
    }
    notifyListeners();
  }

  // ── Login ──────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    isLoading = true;
    loginError = null;
    notifyListeners();

    try {
      final data = await _authService.login(email, password);

      final userData = data['user'] as Map<String, dynamic>? ?? data;
      _userData = userData;
      _token = data['token'] as String?;
      _currentRole = userData['role'] as String? ?? data['role'] as String? ?? 'kepala_sppg';

      final sppgId = (userData['sppg_id'] ?? data['sppg_id'])?.toString();
      _apiClient.setAuthData(sppgId, _currentRole);

      await _saveSession();
      return true;
    } catch (e) {
      loginError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Logout ─────────────────────────────────────────────

  Future<void> logout() async {
    _userData = null;
    _token = null;
    _currentRole = 'kepala_sppg';
    loginError = null;
    isLoading = false;
    _apiClient.setAuthData(null, null);
    await _clearSession();
    notifyListeners();
  }

  // ── Hydrate dari API user (dipanggil di main) ────────

  void setUser(Map<String, dynamic> user, {String? token}) {
    _userData = user;
    _token = token;
    _currentRole = user['role'] as String? ?? 'kepala_sppg';
    final sppgId = user['sppg_id']?.toString();
    _apiClient.setAuthData(sppgId, _currentRole);
    notifyListeners();
  }
}
