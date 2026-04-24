// lib/pages/App/budgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/pages/models/budget_model.dart';
import 'package:frontend_flutter/services/budgets_service.dart';
import 'package:intl/intl.dart';

class Budgets extends StatefulWidget {
  final String token;

  const Budgets({
    super.key,
    required this.token,
  });

  @override
  State<Budgets> createState() => _BudgetsState();
}

class _BudgetsState extends State<Budgets>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  List<BudgetModel> _budgets = [];
  BudgetSummary? _summary;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();
    _loadData();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadBudgets(),
      _loadCategories(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadBudgets() async {
    try {
      final now = DateTime.now();
      final response = await BudgetService.checkBudgetStatus(
        token: widget.token,
        month: now.month,
        year: now.year,
      );

      if (response['success'] == true && mounted) {
        final List<dynamic> data = response['data'] ?? [];
        final summaryData = response['summary'] ?? {};

        setState(() {
          _budgets = data.map((item) => BudgetModel.fromJson(item)).toList();
          _summary = BudgetSummary.fromJson(summaryData);
        });
      }
    } catch (e) {
      print('Error loading budgets: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      // Using BudgetService base URL pattern to call categories
      final response = await BudgetService.getBudgets(
        token: widget.token,
        month: DateTime.now().month,
        year: DateTime.now().year,
      );
      
      // We'll load categories from the budgets data itself
      // The backend controller groups by categories with transactions
      if (response['success'] == true && mounted) {
        final List<dynamic> data = response['data'] ?? [];
        final Set<int> seenCategories = {};
        
        setState(() {
          _categories = data
              .where((item) {
                final id = item['category_id'];
                if (seenCategories.contains(id)) return false;
                seenCategories.add(id);
                return true;
              })
              .map((item) => {
                    'id': item['category_id'],
                    'name': item['category_name'] ?? 'Unknown',
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final value = double.parse(amount.toString());
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  String _formatCompactCurrency(dynamic amount) {
    if (amount == null) return '0';
    final value = double.parse(amount.toString());
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}JT';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'exceeded':
        return const Color(0xFFEF4444);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'half':
        return const Color(0xFF3B82F6);
      case 'safe':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'makanan':
      case 'makan':
        return Icons.restaurant_rounded;
      case 'transportasi':
      case 'transport':
        return Icons.directions_car_rounded;
      case 'belanja':
        return Icons.shopping_bag_rounded;
      case 'hiburan':
        return Icons.movie_rounded;
      case 'tagihan':
        return Icons.receipt_long_rounded;
      case 'pendidikan':
        return Icons.school_rounded;
      case 'kesehatan':
        return Icons.local_hospital_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _showCreateBudgetDialog() {
    int? selectedCategoryId;
    String? selectedCategoryName;
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Buat Budget Baru',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tetapkan batas pengeluaran untuk kategori tertentu',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Category Dropdown
              Text(
                'Kategori',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedCategoryId,
                    isExpanded: true,
                    hint: const Text('Pilih kategori'),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: _categories.map<DropdownMenuItem<int>>((category) {
                      return DropdownMenuItem<int>(
                        value: category['id'],
                        child: Row(
                          children: [
                            Icon(
                              _getCategoryIcon(category['name'] ?? ''),
                              size: 18,
                              color: const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 10),
                            Text(category['name'] ?? ''),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedCategoryId = value;
                        selectedCategoryName = _categories
                            .firstWhere((c) => c['id'] == value)['name'];
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Amount Input
              Text(
                'Jumlah Budget',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Contoh: 3000000',
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF1E3A8A),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const Spacer(),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedCategoryId == null || amountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 12),
                              Text('Mohon lengkapi semua field'),
                            ],
                          ),
                          backgroundColor: const Color(0xFFF59E0B),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    await _createBudget(
                      selectedCategoryId!,
                      double.parse(amountController.text),
                      selectedCategoryName ?? 'Unknown',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Buat Budget',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBudget(int categoryId, double amount, String categoryName) async {
    try {
      final now = DateTime.now();
      final response = await BudgetService.createBudget(
        token: widget.token,
        categoryId: categoryId,
        limitAmount: amount,
        month: now.month,
        year: now.year,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Budget $categoryName berhasil dibuat!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          _loadBudgets();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Gagal membuat budget'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _deleteBudget(int budgetId, String categoryName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 12),
            Text('Hapus Budget', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Budget $categoryName akan dihapus, tetapi transaksi yang sudah ada tidak terpengaruh.',
          style: const TextStyle(color: Colors.grey, height: 1.5),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await BudgetService.deleteBudget(
        token: widget.token,
        budgetId: budgetId,
      );

      if (mounted && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Budget $categoryName berhasil dihapus'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        _loadBudgets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showEditBudgetDialog(BudgetModel budget) {
    final amountController = TextEditingController(
      text: budget.limit?.toStringAsFixed(0) ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Edit Budget ${budget.categoryName}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Jumlah Budget Baru',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Contoh: 5000000',
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A8A),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E3A8A),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  if (amountController.text.isEmpty) return;

                  Navigator.pop(ctx);
                  try {
                    final response = await BudgetService.updateBudget(
                      token: widget.token,
                      budgetId: budget.budgetId!,
                      limitAmount: double.parse(amountController.text),
                    );

                    if (mounted && response['success'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Budget berhasil diupdate'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      _loadBudgets();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Update Budget',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    final totalLimit = _summary?.totalLimit ?? 0;
    final totalSpent = _summary?.totalSpent ?? 0;
    final remaining = totalLimit - totalSpent;
    final percentageUsed = totalLimit > 0 ? (totalSpent / totalLimit) * 100 : 0.0;

    // Calculate daily budget
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = lastDay.difference(now).inDays + 1;
    final dailyBudget = daysRemaining > 0 ? remaining / daysRemaining : 0.0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header Section
        SliverToBoxAdapter(child: _buildHeaderSection(percentageUsed)),

        // Summary Cards
        SliverToBoxAdapter(
          child: _buildSummaryCards(totalLimit, totalSpent, remaining, percentageUsed),
        ),

        // Budget Suggestions
        SliverToBoxAdapter(
          child: _buildSuggestionSection(remaining, dailyBudget, daysRemaining),
        ),

        // Budget List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Daftar Budget',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                if (_budgets.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_budgets.length} Budget',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Budget List or Empty State
        _budgets.isEmpty
            ? SliverToBoxAdapter(child: _buildEmptyState())
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildBudgetItem(_budgets[index]),
                    childCount: _budgets.length,
                  ),
                ),
              ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Memuat data budget...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(double percentageUsed) {
    final statusColor = percentageUsed >= 100
        ? const Color(0xFFEF4444)
        : percentageUsed >= 80
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget Bulanan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Kelola pengeluaranmu dengan bijak',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showCreateBudgetDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: Color(0xFF1E3A8A),
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Budget',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_budgets.isNotEmpty) ...[
                const SizedBox(height: 20),
                // Progress indicator in header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${percentageUsed.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'terpakai',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              percentageUsed >= 100
                                  ? 'Melebihi'
                                  : percentageUsed >= 80
                                      ? 'Hampir Habis'
                                      : 'Aman',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (percentageUsed / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    double totalLimit,
    double totalSpent,
    double remaining,
    double percentageUsed,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
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
                    color: const Color(0xFF1E3A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: Color(0xFF1E3A8A),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ringkasan Budget',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (_budgets.isEmpty)
                  Text(
                    'Belum ada budget',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats Row
            Row(
              children: [
                _buildStatItem(
                  'Total Budget',
                  _formatCompactCurrency(totalLimit),
                  const Color(0xFF1E3A8A),
                ),
                _buildStatItem(
                  'Terpakai',
                  _formatCompactCurrency(totalSpent),
                  const Color(0xFFEF4444),
                ),
                _buildStatItem(
                  'Sisa',
                  _formatCompactCurrency(remaining),
                  remaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionSection(
    double remaining,
    double dailyBudget,
    int daysRemaining,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E3A8A).withOpacity(0.04),
              const Color(0xFF2563EB).withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1E3A8A).withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lightbulb_rounded,
                color: Color(0xFF1E3A8A),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saran Budget',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_budgets.isEmpty)
                    Text(
                      'Buat budget agar pengeluaranmu tetap aman sampai akhir bulan ✨',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    )
                  else if (remaining <= 0)
                    Text(
                      'Budget sudah melebihi batas. Kurangi pengeluaran untuk bulan depan! ⚠️',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade400,
                        height: 1.4,
                      ),
                    )
                  else
                    Text(
                      'Sisa ${_formatCompactCurrency(remaining)}, '
                      'kamu bisa spend ${_formatCompactCurrency(dailyBudget)} '
                      'per hari agar cukup sampai akhir bulan (${daysRemaining} hari lagi) 💡',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kamu Belum Punya Budget',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat budget untuk mengontrol pengeluaranmu\ndan pastikan keuangan tetap aman!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateBudgetDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Buat Budget Pertama'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(BudgetModel budget) {
    final limit = budget.limit ?? 0;
    final spent = budget.spent ?? 0;
    final remaining = budget.remaining ?? limit;
    final percentage = budget.percentage ?? 0;
    final statusColor = Color(budget.statusColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(budget.categoryName),
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.categoryName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(limit),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  budget.statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),

          // Amount Details
          Row(
            children: [
              _buildAmountDetail(
                'Terpakai',
                _formatCompactCurrency(spent),
                const Color(0xFFEF4444),
              ),
              const SizedBox(width: 20),
              _buildAmountDetail(
                'Sisa',
                _formatCompactCurrency(remaining),
                remaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 20),
              _buildAmountDetail(
                'Persentase',
                '${percentage.toStringAsFixed(1)}%',
                statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (budget.hasBudget && budget.budgetId != null) ...[
                TextButton.icon(
                  onPressed: () => _showEditBudgetDialog(budget),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteBudget(budget.budgetId!, budget.categoryName),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Hapus'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
              if (!budget.hasBudget) ...[
                TextButton.icon(
                  onPressed: _showCreateBudgetDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Buat Budget'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDetail(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}