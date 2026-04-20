import 'package:flutter/material.dart';
import 'package:frontend_flutter/pages/auth/login_page.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Menghilangkan banner debug di pojok kanan
      title: 'Aplikasi Auth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Di sinilah kuncinya:
      home: LoginPage(), 
    );
  }
}