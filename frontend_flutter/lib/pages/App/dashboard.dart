import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/App/chatbot_page.dart';
import 'package:frontend_flutter/pages/App/financial_target_list.dart';
import 'package:frontend_flutter/pages/App/report.dart';
import 'package:frontend_flutter/pages/App/scan_receipt_page.dart';
import 'package:frontend_flutter/pages/auth/login_page.dart';
import 'package:frontend_flutter/pages/App/statistic_page.dart';
import 'package:frontend_flutter/pages/App/transaction_page.dart';
import 'package:frontend_flutter/pages/App/budgets.dart';
import 'package:frontend_flutter/pages/App/transaction_history.dart';
import 'package:frontend_flutter/pages/widgets/bottom_nav_bar.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'package:frontend_flutter/services/transaction_service.dart';
import 'package:frontend_flutter/services/financial_target_service.dart';

class DashboardPage extends StatefulWidget {
  final String token;
  final int initialTabIndex;

  const DashboardPage({
    super.key,
    required this.token,
    this.initialTabIndex = 0,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late int _selectedIndex;
  late List<Widget> _pages;

  // ⭐ KEY UNTUK DASHBOARD CONTENT
  final GlobalKey<_DashboardContentState> _dashboardKey = GlobalKey();

  bool _isLoading = false;
  String _userName = 'Pengguna';

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _initializePages();
    _loadUserData();
  }

  void _initializePages() {
    _pages = [
      // ⭐ GUNAKAN KEY PADA DASHBOARD CONTENT
      DashboardContent(key: _dashboardKey, token: widget.token),
      StatisticsPage(token: widget.token),
      TransactionsPage(token: widget.token),
      BudgetsPage(token: widget.token),
      TransactionsHistoryPage(token: widget.token),
    ];
  }

  Future<void> _loadUserData() async {
    try {
      final response = await AuthService.getUser(widget.token);
      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        if (mounted) {
          setState(() {
            _userName = userData['name'] ?? 'Pengguna';
          });
        }
      }
    } catch (e) {
      print('❌ Load User Data Error: $e');
    }
  }

