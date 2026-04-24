// lib/services/budget_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class BudgetService {
  static const String baseUrl = 'http://10.101.0.235:8000/api/v1/budgets';

  // Headers helper
  static Map<String, String> _headers({required String token}) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  // Get all budgets (with optional month/year filter)
  static Future<Map<String, dynamic>> getBudgets({
    required String token,
    int? month,
    int? year,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': response.statusCode == 200,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? [],
        'summary': decodedResponse['summary'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal memuat data budget: $e');
    }
  }

  // Create new budget
  static Future<Map<String, dynamic>> createBudget({
    required String token,
    required int categoryId,
    required double limitAmount,
    required int month,
    required int year,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: _headers(token: token),
        body: jsonEncode({
          'category_id': categoryId,
          'limit_amount': limitAmount,
          'month': month,
          'year': year,
        }),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': response.statusCode == 201,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal membuat budget: $e');
    }
  }

  // Get single budget detail
  static Future<Map<String, dynamic>> getBudgetDetail({
    required String token,
    required int budgetId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$budgetId'),
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': response.statusCode == 200,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal memuat detail budget: $e');
    }
  }

  // Update budget
  static Future<Map<String, dynamic>> updateBudget({
    required String token,
    required int budgetId,
    required double limitAmount,
    int? month,
    int? year,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'limit_amount': limitAmount,
      };

      if (month != null) body['month'] = month;
      if (year != null) body['year'] = year;

      final response = await http.put(
        Uri.parse('$baseUrl/$budgetId'),
        headers: _headers(token: token),
        body: jsonEncode(body),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': response.statusCode == 200,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal mengupdate budget: $e');
    }
  }

  // Delete budget
  static Future<Map<String, dynamic>> deleteBudget({
    required String token,
    required int budgetId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$budgetId'),
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': response.statusCode == 200,
        'message': decodedResponse['message'] ?? '',
      };
    } catch (e) {
      throw Exception('Gagal menghapus budget: $e');
    }
  }

  // Check budget status
  static Future<Map<String, dynamic>> checkBudgetStatus({
    required String token,
    int? month,
    int? year,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      final uri = Uri.parse('$baseUrl/status')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      final decodedResponse = jsonDecode(response.body);
      
      return {
        'success': response.statusCode == 200,
        'message': decodedResponse['message'] ?? '',
        'data': decodedResponse['data'] ?? [],
        'summary': decodedResponse['summary'] ?? {},
      };
    } catch (e) {
      throw Exception('Gagal mengecek status budget: $e');
    }
  }
}