// lib/pages/App/budgets.dart
import 'package:flutter/material.dart';
// ❌ HAPUS import MainLayout

class Budgets extends StatelessWidget {
  final String token;

  const Budgets({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    // ⭐ LANGSUNG RETURN CONTENT dengan Scaffold
    return Container(
      color: Colors.white,
      child: Center(
        child: Text('Add Transaction Page'),
      ),
    );
  }   
}