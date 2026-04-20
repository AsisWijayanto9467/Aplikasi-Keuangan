// lib/pages/App/initial_balance_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/pages/App/dashboard.dart';
import 'package:frontend_flutter/services/transaction_service.dart';

class InitialBalancePage extends StatefulWidget {
  final String token;

  const InitialBalancePage({super.key, required this.token});

  @override
  State<InitialBalancePage> createState() => _InitialBalancePageState();
}

class _InitialBalancePageState extends State<InitialBalancePage> {
  final TextEditingController _balanceController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isSkipLoading = false;

  String _formattedPreview = 'Rp 0';
  String _rawValue = '';
  
  // Flag untuk mencegah multiple navigation
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    String cleaned = value.replaceAll(RegExp(r'[^\d]'), '');

    _rawValue = cleaned;

    if (cleaned.isEmpty) {
      setState(() {
        _formattedPreview = 'Rp 0';
      });
      return;
    }

    final formatted = _formatRupiah(cleaned);
    setState(() {
      _formattedPreview = formatted;
    });

    // Update controller dengan nilai yang sudah diformat
    _balanceController.value = _balanceController.value.copyWith(
      text: _formatNumberWithDot(cleaned),
      selection: TextSelection.collapsed(
        offset: _formatNumberWithDot(cleaned).length,
      ),
    );
  }

  String _formatNumberWithDot(String value) {
    if (value.isEmpty) return '';

    String reversed = value.split('').reversed.join();
    String formatted = '';

    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        formatted += '.';
      }
      formatted += reversed[i];
    }

    return formatted.split('').reversed.join();
  }

  String _formatRupiah(String value) {
    if (value.isEmpty) return 'Rp 0';

    final formatted = _formatNumberWithDot(value);
    return 'Rp $formatted';
  }

  void _setQuickAmount(int amount) {
    _rawValue = amount.toString();
    final formatted = _formatNumberWithDot(amount.toString());

    _balanceController.text = formatted;
    setState(() {
      _formattedPreview = _formatRupiah(amount.toString());
    });

    _focusNode.requestFocus();
    _balanceController.selection = TextSelection.fromPosition(
      TextPosition(offset: _balanceController.text.length),
    );
  }

  Future<void> _handleSetInitialBalance() async {
    // Prevent double submission
    if (_hasNavigated) return;
    
    final amount = double.tryParse(_rawValue);

    if (amount == null || amount <= 0) {
      _showErrorDialog('Mohon masukkan jumlah saldo yang valid');
      return;
    }

    if (amount < 10000) {
      _showErrorDialog('Saldo minimal adalah Rp 10.000');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('📤 Setting initial balance: $amount');

      final response = await TransactionService.setInitialBalance(
        widget.token,
        amount,
      );

      print('📥 Set balance response: $response');

      if (!mounted) return;

      final isSuccess =
          response['initialized'] == true ||
          response['message']?.toString().contains('berhasil') == true;

      if (isSuccess) {
        // Tampilkan success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Saldo awal berhasil disimpan!')),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        // TUNGGU sebentar untuk memastikan data tersimpan
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted && !_hasNavigated) {
          _hasNavigated = true;

          print('🚀 Navigating to Dashboard...');

          // GUNAKAN pushReplacement agar user tidak bisa kembali ke halaman ini
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardPage(
                token: widget.token,
                skipCheckBalance: true, // ⭐ TAMBAHAN
              ),
            ),
          );
        }
      } else {
        _showErrorDialog('Gagal menyimpan saldo awal');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error setting balance: $e');
      if (mounted) {
        _showErrorDialog(
          'Gagal terhubung ke server. Periksa koneksi internet Anda.',
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSkip() async {
    // Prevent double submission
    if (_hasNavigated) return;
    
    final shouldSkip = await showDialog<bool>(
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
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Konfirmasi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Text(
              'Anda yakin ingin melewati pengaturan saldo awal?\n'
              'Saldo akan diatur ke Rp 0 dan Anda bisa menambahkannya nanti.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text('Ya, Lewati'),
              ),
            ],
          ),
    );

    if (shouldSkip != true) return;

    setState(() => _isSkipLoading = true);

    try {
      print('📤 Setting initial balance to 0 (skip)');

      final response = await TransactionService.setInitialBalance(
        widget.token,
        0,
      );

      print('📥 Skip response: $response');

      if (!mounted) return;

      // TUNGGU sebentar
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_hasNavigated) {
        _hasNavigated = true;

        print('🚀 Navigating to Dashboard after skip...');

        // GUNAKAN pushReplacement
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(token: widget.token),
          ),
        );
      }
    } catch (e) {
      print('❌ Error skipping balance: $e');
      if (mounted) {
        setState(() => _isSkipLoading = false);
        _showErrorDialog('Gagal menyimpan saldo. Silakan coba lagi.');
      }
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
                  'Gagal',
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

  void _clearInput() {
    _balanceController.clear();
    _rawValue = '';
    setState(() {
      _formattedPreview = 'Rp 0';
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Mencegah user kembali ke halaman sebelumnya
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
  
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 32,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
  
                  const SizedBox(height: 24),
  
                  // Title
                  const Text(
                    'Atur Saldo Awal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan jumlah saldo yang Anda miliki saat ini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
  
                  const SizedBox(height: 24),
  
                  // Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E3A8A),
                          const Color(0xFF1E3A8A).withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.wallet_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Saldo Anda',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formattedPreview,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
  
                  const SizedBox(height: 24),
  
                  // Input Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jumlah Saldo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                _focusNode.hasFocus
                                    ? const Color(0xFF1E3A8A)
                                    : Colors.grey.shade200,
                            width: _focusNode.hasFocus ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A).withOpacity(0.05),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Rp',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _balanceController,
                                focusNode: _focusNode,
                                onChanged: _onAmountChanged,
                                keyboardType: TextInputType.number,
                                enabled: !_isLoading && !_isSkipLoading,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Masukkan jumlah',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  suffixIcon:
                                      _rawValue.isNotEmpty
                                          ? GestureDetector(
                                            onTap: _clearInput,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          )
                                          : null,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(15),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
  
                  const SizedBox(height: 16),
  
                  // Quick Amount Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Nominal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.5,
                        children: [
                          _buildQuickAmountButton(50000),
                          _buildQuickAmountButton(100000),
                          _buildQuickAmountButton(500000),
                          _buildQuickAmountButton(1000000),
                          _buildQuickAmountButton(5000000),
                          _buildQuickAmountButton(10000000),
                        ],
                      ),
                    ],
                  ),
  
                  const SizedBox(height: 20),
  
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Saldo minimal Rp 10.000',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
  
                  const SizedBox(height: 24),
  
                  // Action Buttons
                  Column(
                    children: [
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              (_rawValue.isNotEmpty &&
                                      !_isLoading &&
                                      !_isSkipLoading)
                                  ? _handleSetInitialBalance
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
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
                                        'Simpan & Mulai',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                        ),
                      ),
  
                      const SizedBox(height: 12),
  
                      // Skip Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed:
                              (_isLoading || _isSkipLoading) ? null : _handleSkip,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child:
                              _isSkipLoading
                                  ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    'Lewati, mulai dengan saldo Rp 0',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(int amount) {
    final isSelected = _rawValue == amount.toString();

    return GestureDetector(
      onTap:
          (_isLoading || _isSkipLoading) ? null : () => _setQuickAmount(amount),
      child: Container(
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF1E3A8A).withOpacity(0.1)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            _formatRupiah(amount.toString()),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}