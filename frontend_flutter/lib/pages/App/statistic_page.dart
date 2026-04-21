// lib/pages/App/statistic_page.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/layouts/main_layout.dart';

class StatisticsPage extends StatelessWidget {
  final String token;

  const StatisticsPage({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentIndex: 1,
      showBottomNav: true,
      title: 'Statistik',
      token: token, // ⭐ Kirim token ke MainLayout
      backgroundColor: Colors.white,
      child: const Center(
        child: Text('Statistics Page'),
      ),
    );
  }
}