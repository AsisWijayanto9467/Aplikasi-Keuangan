// lib/layouts/main_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ⭐ IMPORT HALAMAN-HALAMAN YANG DIBUTUHKAN
import 'package:frontend_flutter/pages/App/dashboard.dart';
import 'package:frontend_flutter/pages/App/statistic_page.dart';
import 'package:frontend_flutter/pages/App/transaction_page.dart';
import 'package:frontend_flutter/pages/App/budgets.dart';
import 'package:frontend_flutter/pages/App/transaction_history.dart';

// ⭐ CUSTOM PAGE ROUTE DENGAN SLIDE TRANSITION
class SlideRightRoute extends PageRouteBuilder {
  final Widget page;

  SlideRightRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0); // Mulai dari kanan
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300), // Durasi animasi
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

// ⭐ CUSTOM PAGE ROUTE DENGAN SLIDE DARI KIRI (UNTUK BACK)
class SlideLeftRoute extends PageRouteBuilder {
  final Widget page;

  SlideLeftRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0); // Mulai dari kiri
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

// ⭐ CUSTOM PAGE ROUTE DENGAN FADE + SCALE (UNTUK ADD BUTTON)
class ScaleFadeRoute extends PageRouteBuilder {
  final Widget page;

  ScaleFadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}

class MainLayout extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final Function(int)? onNavigationChanged;
  final bool showBottomNav;
  final String? title;
  final List<Widget>? actions;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final String? token;

  const MainLayout({
    super.key,
    required this.child,
    this.currentIndex = 0,
    this.onNavigationChanged,
    this.showBottomNav = true,
    this.title,
    this.actions,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
    this.appBar,
    this.token,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;
  int _previousIndex = 0; // ⭐ Simpan index sebelumnya untuk menentukan arah slide

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
    _previousIndex = widget.currentIndex;
    _setStatusBarStyle();
  }

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      setState(() {
        _previousIndex = _selectedIndex;
        _selectedIndex = widget.currentIndex;
      });
    }
  }

  void _setStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  void _onItemTapped(int index) {
    // ⭐ Jangan lakukan apa-apa jika index sama dengan current
    if (index == _selectedIndex) {
      print('ℹ️ Already on page index: $index');
      return;
    }

    // ⭐ Simpan index sebelumnya
    _previousIndex = _selectedIndex;
    
    setState(() {
      _selectedIndex = index;
    });

    if (widget.onNavigationChanged != null) {
      widget.onNavigationChanged!(index);
    } else {
      _handleDefaultNavigation(index);
    }
  }

  void _handleDefaultNavigation(int index) {
    // ⭐ Cek jika token tidak ada, tidak bisa navigasi
    if (widget.token == null || widget.token!.isEmpty) {
      print('⚠️ Token tidak tersedia untuk navigasi');
      return;
    }

    print('🔄 Navigating from $_previousIndex to $index with token: ${widget.token}');

    // ⭐ Tentukan arah slide berdasarkan index
    // Jika index > previousIndex, slide dari kanan ke kiri (push forward)
    // Jika index < previousIndex, slide dari kiri ke kanan (push back)
    final bool isForward = index > _previousIndex;

    switch (index) {
      case 0:
        // Navigasi ke Dashboard
        if (isForward) {
          Navigator.pushReplacement(
            context,
            SlideRightRoute(page: DashboardPage(
              token: widget.token!,
              skipCheckBalance: true,
            )),
          );
        } else {
          Navigator.pushReplacement(
            context,
            SlideLeftRoute(page: DashboardPage(
              token: widget.token!,
              skipCheckBalance: true,
            )),
          );
        }
        break;

      case 1:
        // Navigasi ke Statistics
        if (isForward) {
          Navigator.push(
            context,
            SlideRightRoute(page: StatisticsPage(token: widget.token!)),
          );
        } else {
          Navigator.push(
            context,
            SlideLeftRoute(page: StatisticsPage(token: widget.token!)),
          );
        }
        break;

      case 2:
        // Navigasi ke TransactionsPage (Add Transaction) - gunakan animasi scale+fade
        Navigator.push(
          context,
          ScaleFadeRoute(page: TransactionsPage(token: widget.token!)),
        );
        break;

      case 3:
        // Navigasi ke Budgets
        if (isForward) {
          Navigator.push(
            context,
            SlideRightRoute(page: Budgets(token: widget.token!)),
          );
        } else {
          Navigator.push(
            context,
            SlideLeftRoute(page: Budgets(token: widget.token!)),
          );
        }
        break;

      case 4:
        // Navigasi ke TransactionsHistoryPage
        if (isForward) {
          Navigator.push(
            context,
            SlideRightRoute(page: TransactionsHistoryPage(token: widget.token!)),
          );
        } else {
          Navigator.push(
            context,
            SlideLeftRoute(page: TransactionsHistoryPage(token: widget.token!)),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor ?? Colors.grey.shade50,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      appBar: widget.appBar ??
          (widget.title != null
              ? AppBar(
                  title: Text(
                    widget.title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  actions: widget.actions,
                  elevation: 0,
                  backgroundColor: widget.backgroundColor ?? Colors.white,
                  iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
                )
              : null),
      body: widget.child,
      bottomNavigationBar: widget.showBottomNav ? _buildBottomNavigation() : null,
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Beranda',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.pie_chart_rounded,
                label: 'Statistik',
                index: 1,
              ),
              _buildAddButton(),
              _buildNavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Budget',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.history_rounded,
                label: 'Transaksi',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E3A8A).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade400,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}