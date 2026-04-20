// lib/pages/App/dashboard.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/auth/login_page.dart';
import 'package:frontend_flutter/pages/App/initial_balance_page.dart';
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
  double _income = 0.0;
  double _expense = 0.0;

  // Flag untuk mencegah multiple redirect
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    if (!widget.skipCheckBalance) {
      _checkInitialBalance();
    } else {
      // ⭐ Langsung anggap sudah initialized
      setState(() {
        _isCheckingBalance = false;
        _isBalanceInitialized = true;
      });

      _loadTransactionSummary();
    }
  }

  // ⭐ METHOD UTAMA - Menggabungkan check balance dengan retry logic
  // lib/pages/App/dashboard.dart
  // Ubah bagian _checkInitialBalance

  Future<void> _checkInitialBalance() async {
    if (_hasNavigated) return;

    setState(() => _isCheckingBalance = true);

    // ⭐ Coba cek balance
    const maxRetries = 2; // Kurangi retry untuk mempercepat

    for (int i = 0; i < maxRetries; i++) {
      try {
        print('🔄 Checking balance - Attempt ${i + 1}/$maxRetries');
        print('🔍 Token: ${widget.token.substring(0, 20)}...');

        final response = await TransactionService.checkBalance(widget.token);
        print('📊 Check Balance Response: $response');

        if (!mounted) return;

        final isInitialized = response['initialized'] ?? false;
        final balance = response['balance'] ?? 0.0;

        print('✅ Is Initialized: $isInitialized');
        print('💰 Balance: $balance');

        // ⭐ Jika sudah initialized, tampilkan dashboard
        if (isInitialized == true) {
          setState(() {
            _isBalanceInitialized = true;
            _balance =
                balance is int
                    ? balance.toDouble()
                    : (balance is double ? balance : 0.0);
            _isCheckingBalance = false;
          });
          _loadTransactionSummary();
          return;
        }

        // Jika belum initialized, tunggu sebentar lalu coba lagi
        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }

        // ⭐ Jika masih belum initialized setelah retry
        print('❌ Balance not initialized after $maxRetries attempts');
      } catch (e) {
        print('❌ Check Balance Error (Attempt ${i + 1}): $e');

        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }
      }
    }

    // ⭐ Jika sampai sini berarti balance belum diinisialisasi
    if (mounted && !_hasNavigated) {
      setState(() {
        _isCheckingBalance = false;
        _isBalanceInitialized = false;
      });

      _hasNavigated = true;

      print('🚀 Navigating to InitialBalancePage from Dashboard');

      // ⭐ Gunakan pushReplacement
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
      // TODO: Fetch user data from API
      setState(() {
        _userName = 'John Doe';
      });
    } catch (e) {
      print('Load User Data Error: $e');
    }
  }

  Future<void> _loadTransactionSummary() async {
    try {
      // TODO: Fetch transaction summary from API
      setState(() {
        _income = 5750000.00;
        _expense = 3250000.00;
      });
    } catch (e) {
      print('Load Transaction Summary Error: $e');
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
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
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
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
                borderRadius: BorderRadius.circular(12),
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
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
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

  @override
  Widget build(BuildContext context) {
    // Loading screen saat mengecek saldo
    if (_isCheckingBalance) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Memeriksa data...',
                style: TextStyle(
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

    // Jika saldo belum diinisialisasi, tampilkan loading (akan redirect)
    if (!_isBalanceInitialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Menyiapkan akun Anda...',
                style: TextStyle(
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

    // Tampilan dashboard normal
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Header dengan profil dan notifikasi
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF1E3A8A),
                                width: 2,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFF1E3A8A),
                              child: Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selamat Datang,',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _userName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: Stack(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Color(0xFF1E3A8A),
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Card Saldo Utama
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
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Saldo Utama',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.visibility_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatCurrency(_balance),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildBalanceDetail(
                            icon: Icons.arrow_downward_rounded,
                            label: 'Pemasukan',
                            amount: _income,
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 24),
                          _buildBalanceDetail(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Pengeluaran',
                            amount: _expense,
                            color: const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickAction(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Top Up',
                      onTap: () {},
                    ),
                    _buildQuickAction(
                      icon: Icons.send_rounded,
                      label: 'Transfer',
                      onTap: () {},
                    ),
                    _buildQuickAction(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan',
                      onTap: () {},
                    ),
                    _buildQuickAction(
                      icon: Icons.history_rounded,
                      label: 'History',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Recent Transactions Header
                Row(
                  children: [
                    const Text(
                      'Transaksi Terbaru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                      ),
                      child: const Text(
                        'Lihat Semua',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Transaction List
                _buildTransactionItem(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Belanja Bulanan',
                  date: 'Hari ini',
                  amount: -350000,
                  iconColor: const Color(0xFFEF4444),
                ),
                _buildTransactionItem(
                  icon: Icons.arrow_downward_rounded,
                  title: 'Transfer Masuk',
                  date: 'Kemarin',
                  amount: 1500000,
                  iconColor: const Color(0xFF10B981),
                ),
                _buildTransactionItem(
                  icon: Icons.receipt_long_rounded,
                  title: 'Tagihan Listrik',
                  date: '2 hari lalu',
                  amount: -450000,
                  iconColor: const Color(0xFFF59E0B),
                ),

                const SizedBox(height: 32),

                // Tombol Logout
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 32),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleLogout,
                    icon:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.logout_rounded),
                    label: Text(
                      _isLoading ? 'Memproses...' : 'Logout',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceDetail({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 2),
            Text(
              _formatCurrency(amount),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required String title,
    required String date,
    required double amount,
    required Color iconColor,
  }) {
    final bool isIncome = amount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${_formatCurrency(amount.abs())}',
            style: TextStyle(
              fontSize: 15,
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
