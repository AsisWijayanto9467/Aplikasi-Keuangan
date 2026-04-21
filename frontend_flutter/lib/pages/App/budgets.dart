// lib/pages/App/budgets.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/layouts/main_layout.dart';

class Budgets extends StatelessWidget {
  final String token; // ⭐ Pastikan ada parameter token

  const Budgets({
    super.key,
    required this.token, // ⭐ Required parameter
  });

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentIndex: 3,
      showBottomNav: true,
      title: 'Statistik',
      token: token, // ⭐ Kirim token ke MainLayout
      backgroundColor: Colors.white,
      child: const Center(
        child: Text('budgets Page'),
      ),
    );
  }
}