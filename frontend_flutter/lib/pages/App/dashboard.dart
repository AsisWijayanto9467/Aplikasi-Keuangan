// lib/pages/App/dashboard.dart (Updated)
import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/auth/login_page.dart';
import 'package:frontend_flutter/pages/App/initial_balance_page.dart';
import 'package:frontend_flutter/pages/layouts/main_layout.dart';
import 'package:frontend_flutter/services/auth_service.dart';
import 'package:frontend_flutter/services/transaction_service.dart';

class DashboardPage extends StatefulWidget {
  final String token;
  final bool skipCheckBalance;

  const DashboardPage({
    super.key,
    required this.token,
    this.skipCheckBalance = false,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = false;
  bool _isCheckingBalance = true;
  String _userName = 'Pengguna';
  bool _isBalanceInitialized = true;

  // Data saldo
  double _balance = 0.0;
  double _income = 5750000.00;
  double _expense = 3250000.00;

  // Flag untuk mencegah multiple redirect
  bool _hasNavigated = false;

  // Untuk PageView (geser card)
  final PageController _pageController = PageController();
  int _currentCardIndex = 0;

  // Bulan dan Tahun
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
    _loadUserData();

    if (!widget.skipCheckBalance) {
      _checkInitialBalance();
    } else {
      setState(() {
        _isCheckingBalance = false;
        _isBalanceInitialized = true;
      });
      _loadBalanceDirectly();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _parseBalance(dynamic balanceData) {
    if (balanceData == null) return 0.0;

    if (balanceData is int) {
      return balanceData.toDouble();
    } else if (balanceData is double) {
      return balanceData;
    } else if (balanceData is String) {
      return double.tryParse(balanceData) ?? 0.0;
    } else {
      try {
        return double.parse(balanceData.toString());
      } catch (e) {
        return 0.0;
      }
    }
  }

  Future<void> _loadBalanceDirectly() async {
    try {
      print('📊 Loading balance directly...');
      final response = await TransactionService.checkBalance(widget.token);
      print('📊 Balance response: $response');

      if (mounted) {
        setState(() {
          _balance = _parseBalance(response['balance']);
        });
      }
    } catch (e) {
      print('❌ Error loading balance: $e');
    }
  }

  Future<void> _checkInitialBalance() async {
    if (_hasNavigated) return;

    setState(() => _isCheckingBalance = true);

    const maxRetries = 2;

    for (int i = 0; i < maxRetries; i++) {
      try {
        print('🔄 Checking balance - Attempt ${i + 1}/$maxRetries');

        final response = await TransactionService.checkBalance(widget.token);
        print('📊 Check Balance Response: $response');

        if (!mounted) return;

        final isInitialized = response['initialized'] ?? false;

        if (isInitialized == true) {
          setState(() {
            _isBalanceInitialized = true;
            _balance = _parseBalance(response['balance']);
            _isCheckingBalance = false;
          });
          return;
        }

        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }
      } catch (e) {
        print('❌ Check Balance Error (Attempt ${i + 1}): $e');

        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }
      }
    }

    if (mounted && !_hasNavigated) {
      setState(() {
        _isCheckingBalance = false;
        _isBalanceInitialized = false;
      });

      _hasNavigated = true;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InitialBalancePage(token: widget.token),
        ),
      );
    }
  }

  Future<void> _loadUserData() async {
    try {
      print('🔍 Fetching user data with token: ${widget.token}');
      final response = await AuthService.getUser(widget.token);
      print('📊 User Data Response: $response');

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        print('✅ User data loaded: ${userData['name']}');

        if (mounted) {
          setState(() {
            _userName = userData['name'] ?? 'Pengguna';
          });
        }
      } else {
        print('❌ Failed to load user data: ${response['message']}');
        setState(() {
          _userName = 'Pengguna';
        });
      }
    } catch (e) {
      print('❌ Load User Data Error: $e');
      setState(() {
        _userName = 'Pengguna';
      });
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  const Expanded(
                    child: Text(
                      "Logout Berhasil",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );

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
      builder: (ctx) => AlertDialog(
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
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(
          context,
          '/dashboard',
          arguments: {'token': widget.token},
        );
        break;
      case 1:
        Navigator.pushNamed(
          context,
          '/statistic',
          arguments: {'token': widget.token},
        );
        break;
      case 2:
        Navigator.pushNamed(
          context,
          '/add-transaction',
          arguments: {'token': widget.token},
        );
        break;
      case 3:
        Navigator.pushNamed(
          context,
          '/budgets',
          arguments: {'token': widget.token},
        );
        break;
      case 4:
        Navigator.pushNamed(
          context,
          '/transaction-history',
          arguments: {'token': widget.token},
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingBalance) {
      return _buildLoadingScreen('Memeriksa data...');
    }

    if (!_isBalanceInitialized) {
      return _buildLoadingScreen('Menyiapkan akun Anda...');
    }

    return MainLayout(
      currentIndex: 0,
      onNavigationChanged: _handleNavigation,
      showBottomNav: true,
      token: widget.token, // ⭐ TAMBAHKAN TOKEN
      child: Column(
        children: [
          // ⭐ BAGIAN ATAS DENGAN BACKGROUND BIRU (FIXED)
          _buildTopBlueSection(),

          // ⭐ FITUR CEPAT (FIXED - TIDAK SCROLL)
          _buildQuickFeatures(),

          // ⭐ TRANSAKSI TERBARU (HEADER FIXED, LIST SCROLLABLE)
          Expanded(child: _buildRecentTransactions()),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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

  // ⭐ BAGIAN ATAS DENGAN BACKGROUND BIRU PENUH
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

  // Update method _buildHeader() di DashboardPage
  Widget _buildHeader() {
    return Row(
      children: [
        // ⭐ KLIK PROFILE AKAN NGE-NAVIGASI KE PROFILE PAGE
        GestureDetector(
          onTap: () {
            // Navigasi ke Profile Page
            Navigator.pushNamed(
              context,
              '/profile',
              arguments: {'token': widget.token},
            );
          },
          child: Row(
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
                    // ⭐ AMBIL HURUF PERTAMA DAN UBAH KE UPPERCASE
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
        ),
        const Spacer(),

        // ⭐ TOMBOL NOTIFIKASI
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: IconButton(
            onPressed: () {
              // Navigasi ke halaman notifikasi (opsional)
              // Navigator.pushNamed(context, '/notifications');
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

        // ⭐ TOMBOL LOGOUT (DIPINDAHKAN KE SINI)
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: IconButton(
            onPressed: _handleLogout,
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
                      _formatCurrency(_income),
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
                      _formatCurrency(_expense),
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
                    color: isPositive
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
                        '${isPositive ? '+' : ''}${_formatCurrency(netCashflow)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isPositive
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    const Text(
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
            _formatCurrency(_balance),
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

  // ⭐ FITUR CEPAT - FIXED (TIDAK SCROLL)
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
                onTap: () {},
              ),
              _buildQuickAction(
                icon: Icons.flag_rounded,
                label: 'Target',
                color: const Color(0xFFF59E0B),
                onTap: () {},
              ),
              _buildQuickAction(
                icon: Icons.cloud_upload_rounded,
                label: 'Upload',
                color: const Color(0xFF10B981),
                onTap: () {},
              ),
              _buildQuickAction(
                icon: Icons.chat_bubble_rounded,
                label: 'AI Chat',
                color: const Color(0xFF8B5CF6),
                onTap: () {},
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

  // ⭐ TRANSAKSI TERBARU - HEADER FIXED, LIST SCROLLABLE
  Widget _buildRecentTransactions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Fixed
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
              TextButton(
                onPressed: () => _handleNavigation(4),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List Scrollable
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildTransactionItem(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Belanja Bulanan',
                  category: 'Belanja',
                  date: 'Hari ini',
                  amount: -350000,
                  iconColor: const Color(0xFFEF4444),
                ),
                _buildTransactionItem(
                  icon: Icons.arrow_downward_rounded,
                  title: 'Transfer Masuk',
                  category: 'Transfer',
                  date: 'Kemarin',
                  amount: 1500000,
                  iconColor: const Color(0xFF10B981),
                ),
                _buildTransactionItem(
                  icon: Icons.receipt_long_rounded,
                  title: 'Tagihan Listrik',
                  category: 'Tagihan',
                  date: '18/4/2026',
                  amount: -450000,
                  iconColor: const Color(0xFFF59E0B),
                ),
                _buildTransactionItem(
                  icon: Icons.restaurant_rounded,
                  title: 'Makan Siang',
                  category: 'Makanan',
                  date: '18/4/2026',
                  amount: -85000,
                  iconColor: const Color(0xFFF97316),
                ),
                _buildTransactionItem(
                  icon: Icons.local_gas_station_rounded,
                  title: 'Bensin',
                  category: 'Transportasi',
                  date: '17/4/2026',
                  amount: -200000,
                  iconColor: const Color(0xFF8B5CF6),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required String title,
    required String category,
    required String date,
    required double amount,
    required Color iconColor,
  }) {
    final bool isIncome = amount > 0;
    return Container(
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
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 10,
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
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isIncome
                  ? const Color(0xFF10B981).withOpacity(0.08)
                  : const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${isIncome ? '+' : '-'}${_formatCurrency(amount.abs())}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isIncome
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}