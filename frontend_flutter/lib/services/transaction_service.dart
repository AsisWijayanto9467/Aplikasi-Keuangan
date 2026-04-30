import 'dart:convert';
import 'package:http/http.dart' as http;

class TransactionService {
  static const String baseUrl = 'http://10.152.224.235:8000/api/v1';

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

      final response = await http
          .post(
            Uri.parse('$baseUrl/balance'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'amount': amount}),
          )
          .timeout(const Duration(seconds: 10)); // Tambahkan timeout

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

  // lib/services/transaction_service.dart

  /// Get list kategori
  static Future<List<Map<String, dynamic>>> getCategories(String token) async {
    try {
      print('=== LOADING CATEGORIES ===');
      print('URL: $baseUrl/categories');

      final response = await http
          .get(
            Uri.parse('$baseUrl/categories'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('Categories Response Status: ${response.statusCode}');
      print('Categories Response Body: ${response.body}');

     if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);  // ⬅️ Ini benar
      } else {
        throw Exception('Gagal load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading categories: $e');
      rethrow;
    }
  }

  // ==================== TRANSACTIONS ====================

  /// Get list transaksi dengan filter & pagination
  static Future<Map<String, dynamic>> getTransactions({
    required String token,
    String? type,
    String? categoryId,
    String? startDate,
    String? endDate,
    int page = 1,
  }) async {
    final Map<String, String> queryParams = {'page': page.toString()};

    if (type != null) queryParams['type'] = type;
    if (categoryId != null) queryParams['category_id'] = categoryId;
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    final uri = Uri.parse(
      '$baseUrl/transactions',
    ).replace(queryParameters: queryParams);

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

  static Future<Map<String, dynamic>> getStatistics({
    required String token,
    String period = 'month', // 'week', 'month', 'year'
    int? year,
    int? month,
  }) async {
    try {
      final Map<String, String> queryParams = {'period': period};

      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();

      final uri = Uri.parse(
        '$baseUrl/statistics',
      ).replace(queryParameters: queryParams);

      print('=== GET STATISTICS ===');
      print('URL: $uri');

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load statistics: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Statistics Error: $e');
      rethrow;
    }
  }

  /// Create transaksi baru
  // lib/services/transaction_service.dart
  static Future<Map<String, dynamic>> createTransaction({
    required String token,
    required String categoryId,
    required String title,
    String? description,
    required double amount,
    required String paymentMethod,
    required String type,
    required String date,
  }) async {
    try {
      // 🔍 LOGGING LENGKAP
      print('=== CREATE TRANSACTION REQUEST ===');
      print('URL: $baseUrl/transactions');
      print('Token: ${token.substring(0, 20)}...');
      print('Headers: Bearer $token');

      final body = {
        'category_id': categoryId,
        'title': title,
        'description': description,
        'amount': amount,
        'payment_method': paymentMethod,
        'type': type,
        'date': date,
      };

      print('Request Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/transactions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json', // ⬅️ TAMBAHKAN INI
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10)); // ⬅️ Tambahkan timeout

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // ⭐ CEK STATUS CODE
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception(
          'Saldo belum diinisialisasi. Silakan atur saldo terlebih dahulu.',
        );
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Validasi gagal');
      } else if (response.statusCode == 401) {
        throw Exception('Token tidak valid atau expired');
      } else {
        throw Exception(
          'Gagal membuat transaksi (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print('Create Transaction Error: $e');
      rethrow;
    }
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
    required String type, // 'income', 'expense'
    required String date, // format: 'YYYY-MM-DD'
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
