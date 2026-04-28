// lib/pages/App/budgets.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/services/budget_service.dart';
import 'package:frontend_flutter/services/category_service.dart';

class BudgetsPage extends StatefulWidget {
  final String token;

  const BudgetsPage({super.key, required this.token});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  bool _isInitialSetup = false;
  String _errorMessage = '';

  // Data Budget
  Map<String, dynamic>? _budgetOverview;
  List<dynamic> _categories = [];
  List<dynamic> _budgets = [];
  List<dynamic> _transactions = [];
  List<dynamic> _budgetHistory = [];

  // Month & Year
  late int _selectedMonth;
  late int _selectedYear;

  final List<String> _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  // Formatting
  final _currencyFormat = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await Future.wait([
        _checkBudgetOverview(),
        _loadCategories(),
        _loadBudgetHistory(),
      ]);

      // Cek apakah sudah setup budget
      if (_budgetOverview != null &&
          _budgetOverview!['income'] != null &&
          _budgetOverview!['budgets'] != null &&
          (_budgetOverview!['budgets'] as List).isNotEmpty) {
        _isInitialSetup = true;
        await _loadTransactions();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkBudgetOverview() async {
    try {
      final response = await BudgetService.getBudgetOverview(
        token: widget.token,
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _budgetOverview = response['data'];
          _budgets = response['data']['budgets'] ?? [];
        });
      }
    } catch (e) {
      print('❌ Error checking budget overview: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await CategoryService.getExpenseCategories(
        token: widget.token,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _categories = response['data'] ?? [];
        });
      }
    } catch (e) {
      print('❌ Error loading categories: $e');
    }
  }

  Future<void> _loadBudgetHistory() async {
    try {
      final response = await BudgetService.getBudgetHistory(
        token: widget.token,
        limit: 12,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _budgetHistory = response['data'] ?? [];
        });
      }
    } catch (e) {
      print('❌ Error loading budget history: $e');
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final response = await BudgetService.getTransactions(
        token: widget.token,
        month: _selectedMonth,
        year: _selectedYear,
        perPage: 50,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _transactions = response['data']['data'] ?? [];
        });
      }
    } catch (e) {
      print('❌ Error loading transactions: $e');
    }
  }

  Future<void> _changeMonth(int month, int year) async {
    setState(() {
      _selectedMonth = month;
      _selectedYear = year;
      _isLoading = true;
    });

    try {
      await Future.wait([_checkBudgetOverview(), _loadTransactions()]);

      // Cek lagi apakah sudah setup
      if (_budgetOverview != null &&
          _budgetOverview!['income'] != null &&
          _budgetOverview!['budgets'] != null &&
          (_budgetOverview!['budgets'] as List).isNotEmpty) {
        _isInitialSetup = true;
      } else {
        _isInitialSetup = false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSetupBudgetDialog() {
    final incomeController = TextEditingController();
    final budgetControllers = <int, TextEditingController>{};
    bool isSaving = false;
    double totalBudget = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Setup Budget Bulanan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${_months[_selectedMonth - 1]} $_selectedYear',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Input Income
                    Text(
                      'Total Pemasukan Bulanan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: incomeController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Contoh: 5000000',
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E3A8A),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Kategori Budget
                    Text(
                      'Alokasi Budget per Kategori',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // List kategori
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final catId = category['id'];
                          budgetControllers.putIfAbsent(
                            catId,
                            () => TextEditingController(),
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(
                                      index,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(category['name'] ?? ''),
                                    color: _getCategoryColor(index),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    category['name'] ?? 'Kategori',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: TextField(
                                    controller: budgetControllers[catId],
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      double newTotal = 0;
                                      budgetControllers.forEach((key, ctrl) {
                                        newTotal +=
                                            double.tryParse(ctrl.text) ?? 0;
                                      });
                                      setDialogState(() {
                                        totalBudget = newTotal;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      prefixText: 'Rp ',
                                      prefixStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Total Budget vs Income
                    if (incomeController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              totalBudget >
                                      (double.tryParse(incomeController.text) ??
                                          0)
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              totalBudget >
                                      (double.tryParse(incomeController.text) ??
                                          0)
                                  ? Icons.warning_rounded
                                  : Icons.check_circle_rounded,
                              color:
                                  totalBudget >
                                          (double.tryParse(
                                                incomeController.text,
                                              ) ??
                                              0)
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF10B981),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                totalBudget >
                                        (double.tryParse(
                                              incomeController.text,
                                            ) ??
                                            0)
                                    ? 'Total budget melebihi pemasukan!'
                                    : 'Total budget: ${_formatCurrency(totalBudget)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      totalBudget >
                                              (double.tryParse(
                                                    incomeController.text,
                                                  ) ??
                                                  0)
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isSaving
                                ? null
                                : () async {
                                  final income = double.tryParse(
                                    incomeController.text,
                                  );
                                  if (income == null || income <= 0) {
                                    _showSnackBar(
                                      'Masukkan total pemasukan yang valid',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  final budgets = <Map<String, dynamic>>[];
                                  budgetControllers.forEach((catId, ctrl) {
                                    final amount = double.tryParse(ctrl.text);
                                    if (amount != null && amount > 0) {
                                      budgets.add({
                                        'category_id': catId,
                                        'limit_amount': amount,
                                      });
                                    }
                                  });

                                  if (budgets.isEmpty) {
                                    _showSnackBar(
                                      'Minimal 1 kategori harus diisi',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  final totalAllocation = budgets.fold<double>(
                                    0,
                                    (sum, b) => sum + b['limit_amount'],
                                  );
                                  if (totalAllocation > income) {
                                    _showSnackBar(
                                      'Total budget melebihi pemasukan',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);

                                  try {
                                    final response =
                                        await BudgetService.setupMonthlyBudget(
                                          token: widget.token,
                                          totalIncome: income,
                                          month: _selectedMonth,
                                          year: _selectedYear,
                                          budgets: budgets,
                                        );

                                    if (response['success'] == true) {
                                      Navigator.pop(ctx);
                                      _showSnackBar(
                                        response['message'] ??
                                            'Budget berhasil disimpan',
                                      );
                                      await _loadInitialData();
                                    } else {
                                      _showSnackBar(
                                        response['message'] ??
                                            'Gagal setup budget',
                                        isError: true,
                                      );
                                    }
                                  } catch (e) {
                                    _showSnackBar(
                                      'Error: ${e.toString()}',
                                      isError: true,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setDialogState(() => isSaving = false);
                                    }
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child:
                            isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text(
                                  'Simpan Budget',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTransactionDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    int? selectedCategoryId;
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.remove_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Catat Pengeluaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Dropdown Kategori
                    Text(
                      'Kategori',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: InputDecoration(
                        hintText: 'Pilih kategori',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items:
                          _budgets.map<DropdownMenuItem<int>>((budget) {
                            return DropdownMenuItem<int>(
                              value: budget['category_id'],
                              child: Row(
                                children: [
                                  Text(budget['category_name'] ?? ''),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(Sisa: ${_formatCurrency(_parseDouble(budget['remaining_amount'] ?? 0))})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategoryId = value);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Input Amount
                    Text(
                      'Jumlah',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Masukkan jumlah',
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E3A8A),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input Description
                    Text(
                      'Deskripsi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Belanja bulanan',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E3A8A),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date Picker
                    Text(
                      'Tanggal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Current Budget Info
                    if (selectedCategoryId != null)
                      _buildBudgetInfoCard(selectedCategoryId!),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isSaving
                                ? null
                                : () async {
                                  if (selectedCategoryId == null) {
                                    _showSnackBar(
                                      'Pilih kategori terlebih dahulu',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  final amount = double.tryParse(
                                    amountController.text,
                                  );
                                  if (amount == null || amount <= 0) {
                                    _showSnackBar(
                                      'Masukkan jumlah yang valid',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  if (descController.text.trim().isEmpty) {
                                    _showSnackBar(
                                      'Deskripsi tidak boleh kosong',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);

                                  try {
                                    final response =
                                        await BudgetService.addTransaction(
                                          token: widget.token,
                                          categoryId: selectedCategoryId!,
                                          amount: amount,
                                          description:
                                              descController.text.trim(),
                                          date:
                                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                        );

                                    if (response['success'] == true) {
                                      Navigator.pop(ctx);
                                      _showSnackBar(
                                        'Transaksi berhasil dicatat',
                                      );
                                      await _loadInitialData();
                                    } else {
                                      _showSnackBar(
                                        response['message'] ??
                                            'Gagal mencatat transaksi',
                                        isError: true,
                                      );
                                    }
                                  } catch (e) {
                                    _showSnackBar(
                                      'Error: ${e.toString()}',
                                      isError: true,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setDialogState(() => isSaving = false);
                                    }
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child:
                            isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text(
                                  'Simpan Transaksi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditBudgetDialog(Map<String, dynamic> budget) {
    final limitController = TextEditingController(
      text: budget['limit_amount'].toString(),
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                            Icons.edit_rounded,
                            color: Color(0xFF1E3A8A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit Budget: ${budget['category_name']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Limit Budget',
                        prefixText: 'Rp ',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total terpakai: ${_formatCurrency(_parseDouble(budget['total_spent'] ?? 0))}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isSaving
                                ? null
                                : () async {
                                  final newLimit = double.tryParse(
                                    limitController.text,
                                  );
                                  if (newLimit == null || newLimit < 0) {
                                    _showSnackBar(
                                      'Masukkan jumlah yang valid',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);

                                  try {
                                    final response =
                                        await BudgetService.updateBudget(
                                          token: widget.token,
                                          budgetId: budget['id'],
                                          limitAmount: newLimit,
                                        );

                                    if (response['success'] == true) {
                                      Navigator.pop(ctx);
                                      _showSnackBar(
                                        response['message'] ??
                                            'Budget berhasil diupdate',
                                      );
                                      await _checkBudgetOverview();
                                    } else {
                                      _showSnackBar(
                                        response['message'] ?? 'Gagal update',
                                        isError: true,
                                      );
                                    }
                                  } catch (e) {
                                    _showSnackBar(
                                      'Error: ${e.toString()}',
                                      isError: true,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setDialogState(() => isSaving = false);
                                    }
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child:
                            isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTransaction(dynamic transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Hapus Transaksi'),
              ],
            ),
            content: Text(
              'Hapus transaksi "${transaction['description']}" sebesar ${_formatCurrency((transaction['amount'] ?? 0).toDouble())}?',
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
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final response = await BudgetService.deleteTransaction(
          token: widget.token,
          transactionId: transaction['id'],
        );

        if (response['success'] == true) {
          _showSnackBar('Transaksi berhasil dihapus');
          await _loadInitialData();
        } else {
          _showSnackBar(
            response['message'] ?? 'Gagal menghapus',
            isError: true,
          );
        }
      } catch (e) {
        _showSnackBar('Error: ${e.toString()}', isError: true);
      }
    }
  }

  Widget _buildBudgetInfoCard(int categoryId) {
    final budget = _budgets.firstWhere(
      (b) => b['category_id'] == categoryId,
      orElse: () => {},
    );

    if (budget.isEmpty) return const SizedBox();

    final usage = _parseDouble(budget['usage_percentage']); // ✅ sudah benar
    final remaining = _parseDouble(budget['remaining_amount']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBudgetStatusColor(budget['status']).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBudgetStatusColor(budget['status']).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sisa Budget: ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                _formatCurrency(remaining),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getBudgetStatusColor(budget['status']),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${usage.toStringAsFixed(1)}% terpakai',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Color _getBudgetStatusColor(String? status) {
    switch (status) {
      case 'exceeded':
        return const Color(0xFFDC2626);
      case 'danger':
        return const Color(0xFFEF4444);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'moderate':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF10B981);
    }
  }

  IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'makanan':
        return Icons.restaurant_rounded;
      case 'transportasi':
        return Icons.local_gas_station_rounded;
      case 'belanja':
        return Icons.shopping_bag_rounded;
      case 'tagihan':
        return Icons.receipt_long_rounded;
      case 'hiburan':
        return Icons.movie_rounded;
      case 'kesehatan':
        return Icons.local_hospital_rounded;
      case 'pendidikan':
        return Icons.school_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(int index) {
    const colors = [
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF97316),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(_currencyFormat, (Match m) => '${m[1]}.')}';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return _buildLoadingScreen('Memuat data budget...');
    }

    if (_errorMessage.isNotEmpty && _budgetOverview == null) {
      return _buildErrorScreen();
    }

    return CustomScrollView(
      slivers: [
        // Header Section
        SliverToBoxAdapter(child: _buildHeaderSection()),

        // Month Selector
        SliverToBoxAdapter(child: _buildMonthSelector()),

        // Budget Summary
        if (_isInitialSetup && _budgetOverview != null) ...[
          SliverToBoxAdapter(child: _buildBudgetSummary()),
          SliverToBoxAdapter(child: _buildBudgetList()),
          SliverToBoxAdapter(child: _buildDailyRecommendation()),
          SliverToBoxAdapter(child: _buildRecentTransactions()),
        ] else
          SliverToBoxAdapter(child: _buildEmptyBudget()),

        // Budget History
        SliverToBoxAdapter(child: _buildBudgetHistory()),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildLoadingScreen(String message) {
    return SizedBox.expand(
      child: Center(
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
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gagal Memuat Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget Bulanan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Atur keuanganmu dengan bijak',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isInitialSetup)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _showAddTransactionDialog,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              int newMonth = _selectedMonth - 1;
              int newYear = _selectedYear;
              if (newMonth < 1) {
                newMonth = 12;
                newYear--;
              }
              _changeMonth(newMonth, newYear);
            },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${_months[_selectedMonth - 1]} $_selectedYear',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              int newMonth = _selectedMonth + 1;
              int newYear = _selectedYear;
              if (newMonth > 12) {
                newMonth = 1;
                newYear++;
              }
              _changeMonth(newMonth, newYear);
            },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary() {
    final income = _budgetOverview!['income'];
    if (income == null) return const SizedBox();

    // ⭐ UBAH SEMUA .toDouble() MENJADI _parseDouble()
    final totalIncome = _parseDouble(income['total_income']);
    final totalSpent = _parseDouble(income['total_spent']);
    final remaining = _parseDouble(income['remaining_balanced']);
    final usagePercentage = _parseDouble(income['budget_usage_percentage']);
    final dailyRec = _parseDouble(income['daily_recommendation']);
    final todaySpent = _parseDouble(_budgetOverview!['today_spent']);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF2563EB).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ringkasan Budget',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.today_rounded,
                      color: Colors.white70,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Hari ini: ${_formatCurrency(todaySpent)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Pemasukan',
                  totalIncome,
                  Icons.arrow_downward_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryItem(
                  'Terpakai',
                  totalSpent,
                  Icons.arrow_upward_rounded,
                  const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryItem(
                  'Sisa',
                  remaining,
                  Icons.savings_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (usagePercentage / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePercentage >= 90
                    ? const Color(0xFFEF4444)
                    : usagePercentage >= 70
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${usagePercentage.toStringAsFixed(1)}% terpakai',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              Text(
                'Saran harian: ${_formatCurrency(dailyRec)}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Alokasi Budget',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (_budgetOverview!['alerts'] != null &&
                  _budgetOverview!['alerts']['almost_exceeded'] != null &&
                  (_budgetOverview!['alerts']['almost_exceeded'] as List)
                      .isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: Color(0xFFD97706),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Ada budget hampir habis',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...(_budgets.map((budget) {
            final usage = _parseDouble(budget['usage_percentage']);
            final remaining = _parseDouble(budget['remaining_amount']);
            final spent = _parseDouble(budget['total_spent']);
            final limit = _parseDouble(budget['limit_amount']);
            final categoryName = budget['category_name'] ?? 'Kategori';
            final status = budget['status'] ?? 'safe';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getBudgetStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getCategoryIcon(categoryName),
                          color: _getBudgetStatusColor(status),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_formatCurrency(spent)} / ${_formatCurrency(limit)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getBudgetStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${usage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getBudgetStatusColor(status),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showEditBudgetDialog(budget),
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (usage / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getBudgetStatusColor(status),
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sisa ${_formatCurrency(remaining)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (budget['daily_recommendation'] != null)
                        Text(
                          'Max/hari: ${_formatCurrency(_parseDouble(budget['daily_recommendation'] ?? 0))}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          })),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _showSetupBudgetDialog,
              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
              label: const Text(
                'Edit Budget Bulanan',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRecommendation() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rekomendasi Harian',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pengeluaran maksimal hari ini: ${_formatCurrency(_parseDouble(_budgetOverview!['income']?['daily_recommendation'] ?? 0))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Transaksi Terbaru',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (_transactions.isNotEmpty)
                TextButton(
                  onPressed: _showAddTransactionDialog,
                  child: const Text('+ Tambah', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 40,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada transaksi bulan ini',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_transactions.take(5).map((transaction) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.remove_rounded,
                        color: Color(0xFFEF4444),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction['description'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${transaction['category']?['name'] ?? ''} • ${transaction['date'] ?? ''}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '-${_formatCurrency(_parseDouble(transaction['amount'] ?? 0))}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteTransaction(transaction),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }

  Widget _buildEmptyBudget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 48,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Budget',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Setup budget untuk ${_months[_selectedMonth - 1]} $_selectedYear\ndan mulailah mengatur keuanganmu!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showSetupBudgetDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Setup Budget'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetHistory() {
    if (_budgetHistory.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Budget',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          ...(_budgetHistory.map((history) {
            // ⭐ UBAH INI - gunakan _parseDouble
            final usage = _parseDouble(history['budget_usage_percentage']);
            final income = _parseDouble(history['total_income']);
            final spent = _parseDouble(history['total_spent']);
            final remaining = _parseDouble(history['remaining_balanced']);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          remaining >= 0
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      remaining >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color:
                          remaining >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          history['month_label'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Pemasukan: ${_formatCurrency(income)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(spent),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      Text(
                        '${usage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              usage >= 90
                                  ? const Color(0xFFDC2626)
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }
}
