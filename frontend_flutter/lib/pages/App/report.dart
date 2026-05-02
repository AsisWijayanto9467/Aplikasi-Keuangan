// lib/pages/App/statistic_report_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend_flutter/pages/App/financial_target_detail.dart';
import 'package:frontend_flutter/pages/App/financial_target_list.dart';
import 'package:frontend_flutter/services/budget_service.dart';
import 'package:frontend_flutter/services/financial_target_service.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:frontend_flutter/services/transaction_service.dart';

class StatisticReportPage extends StatefulWidget {
  final String token;

  const StatisticReportPage({super.key, required this.token});

  @override
  State<StatisticReportPage> createState() => _StatisticReportPageState();
}

class _StatisticReportPageState extends State<StatisticReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true; // ⭐ UBAH JADI true UNTUK LOADING AWAL
  bool _isLocaleInitialized = false;

  // Period state
  String _selectedPeriod = 'month'; // 'week', 'month', 'year'
  DateTime _selectedDate = DateTime.now();

  // UI State
  int _touchedBarIndex = -1;
  int _touchedPieIndex = -1;
  int _selectedTargetFilter = 0; // 0: All, 1: Active, 2: Achieved

  // ⭐ DATA DARI API
  double _totalIncome = 0;
  double _totalExpense = 0;
  List<Map<String, dynamic>> _expenseByCategory = [];
  List<Map<String, dynamic>> _incomeByCategory = [];
  List<Map<String, dynamic>> _trendData = [];
  Map<String, dynamic> _summary = {};

  int _transactionCount = 0;
  Map<String, dynamic>? _budgetData; // Data budget dari API
  bool _isBudgetLoading = true; // Loading state budget
  bool _hasBudget = false; // Apakah budget sudah disetup?
  String _budgetErrorMessage = '';

  List<Map<String, dynamic>> _targetHistory = [];
  bool _isTargetLoading = true;
  String? _targetErrorMessage;

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

  final List<Color> _pieChartColors = [
    const Color(0xFFEF4444), // Red
    const Color(0xFFF97316), // Orange
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF10B981), // Green
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEC4899), // Pink
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF6366F1), // Indigo
    const Color(0xFF14B8A6), // Teal
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setStatusBarDark();
    _initializeLocale();
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocale() async {
    try {
      await initializeDateFormatting('id_ID', null);
      Intl.defaultLocale = 'id_ID';
      if (mounted) {
        setState(() {
          _isLocaleInitialized = true;
        });
      }
    } catch (e) {
      print('❌ Error initializing locale: $e');
      if (mounted) {
        setState(() {
          _isLocaleInitialized = true;
        });
      }
    }
  }

  Future<void> _loadTargetData() async {
    setState(() => _isTargetLoading = true);

    try {
      print('🎯 Loading target data...');

      final targets = await FinancialTargetService.getAllTargets(
        token: widget.token,
      );

      print('🎯 Loaded ${targets.length} targets');

      if (mounted) {
        setState(() {
          _targetHistory =
              targets.map((target) {
                // Mapping field dari backend ke format yang digunakan UI
                return {
                  'id': target['id']?.toString() ?? '',
                  'title': target['title']?.toString() ?? 'Tanpa Judul',
                  'target_amount': _safeToDouble(target['target_amount']),
                  'current_amount': _safeToDouble(target['current_amount']),
                  'deadline': target['target_date']?.toString() ?? '',
                  'status': target['status']?.toString() ?? 'active',
                  'category_icon': FinancialTargetService.getIconForCategory(
                    target['category']?.toString() ?? 'other',
                  ),
                  'category': target['category']?.toString() ?? 'other',
                  'reason': target['reason']?.toString() ?? '',
                  'progress_percentage': _safeToDouble(
                    target['progress_percentage'],
                  ),
                  'remaining_days': target['remaining_days'] ?? 0,
                  'is_overdue': target['is_overdue'] ?? false,
                  'is_completed': target['is_completed'] ?? false,
                };
              }).toList();
          _isTargetLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading targets: $e');
      if (mounted) {
        setState(() {
          _targetErrorMessage = 'Gagal memuat data target';
          _isTargetLoading = false;
        });
      }
    }
  }

  double get _totalBudget {
    if (!_hasBudget || _budgetData == null) return 0;
    final income = _budgetData?['income'];
    // Perbaikan: Pastikan nilai sudah berupa angka sebelum konversi
    final value = income?['total_budget'];
    if (value == null) return 0;
    if (value is String) return double.tryParse(value) ?? 0;
    return (value as num).toDouble();
  }

  double get _totalBudgetSpent {
    if (!_hasBudget || _budgetData == null) return 0;
    final income = _budgetData?['income'];
    final value = income?['total_spent'];
    if (value == null) return 0;
    if (value is String) return double.tryParse(value) ?? 0;
    return (value as num).toDouble();
  }

  double get _remainingBudget {
    if (!_hasBudget || _budgetData == null) return 0;
    final income = _budgetData?['income'];
    final value = income?['remaining_balanced'];
    if (value == null) return 0;
    if (value is String) return double.tryParse(value) ?? 0;
    return (value as num).toDouble();
  }

  double get _budgetUsagePercent {
    if (!_hasBudget || _budgetData == null) return 0;
    final income = _budgetData?['income'];
    final value = income?['budget_usage_percentage'];
    if (value == null) return 0;
    if (value is String) return double.tryParse(value) ?? 0;
    return (value as num).toDouble();
  }

  List<Map<String, dynamic>> get _budgetCategories {
    if (!_hasBudget || _budgetData == null) return [];
    final budgets = _budgetData?['budgets'] as List<dynamic>? ?? [];
    return budgets.map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  Future<void> _loadBudgetData() async {
    setState(() => _isBudgetLoading = true);

    try {
      print('💰 Loading budget data...');

      final response = await BudgetService.getBudgetOverview(
        token: widget.token,
        month: _selectedDate.month,
        year: _selectedDate.year,
      );

      print('💰 Budget response: $response');

      if (mounted) {
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'];

          // Cek apakah income ada (berarti budget sudah disetup)
          if (data['income'] != null) {
            setState(() {
              _budgetData = data;
              _hasBudget = true;
              _isBudgetLoading = false;
            });
            print('✅ Budget data loaded successfully');
          } else {
            setState(() {
              _hasBudget = false;
              _budgetErrorMessage =
                  'Budget untuk ${_months[_selectedDate.month - 1]} ${_selectedDate.year} belum dibuat';
              _isBudgetLoading = false;
            });
          }
        } else {
          setState(() {
            _hasBudget = false;
            _budgetErrorMessage =
                response['message'] ?? 'Budget untuk periode ini belum dibuat';
            _isBudgetLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading budget: $e');
      if (mounted) {
        setState(() {
          _hasBudget = false;
          _budgetErrorMessage = 'Gagal memuat data budget';
          _isBudgetLoading = false;
        });
      }
    }
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value
          .replaceAll(RegExp(r'[^0-9.,-]'), '')
          .replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final response = await TransactionService.getStatistics(
        token: widget.token,
        period: _selectedPeriod,
        year: _selectedDate.year,
        month: _selectedPeriod == 'month' ? _selectedDate.month : null,
      );

      if (mounted && response['data'] != null) {
        final data = response['data'];
        final summary = data['summary'] ?? {};

        final List<dynamic> expenseCategories =
            data['expense_by_category'] ?? [];
        final List<dynamic> incomeCategories = data['income_by_category'] ?? [];
        final List<dynamic> trendDataList = data['trend_data'] ?? [];

        // Di dalam _loadStatistics method, pada bagian setState
        setState(() {
          _summary = Map<String, dynamic>.from(summary);

          // Perbaikan konversi dengan safe conversion
          _totalIncome = _safeToDouble(summary['total_income']);
          _totalExpense = _safeToDouble(summary['total_expense']);

          // Konversi expense by category
          _expenseByCategory =
              expenseCategories.map((item) {
                return {
                  'category': item['category'] ?? 'Lainnya',
                  'amount': _safeToDouble(item['amount']),
                  'icon': item['icon'] ?? '📊',
                  'color': item['color'] ?? '#64748B',
                };
              }).toList();

          // Konversi income by category
          _incomeByCategory =
              incomeCategories.map((item) {
                return {
                  'category': item['category'] ?? 'Lainnya',
                  'amount': _safeToDouble(item['amount']),
                  'icon': item['icon'] ?? '📊',
                  'color': item['color'] ?? '#64748B',
                };
              }).toList();

          // Konversi trend data
          _trendData =
              trendDataList.map((item) {
                return {
                  'label': item['label']?.toString() ?? '',
                  'income': _safeToDouble(item['income']),
                  'expense': _safeToDouble(item['expense']),
                };
              }).toList();

          _transactionCount =
              _incomeByCategory.length + _expenseByCategory.length;
          _isLoading = false;
        });

        await Future.wait([_loadBudgetData(), _loadTargetData()]);
      }
    } catch (e) {
      print('❌ Error loading statistics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Gagal memuat data statistik: $e');
      }
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadStatistics(),
      _loadBudgetData(),
      _loadTargetData(), // ⭐ TAMBAHKAN INI
    ]);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
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
        duration: const Duration(seconds: 4),
      ),
    );
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

  String _formatCurrency(double amount) {
    if (!_isLocaleInitialized) {
      return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    }

    try {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(amount);
    } catch (e) {
      return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    }
  }

  String _formatDate(String dateStr) {
    if (!_isLocaleInitialized) {
      return dateStr;
    }

    try {
      final date = DateTime.tryParse(dateStr);
      if (date == null) return dateStr;
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(0)}JT';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  bool get _isOverBudget {
    if (!_hasBudget || _budgetData == null) return false;
    final income = _budgetData?['income'];
    if (income == null) return false;

    final totalBudget = _safeToDouble(income['total_budget']);
    final totalSpent = _safeToDouble(income['total_spent']);

    return totalSpent > totalBudget;
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pilih Periode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildPeriodButton('Minggu', 'week'),
                      const SizedBox(width: 10),
                      _buildPeriodButton('Bulan', 'month'),
                      const SizedBox(width: 10),
                      _buildPeriodButton('Tahun', 'year'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(), // ⭐ HAPUS KOMA DI SINI, langsung lanjut if
                if (_selectedPeriod == 'week')
                  _buildWeekSelector()
                else if (_selectedPeriod == 'month')
                  _buildMonthYearSelector()
                else
                  _buildYearSelector(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadStatistics();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Terapkan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
    );
  }

  // Ganti method _buildPeriodButton dengan ini
  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value); // ⭐ TAMBAHKAN {}
        },
        child: Container(
          // ⭐ GANTI AnimatedContainer JADI Container
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // GANTI method _buildTransactionChart dengan versi scrollable
  Widget _buildTransactionChart() {
    if (_trendData.isEmpty) return const SizedBox.shrink();

    // ⭐ Hitung lebar minimum per bar
    final minBarWidth = _trendData.length > 15 ? 40.0 : 55.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Diagram Pemasukan & Pengeluaran',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              // ⭐ Tampilkan hint geser jika data > 7
              if (_trendData.length > 7)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Geser',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // ⭐ SCROLLABLE CHART
          SizedBox(
            height: 250,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: _trendData.length * minBarWidth, // ⭐ Dynamic width
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 16, bottom: 8),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.center,
                      maxY: _calculateNiceMax(
                        _trendData.fold<double>(0, (max, item) {
                          final income = (item['income'] as double);
                          final expense = (item['expense'] as double);
                          return income > max
                              ? income
                              : expense > max
                              ? expense
                              : max;
                        }),
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final isIncome = rodIndex == 0;
                            final value = rod.toY;
                            return BarTooltipItem(
                              '${isIncome ? 'Pemasukan' : 'Pengeluaran'}\n',
                              const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                              children: [
                                TextSpan(
                                  text: _formatCurrency(value),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          tooltipHorizontalAlignment:
                              FLHorizontalAlignment.center,
                          tooltipMargin: 8,
                        ),
                        touchCallback: (event, response) {
                          setState(() {
                            if (response?.spot != null) {
                              _touchedBarIndex =
                                  response!.spot!.touchedBarGroupIndex;
                            } else {
                              _touchedBarIndex = -1;
                            }
                          });
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < _trendData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _trendData[value.toInt()]['label']
                                        as String,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            interval:
                                _calculateNiceMax(
                                  _trendData.fold<double>(0, (max, item) {
                                    final income = (item['income'] as double);
                                    final expense = (item['expense'] as double);
                                    return income > max
                                        ? income
                                        : expense > max
                                        ? expense
                                        : max;
                                  }),
                                ) /
                                5,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  _formatCompactCurrency(value),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval:
                            _calculateNiceMax(
                              _trendData.fold<double>(0, (max, item) {
                                final income = (item['income'] as double);
                                final expense = (item['expense'] as double);
                                return income > max
                                    ? income
                                    : expense > max
                                    ? expense
                                    : max;
                              }),
                            ) /
                            5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups:
                          _buildScrollableBarGroups(), // ⭐ GUNAKAN BAR GROUP SCROLLABLE
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Pemasukan', const Color(0xFF10B981)),
              const SizedBox(width: 24),
              _buildLegendItem('Pengeluaran', const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildScrollableBarGroups() {
    final barWidth = _trendData.length > 15 ? 8.0 : 12.0;

    return List.generate(_trendData.length, (index) {
      final data = _trendData[index];
      final income = (data['income'] as double);
      final expense = (data['expense'] as double);

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: income,
            color:
                _touchedBarIndex == index
                    ? const Color(0xFF10B981)
                    : const Color(0xFF10B981).withOpacity(0.7),
            width: barWidth, // ⭐ Dynamic width
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            borderSide:
                _touchedBarIndex == index
                    ? const BorderSide(color: Color(0xFF10B981), width: 2)
                    : BorderSide.none,
          ),
          BarChartRodData(
            toY: expense,
            color:
                _touchedBarIndex == index
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFEF4444).withOpacity(0.7),
            width: barWidth, // ⭐ Dynamic width
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            borderSide:
                _touchedBarIndex == index
                    ? const BorderSide(color: Color(0xFFEF4444), width: 2)
                    : BorderSide.none,
          ),
        ],
        barsSpace: 2,
      );
    });
  }

  Widget _buildWeekSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildYearDropdown(),
          const SizedBox(height: 12),
          _buildDropdownButton<String>(
            value: 'Minggu ke-${(_selectedDate.day / 7).ceil()}',
            items: List.generate(4, (i) => 'Minggu ke-${i + 1}'),
            onChanged: (value) {},
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildDropdownButton<String>(
              value: _months[_selectedDate.month - 1],
              items: _months,
              onChanged: (value) {
                final index = _months.indexOf(value!);
                setState(() {
                  _selectedDate = DateTime(_selectedDate.year, index + 1);
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _buildYearDropdown()),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildYearDropdown(),
    );
  }

  Widget _buildYearDropdown() {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => (currentYear - 2 + i).toString());
    return _buildDropdownButton<String>(
      value: _selectedDate.year.toString(),
      items: years,
      onChanged: (value) {
        setState(() {
          _selectedDate = DateTime(int.parse(value!), _selectedDate.month);
        });
      },
    );
  }

  Widget _buildDropdownButton<T>({
    required T value,
    required List<T> items,
    required Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items:
              items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item.toString()),
                );
              }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setStatusBarDark();
    });

    if (!_isLocaleInitialized) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: _buildLoadingScreen(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child:
                  _isLoading
                      ? _buildLoadingScreen()
                      : RefreshIndicator(
                        onRefresh: _refreshData, // ⭐ GUNAKAN REFRESH DATA
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              _buildSummaryCards(),
                              if (_trendData.isNotEmpty)
                                _buildTransactionChart(),
                              _buildCombinedInfoCard(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    final bool isOverBudget = _isOverBudget;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // ⭐ UBAH DARI CONTAINER BIASA MENJADI GESTUREDETECTOR UNTUK NAVIGASI KE DASHBOARD
              GestureDetector(
                onTap: () {
                  // ⭐ NAVIGASI KE DASHBOARD
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard',
                    (route) => false,
                    arguments: {'token': widget.token},
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.home_rounded, // ⭐ UBAH ICON MENJADI HOME
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Laporan Keuangan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Ringkasan transaksi & budget',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showPeriodPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: const Color(0xFF1E3A8A),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedPeriod == 'month'
                            ? '${_months[_selectedDate.month - 1].substring(0, 3)} ${_selectedDate.year}'
                            : _selectedPeriod == 'week'
                            ? 'Minggu ini'
                            : _selectedDate.year.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Color(0xFF1E3A8A),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isOverBudget) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Budget terlampaui! Pengeluaran melebihi budget yang ditetapkan.',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== SUMMARY CARDS ====================
  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  label: 'Pemasukan',
                  amount: _formatCurrency(_totalIncome),
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF10B981),
                  subtitle: 'Total pemasukan',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  label: 'Pengeluaran',
                  amount: _formatCurrency(_totalExpense),
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFEF4444),
                  subtitle: 'Total pengeluaran',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (_totalIncome - _totalExpense) >= 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  (_totalIncome - _totalExpense) >= 0
                      ? const Color(0xFF34D399)
                      : const Color(0xFFF87171),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: ((_totalIncome - _totalExpense) >= 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444))
                      .withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    (_totalIncome - _totalExpense) >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Net Cashflow',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    Text(
                      _formatCurrency(_totalIncome - _totalExpense),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (_totalIncome - _totalExpense) >= 0 ? 'Surplus' : 'Defisit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String amount,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(_trendData.length, (index) {
      final data = _trendData[index];
      final income = (data['income'] as double);
      final expense = (data['expense'] as double);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: income,
            color:
                _touchedBarIndex == index
                    ? const Color(0xFF10B981)
                    : const Color(0xFF10B981).withOpacity(0.7),
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            borderSide:
                _touchedBarIndex == index
                    ? const BorderSide(color: Color(0xFF10B981), width: 2)
                    : BorderSide.none,
          ),
          BarChartRodData(
            toY: expense,
            color:
                _touchedBarIndex == index
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFEF4444).withOpacity(0.7),
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            borderSide:
                _touchedBarIndex == index
                    ? const BorderSide(color: Color(0xFFEF4444), width: 2)
                    : BorderSide.none,
          ),
        ],
        barsSpace: 4,
      );
    });
  }

  double _calculateNiceMax(double value) {
    if (value <= 0) return 1000000.0;
    double orderOfMagnitude = 1;
    while (orderOfMagnitude <= value) {
      orderOfMagnitude *= 10;
    }
    orderOfMagnitude /= 10;
    double niceMax;
    if (value <= orderOfMagnitude * 1) {
      niceMax = orderOfMagnitude * 1;
    } else if (value <= orderOfMagnitude * 2) {
      niceMax = orderOfMagnitude * 2;
    } else if (value <= orderOfMagnitude * 2.5) {
      niceMax = orderOfMagnitude * 2.5;
    } else if (value <= orderOfMagnitude * 5) {
      niceMax = orderOfMagnitude * 5;
    } else {
      niceMax = orderOfMagnitude * 10;
    }
    return niceMax * 1.1;
  }

  // ==================== COMBINED INFO CARD (TRANSAKSI, BUDGET, TARGET) ====================
  Widget _buildCombinedInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          // Tab Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              labelPadding: const EdgeInsets.symmetric(vertical: 2),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Transaksi'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Budget'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Target'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 420,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionDetailCompact(),
                _buildBudgetSectionCompact(),
                _buildTargetHistoryCompact(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DETAIL TRANSAKSI COMPACT ====================
  Widget _buildTransactionDetailCompact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.08),
                  const Color(0xFF3B82F6).withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Transaksi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(_totalIncome + _totalExpense),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '10 Transaksi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickSummaryPill(
                  label: 'Pemasukan',
                  amount: _formatCurrency(_totalIncome),
                  color: const Color(0xFF10B981),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickSummaryPill(
                  label: 'Pengeluaran',
                  amount: _formatCurrency(_totalExpense),
                  color: const Color(0xFFEF4444),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          _buildTransactionSummaryRow(
            title: 'Pemasukan per Kategori',
            amount: _totalIncome,
            color: const Color(0xFF10B981),
            icon: Icons.arrow_downward_rounded,
            items: _incomeByCategory,
            isExpanded: true,
          ),
          const SizedBox(height: 16),
          const Divider(),
          _buildTransactionSummaryRow(
            title: 'Pengeluaran per Kategori',
            amount: _totalExpense,
            color: const Color(0xFFEF4444),
            icon: Icons.arrow_upward_rounded,
            items: _expenseByCategory,
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSummaryPill({
    required String label,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSummaryRow({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    bool isExpanded = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            Text(
              _formatCurrency(amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        if (isExpanded && items.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...items.map((item) {
            final itemAmount = (item['amount'] as double);
            final percentage = amount > 0 ? (itemAmount / amount) * 100 : 0.0;
            final index = items.indexOf(item);
            final itemColor = _pieChartColors[index % _pieChartColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: itemColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['category'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    _formatCurrency(itemAmount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildBudgetSectionCompact() {
    if (_isBudgetLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
        ),
      );
    }

    if (!_hasBudget) {
      return _buildBudgetNotSetup();
    }

    final budgetUsagePercent = _budgetUsagePercent;
    final isOverBudget = _isOverBudget;
    final statusColor =
        isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final statusText = isOverBudget ? 'Budget Terlampaui' : 'Budget Tersedia';
    final budgetCategories = _budgetCategories;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isOverBudget
                        ? [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)]
                        : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isOverBudget
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFA7F3D0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isOverBudget
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOverBudget
                            ? 'Anda telah melebihi budget sebesar ${_formatCurrency(_totalBudgetSpent - _totalBudget)}'
                            : 'Sisa budget Anda: ${_formatCurrency(_remainingBudget)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Progress bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Penggunaan Budget',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${budgetUsagePercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (budgetUsagePercent / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                isOverBudget
                                    ? [
                                      const Color(0xFFEF4444),
                                      const Color(0xFFF87171),
                                    ]
                                    : [
                                      const Color(0xFFF59E0B),
                                      const Color(0xFFFBBF24),
                                    ],
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    if (isOverBudget)
                      Positioned(
                        right: 0,
                        top: -3,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // ⭐ BAGIAN INI YANG DIGANTI
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isOverBudget
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isOverBudget
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOverBudget
                            ? Icons.error_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 14,
                        color:
                            isOverBudget
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isOverBudget
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF065F46),
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'Terpakai '),
                              TextSpan(
                                text: _formatCurrency(_totalBudgetSpent),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ' dari total '),
                              TextSpan(
                                text: _formatCurrency(_totalBudget),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isOverBudget) ...[
                                const TextSpan(text: '\n'),
                                TextSpan(
                                  text:
                                      'Melebihi budget sebesar ${_formatCurrency(_totalBudgetSpent - _totalBudget)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                const TextSpan(text: '\n'),
                                TextSpan(
                                  text:
                                      'Sisa budget: ${_formatCurrency(_remainingBudget)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ⭐ Budget per kategori (jika ada)
          if (budgetCategories.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Budget per Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            ...budgetCategories.take(5).map((budget) {
              final limitAmount = _safeToDouble(budget['limit_amount']);
              final totalSpent = _safeToDouble(budget['total_spent']);
              final remainingAmount = _safeToDouble(budget['remaining_amount']);
              final usagePercent = _safeToDouble(budget['usage_percentage']);
              final categoryName = budget['category_name'] ?? '';
              final status = budget['status'] ?? 'safe';
              Color itemColor;
              switch (status) {
                case 'exceeded':
                  itemColor = const Color(0xFFEF4444);
                  break;
                case 'danger':
                  itemColor = const Color(0xFFF97316);
                  break;
                case 'warning':
                  itemColor = const Color(0xFFF59E0B);
                  break;
                default:
                  itemColor = const Color(0xFF10B981);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                categoryName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_formatCurrency(totalSpent)} / ${_formatCurrency(limitAmount)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (usagePercent / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                itemColor,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${usagePercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: itemColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 20),

          // Tips card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOverBudget
                        ? 'Tips: Kurangi pengeluaran tidak perlu dan fokus pada kebutuhan prioritas.'
                        : 'Tips: Tetap pertahankan pengeluaran di bawah budget untuk keuangan yang sehat.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⭐ TAMBAHKAN METHOD BARU: Budget Not Setup
  Widget _buildBudgetNotSetup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFFF59E0B),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Budget Belum Dibuat',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Budget untuk ${_months[_selectedDate.month - 1]} ${_selectedDate.year} belum dibuat.\nSilakan atur budget terlebih dahulu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Navigasi ke halaman setup budget
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Navigasi ke halaman setup budget'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Atur Budget'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  foregroundColor: const Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          // Perbaikan: Pastikan amount valid
          Text(
            _formatCompactCurrency(amount.isNaN ? 0 : amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Di _buildTargetHistoryCompact, update filter:
  Widget _buildTargetHistoryCompact() {
    List<Map<String, dynamic>> filteredTargets = _targetHistory;

    if (_selectedTargetFilter == 1) {
      // Filter: Aktif
      filteredTargets =
          _targetHistory.where((t) => t['status'] == 'active').toList();
    } else if (_selectedTargetFilter == 2) {
      // Filter: Tercapai/Completed
      filteredTargets =
          _targetHistory.where((t) => t['status'] == 'completed').toList();
    } else if (_selectedTargetFilter == 3) {
      // Filter: Dibatalkan (optional)
      filteredTargets =
          _targetHistory.where((t) => t['status'] == 'cancelled').toList();
    }

    // ⭐ Handle loading state
    if (_isTargetLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _buildFilterChip('Semua', 0),
              const SizedBox(width: 8),
              _buildFilterChip('Aktif', 1),
              const SizedBox(width: 8),
              _buildFilterChip('Tercapai', 2),
            ],
          ),
        ),
        Expanded(
          child:
              filteredTargets.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 40,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _targetErrorMessage ?? 'Tidak ada target',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTargets.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filteredTargets.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                // ⭐ NAVIGASI KE HALAMAN LIST TARGET
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => FinancialTargetListPage(
                                          token: widget.token,
                                        ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                foregroundColor: const Color(0xFF1E3A8A),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Lihat Semua Target',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, size: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return _buildTargetCard(filteredTargets[index]);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildTargetCard(Map<String, dynamic> target) {
    final targetAmount = _safeToDouble(target['target_amount']);
    final currentAmount = _safeToDouble(target['current_amount']);
    final progress = targetAmount > 0 ? (currentAmount / targetAmount) : 0.0;

    // ⭐ Handle status dari backend
    final status = target['status']?.toString() ?? 'active';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';
    final isOverdue = target['is_overdue'] == true;

    // ⭐ Tentukan warna progress
    Color progressColor;
    if (isCompleted) {
      progressColor = const Color(0xFF10B981);
    } else if (isOverdue) {
      progressColor = const Color(0xFFEF4444);
    } else if (isCancelled) {
      progressColor = const Color(0xFF9E9E9E);
    } else {
      progressColor = const Color(0xFF8B5CF6);
    }

    return GestureDetector(
      onTap: () {
        final targetId = target['id']?.toString();
        if (targetId != null && targetId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => FinancialTargetDetailPage(
                    token: widget.token,
                    targetId: targetId,
                  ),
            ),
          ).then((_) {
            // Refresh data setelah kembali dari detail
            _loadTargetData();
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isCompleted
                    ? const Color(0xFFA7F3D0)
                    : isOverdue
                    ? const Color(0xFFFECACA)
                    : Colors.grey.shade100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  target['category_icon']?.toString() ?? '💰',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              target['title']?.toString() ?? 'Tanpa Judul',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          // ⭐ Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isCompleted
                                      ? const Color(0xFFD1FAE5)
                                      : isOverdue
                                      ? const Color(0xFFFEE2E2)
                                      : isCancelled
                                      ? Colors.grey.shade200
                                      : const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isCompleted
                                  ? '✓ Tercapai'
                                  : isOverdue
                                  ? 'Terlambat'
                                  : isCancelled
                                  ? 'Dibatalkan'
                                  : 'Aktif',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color:
                                    isCompleted
                                        ? const Color(0xFF059669)
                                        : isOverdue
                                        ? const Color(0xFFDC2626)
                                        : isCancelled
                                        ? Colors.grey.shade600
                                        : const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deadline: ${_formatDate(target['deadline']?.toString() ?? '')}',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              isOverdue
                                  ? const Color(0xFFEF4444)
                                  : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // ⭐ Arrow indicator untuk menunjukkan bisa diklik
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatCurrency(currentAmount),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: progressColor,
                            ),
                          ),
                          Text(
                            _formatCurrency(targetAmount),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ),
              ],
            ),
            // ⭐ Tampilkan sisa hari untuk target aktif
            if (status == 'active' && target['remaining_days'] != null) ...[
              const SizedBox(height: 6),
              Text(
                '${target['remaining_days']} hari lagi',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      target['remaining_days'] < 30
                          ? const Color(0xFFF59E0B)
                          : Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== FILTER CHIP & LEGEND ====================
  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedTargetFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTargetFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ==================== LOADING SCREEN ====================
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
            'Memuat laporan keuangan...',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
