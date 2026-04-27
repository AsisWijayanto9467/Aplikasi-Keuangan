// lib/services/budget_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class BudgetService {
  static const String baseUrl = 'http://10.139.16.235:8000/api/v1/budget';

  // Headers helper
  static Map<String, String> _headers({required String token}) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  // Setup monthly budget
  static Future<Map<String, dynamic>> setupMonthlyBudget({
    required String token,
    required double totalIncome,
    required int month,
    required int year,
    required List<Map<String, dynamic>> budgets,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/setup'),
        headers: _headers(token: token),
        body: jsonEncode({
          'total_income': totalIncome,
          'month': month,
          'year': year,
          'budgets': budgets, // Format: [{'category_id': 1, 'limit_amount': 500000}]
        }),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal setup budget bulanan: $e');
    }
  }

  // Get budget overview
  static Future<Map<String, dynamic>> getBudgetOverview({
    required String token,
    int? month,
    int? year,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      final uri = Uri.parse('$baseUrl/overview')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal memuat overview budget: $e');
    }
  }

  // Get daily recommendations
  static Future<Map<String, dynamic>> getDailyRecommendations({
    required String token,
    int? month,
    int? year,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      final uri = Uri.parse('$baseUrl/daily-recommendations')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal memuat rekomendasi harian: $e');
    }
  }

  // Get budget history
  static Future<Map<String, dynamic>> getBudgetHistory({
    required String token,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$baseUrl/history')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? [],
      };
    } catch (e) {
      throw Exception('Gagal memuat history budget: $e');
    }
  }

  // ==================== TRANSACTIONS ====================

  // Add transaction
  static Future<Map<String, dynamic>> addTransaction({
    required String token,
    required int categoryId,
    required double amount,
    required String description,
    required String date, // Format: YYYY-MM-DD
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transactions'),
        headers: _headers(token: token),
        body: jsonEncode({
          'category_id': categoryId,
          'amount': amount,
          'description': description,
          'date': date,
        }),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal menambah transaksi: $e');
    }
  }

  // Get transactions
  static Future<Map<String, dynamic>> getTransactions({
    required String token,
    int? month,
    int? year,
    int? categoryId,
    String? date,
    String? search,
    int? perPage,
    int? page,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (date != null) queryParams['date'] = date;
      if (search != null) queryParams['search'] = search;
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      if (page != null) queryParams['page'] = page.toString();

      final uri = Uri.parse('$baseUrl/transactions')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal memuat transaksi: $e');
    }
  }

  // Delete transaction
  static Future<Map<String, dynamic>> deleteTransaction({
    required String token,
    required int transactionId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/transactions/$transactionId'),
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
      };
    } catch (e) {
      throw Exception('Gagal menghapus transaksi: $e');
    }
  }

  // ==================== EDIT BUDGET & INCOME ====================

  // Update budget
  static Future<Map<String, dynamic>> updateBudget({
    required String token,
    required int budgetId,
    required double limitAmount,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$budgetId'),
        headers: _headers(token: token),
        body: jsonEncode({
          'limit_amount': limitAmount,
        }),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal mengupdate budget: $e');
    }
  }

  // Update monthly income
  static Future<Map<String, dynamic>> updateIncome({
    required String token,
    required double totalIncome,
    required int month,
    required int year,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/income/update'),
        headers: _headers(token: token),
        body: jsonEncode({
          'total_income': totalIncome,
          'month': month,
          'year': year,
        }),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal mengupdate income: $e');
    }
  }

  // ==================== RESET ====================

  // Reset transactions (optional by category)
  static Future<Map<String, dynamic>> resetTransactions({
    required String token,
    required int month,
    required int year,
    int? categoryId,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'month': month,
        'year': year,
      };
      
      if (categoryId != null) body['category_id'] = categoryId;

      final response = await http.post(
        Uri.parse('$baseUrl/reset/transactions'),
        headers: _headers(token: token),
        body: jsonEncode(body),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal mereset transaksi: $e');
    }
  }

  // Reset all budget data
  static Future<Map<String, dynamic>> resetAllBudget({
    required String token,
    required int month,
    required int year,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/reset/all'),
        headers: _headers(token: token),
        body: jsonEncode({
          'month': month,
          'year': year,
        }),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': decodedResponse['success'] ?? false,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal mereset semua data budget: $e');
    }
  }
}