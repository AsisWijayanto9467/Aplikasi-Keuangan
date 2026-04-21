// lib/pages/App/transaction_history.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/layouts/main_layout.dart';

class TransactionsPage extends StatelessWidget {
  final String token; // ⭐ Pastikan ada parameter token

  const TransactionsPage({
    super.key,
    required this.token, // ⭐ Required parameter
  });

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentIndex: 2,
      showBottomNav: true,
      title: 'Statistik',
      token: token, // ⭐ Kirim token ke MainLayout
      backgroundColor: Colors.white,
      child: const Center(
        child: Text('transaction add Page'),
      ),
    );
  }
}