  // ⭐ METHOD UNTUK HANDLE TAB CHANGE
  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // ⭐ Jika kembali ke tab dashboard (index 0), refresh data
    if (index == 0) {
      _refreshDashboard();
    }
  }

  // ⭐ METHOD UNTUK REFRESH DASHBOARD
  void _refreshDashboard() {
    print('🔄 Refreshing dashboard data...');
    _dashboardKey.currentState?.refreshAllData();
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 28),
                SizedBox(width: 12),
                Text(
                  'Konfirmasi Logout',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari akun?',
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (shouldLogout != true) return;
    setState(() => _isLoading = true);

    try {
      final response = await AuthService.logout(widget.token);
      if (mounted) {
        if (response['message'] == 'Logout berhasil') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        } else {
          _showErrorDialog(response['message'] ?? 'Gagal logout');
        }
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ⭐ HANDLE BACK BUTTON (REFRESH KETIKA KEMBALI DARI HALAMAN LAIN)
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _pages),
            ),
            SafeArea(
              bottom: true,
              top: false,
              child: BottomNavBar(
                currentIndex: _selectedIndex,
                onTap: _onTabChanged, // ⭐ GUNAKAN METHOD BARU
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== DASHBOARD CONTENT (DENGAN AUTO-REFRESH) ====================
class DashboardContent extends StatefulWidget {
  final String token;

  const DashboardContent({super.key, required this.token});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();

  // Data dari API
  double _balance = 0.0;
  double _income = 0.0;
  double _expense = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, dynamic>? _financialSummary;

  int _currentCardIndex = 0;
  String _userName = 'Pengguna';
  bool _isLoadingBalance = true;
  bool _isLoadingTransactions = true;
  bool _isLoadingStats = true;

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

  String get _currentMonthYear {
    final now = DateTime.now();
    return '${_months[now.month - 1]} ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    // ⭐ TAMBAHKAN OBSERVER UNTUK MONITORING APP LIFECYCLE
    WidgetsBinding.instance.addObserver(this);
    _loadAllData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  // ⭐ DETECT KETIKA APP / HALAMAN MENJADI VISIBLE KEMBALI
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App kembali dari background, refresh data
      print('📱 App resumed, refreshing dashboard...');
      refreshAllData();
    }
  }

  // ⭐ PUBLIC METHOD UNTUK REFRESH DARI PARENT
  void refreshAllData() {
    print('🔄 refreshAllData() called');
    _loadAllData();
  }

  // Load semua data dashboard
  Future<void> _loadAllData() async {
    print('📊 Loading all dashboard data...');
    await Future.wait([
      _loadUserData(),
      _loadBalance(),
      _loadStatistics(),
      _loadRecentTransactions(),
      _loadFinancialSummary(),
    ]);
  }

  // ⭐ REFRESH DATA (PULL-TO-REFRESH)
  Future<void> _refreshData() async {
    print('👆 Pull-to-refresh triggered');
    await _loadAllData();
  }

  Future<void> _loadUserData() async {
    try {
      final response = await AuthService.getUser(widget.token);
      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        if (mounted) {
          setState(() {
            _userName = userData['name'] ?? 'Pengguna';
          });
        }
      }
    } catch (e) {
      print('❌ Load User Data Error: $e');
    }
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoadingBalance = true);
    print('💰 Loading balance...');

    try {
      final response = await TransactionService.checkBalance(widget.token);
      print('📊 Balance response: $response');

      if (mounted) {
        double newBalance = 0.0;

        // Handle berbagai format response
        if (response['balance'] != null) {
          final balanceData = response['balance'];
          if (balanceData is int) {
            newBalance = balanceData.toDouble();
          } else if (balanceData is double) {
            newBalance = balanceData;
          } else if (balanceData is String) {
            newBalance = double.tryParse(balanceData) ?? 0.0;
          }
        } else if (response['data'] != null &&
            response['data']['balance'] != null) {
          final balanceData = response['data']['balance'];
          if (balanceData is int) {
            newBalance = balanceData.toDouble();
          } else if (balanceData is double) {
            newBalance = balanceData;
          }
        }

        print('💰 New balance: $newBalance');
        setState(() {
          _balance = newBalance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      print('❌ Error loading balance: $e');
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoadingStats = true);
    print('📈 Loading statistics...');

    try {
      final now = DateTime.now();
      final response = await TransactionService.getStatistics(
        token: widget.token,
        period: 'month',
        year: now.year,
        month: now.month,
      );

      print('📊 Statistics response: $response');

      if (mounted && response['data'] != null) {
        final summary = response['data']['summary'];
        setState(() {
          _income = (summary['total_income'] ?? 0).toDouble();
          _expense = (summary['total_expense'] ?? 0).toDouble();
          _isLoadingStats = false;
        });
        print('📈 Income: $_income, Expense: $_expense');
      }
    } catch (e) {
      print('❌ Error loading statistics: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _loadRecentTransactions() async {
    setState(() => _isLoadingTransactions = true);
    print('📋 Loading recent transactions...');

    try {
      final response = await TransactionService.getTransactions(
        token: widget.token,
        page: 1,
      );

      print('📊 Transactions response received');

      if (mounted && response['data'] != null) {
        final transactions = response['data']['data'] ?? [];
        setState(() {
          _recentTransactions = List<Map<String, dynamic>>.from(
            transactions.take(5), // Ambil 5 transaksi terbaru
          );
          _isLoadingTransactions = false;
        });
        print('📋 Loaded ${_recentTransactions.length} transactions');
      }
    } catch (e) {
      print('❌ Error loading transactions: $e');
      if (mounted) {
        setState(() => _isLoadingTransactions = false);
      }
    }
  }

  Future<void> _loadFinancialSummary() async {
    try {
      print('🎯 Loading financial targets summary...');
      final response = await FinancialTargetService.getSummary(
        token: widget.token,
      );

      if (mounted && response['success'] == true) {
        setState(() {
          _financialSummary = response['data'];
        });
        print('🎯 Financial summary loaded');
      }
    } catch (e) {
      print('❌ Error loading financial summary: $e');
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String _formatRelativeDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Hari ini';
      } else if (difference.inDays == 1) {
        return 'Kemarin';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} hari lalu';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  IconData _getTransactionIcon(String? categoryType, String type) {
    if (type == 'income') {
      return Icons.arrow_downward_rounded;
    }

    switch (categoryType?.toLowerCase()) {
      case 'makanan':
      case 'food':
        return Icons.restaurant_rounded;
      case 'transportasi':
      case 'transport':
        return Icons.directions_car_rounded;
      case 'belanja':
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'tagihan':
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'hiburan':
      case 'entertainment':
        return Icons.movie_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Color _getTransactionColor(String type) {
    return type == 'income' ? const Color(0xFF10B981) : const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBlueSection(),
            _buildQuickFeatures(),
            _buildFinancialTargetSummary(),
            _buildRecentTransactionsHeader(),
            _buildTransactionList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==================== TOP BLUE SECTION ====================
  Widget _buildTopBlueSection() {
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSwipeableCards(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withOpacity(0.15),
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selamat Datang,',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        // Notifikasi
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: IconButton(
            onPressed: () {
              // TODO: Navigate to notifications
            },
            icon: Stack(
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E3A8A),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Logout
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: IconButton(
            onPressed: () {
              final dashboardState =
                  context.findAncestorStateOfType<_DashboardPageState>();
              dashboardState?._handleLogout();
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeableCards() {
    return Column(
      children: [
        SizedBox(
          height: 175,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentCardIndex = index;
              });
            },
            children: [_buildCashflowCard(), _buildTotalBalanceCard()],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDotIndicator(isActive: _currentCardIndex == 0),
            const SizedBox(width: 8),
            _buildDotIndicator(isActive: _currentCardIndex == 1),
          ],
        ),
      ],
    );
  }

  Widget _buildDotIndicator({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // Card 1: Cashflow (data dari API statistics)
  Widget _buildCashflowCard() {
    final double netCashflow = _income - _expense;
    final bool isPositive = netCashflow >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cashflow',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _currentMonthYear,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
              const Spacer(),
              if (_isLoadingStats)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 9,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Pemasukan',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoadingStats ? '...' : _formatCurrency(_income),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 9,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Pengeluaran',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoadingStats ? '...' : _formatCurrency(_expense),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color:
                        isPositive
                            ? const Color(0xFF10B981).withOpacity(0.4)
                            : const Color(0xFFEF4444).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoadingStats
                            ? '...'
                            : '${isPositive ? '+' : ''}${_formatCurrency(netCashflow)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _isLoadingStats
                            ? 'Memuat...'
                            : isPositive
                            ? 'Sisa keuangan positif'
                            : 'Sisa keuangan negatif',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.8),
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
    );
  }

  // Card 2: Total Balance (data dari API balance)
  Widget _buildTotalBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Total Saldo',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 10,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Tersedia',
                      style: TextStyle(fontSize: 9, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isLoadingBalance ? "Memuat..." : _formatCurrency(_balance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white70,
                  size: 11,
                ),
                SizedBox(width: 5),
                Text(
                  'Saldo dapat digunakan untuk transaksi',
                  style: TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== QUICK FEATURES ====================
  Widget _buildQuickFeatures() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey.shade50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fitur Cepat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(
                icon: Icons.description_rounded,
                label: 'Laporan',
                color: const Color(0xFF3B82F6),
                onTap: () {
                  // ⭐ NAVIGASI KE HALAMAN TARGET
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => StatisticReportPage(token: widget.token),
                    ),
                  ).then((_) {
                    refreshAllData();
                  });
                },
              ),
              _buildQuickAction(
                icon: Icons.flag_rounded,
                label: 'Target',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  // ⭐ NAVIGASI KE HALAMAN TARGET
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              FinancialTargetListPage(token: widget.token),
                    ),
                  ).then((_) {
                    // ⭐ REFRESH SAAT KEMBALI
                    refreshAllData();
                  });
                },
              ),
              _buildQuickAction(
                icon: Icons.document_scanner_rounded, // ⬅️ GANTI ICON
                label: 'Scan', // ⬅️ GANTI LABEL
                color: const Color(0xFF10B981),
                onTap: () {
                  // ⬅️ NAVIGASI KE HALAMAN SCAN
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ScanReceiptPage(token: widget.token),
                    ),
                  ).then((_) {
                    // ⬅️ REFRESH SAAT KEMBALI
                    refreshAllData();
                  });
                },
              ),
              _buildQuickAction(
                icon: Icons.chat_bubble_rounded,
                label: 'AI Chat',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  // ⭐ NAVIGASI KE HALAMAN TARGET
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AiChatPage(token: widget.token),
                    ),
                  ).then((_) {
                    // ⭐ REFRESH SAAT KEMBALI
                    refreshAllData();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // UPDATE BAGIAN FINANCIAL TARGET SUMMARY
  Widget _buildFinancialTargetSummary() {
    if (_financialSummary == null ||
        (_financialSummary!['total_active'] == 0 &&
            _financialSummary!['total_completed'] == 0)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.1),
            const Color(0xFFF59E0B).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Target Keuangan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // ⭐ TAMBAHKAN NAVIGASI KE HALAMAN TARGET
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              FinancialTargetListPage(token: widget.token),
                    ),
                  ).then((_) {
                    // ⭐ REFRESH DATA SAAT KEMBALI
                    refreshAllData();
                  });
                },
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTargetStatItem(
                label: 'Aktif',
                value: '${_financialSummary!['total_active'] ?? 0}',
                color: const Color(0xFF10B981),
              ),
              _buildTargetStatItem(
                label: 'Selesai',
                value: '${_financialSummary!['total_completed'] ?? 0}',
                color: const Color(0xFF3B82F6),
              ),
              _buildTargetStatItem(
                label: 'Progress',
                value: '${_financialSummary!['overall_progress'] ?? 0}%',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: color.withOpacity(0.15), width: 1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ==================== RECENT TRANSACTIONS ====================
  Widget _buildRecentTransactionsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Transaksi Terbaru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Pindah ke tab transaksi (index 2)
              final dashboardState =
                  context.findAncestorStateOfType<_DashboardPageState>();
              dashboardState?.setState(() {
                dashboardState._selectedIndex = 2;
              });
            },
            child: const Text(
              'Lihat Semua',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_isLoadingTransactions) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recentTransactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'Belum ada transaksi',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children:
            _recentTransactions.map((transaction) {
              return _buildTransactionItem(transaction);
            }).toList(),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final bool isIncome = transaction['type'] == 'income';
    final double amount =
        double.tryParse(transaction['amount'].toString()) ?? 0;
    final String categoryName = transaction['category']?['name'] ?? 'Lainnya';
    final String title = transaction['title'] ?? 'Transaksi';
    final String date = _formatRelativeDate(transaction['date'] ?? '');
    final IconData icon = _getTransactionIcon(
      categoryName,
      transaction['type'],
    );
    final Color iconColor =
        isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${_formatCurrency(amount.abs())}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}
