import 'dart:convert';
import 'package:http/http.dart' as http;

class TransactionService {
  static const String baseUrl = 'http://10.146.91.235:8000/api/v1';

  /// Cek apakah user sudah set saldo awal
   static Future<Map<String, dynamic>> checkBalance(String token) async {
    try {
      print('=== CHECK BALANCE REQUEST ===');
      print('URL: $baseUrl/balance');
      print('Token: $token');
      
      final response = await http.get(
        Uri.parse('$baseUrl/balance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to check balance: ${response.statusCode}');
      }
    } catch (e) {
      print('Check Balance Error: $e');
      rethrow;
    }
  }

  // lib/services/transaction_service.dart
  static Future<Map<String, dynamic>> setInitialBalance(
    String token, 
    double amount,
  ) async {
    try {
      print('=== SET INITIAL BALANCE REQUEST ===');
      print('URL: $baseUrl/balance');
      print('Token: ${token.substring(0, 20)}...'); // Jangan print full token
      print('Amount: $amount');
      
      final response = await http.post(
        Uri.parse('$baseUrl/balance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amount': amount}),
      ).timeout(const Duration(seconds: 10)); // Tambahkan timeout

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // ⭐ VERIFIKASI response
        print('Is Initialized from response: ${data['initialized']}');
        
        return data;
      } else {
        throw Exception('Failed to set balance: ${response.statusCode}');
      }
    } catch (e) {
      print('Set Initial Balance Error: $e');
      rethrow;
    }
  }

  // ==================== TRANSACTIONS ====================

  /// Get list transaksi dengan filter & pagination
  static Future<Map<String, dynamic>> getTransactions({
    required String token,
    String? type,           // 'income' atau 'expense'
    int? month,
    int? year,
    int page = 1,
  }) async {
    // Build query parameters
    final Map<String, String> queryParams = {'page': page.toString()};
    
    if (type != null) queryParams['type'] = type;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final uri = Uri.parse('$baseUrl/transactions')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return jsonDecode(response.body);
  }

  /// Get detail transaksi by ID
  static Future<Map<String, dynamic>> getTransactionById({
    required String token,
    required String id,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return jsonDecode(response.body);
  }

  /// Create transaksi baru
  static Future<Map<String, dynamic>> createTransaction({
    required String token,
    required String categoryId,
    required String title,
    String? description,
    required double amount,
    required String paymentMethod, // 'cash', 'qris', 'transfer'
    required String type,          // 'income', 'expense'
    required String date,          // format: 'YYYY-MM-DD'
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'category_id': categoryId,
        'title': title,
        'description': description,
        'amount': amount,
        'payment_method': paymentMethod,
        'type': type,
        'date': date,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Update transaksi
  static Future<Map<String, dynamic>> updateTransaction({
    required String token,
    required String id,
    required String categoryId,
    required String title,
    String? description,
    required double amount,
    required String paymentMethod, // 'cash', 'qris', 'transfer'
    required String type,          // 'income', 'expense'
    required String date,          // format: 'YYYY-MM-DD'
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/transactions/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'category_id': categoryId,
        'title': title,
        'description': description,
        'amount': amount,
        'payment_method': paymentMethod,
        'type': type,
        'date': date,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Delete transaksi
  static Future<Map<String, dynamic>> deleteTransaction({
    required String token,
    required String id,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/transactions/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return jsonDecode(response.body);
  }
}