// lib/pages/App/transaction_history.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/layouts/main_layout.dart';

class TransactionsHistoryPage extends StatelessWidget {
  final String token; // ⭐ Pastikan ada parameter token

  const TransactionsHistoryPage({
    super.key,
    required this.token, // ⭐ Required parameter
  });

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentIndex: 4,
      showBottomNav: true,
      title: 'Statistik',
      token: token, // ⭐ Kirim token ke MainLayout
      backgroundColor: Colors.white,
      child: const Center(
        child: Text('transaction history Page'),
      ),
    );
  }
}