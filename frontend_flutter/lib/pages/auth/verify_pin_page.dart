import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/pages/App/dashboard.dart';
import 'package:frontend_flutter/pages/App/initial_balance_page.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'dart:async';

import 'package:frontend_flutter/services/transaction_service.dart';

class VerifyPinPage extends StatefulWidget {
  final String token;

  const VerifyPinPage({super.key, required this.token});

  @override
  State<VerifyPinPage> createState() => _VerifyPinPageState();
}

class _VerifyPinPageState extends State<VerifyPinPage> {
  // Controllers untuk PIN (hanya 6 digit)
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _obscurePin = true;
  int _attemptCount = 0;
  String _currentPin = '';
  bool _isSubmitting = false; // ⭐ Tambahkan flag untuk mencegah multiple submit

  @override
  void initState() {
    super.initState();
    // Listener untuk PIN
    for (var controller in _pinControllers) {
      controller.addListener(_updatePin);
    }

    // ⭐ Auto focus ke field pertama setelah build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    });
  }

  void _updatePin() {
    final newPin = _pinControllers.map((c) => c.text).join();

    setState(() {
      _currentPin = newPin;
    });

    // ⭐ Auto submit jika PIN sudah 6 digit dan tidak sedang loading/submit
    if (newPin.length == 6 && !_isLoading && !_isSubmitting) {
      // Gunakan Future.microtask untuk menghindari setState selama build
      Future.microtask(() => _handleVerifyPin());
    }
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.removeListener(_updatePin);
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(String value, int index) {
    if (value.length == 1) {
      // Move to next field
      if (index < 5) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        // Last field, unfocus
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  // lib/pages/auth/verify_pin_page.dart
  // Ubah bagian setelah PIN berhasil diverifikasi

  Future<void> _handleVerifyPin() async {
    if (_currentPin.length != 6 || _isLoading || _isSubmitting) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });

    try {
      final response = await AuthService.verifyPin(widget.token, _currentPin);

      if (mounted) {
        if (response['verified'] == true ||
            response['message'] == 'PIN verified successfully') {
          // Success
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
                      response['message'] ?? "PIN Benar",
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
              duration: const Duration(seconds: 1),
            ),
          );

          setState(() {
            _isLoading = false;
            _isSubmitting = false;
          });

          // ⭐ SEBELUM NAVIGASI, CEK STATUS BALANCE DULU
          await _checkBalanceAndNavigate();
        } else {
          _handleWrongPin();
        }
      }
    } catch (e) {
      if (mounted) {
        _handleWrongPin();
      }
    }
  }

  // ⭐ METHOD BARU: Cek balance sebelum navigasi
  Future<void> _checkBalanceAndNavigate() async {
    try {
      print('🔍 Checking balance status before navigation...');

      final balanceResponse = await TransactionService.checkBalance(
        widget.token,
      );
      print('📊 Balance response: $balanceResponse');

      final isInitialized = balanceResponse['initialized'] ?? false;

      if (!mounted) return;

      // Di dalam VerifyPinPage, method _checkBalanceAndNavigate
      if (isInitialized) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
          arguments: {'token': widget.token, 'skipCheckBalance': true},
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/initial-balance',
          (route) => false,
          arguments: {'token': widget.token},
        );
      }
    } catch (e) {
      print('❌ Error checking balance: $e');
      // Jika gagal cek, default ke Dashboard dengan skipCheckBalance
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    DashboardPage(token: widget.token, skipCheckBalance: true),
          ),
          (route) => false,
        );
      }
    }
  }

  void _handleWrongPin() {
    setState(() {
      _attemptCount++;
      _isLoading = false;
      _isSubmitting = false; // ⭐ Reset submitting flag

      // Clear PIN fields
      for (var controller in _pinControllers) {
        controller.clear();
      }

      // Focus back to first field
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_focusNodes[0]);
        }
      });
    });

    // ⭐ Cek batas percobaan
    if (_attemptCount >= 3) {
      _showMaxAttemptsDialog();
    } else {
      _showErrorDialog(
        'PIN yang Anda masukkan salah.\n'
        'Sisa percobaan: ${3 - _attemptCount}',
      );
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
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Verifikasi Gagal',
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

  void _showMaxAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Akun Terkunci',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Text(
              'Anda telah melebihi batas percobaan PIN.\n'
              'Silakan login kembali untuk keamanan.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Kembali ke halaman login
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Kembali ke Login',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  void _clearAllFields() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  // ⭐ Fixed PIN input field dengan posisi center
  Widget _buildPinInputField({
    required int index,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return Container(
      width: 52,
      height: 60,
      alignment: Alignment.center, // ⭐ Center alignment
      decoration: BoxDecoration(
        color:
            focusNode.hasFocus
                ? const Color(0xFF1E3A8A).withOpacity(0.05)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              focusNode.hasFocus
                  ? const Color(0xFF1E3A8A)
                  : (controller.text.isNotEmpty
                      ? const Color(0xFF1E3A8A)
                      : Colors.grey.shade200),
          width:
              focusNode.hasFocus ? 2 : (controller.text.isNotEmpty ? 1.5 : 1),
        ),
        boxShadow:
            focusNode.hasFocus
                ? [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: _obscurePin,
        style: const TextStyle(
          fontSize: 24, // ⭐ Adjusted font size
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E3A8A),
          height: 1.0, // ⭐ Added height for vertical centering
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(bottom: 0), // ⭐ Adjusted padding
          isDense: true,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) => _onPinChanged(value, index),
        onFieldSubmitted: (_) {
          // Handle submit jika perlu
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.06),

                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Optional: navigasi kembali
                        Navigator.pop(context);
                      },
                      child: Container(
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
                            color: const Color(0xFF1E3A8A).withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          size: 36,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    const Spacer(),
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

                const SizedBox(height: 32),

                // Welcome Text
                const Text(
                  'Verifikasi PIN',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(
                    'Masukkan PIN 6 digit Anda untuk melanjutkan.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // PIN Input Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Masukkan PIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            setState(() => _obscurePin = !_obscurePin);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _obscurePin
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _obscurePin ? 'Tampilkan' : 'Sembunyikan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PIN Anda bersifat rahasia dan aman',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 6 Kotak PIN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return _buildPinInputField(
                          index: index,
                          controller: _pinControllers[index],
                          focusNode: _focusNodes[index],
                        );
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Tombol Clear & Sisa Percobaan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_attemptCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sisa: ${3 - _attemptCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_currentPin.isNotEmpty && !_isLoading)
                      TextButton(
                        onPressed: _clearAllFields,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                        ),
                        child: Text(
                          'Hapus Semua',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 32),

                // Info keamanan
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: Color(0xFF1E3A8A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Jangan beritahu PIN Anda kepada siapapun, termasuk pihak kami.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Tombol Verifikasi
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withOpacity(
                          _currentPin.length == 6 && !_isLoading ? 0.2 : 0.1,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          (_currentPin.length == 6 && !_isLoading)
                              ? _handleVerifyPin
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Verifikasi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Lupa PIN
                Center(
                  child: TextButton(
                    onPressed: () {
                      // TODO: Navigasi ke halaman lupa PIN
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur lupa PIN akan segera hadir'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A8A),
                    ),
                    child: Text(
                      'Lupa PIN?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3A8A).withOpacity(0.8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Footer
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
                            'Dilindungi Enkripsi • v1.0.0',
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

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
