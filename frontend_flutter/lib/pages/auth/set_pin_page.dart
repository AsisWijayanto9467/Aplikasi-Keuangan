import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/pages/App/dashboard.dart';
import 'package:frontend_flutter/pages/App/initial_balance_page.dart';
import 'package:frontend_flutter/pages/auth/verify_pin_page.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'dart:async';

import 'package:frontend_flutter/services/transaction_service.dart';

class SetPinPage extends StatefulWidget {
  final String token;
  
  const SetPinPage({
    super.key,
    required this.token,
  });

  @override
  State<SetPinPage> createState() => _SetPinPageState();
}

class _SetPinPageState extends State<SetPinPage> {
  // Controllers untuk PIN
  final List<TextEditingController> _pinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  final List<TextEditingController> _confirmPinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _confirmFocusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  
  String _currentPin = '';
  String _currentConfirmPin = '';

  @override
  void initState() {
    super.initState();
    // Listener untuk PIN
    for (var controller in _pinControllers) {
      controller.addListener(_updatePin);
    }
    // Listener untuk Confirm PIN
    for (var controller in _confirmPinControllers) {
      controller.addListener(_updateConfirmPin);
    }
  }

  void _updatePin() {
    setState(() {
      _currentPin = _pinControllers.map((c) => c.text).join();
    });
  }

  void _updateConfirmPin() {
    setState(() {
      _currentConfirmPin = _confirmPinControllers.map((c) => c.text).join();
    });
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
    for (var controller in _confirmPinControllers) {
      controller.removeListener(_updateConfirmPin);
      controller.dispose();
    }
    for (var node in _confirmFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(String value, int index, bool isConfirm) {
    if (value.length == 1) {
      // Move to next field
      if (index < 5) {
        if (isConfirm) {
          FocusScope.of(context).requestFocus(_confirmFocusNodes[index + 1]);
        } else {
          FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
        }
      } else {
        // Last field, unfocus
        if (isConfirm) {
          _confirmFocusNodes[index].unfocus();
        } else {
          _focusNodes[index].unfocus();
        }
      }
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace
      if (isConfirm) {
        FocusScope.of(context).requestFocus(_confirmFocusNodes[index - 1]);
      } else {
        FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      }
    }
  }

  
  Future<void> _handleSetPin() async {
    if (_currentPin.length != 6) {
      _showErrorDialog('PIN harus 6 digit');
      return;
    }

    if (_currentPin != _currentConfirmPin) {
      _showErrorDialog('PIN dan Konfirmasi PIN tidak cocok');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.setPin(
        widget.token,
        _currentPin,
        _currentConfirmPin,
      );

      if (response.containsKey('message') && response['message'] == 'PIN berhasil dibuat') {
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
                      response['message'] ?? "PIN Berhasil Dibuat",
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
          
          // Di dalam SetPinPage, ganti navigasi
          Navigator.pushReplacementNamed(
            context,
            '/verify-pin',
            arguments: {'token': widget.token},
          );
        }
      } else {
        _showErrorDialog(response['message'] ?? 'Gagal membuat PIN');
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
      builder: (ctx) => AlertDialog(
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
              'PIN Gagal',
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
              'OK',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinBox(String value, bool isFilled) {
    return Container(
      width: 52,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFilled ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
          width: isFilled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: isFilled ? const Color(0xFF1E3A8A) : Colors.grey.shade400,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildPinInputField({
    required int index,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isConfirm,
  }) {
    return Container(
      width: 52,
      height: 60,
      alignment: Alignment.center, // ⭐ Tambahkan ini
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: controller.text.isNotEmpty 
              ? const Color(0xFF1E3A8A) 
              : Colors.grey.shade200,
          width: controller.text.isNotEmpty ? 1.5 : 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: isConfirm ? _obscureConfirmPin : _obscurePin,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E3A8A),
          height: 1.0, // ⭐ Tambahkan height untuk vertical alignment
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(bottom: 0), // ⭐ Adjust padding
          isDense: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) => _onPinChanged(value, index, isConfirm),
      ),
    );
  }

  Widget _buildPinSection({
    required String title,
    required String subtitle,
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required bool isConfirm,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onToggleVisibility,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      obscureText ? 'Tampilkan' : 'Sembunyikan',
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
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return _buildPinInputField(
              index: index,
              controller: controllers[index],
              focusNode: focusNodes[index],
              isConfirm: isConfirm,
            );
          }),
        ),
      ],
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
                  'Buat PIN',
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
                    'Buat PIN 6 digit untuk mengamankan akun dan transaksi Anda.',
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
                _buildPinSection(
                  title: 'Masukkan PIN',
                  subtitle: 'PIN akan digunakan untuk setiap transaksi',
                  controllers: _pinControllers,
                  focusNodes: _focusNodes,
                  isConfirm: false,
                  obscureText: _obscurePin,
                  onToggleVisibility: () {
                    setState(() => _obscurePin = !_obscurePin);
                  },
                ),

                const SizedBox(height: 32),

                // Confirm PIN Input Section
                _buildPinSection(
                  title: 'Konfirmasi PIN',
                  subtitle: 'Masukkan ulang PIN Anda',
                  controllers: _confirmPinControllers,
                  focusNodes: _confirmFocusNodes,
                  isConfirm: true,
                  obscureText: _obscureConfirmPin,
                  onToggleVisibility: () {
                    setState(() => _obscureConfirmPin = !_obscureConfirmPin);
                  },
                ),

                const SizedBox(height: 20),

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
                          'Jangan beritahu PIN Anda kepada siapapun, termasuk pihak bank.',
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

                // Tombol Lanjutkan
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withOpacity(
                          _currentPin.length == 6 && _currentConfirmPin.length == 6 ? 0.2 : 0.1,
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
                      onPressed: (_currentPin.length == 6 && _currentConfirmPin.length == 6 && !_isLoading)
                          ? _handleSetPin
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
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Lanjutkan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ],
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