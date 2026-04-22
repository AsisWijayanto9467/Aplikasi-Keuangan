// lib/pages/App/transaction_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ⬅️ TAMBAHKAN IMPORT INI
import 'package:frontend_flutter/services/transaction_service.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends StatefulWidget {
  final String token;

  const TransactionsPage({super.key, required this.token});

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
  String _selectedCategoryId = '';
  String _selectedPaymentMethod = 'cash';
  String _transactionType = 'expense';
  DateTime _selectedDate = DateTime.now();

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

  @override
  void initState() {
    super.initState();
    _setStatusBarDark(); // ⬅️ ATUR STATUS BAR
    _loadInitialData();
  }

  // ⬅️ FUNGSI UNTUK MENGATUR STATUS BAR STYLE (IKON HITAM)
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
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      await Future.wait([
        _loadBalance(),
        _loadCategories(),
      ]);
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
    // TODO: Implement getCategories API di TransactionService
    // Untuk sementara gunakan dummy categories
    setState(() {
      _categories = [
        {'id': '1', 'name': 'Makanan', 'type': 'expense'},
        {'id': '2', 'name': 'Transportasi', 'type': 'expense'},
        {'id': '3', 'name': 'Belanja', 'type': 'expense'},
        {'id': '4', 'name': 'Tagihan', 'type': 'expense'},
        {'id': '5', 'name': 'Hiburan', 'type': 'expense'},
        {'id': '6', 'name': 'Gaji', 'type': 'income'},
        {'id': '7', 'name': 'Bonus', 'type': 'income'},
        {'id': '8', 'name': 'Investasi', 'type': 'income'},
      ];
      // Set default category
      _updateDefaultCategory();
    });
  }

  void _updateDefaultCategory() {
    final filtered = _categories
        .where((c) => c['type'] == _transactionType)
        .toList();
    if (filtered.isNotEmpty) {
      _selectedCategoryId = filtered.first['id'];
    }
  }

  Future<void> _handleCreateTransaction() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final response = await TransactionService.createTransaction(
        token: widget.token,
        categoryId: _selectedCategoryId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        amount: double.parse(_amountController.text.trim()),
        paymentMethod: _selectedPaymentMethod,
        type: _transactionType,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );

      if (mounted) {
        if (response.containsKey('data')) {
          _showSuccessDialog();
          _resetForm();
          await _loadBalance(); // Refresh saldo setelah transaksi
        } else {
          _showErrorDialog(response['message'] ?? 'Gagal menambah transaksi');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_selectedCategoryId.isEmpty) {
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
    return true;
  }

  void _resetForm() {
    _titleController.clear();
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedPaymentMethod = 'cash';
      _selectedDate = DateTime.now();
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 32),
            SizedBox(width: 12),
            Text('Berhasil!', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
          'Transaksi berhasil ditambahkan.',
          style: TextStyle(color: Colors.grey, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
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
              child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
              child: const Icon(Icons.error_outline, color: Colors.white, size: 20),
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 12),
            Text('Error', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
            Icon(icon, color: isSelected ? color : Colors.grey.shade500, size: 20),
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
    final filteredCategories = _categories
        .where((c) => c['type'] == _transactionType)
        .toList();

    if (filteredCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: filteredCategories.map((category) {
            final isSelected = _selectedCategoryId == category['id'];
            final categoryName = category['name'];
            final color = _categoryColors[categoryName] ?? const Color(0xFF64748B);
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryId = category['id'];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
              child: const Icon(Icons.title_rounded, color: Color(0xFF1E3A8A), size: 20),
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
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
              child: const Icon(Icons.payments_rounded, color: Color(0xFF1E3A8A), size: 20),
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
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
              child: const Icon(Icons.description_outlined, color: Color(0xFF1E3A8A), size: 20),
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
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        Row(
          children: methods.map((method) {
            final isSelected = _selectedPaymentMethod == method;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPaymentMethod = method),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E3A8A).withOpacity(0.08) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _paymentIcons[method],
                        color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade500,
                        size: 22,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _paymentLabels[method]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
                  child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF1E3A8A), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down_rounded, color: Colors.grey.shade500),
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
          onPressed: _isLoading || _isLoadingData ? null : _handleCreateTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
            disabledBackgroundColor: Colors.grey.shade400,
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
                    Text('Simpan Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(width: 8),
                    Icon(Icons.save_rounded, size: 20),
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

    // ⬅️ PASTIKAN STATUS BAR TETAP KONSISTEN SAAT WIDGET DI-BUILD ULANG
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setStatusBarDark();
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoadingData
            ? _buildLoadingScreen()
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
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

                    // Saldo Card
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

                    // Form
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