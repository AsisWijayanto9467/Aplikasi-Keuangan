// lib/pages/App/transaction_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/services/transaction_service.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? transactionToEdit;
  final Map<String, dynamic>? scanData;

  const TransactionsPage({
    super.key,
    required this.token,
    this.transactionToEdit,
    this.scanData,
  });

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;

  List<dynamic> _categories = [];
  double _currentBalance = 0.0;

  // Form state
  dynamic _selectedCategoryId = '';
  String _selectedPaymentMethod = 'cash';
  String _transactionType = 'expense';
  DateTime _selectedDate = DateTime.now();

  // Untuk mode edit
  bool get _isEditMode => widget.transactionToEdit != null;
  String? _editingTransactionId;

  final Map<String, IconData> _paymentIcons = {
    'cash': Icons.money_rounded,
    'qris': Icons.qr_code_scanner_rounded,
    'transfer': Icons.swap_horiz_rounded,
  };

  final Map<String, String> _paymentLabels = {
    'cash': 'Tunai',
    'qris': 'QRIS',
    'transfer': 'Transfer',
  };

  final Map<String, Color> _categoryColors = {
    'Makanan': const Color(0xFFF97316),
    'Transportasi': const Color(0xFF8B5CF6),
    'Belanja': const Color(0xFFEF4444),
    'Tagihan': const Color(0xFFF59E0B),
    'Hiburan': const Color(0xFFEC4899),
    'Kesehatan': const Color(0xFF10B981),
    'Pendidikan': const Color(0xFF3B82F6),
    'Gaji': const Color(0xFF059669),
    'Bonus': const Color(0xFF6366F1),
    'Investasi': const Color(0xFF14B8A6),
    'Lainnya': const Color(0xFF64748B),
  };

  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();

    if (_isEditMode) {
      _loadTransactionData();
    } else if (widget.scanData != null) {
      // ⬅️ TAMBAHKAN INI: Load data dari scan
      _loadScanData();
    } else {
      _loadInitialData();
    }
  }

  // ⬅️ TAMBAHKAN METHOD BARU
  Future<void> _loadScanData() async {
    setState(() => _isLoadingData = true);
    try {
      final scanData = widget.scanData!;

      // Isi form dengan data hasil scan
      _titleController.text = scanData['title'] ?? '';
      _amountController.text = scanData['amount']?.toString() ?? '';
      _descriptionController.text = scanData['description'] ?? '';
      _transactionType = scanData['type'] ?? 'expense';
      _selectedPaymentMethod = scanData['payment_method'] ?? 'cash';

      // Parse tanggal
      if (scanData['date'] != null) {
        _selectedDate = DateTime.tryParse(scanData['date']) ?? DateTime.now();
      }

      // Load categories dulu
      await _loadCategories();

      // Set kategori dari scan jika ada
      if (scanData['suggested_category_id'] != null &&
          scanData['suggested_category_id'].toString().isNotEmpty) {
        _selectedCategoryId = scanData['suggested_category_id'].toString();
      }

      await _loadBalance();

      // Tampilkan snackbar info
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Data struk berhasil diisi, silakan periksa kembali',
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
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data scan: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _refreshOnResume() async {
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && !_isFirstLoad) {
      // Halaman menjadi aktif kembali, refresh balance
      await _loadBalance();
      if (!_isEditMode) {
        await _loadCategories();
      }
    }
    _isFirstLoad = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshOnResume();
  }

  Future<void> _loadTransactionData() async {
    setState(() => _isLoadingData = true);
    try {
      final transaction = widget.transactionToEdit!;
      _editingTransactionId = transaction['id'].toString();

      _titleController.text = transaction['title'] ?? '';
      _amountController.text = (transaction['amount'] ?? 0).toString();
      _descriptionController.text = transaction['description'] ?? '';
      _transactionType = transaction['type'] ?? 'expense';
      _selectedPaymentMethod = transaction['payment_method'] ?? 'cash';
      _selectedDate =
          DateTime.tryParse(transaction['date'] ?? '') ?? DateTime.now();

      await _loadCategories();

      if (transaction['category'] != null) {
        _selectedCategoryId = transaction['category']['id'].toString();
      }

      await _loadBalance();
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data transaksi: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _setStatusBarDark() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      await Future.wait([_loadBalance(), _loadCategories()]);
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _loadBalance() async {
    try {
      final response = await TransactionService.checkBalance(widget.token);
      if (mounted) {
        setState(() {
          _currentBalance = _parseDouble(response['balance']);
        });
      }
    } catch (e) {
      print('Error loading balance: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await TransactionService.getCategories(widget.token);
      print('=== CATEGORIES LOADED ===');
      print('Raw categories: $categories');

      if (mounted) {
        setState(() {
          _categories = categories;
          if (!_isEditMode) {
            _updateDefaultCategory();
          }
        });
        print('Selected category ID: $_selectedCategoryId');
      }
    } catch (e) {
      print('Error loading categories: $e');
      _showErrorSnackBar('Gagal memuat kategori');
    }
  }

  void _updateDefaultCategory() {
    final filtered =
        _categories.where((c) => c['type'] == _transactionType).toList();
    if (filtered.isNotEmpty && _selectedCategoryId.toString().isEmpty) {
      _selectedCategoryId = filtered.first['id'].toString();
      print('Default category set to: $_selectedCategoryId');
    }
  }

  bool _validateForm() {
    print('=== VALIDATING FORM ===');
    print('Category ID: "$_selectedCategoryId"');
    print('Title: "${_titleController.text.trim()}"');
    print('Amount: "${_amountController.text.trim()}"');

    if (_selectedCategoryId.toString().isEmpty) {
      _showErrorSnackBar('Pilih kategori terlebih dahulu');
      return false;
    }
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Judul transaksi tidak boleh kosong');
      return false;
    }
    if (_amountController.text.trim().isEmpty) {
      _showErrorSnackBar('Jumlah tidak boleh kosong');
      return false;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Jumlah harus lebih dari 0');
      return false;
    }

    print('✅ ALL VALIDATIONS PASSED');
    return true;
  }

  void _showSuccessDialogAndReset(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 32,
                ),
                SizedBox(width: 12),
                Text(
                  'Berhasil!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.grey, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Tutup dialog
                  _resetForm(); // Reset form setelah dialog tertutup
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialogAndPop(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 32,
                ),
                SizedBox(width: 12),
                Text(
                  'Berhasil!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.grey, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Tutup dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Kembali ke halaman history dengan result true
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _handleSaveTransaction() async {
    print('=== BUTTON SAVE CLICKED ===');
    print('Edit Mode: $_isEditMode');
    print('Selected Category ID: $_selectedCategoryId');
    print('Title: ${_titleController.text}');
    print('Amount: ${_amountController.text}');

    if (!_validateForm()) {
      print('❌ VALIDATION FAILED');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);

      Map<String, dynamic> response;

      if (_isEditMode) {
        response = await TransactionService.updateTransaction(
          token: widget.token,
          id: _editingTransactionId!,
          categoryId: _selectedCategoryId.toString(),
          title: _titleController.text.trim(),
          description:
              _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
          amount: amount,
          paymentMethod: _selectedPaymentMethod,
          type: _transactionType,
          date: dateFormatted,
        );
      } else {
        response = await TransactionService.createTransaction(
          token: widget.token,
          categoryId: _selectedCategoryId.toString(),
          title: _titleController.text.trim(),
          description:
              _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
          amount: amount,
          paymentMethod: _selectedPaymentMethod,
          type: _transactionType,
          date: dateFormatted,
        );
      }

      print('API Response: $response');

      if (mounted) {
        if (response.containsKey('data') || response['success'] == true) {
          // Refresh balance setelah transaksi
          await _loadBalance();

          if (_isEditMode) {
            // Mode edit: Kembali ke halaman history
            _showSuccessDialogAndPop(
              _isEditMode
                  ? 'Transaksi berhasil diupdate!'
                  : 'Transaksi berhasil ditambahkan!',
            );
          } else {
            // Mode create: Reset form dan tetap di halaman
            _showSuccessDialogAndReset(
              _isEditMode
                  ? 'Transaksi berhasil diupdate!'
                  : 'Transaksi berhasil ditambahkan!',
            );
          }
        } else {
          _showErrorDialog(response['message'] ?? 'Gagal menyimpan transaksi');
        }
      }
    } catch (e) {
      print('❌ ERROR: $e');
      _showErrorSnackBar('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _titleController.clear();
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedPaymentMethod = 'cash';
      _selectedDate = DateTime.now();
      _transactionType = 'expense';
      _updateDefaultCategory();
    });
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 32,
                ),
                SizedBox(width: 12),
                Text(
                  'Berhasil!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.grey, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Hanya tutup dialog

                  // Untuk mode create, reset form
                  if (!_isEditMode) {
                    _resetForm();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showErrorSnackBar(String message) {
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
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
                SizedBox(width: 12),
                Text('Error', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            content: Text(
              message,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipe Transaksi',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                label: 'Pengeluaran',
                icon: Icons.arrow_upward_rounded,
                isSelected: _transactionType == 'expense',
                color: const Color(0xFFEF4444),
                onTap: () {
                  setState(() {
                    _transactionType = 'expense';
                    _updateDefaultCategory();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeOption(
                label: 'Pemasukan',
                icon: Icons.arrow_downward_rounded,
                isSelected: _transactionType == 'income',
                color: const Color(0xFF10B981),
                onTap: () {
                  setState(() {
                    _transactionType = 'income';
                    _updateDefaultCategory();
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final filteredCategories =
        _categories.where((c) => c['type'] == _transactionType).toList();

    if (filteredCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              filteredCategories.map((category) {
                final isSelected =
                    _selectedCategoryId.toString() == category['id'].toString();
                final categoryName = category['name'];
                final color =
                    _categoryColors[categoryName] ?? const Color(0xFF64748B);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = category['id'].toString();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? color.withOpacity(0.1)
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? color : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Judul Transaksi',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Contoh: Belanja Bulanan',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.title_rounded,
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
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF1E3A8A),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nominal',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.payments_rounded,
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
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF1E3A8A),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deskripsi (Opsional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Tambahkan catatan...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_outlined,
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
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF1E3A8A),
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    final methods = ['cash', 'qris', 'transfer'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Metode Pembayaran',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children:
              methods.map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return Expanded(
                  child: GestureDetector(
                    onTap:
                        () => setState(() => _selectedPaymentMethod = method),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFF1E3A8A).withOpacity(0.08)
                                : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _paymentIcons[method],
                            color:
                                isSelected
                                    ? const Color(0xFF1E3A8A)
                                    : Colors.grey.shade500,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _paymentLabels[method]!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  isSelected
                                      ? const Color(0xFF1E3A8A)
                                      : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tanggal',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF1E3A8A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.2),
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
              _isLoading || _isLoadingData ? null : _handleSaveTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
            disabledBackgroundColor: Colors.grey.shade400,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isEditMode ? 'Update Transaksi' : 'Simpan Transaksi',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isEditMode ? Icons.update_rounded : Icons.save_rounded,
                        size: 20,
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E3A8A).withOpacity(0.08),
                  const Color(0xFF1E3A8A).withOpacity(0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Memuat data...',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setStatusBarDark();
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar:
          _isEditMode
              ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF0F172A),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Edit Transaksi',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
              )
              : null,
      body: SafeArea(
        child:
            _isLoadingData
                ? _buildLoadingScreen()
                : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: _isEditMode ? 0 : 24,
                    bottom: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEditMode) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1E3A8A),
                                    Color(0xFF2563EB),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tambah Transaksi',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Catat pemasukan atau pengeluaran Anda',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Saldo Saat Ini',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(_currentBalance),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildTypeSelector(),
                      const SizedBox(height: 24),
                      _buildCategorySelector(),
                      const SizedBox(height: 24),
                      _buildTitleInput(),
                      const SizedBox(height: 20),
                      _buildAmountInput(),
                      const SizedBox(height: 20),
                      _buildDescriptionInput(),
                      const SizedBox(height: 24),
                      _buildPaymentMethodSelector(),
                      const SizedBox(height: 24),
                      _buildDatePicker(),
                      const SizedBox(height: 32),
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
      ),
    );
  }
}
