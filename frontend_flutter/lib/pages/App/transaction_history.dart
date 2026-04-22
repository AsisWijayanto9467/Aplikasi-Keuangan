// lib/pages/App/transaction_history.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/services/transaction_service.dart';
import 'package:intl/intl.dart';

class TransactionsHistoryPage extends StatefulWidget {
  final String token;

  const TransactionsHistoryPage({
    super.key,
    required this.token,
  });

  @override
  State<TransactionsHistoryPage> createState() => _TransactionsHistoryPageState();
}

class _TransactionsHistoryPageState extends State<TransactionsHistoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;

  // Data
  List<dynamic> _transactions = [];
  List<dynamic> _categories = [];
  double _currentBalance = 0.0;

  // Filter state
  String _selectedType = 'all'; // 'all', 'income', 'expense'
  String _selectedCategoryId = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilterPanel = false;

  // Summary data
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

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

  final Map<String, IconData> _categoryIcons = {
    'Makanan': Icons.restaurant_rounded,
    'Transportasi': Icons.local_gas_station_rounded,
    'Belanja': Icons.shopping_bag_outlined,
    'Tagihan': Icons.receipt_long_rounded,
    'Hiburan': Icons.movie_rounded,
    'Kesehatan': Icons.local_hospital_rounded,
    'Pendidikan': Icons.school_rounded,
    'Gaji': Icons.work_rounded,
    'Bonus': Icons.card_giftcard_rounded,
    'Investasi': Icons.trending_up_rounded,
    'Lainnya': Icons.more_horiz_rounded,
  };

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadBalance(),
        _loadCategories(),
        _loadTransactions(),
      ]);
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    // TODO: Implement getCategories API
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
    });
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
    }

    try {
      final response = await TransactionService.getTransactions(
        token: widget.token,
        type: _selectedType == 'all' ? null : _selectedType,
        page: _currentPage,
      );

      if (mounted) {
        final data = response['data'] ?? [];
        final transactions = data['data'] ?? [];

        // Filter lokal untuk kategori dan tanggal (sementara sampai API support)
        List<dynamic> filteredTransactions = List.from(transactions);
        
        // Filter by category
        if (_selectedCategoryId != 'all') {
          filteredTransactions = filteredTransactions
              .where((t) => t['category']?['id']?.toString() == _selectedCategoryId)
              .toList();
        }

        // Filter by date range
        if (_startDate != null) {
          filteredTransactions = filteredTransactions.where((t) {
            final date = DateTime.tryParse(t['date'] ?? '');
            return date != null && date.isAfter(_startDate!.subtract(const Duration(days: 1)));
          }).toList();
        }
        if (_endDate != null) {
          filteredTransactions = filteredTransactions.where((t) {
            final date = DateTime.tryParse(t['date'] ?? '');
            return date != null && date.isBefore(_endDate!.add(const Duration(days: 1)));
          }).toList();
        }

        setState(() {
          if (refresh) {
            _transactions = filteredTransactions;
          } else {
            _transactions.addAll(filteredTransactions);
          }
          _hasMoreData = data['next_page_url'] != null;
          _calculateSummary();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memuat transaksi');
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadTransactions();
    setState(() => _isLoadingMore = false);
  }

  void _calculateSummary() {
    double income = 0;
    double expense = 0;

    for (var t in _transactions) {
      final amount = _parseDouble(t['amount']);
      if (t['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }

    setState(() {
      _totalIncome = income;
      _totalExpense = expense;
    });
  }

  Future<void> _handleDeleteTransaction(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 12),
            Text('Hapus Transaksi', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
          'Transaksi yang dihapus tidak dapat dikembalikan.',
          style: TextStyle(color: Colors.grey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final response = await TransactionService.deleteTransaction(
        token: widget.token,
        id: id,
      );

      if (mounted) {
        if (response['message'] == 'Transaksi berhasil dihapus') {
          _showSuccessSnackBar('Transaksi berhasil dihapus');
          await _loadBalance();
          await _loadTransactions(refresh: true);
        } else {
          _showErrorSnackBar(response['message'] ?? 'Gagal menghapus transaksi');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Gagal terhubung ke server');
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Filter Transaksi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedType = 'all';
                          _selectedCategoryId = 'all';
                          _startDate = null;
                          _endDate = null;
                        });
                        setState(() {});
                      },
                      child: const Text('Reset'),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type Filter
                      const Text(
                        'Tipe Transaksi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildFilterChip('Semua', 'all', setModalState),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pemasukan', 'income', setModalState),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pengeluaran', 'expense', setModalState),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Category Filter
                      const Text(
                        'Kategori',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCategoryChip('Semua', 'all', setModalState),
                          ..._categories.map((cat) => _buildCategoryChip(
                            cat['name'],
                            cat['id'].toString(),
                            setModalState,
                            cat['type'],
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Date Range
                      const Text(
                        'Rentang Tanggal',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePickerButton(
                              label: 'Dari',
                              date: _startDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() => _startDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDatePickerButton(
                              label: 'Sampai',
                              date: _endDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() => _endDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {});
                            _loadTransactions(refresh: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Text(
                            'Terapkan Filter',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, StateSetter setModalState) {
    final isSelected = _selectedType == value;
    final color = value == 'income' 
        ? const Color(0xFF10B981) 
        : value == 'expense' 
            ? const Color(0xFFEF4444) 
            : const Color(0xFF1E3A8A);

    return GestureDetector(
      onTap: () => setModalState(() => _selectedType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value, StateSetter setModalState, [String? type]) {
    final isSelected = _selectedCategoryId == value;
    final color = value == 'all' 
        ? const Color(0xFF1E3A8A)
        : _categoryColors[label] ?? const Color(0xFF64748B);

    return GestureDetector(
      onTap: () => setModalState(() => _selectedCategoryId = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            if (value != 'all')
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: Colors.grey.shade500, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? DateFormat('dd/MM/yy').format(date) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: date != null ? const Color(0xFF0F172A) : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF34D399)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 6),
                      const Text('Pemasukan', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(_totalIncome),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 6),
                      const Text('Pengeluaran', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(_totalExpense),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    final List<Widget> chips = [];
    
    if (_selectedType != 'all') {
      chips.add(_buildActiveFilterChip(
        _selectedType == 'income' ? 'Pemasukan' : 'Pengeluaran',
        () => setState(() => _selectedType = 'all'),
      ));
    }
    
    if (_selectedCategoryId != 'all') {
      final category = _categories.firstWhere(
        (c) => c['id'].toString() == _selectedCategoryId,
        orElse: () => {'name': 'Kategori'},
      );
      chips.add(_buildActiveFilterChip(
        category['name'],
        () => setState(() => _selectedCategoryId = 'all'),
      ));
    }
    
    if (_startDate != null) {
      chips.add(_buildActiveFilterChip(
        'Dari: ${DateFormat('dd/MM/yy').format(_startDate!)}',
        () => setState(() => _startDate = null),
      ));
    }
    
    if (_endDate != null) {
      chips.add(_buildActiveFilterChip(
        'Sampai: ${DateFormat('dd/MM/yy').format(_endDate!)}',
        () => setState(() => _endDate = null),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1E3A8A)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(dynamic transaction) {
    final isIncome = transaction['type'] == 'income';
    final category = transaction['category'];
    final categoryName = category != null ? category['name'] : 'Lainnya';
    final amount = _parseDouble(transaction['amount']);
    final date = DateTime.tryParse(transaction['date'] ?? '') ?? DateTime.now();
    final color = _categoryColors[categoryName] ?? const Color(0xFF64748B);
    final icon = _categoryIcons[categoryName] ?? Icons.receipt_long_rounded;
    final paymentMethod = transaction['payment_method'] ?? 'cash';

    return Dismissible(
      key: Key(transaction['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Hapus Transaksi?'),
            content: const Text('Transaksi yang dihapus tidak dapat dikembalikan.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _handleDeleteTransaction(transaction['id'].toString());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction['title'] ?? 'Tanpa Judul',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          categoryName,
                          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _paymentIcons[paymentMethod] ?? Icons.money_rounded,
                        size: 10,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _paymentLabels[paymentMethod] ?? paymentMethod,
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${_formatCurrency(amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yy').format(date),
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
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
          const SizedBox(height: 20),
          Text(
            'Memuat transaksi...',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada transaksi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transaksi yang Anda buat akan muncul di sini',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Riwayat Transaksi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      // Filter Button
                      GestureDetector(
                        onTap: _showFilterBottomSheet,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_selectedType != 'all' || _selectedCategoryId != 'all' || _startDate != null || _endDate != null)
                                ? const Color(0xFF1E3A8A).withOpacity(0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_selectedType != 'all' || _selectedCategoryId != 'all' || _startDate != null || _endDate != null)
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.filter_list_rounded,
                                size: 18,
                                color: (_selectedType != 'all' || _selectedCategoryId != 'all' || _startDate != null || _endDate != null)
                                    ? const Color(0xFF1E3A8A)
                                    : Colors.grey.shade600,
                              ),
                              if (_selectedType != 'all' || _selectedCategoryId != 'all' || _startDate != null || _endDate != null)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E3A8A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Saldo
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF1E3A8A).withOpacity(0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Saldo: ',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        Text(
                          _formatCurrency(_currentBalance),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Summary Cards
            if (!_isLoading && _transactions.isNotEmpty) _buildSummaryCards(),
            // Active Filters
            _buildActiveFilters(),
            // Transaction List
            Expanded(
              child: _isLoading && _transactions.isEmpty
                  ? _buildLoadingScreen()
                  : _transactions.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => _loadTransactions(refresh: true),
                          color: const Color(0xFF1E3A8A),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                            itemCount: _transactions.length + (_hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _transactions.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        const Color(0xFF1E3A8A).withOpacity(0.5),
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              return _buildTransactionItem(_transactions[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}