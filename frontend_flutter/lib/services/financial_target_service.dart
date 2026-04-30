// lib/services/financial_target_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class FinancialTargetService {
  static const String baseUrl = 'http://10.152.224.235:8000/api/v1';

  // ==================== GET ALL TARGETS ====================
  
  /// Get list semua target finansial dengan filter & pagination
  static Future<Map<String, dynamic>> getTargets({
    required String token,
    String? status, // 'active', 'completed', 'cancelled'
    String? category, // 'education', 'work', 'vacation', etc
    String? sortBy, // 'created_at', 'target_date', 'target_amount'
    String? sortOrder, // 'asc', 'desc'
    int page = 1,
  }) async {
    try {
      print('=== GET ALL TARGETS REQUEST ===');
      print('Token: ${token.substring(0, 20)}...');
      
      final Map<String, String> queryParams = {'page': page.toString()};
      
      if (status != null) queryParams['status'] = status;
      if (category != null) queryParams['category'] = category;
      if (sortBy != null) queryParams['sort_by'] = sortBy;
      if (sortOrder != null) queryParams['sort_order'] = sortOrder;
      
      final uri = Uri.parse('$baseUrl/financial-targets')
          .replace(queryParameters: queryParams);
      
      print('URL: $uri');
      
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Gagal memuat target: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Targets Error: $e');
      rethrow;
    }
  }

  // ==================== GET ALL TARGETS WITHOUT PAGINATION ====================
  
  /// Get semua target (untuk dropdown/picker)
  static Future<List<Map<String, dynamic>>> getAllTargets({
    required String token,
    String? status,
  }) async {
    try {
      print('=== GET ALL TARGETS (NO PAGINATION) ===');
      
      final Map<String, String> queryParams = {};
      if (status != null) queryParams['status'] = status;
      queryParams['per_page'] = '100'; // Ambil banyak data
      
      final uri = Uri.parse('$baseUrl/financial-targets')
          .replace(queryParameters: queryParams);
      
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']['data'] ?? []);
      } else {
        throw Exception('Gagal memuat target: ${response.statusCode}');
      }
    } catch (e) {
      print('Get All Targets Error: $e');
      rethrow;
    }
  }

  

  // ==================== CREATE TARGET ====================
  
  static Future<Map<String, dynamic>> createTarget({
    required String token,
    required String title,
    required String category, // education, work, vacation, medical, etc
    required String reason,
    required double targetAmount,
    required String targetDate, // format: 'YYYY-MM-DD'
    String? icon,
    String? notes,
  }) async {
    try {
      print('=== CREATE TARGET REQUEST ===');
      print('URL: $baseUrl/financial-targets');
      print('Token: ${token.substring(0, 20)}...');
      
      final body = {
        'title': title,
        'category': category,
        'reason': reason,
        'target_amount': targetAmount,
        'target_date': targetDate,
        'icon': icon,
        'notes': notes,
      };
      
      // Remove null values
      body.removeWhere((key, value) => value == null);
      
      print('Request Body: ${jsonEncode(body)}');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/financial-targets'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        final errors = errorData['errors'];
        String errorMessage = 'Validasi gagal:\n';
        errors.forEach((key, value) {
          errorMessage += '- ${value.join(', ')}\n';
        });
        throw Exception(errorMessage);
      } else {
        throw Exception('Gagal membuat target (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Create Target Error: $e');
      rethrow;
    }
  }

  // ==================== GET SINGLE TARGET ====================
  
  /// Get detail satu target finansial
  static Future<Map<String, dynamic>> getTargetById({
    required String token,
    required String targetId,
  }) async {
    try {
      print('=== GET TARGET DETAIL ===');
      print('URL: $baseUrl/financial-targets/$targetId');
      print('Token: ${token.substring(0, 20)}...');
      
      final response = await http
          .get(
            Uri.parse('$baseUrl/financial-targets/$targetId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Target tidak ditemukan');
      } else {
        throw Exception('Gagal memuat target: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Target Detail Error: $e');
      rethrow;
    }
  }

  // ==================== ADD SAVING ====================
  
  /// Tambah setoran ke target tabungan
  static Future<Map<String, dynamic>> addSaving({
    required String token,
    required String targetId,
    required double amount,
    required String savingDate, // format: 'YYYY-MM-DD'
    String? notes,
  }) async {
    try {
      print('=== ADD SAVING REQUEST ===');
      print('URL: $baseUrl/financial-targets/$targetId/savings');
      print('Token: ${token.substring(0, 20)}...');
      
      final body = {
        'amount': amount,
        'saving_date': savingDate,
        'notes': notes,
      };
      
      // Remove null values
      body.removeWhere((key, value) => value == null);
      
      print('Request Body: ${jsonEncode(body)}');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/financial-targets/$targetId/savings'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Target sudah tidak aktif');
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        final errors = errorData['errors'];
        String errorMessage = 'Validasi gagal:\n';
        errors.forEach((key, value) {
          errorMessage += '- ${value.join(', ')}\n';
        });
        throw Exception(errorMessage);
      } else {
        throw Exception('Gagal menambah setoran (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Add Saving Error: $e');
      rethrow;
    }
  }

  // ==================== GET PROGRESS DATA ====================
  
  /// Get data progress target (dengan chart)
  static Future<Map<String, dynamic>> getProgressData({
    required String token,
    required String targetId,
  }) async {
    try {
      print('=== GET PROGRESS DATA ===');
      print('URL: $baseUrl/financial-targets/$targetId/progress');
      print('Token: ${token.substring(0, 20)}...');
      
      final response = await http
          .get(
            Uri.parse('$baseUrl/financial-targets/$targetId/progress'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Target tidak ditemukan');
      } else {
        throw Exception('Gagal memuat progress: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Progress Data Error: $e');
      rethrow;
    }
  }

  // ==================== GET SUMMARY ====================
  
  /// Get ringkasan semua target finansial
  static Future<Map<String, dynamic>> getSummary({
    required String token,
  }) async {
    try {
      print('=== GET TARGETS SUMMARY ===');
      print('URL: $baseUrl/financial-targets/summary');
      print('Token: ${token.substring(0, 20)}...');
      
      final response = await http
          .get(
            Uri.parse('$baseUrl/financial-targets/summary'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Gagal memuat ringkasan: ${response.statusCode}');
      }
    } catch (e) {
      print('Get Summary Error: $e');
      rethrow;
    }
  }

  // ==================== CANCEL TARGET ====================
  
  /// Batalkan target finansial
  static Future<Map<String, dynamic>> cancelTarget({
    required String token,
    required String targetId,
  }) async {
    try {
      print('=== CANCEL TARGET ===');
      print('URL: $baseUrl/financial-targets/$targetId/cancel');
      print('Token: ${token.substring(0, 20)}...');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/financial-targets/$targetId/cancel'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Target tidak ditemukan');
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Gagal membatalkan target');
      } else {
        throw Exception('Gagal membatalkan target (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Cancel Target Error: $e');
      rethrow;
    }
  }

  // ==================== HELPER METHODS ====================
  
  /// Format currency untuk tampilan
  static String formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  /// Get icon berdasarkan kategori
  static String getIconForCategory(String category) {
    switch (category) {
      case 'education':
        return '🎓';
      case 'work':
        return '💼';
      case 'vacation':
        return '🏖️';
      case 'medical':
        return '🏥';
      case 'emergency_fund':
        return '🚨';
      case 'property':
        return '🏠';
      case 'vehicle':
        return '🚗';
      case 'business':
        return '💼';
      case 'wedding':
        return '💒';
      case 'other':
        return '🎯';
      default:
        return '💰';
    }
  }

  /// Get label kategori dalam bahasa Indonesia
  static String getCategoryLabel(String category) {
    switch (category) {
      case 'education':
        return 'Pendidikan';
      case 'work':
        return 'Pekerjaan';
      case 'vacation':
        return 'Liburan';
      case 'medical':
        return 'Kesehatan';
      case 'emergency_fund':
        return 'Dana Darurat';
      case 'property':
        return 'Properti';
      case 'vehicle':
        return 'Kendaraan';
      case 'business':
        return 'Bisnis';
      case 'wedding':
        return 'Pernikahan';
      case 'other':
        return 'Lainnya';
      default:
        return category;
    }
  }

  /// Get warna progress bar berdasarkan persentase
  static int getProgressColor(double percentage) {
    if (percentage >= 100) {
      return 0xFF4CAF50; // Hijau - completed
    } else if (percentage >= 75) {
      return 0xFF2196F3; // Biru - hampir selesai
    } else if (percentage >= 50) {
      return 0xFFFF9800; // Orange - setengah jalan
    } else if (percentage >= 25) {
      return 0xFFFF5722; // Deep Orange - mulai
    } else {
      return 0xFFF44336; // Merah - baru mulai
    }
  }

  /// Get status text
  static String getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'overdue':
        return 'Terlambat';
      case 'on_track':
        return 'Sesuai Target';
      default:
        return status;
    }
  }

  /// Get status color
  static int getStatusColor(String status) {
    switch (status) {
      case 'active':
      case 'on_track':
        return 0xFF4CAF50; // Hijau
      case 'completed':
        return 0xFF2196F3; // Biru
      case 'cancelled':
        return 0xFF9E9E9E; // Abu-abu
      case 'overdue':
        return 0xFFF44336; // Merah
      default:
        return 0xFF000000; // Hitam
    }
  }

  /// Calculate estimated monthly saving needed
  static double calculateMonthlyTarget(double remainingAmount, int remainingDays) {
    if (remainingDays <= 0) return remainingAmount;
    return (remainingAmount / remainingDays) * 30;
  }

  /// Get list kategori untuk dropdown
  static List<Map<String, String>> getCategories() {
    return [
      {'value': 'education', 'label': '🎓 Pendidikan', 'description': 'Biaya sekolah, kursus, buku'},
      {'value': 'work', 'label': '💼 Pekerjaan', 'description': 'Modal usaha, peralatan kerja'},
      {'value': 'vacation', 'label': '🏖️ Liburan', 'description': 'Travel, hotel, jalan-jalan'},
      {'value': 'medical', 'label': '🏥 Kesehatan', 'description': 'Biaya dokter, obat, asuransi'},
      {'value': 'emergency_fund', 'label': '🚨 Dana Darurat', 'description': 'Persiapan keadaan darurat'},
      {'value': 'property', 'label': '🏠 Properti', 'description': 'Beli/renovasi rumah, tanah'},
      {'value': 'vehicle', 'label': '🚗 Kendaraan', 'description': 'Beli mobil/motor, maintenance'},
      {'value': 'business', 'label': '💼 Bisnis', 'description': 'Modal usaha, investasi bisnis'},
      {'value': 'wedding', 'label': '💒 Pernikahan', 'description': 'Biaya nikah, resepsi'},
      {'value': 'other', 'label': '🎯 Lainnya', 'description': 'Target keuangan lainnya'},
    ];
  }
}