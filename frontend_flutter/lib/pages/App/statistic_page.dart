// lib/pages/App/statistic_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend_flutter/services/transaction_service.dart';
import 'package:intl/intl.dart';

class StatisticsPage extends StatefulWidget {
  final String token;

  const StatisticsPage({super.key, required this.token});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;

  bool _isLoading = true;
  String _selectedPeriod = 'month'; // 'week', 'month', 'year'
  DateTime _selectedDate = DateTime.now();

  // Data statistik
  Map<String, dynamic> _statisticsData = {};
  List<dynamic> _expenseByCategory = [];
  List<dynamic> _incomeByCategory = [];
  List<dynamic> _trendData = [];
  Map<String, dynamic> _summary = {};

  // UI State
  int _touchedBarIndex = -1;
  int _touchedPieIndex = -1;

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
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final response = await TransactionService.getStatistics(
        token: widget.token,
        period: _selectedPeriod,
        year: _selectedDate.year,
        month: _selectedPeriod == 'month' ? _selectedDate.month : null,
      );

      if (mounted) {
        setState(() {
          _statisticsData = response['data'] ?? {};
          _expenseByCategory = _statisticsData['expense_by_category'] ?? [];
          _incomeByCategory = _statisticsData['income_by_category'] ?? [];
          _trendData = _statisticsData['trend_data'] ?? [];
          _summary = _statisticsData['summary'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Gagal memuat data statistik: $e');
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
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
      ),
    );
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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

                // Period selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildPeriodButton('Bulan', 'month'),
                      const SizedBox(width: 10),
                      _buildPeriodButton('Tahun', 'year'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),

                // Date selector
                if (_selectedPeriod == 'month') ...[
                  _buildMonthYearSelector(),
                ] else ...[
                  _buildYearSelector(),
                ],

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

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value);
        },
        child: Container(
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
            ),
          ),
        ),
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
        ),
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
            _buildHeader(),
            _buildSummaryCards(),
            _buildTabBar(),
            Expanded(
              child:
                  _isLoading
                      ? _buildLoadingScreen()
                      : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTrendTab(),
                          _buildExpensePieTab(),
                          _buildIncomePieTab(),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Statistik Keuangan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
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
                            ? '${_months[_selectedDate.month - 1]} ${_selectedDate.year}'
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
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalIncome = (_summary['total_income'] ?? 0.0).toDouble();
    final totalExpense = (_summary['total_expense'] ?? 0.0).toDouble();
    final netCashflow = (_summary['net_cashflow'] ?? 0.0).toDouble();
    final incomePercentage = (_summary['income_percentage'] ?? 0.0).toDouble();
    final expensePercentage =
        (_summary['expense_percentage'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  label: 'Pemasukan',
                  amount: _formatCurrency(totalIncome),
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF10B981),
                  percentage: incomePercentage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  label: 'Pengeluaran',
                  amount: _formatCurrency(totalExpense),
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFEF4444),
                  percentage: expensePercentage,
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
                  netCashflow >= 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  netCashflow >= 0
                      ? const Color(0xFF34D399)
                      : const Color(0xFFF87171),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
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
                    netCashflow >= 0
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
                      _formatCurrency(netCashflow),
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
                    '${netCashflow >= 0 ? 'Surplus' : 'Defisit'}',
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
    required double percentage,
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
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4), // Add padding for better spacing
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF1E3A8A), // Same blue color for active tab
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab, // Make indicator fill the tab
        labelColor: Colors.white, // White text for active tab
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        labelPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 16,
        ), // Equal padding for all tabs
        tabs: const [
          Tab(child: Text('Tren')),
          Tab(child: Text('Pengeluaran')),
          Tab(child: Text('Pemasukan')),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildScrollableBarGroups() {
    final barWidth = _trendData.length > 15 ? 8.0 : 12.0;

    return List.generate(_trendData.length, (index) {
      final data = _trendData[index];
      final income = (data['income'] ?? 0).toDouble();
      final expense = (data['expense'] ?? 0).toDouble();

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: income,
            color:
                _touchedBarIndex == index
                    ? const Color(0xFF10B981)
                    : const Color(0xFF10B981).withOpacity(0.7),
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: expense,
            color:
                _touchedBarIndex == index
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFEF4444).withOpacity(0.7),
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        barsSpace: 2,
      );
    });
  }

  Widget _buildTrendTab() {
    if (_trendData.isEmpty) {
      return _buildEmptyState('Belum ada data tren untuk periode ini');
    }

    // Calculate dynamic sizing based on data length
    final minBarWidth = _trendData.length > 15 ? 40.0 : 60.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
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
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.show_chart_rounded,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Tren Pemasukan & Pengeluaran',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Add scroll hint for mobile
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
                                  Icon(
                                    Icons.swipe,
                                    size: 14,
                                    color: Colors.amber.shade700,
                                  ),
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
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Scrollable chart container
                SizedBox(
                  height: 280,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      // Dynamic width based on number of bars
                      width: _trendData.length * minBarWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 16,
                          bottom: 8,
                        ),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.center,
                            maxY: _getMaxBarValue(),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (
                                  group,
                                  groupIndex,
                                  rod,
                                  rodIndex,
                                ) {
                                  final isIncome = rodIndex == 0;
                                  final value = rod.toY.round();
                                  return BarTooltipItem(
                                    '${isIncome ? 'Pemasukan' : 'Pengeluaran'}\n',
                                    const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _formatCurrency(value.toDouble()),
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
                                  interval: 1, // Show every label
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 &&
                                        value.toInt() < _trendData.length) {
                                      final label =
                                          _trendData[value.toInt()]['label']
                                              .toString();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          label,
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
                                  reservedSize:
                                      60, // Increased for better spacing
                                  interval:
                                      _getGridInterval(), // Use the calculated interval
                                  getTitlesWidget: (value, meta) {
                                    // Only show labels at interval points
                                    if (value % _getGridInterval() == 0) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Text(
                                          _formatCompactCurrency(value),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox();
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
                              horizontalInterval: _getGridInterval(),
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.shade200,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _buildScrollableBarGroups(),
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
                    const SizedBox(width: 20),
                    _buildLegendItem('Pengeluaran', const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(_trendData.length, (index) {
      final data = _trendData[index];
      final income = (data['income'] ?? 0).toDouble();
      final expense = (data['expense'] ?? 0).toDouble();

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: income,
            color:
                _touchedBarIndex == index
                    ? const Color(0xFF10B981)
                    : const Color(0xFF10B981).withOpacity(0.7),
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          BarChartRodData(
            toY: expense,
            color:
                _touchedBarIndex == index
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFEF4444).withOpacity(0.7),
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
        barsSpace: 4,
      );
    });
  }

  double _getMaxBarValue() {
    if (_trendData.isEmpty) return 100000.0;

    double maxValue = 0;
    for (var data in _trendData) {
      final income = (data['income'] ?? 0).toDouble();
      final expense = (data['expense'] ?? 0).toDouble();
      if (income > maxValue) maxValue = income;
      if (expense > maxValue) maxValue = expense;
    }

    // Round up to the next nice number
    if (maxValue == 0) return 100000.0;

    // Calculate the magnitude (power of 10)
    final magnitude = _calculateNiceMax(maxValue);
    return magnitude;
  }

  double _calculateNiceMax(double value) {
    if (value <= 0) return 100000.0;

    // Find the order of magnitude
    double orderOfMagnitude = 1;
    while (orderOfMagnitude <= value) {
      orderOfMagnitude *= 10;
    }
    orderOfMagnitude /= 10; // Go back one step

    // Calculate nice intervals
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

    // Add 10% padding for better visualization
    return niceMax * 1.1;
  }

  double _getGridInterval() {
    final maxValue = _getMaxBarValue();

    // Calculate nice intervals (5 divisions)
    double interval = maxValue / 5;

    // Round interval to nice number
    double orderOfMagnitude = 1;
    while (orderOfMagnitude <= interval) {
      orderOfMagnitude *= 10;
    }
    orderOfMagnitude /= 10;

    double niceInterval;
    double normalizedInterval = interval / orderOfMagnitude;

    if (normalizedInterval <= 1) {
      niceInterval = 1 * orderOfMagnitude;
    } else if (normalizedInterval <= 2) {
      niceInterval = 2 * orderOfMagnitude;
    } else if (normalizedInterval <= 2.5) {
      niceInterval = 2.5 * orderOfMagnitude;
    } else if (normalizedInterval <= 5) {
      niceInterval = 5 * orderOfMagnitude;
    } else {
      niceInterval = 10 * orderOfMagnitude;
    }

    return niceInterval;
  }

  Widget _buildExpensePieTab() {
    return _buildPieChartTab(
      data: _expenseByCategory,
      title: 'Pengeluaran per Kategori',
      emptyMessage: 'Belum ada data pengeluaran',
    );
  }

  Widget _buildIncomePieTab() {
    return _buildPieChartTab(
      data: _incomeByCategory,
      title: 'Pemasukan per Kategori',
      emptyMessage: 'Belum ada data pemasukan',
    );
  }

  Widget _buildPieChartTab({
    required List<dynamic> data,
    required String title,
    required String emptyMessage,
  }) {
    if (data.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    final total = data.fold<double>(
      0,
      (sum, item) => sum + (item['amount'] ?? 0).toDouble(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
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
                        Icons.pie_chart_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (response?.touchedSection != null) {
                              _touchedPieIndex =
                                  response!.touchedSection!.touchedSectionIndex;
                            } else {
                              _touchedPieIndex = -1;
                            }
                          });
                        },
                      ),
                      sections: _buildPieSections(data, total),
                      centerSpaceRadius: 50,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Detail Kategori',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                ...data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final amount = (item['amount'] ?? 0).toDouble();
                  final percentage = total > 0 ? (amount / total) * 100 : 0.0;
                  final color = _pieChartColors[index % _pieChartColors.length];

                  return _buildCategoryDetailItem(
                    category: item['category'] ?? 'Lainnya',
                    amount: amount,
                    percentage: percentage,
                    color: color,
                    isHighlighted: _touchedPieIndex == index,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    List<dynamic> data,
    double total,
  ) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final amount = (item['amount'] ?? 0.0).toDouble();
      final percentage = (amount / total) * 100;
      final color = _pieChartColors[index % _pieChartColors.length];

      return PieChartSectionData(
        color: color,
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: _touchedPieIndex == index ? 60 : 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget:
            _touchedPieIndex == index
                ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(Icons.circle, color: color, size: 12),
                )
                : null,
        badgePositionPercentageOffset: 80,
      );
    }).toList();
  }

  Widget _buildCategoryDetailItem({
    required String category,
    required double amount,
    required double percentage,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border:
            isHighlighted ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      _formatCurrency(amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            'Memuat data statistik...',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
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
              Icons.pie_chart_outline_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
