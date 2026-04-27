// lib/services/category_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class CategoryService {
  static const String baseUrl = 'http://10.139.16.235:8000/api/v1/categories';

  static Map<String, String> _headers({required String token}) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  static Future<Map<String, dynamic>> getExpenseCategories({
    required String token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl?type=expense');
      
      final response = await http.get(
        uri,
        headers: _headers(token: token),
      );

      print('Category API Response Status: ${response.statusCode}');
      print('Category API Response Body: ${response.body}');
      
      final decodedResponse = jsonDecode(response.body);
      
      // ⚠️ Cek HTTP status code
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decodedResponse['message'] ?? '',
          'data': decodedResponse['data'] ?? [],
        };
      } else {
        // ⚠️ Jika bukan 200, return success: false
        return {
          'success': false,
          'message': decodedResponse['message'] ?? 'Gagal memuat kategori (${response.statusCode})',
          'data': [],
        };
      }
    } catch (e) {
      print('Category API Error: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'data': [],
      };
    }
  }
}