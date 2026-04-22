// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://192.168.101.6:8000/api/v1/auth';

  // Headers helper
  static Map<String, String> _headers({String? token}) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // Register
  static Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: _headers(),
        body: jsonEncode(userData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // Set PIN
  static Future<Map<String, dynamic>> setPin(String token, String pin, String pinConfirmation) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/set-pin'),
        headers: _headers(token: token),
        body: jsonEncode({
          'pin': pin,
          'pin_confirmation': pinConfirmation,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // Verify PIN
  static Future<Map<String, dynamic>> verifyPin(String token, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-pin'),
        headers: _headers(token: token),
        body: jsonEncode({'pin': pin}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // Get User Data (NEW)
  static Future<Map<String, dynamic>> getUser(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      // Return data user dari response
      return {
        'success': response.statusCode == 200,
        'message': decodedResponse['message'],
        'data': decodedResponse['data'],
      };
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // Update User Data (NEW)
  static Future<Map<String, dynamic>> updateUser({
    required String token,
    String? name,
    String? email,
    String? phone,
    String? gender,
    String? birthDate,
    String? password,
    String? passwordConfirmation,
  }) async {
    try {
      final Map<String, dynamic> body = {};

      // Hanya tambahkan field yang tidak null
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (gender != null) body['gender'] = gender;
      if (birthDate != null) body['birth_date'] = birthDate;
      if (password != null) body['password'] = password;
      if (passwordConfirmation != null) {
        body['password_confirmation'] = passwordConfirmation;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/user/update'),
        headers: _headers(token: token),
        body: jsonEncode(body),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': response.statusCode == 200,
        'message': decodedResponse['message'],
        'data': decodedResponse['data'],
      };
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  // Logout
  static Future<Map<String, dynamic>> logout(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: _headers(token: token),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }
}