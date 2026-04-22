import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ⭐ TAMBAHKAN IMPORT INI
import 'package:frontend_flutter/pages/auth/register_page.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // ⭐ ATUR STATUS BAR MENJADI GELAP (IKON HITAM) AGAR TERLIHAT DI BACKGROUND PUTIH
    _setStatusBarDark();
  }

  // ⭐ FUNGSI UNTUK MENGATUR STATUS BAR STYLE
  void _setStatusBarDark() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // IKON HITAM (Android)
        statusBarBrightness: Brightness.light,     // TEKS HITAM (iOS)
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Di dalam _handleLogin() method, setelah login sukses
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (response.containsKey('token')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      response['message'] ?? "Login Berhasil",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );

          final token = response['token'];
          final hasPin = response['has_pin'] ?? false;

          // ⭐ LOGIC BARU: Selalu cek PIN dulu
          if (!hasPin) {
            // User belum set PIN → ke SetPinPage
            Navigator.pushReplacementNamed(
              context,
              '/set-pin',
              arguments: {'token': token},
            );
          } else {
            // User sudah punya PIN → harus verify PIN dulu
            Navigator.pushReplacementNamed(
              context,
              '/verify-pin',
              arguments: {
                'token': token,
                'from': 'login', // Untuk membedakan flow
              },
            );
          }
        }
      } else {
        _showErrorDialog(response['message'] ?? 'Email atau password salah');
      }
    } catch (e) {
      _showErrorDialog(
        'Gagal terhubung ke server. Periksa koneksi internet Anda.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Login Gagal',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Text(
              message,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    // ⭐ PASTIKAN STATUS BAR STYLE TETAP KONSISTEN SAAT WIDGET DI-BUILD ULANG
    // Ini penting untuk kasus ketika user kembali dari halaman lain atau keyboard muncul
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setStatusBarDark();
    });

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // Ini sudah default true
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics:
                  isKeyboardVisible
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SPACER - lebih kecil saat keyboard muncul
                        SizedBox(
                          height:
                              isKeyboardVisible
                                  ? size.height * 0.04
                                  : size.height * 0.08,
                        ),

                        // Header dengan dekorasi subtle
                        Row(
                          children: [
                            // Logo Container dengan gradient subtle
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF1E3A8A).withOpacity(0.08),
                                    const Color(0xFF1E3A8A).withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF1E3A8A,
                                  ).withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 36,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const Spacer(),
                            // Chip kecil untuk branding
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Secure',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Sembunyikan welcome text saat keyboard muncul untuk menghemat space
                        if (!isKeyboardVisible) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Selamat Datang',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.only(right: 40),
                            child: Text(
                              'Kelola keuangan Anda dengan mudah, aman, dan terpercaya.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ] else
                          const SizedBox(height: 20),

                        // Spacer hanya aktif saat keyboard tidak muncul
                        if (!isKeyboardVisible) const Spacer(),

                        // FORM dengan card subtle
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Input Email dengan styling enhanced
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: 'Alamat Email',
                                    labelStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    hintText: 'nama@email.com',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1E3A8A,
                                        ).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.email_outlined,
                                        color: Color(0xFF1E3A8A),
                                        size: 20,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF1E3A8A),
                                        width: 1.5,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFDC2626),
                                        width: 1,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email tidak boleh kosong';
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Input Password dengan styling enhanced
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: 'Kata Sandi',
                                    labelStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1E3A8A,
                                        ).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.lock_outline_rounded,
                                        color: Color(0xFF1E3A8A),
                                        size: 20,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(
                                          () =>
                                              _obscurePassword =
                                                  !_obscurePassword,
                                        );
                                      },
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                          color: Colors.grey.shade600,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF1E3A8A),
                                        width: 1.5,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFDC2626),
                                        width: 1,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Kata sandi tidak boleh kosong';
                                    }
                                    if (value.length < 6) {
                                      return 'Kata sandi minimal 6 karakter';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Lupa Password dengan styling lebih baik
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // Navigasi ke halaman lupa password
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E3A8A),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Lupa Kata Sandi?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: const Color(
                                        0xFF1E3A8A,
                                      ).withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Tombol Login dengan efek elevation
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1E3A8A,
                                      ).withOpacity(0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                      disabledBackgroundColor:
                                          Colors.grey.shade400,
                                    ),
                                    child:
                                        _isLoading
                                            ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'Masuk',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Divider yang lebih elegan
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade300,
                                thickness: 0.5,
                                endIndent: 16,
                              ),
                            ),
                            Text(
                              'atau',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade300,
                                thickness: 0.5,
                                indent: 16,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Tombol Register dengan card style
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Belum punya akun?',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Cara 1: Navigator.push
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const RegisterPage(),
                                    ),
                                  );

                                  // Cara 2: Navigator.pushNamed (jika sudah setup routes)
                                  // Navigator.pushNamed(context, '/register');
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E3A8A),
                                ),
                                child: const Text(
                                  'Daftar Sekarang',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Spacer atau padding bottom
                        if (!isKeyboardVisible) const Spacer(),

                        // Footer dengan styling lebih baik
                        if (!isKeyboardVisible) ...[
                          Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shield_rounded,
                                      size: 14,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Keamanan Terjamin • v1.0.0',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '© 2024 FinanceApp • All Rights Reserved',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}