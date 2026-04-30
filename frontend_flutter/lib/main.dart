// lib/main.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/App/dashboard.dart';
import 'package:frontend_flutter/pages/layouts/main_layout.dart';
import 'package:frontend_flutter/pages/auth/login_page.dart';
import 'package:frontend_flutter/pages/auth/register_page.dart';
import 'package:frontend_flutter/pages/auth/set_pin_page.dart';
import 'package:frontend_flutter/pages/auth/verify_pin_page.dart';
import 'package:frontend_flutter/pages/App/initial_balance_page.dart';
import 'package:frontend_flutter/pages/App/profile_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Keuangan',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        
        '/set-pin': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return SetPinPage(token: args?['token'] ?? '');
        },
        
        '/verify-pin': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return VerifyPinPage(token: args?['token'] ?? '');
        },

        '/dashboard': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return DashboardPage(token: args?['token'] ?? '');
        },
        
        


        
        '/profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return ProfilePage(token: args?['token'] ?? '');
        },
        
        '/initial-balance': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return InitialBalancePage(token: args?['token'] ?? '');
        },
        
        // ⭐ HAPUS ROUTE UNTUK HALAMAN-HALAMAN INI karena sudah ditangani oleh MainLayout
        // '/dashboard': ...
        // '/statistic': ...
        // '/add-transaction': ...
        // '/budgets': ...
        // '/transaction-history': ...
      },
    );
  }
}