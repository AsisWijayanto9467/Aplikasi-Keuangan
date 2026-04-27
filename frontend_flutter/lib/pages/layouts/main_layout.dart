// lib/pages/App/main_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/pages/App/dashboard.dart';
import 'package:frontend_flutter/pages/App/statistic_page.dart';
import 'package:frontend_flutter/pages/App/transaction_page.dart';
import 'package:frontend_flutter/pages/App/budgets.dart';
import 'package:frontend_flutter/pages/App/transaction_history.dart';

class MainLayout extends StatefulWidget {
  final Widget? child;
  final int currentIndex;
  final Function(int)? onNavigationChanged;
  final bool showBottomNav;
  final String? title;
  final List<Widget>? actions;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final String token; // ⭐ UBAH: jadi required, bukan optional

  const MainLayout({
    super.key,
    this.child,
    this.currentIndex = 0,
    this.onNavigationChanged,
    this.showBottomNav = true,
    this.title,
    this.actions,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
    this.appBar,
    required this.token, // ⭐ UBAH: required
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;
  late PageController _pageController;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    _setStatusBarStyle();
    _initializePages();
  }

  void _initializePages() {
    // ⭐ Token sudah pasti ada karena required
    _pages = [
      DashboardPage(
        token: widget.token,
        skipCheckBalance: true,
      ),
      StatisticsPage(token: widget.token),
      TransactionsPage(token: widget.token),
      BudgetsPage(token: widget.token),
      TransactionsHistoryPage(token: widget.token), // ⭐ Sekarang aman
    ];
  }

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      setState(() {
        _selectedIndex = widget.currentIndex;
      });
      _pageController.jumpToPage(widget.currentIndex);
    }
    
    // ⭐ Jika token berubah, re-initialize pages
    if (widget.token != oldWidget.token) {
      _initializePages();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    if (index == _selectedIndex) {
      print('ℹ️ Already on page index: $index');
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    if (widget.onNavigationChanged != null) {
      widget.onNavigationChanged!(index);
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
        body: widget.child ?? PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: _pages,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (widget.onNavigationChanged != null) {
              widget.onNavigationChanged!(index);
            }
          },
        ),
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