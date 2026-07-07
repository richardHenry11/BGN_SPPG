// lib/screens/login/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/providers/auth_provider.dart';
import 'package:bgn/distribusi/theme/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:bgn/distribusi/widgets/common/car_loading.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool _showPass    = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _formValid =>
      _emailCtrl.text.isNotEmpty && _passCtrl.text.isNotEmpty;

  Future<void> _handleLogin() async {
    if (!_formValid) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) return;

    final ok = await auth.login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (ok && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: BGNColors.bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              // ── Logo area ──
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: BGNColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: BGNColors.border),
                      ),
                      child: const Icon(
                        TablerIcons.truck,
                        color: BGNColors.primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Distribusi BGN',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: BGNColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tepat Sasaran · Tepat Jumlah · Tepat Waktu',
                      style: TextStyle(
                        fontSize: 13,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                decoration: const BoxDecoration(
                  color: BGNColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masuk ke akun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: BGNColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Masukkan email dan password kamu',
                      style: TextStyle(
                        fontSize: 12,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Email ──
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _handleLogin(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: BGNColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'contoh@email.com',
                        prefixIcon: const Icon(
                          TablerIcons.mail,
                          size: 18,
                          color: BGNColors.textHint,
                        ),
                        filled: true,
                        fillColor: auth.loginError != null
                            ? BGNColors.surfaceAlt
                            : BGNColors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: auth.loginError != null
                                ? BGNColors.danger
                                : BGNColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: auth.loginError != null
                                ? BGNColors.danger
                                : BGNColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: BGNColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Password ──
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: BGNColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passCtrl,
                      obscureText: !_showPass,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _handleLogin(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: BGNColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Password kamu',
                        prefixIcon: const Icon(
                          TablerIcons.lock,
                          size: 18,
                          color: BGNColors.textHint,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () =>
                              setState(() => _showPass = !_showPass),
                          child: Icon(
                            _showPass
                                ? TablerIcons.eye_off
                                : TablerIcons.eye,
                            size: 18,
                            color: BGNColors.textHint,
                          ),
                        ),
                        filled: true,
                        fillColor: auth.loginError != null
                            ? BGNColors.surfaceAlt
                            : BGNColors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: auth.loginError != null
                                ? BGNColors.danger
                                : BGNColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: auth.loginError != null
                                ? BGNColors.danger
                                : BGNColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: BGNColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Error ──
                    if (auth.loginError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: BGNColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: BGNColors.danger
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              TablerIcons.alert_circle,
                              size: 14,
                              color: BGNColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.loginError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: BGNColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (auth.loginError != null)
                      const SizedBox(height: 16),

                    // ── Login button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_formValid && !auth.isLoading)
                            ? _handleLogin
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_formValid && !auth.isLoading)
                              ? BGNColors.primary
                              : BGNColors.surfaceAlt,
                          foregroundColor:
                              (_formValid && !auth.isLoading)
                                  ? BGNColors.white
                                  : BGNColors.textHint,
                          disabledBackgroundColor: BGNColors.surfaceAlt,
                          disabledForegroundColor: BGNColors.textHint,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (auth.isLoading)
                              const ButtonCarLoading()
                            else
                              const Icon(
                                TablerIcons.login,
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              auth.isLoading
                                  ? 'Memproses...'
                                  : 'Masuk',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    // ── Version ──
                    Center(
                      child: Text(
                        'Distribusi BGN v1.0.0',
                        style: TextStyle(
                          fontSize: 10,
                          color: BGNColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
