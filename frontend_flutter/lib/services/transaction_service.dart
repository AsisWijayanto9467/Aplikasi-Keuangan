import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']); // ⬅️ Ini benar
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

  /// Scan struk/receipt menggunakan AI Vision
  static Future<Map<String, dynamic>> scanReceipt({
    required String token,
    required File imageFile,
  }) async {
    try {
      print('=== SCAN RECEIPT REQUEST ===');
      print('URL: $baseUrl/scan-receipt');
      print('Token: ${token.substring(0, 20)}...');
      print('Image Path: ${imageFile.path}');
      print('Image Size: ${await imageFile.length()} bytes');

      // Buat multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/scan-receipt'),
      );

      // Tambahkan headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Tambahkan file image
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      // Kirim request dengan timeout
      final streamedResponse = await request.send().timeout(
        const Duration(
          seconds: 30,
        ), // Timeout lebih lama untuk upload & AI processing
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          print('✅ Receipt scanned successfully');
          print('Title: ${data['data']['title']}');
          print('Amount: ${data['data']['amount']}');
          print('Date: ${data['data']['date']}');
          print('Category ID: ${data['data']['suggested_category_id']}');

          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Gagal scan struk');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Token tidak valid atau expired');
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Validasi gambar gagal');
      } else if (response.statusCode == 500) {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Server error saat memproses struk',
        );
      } else {
        throw Exception('Gagal scan struk (Status: ${response.statusCode})');
      }
    } on SocketException {
      throw Exception('Tidak ada koneksi internet');
    } on TimeoutException {
      throw Exception('Waktu scan habis, coba lagi');
    } catch (e) {
      print('Scan Receipt Error: $e');
      rethrow;
    }
  }

  /// Create transaksi dari hasil scan struk
  static Future<Map<String, dynamic>> createTransactionFromScan({
    required String token,
    required Map<String, dynamic> scanResult,
    String? customTitle,
    String? customCategoryId,
    String? customDate,
    String? customDescription,
  }) async {
    try {
      print('=== CREATE TRANSACTION FROM SCAN ===');
      print('Scan Result: $scanResult');

      // Gunakan data dari scan atau custom input
      final body = {
        'category_id':
            customCategoryId ??
            scanResult['suggested_category_id']?.toString() ??
            '',
        'title': customTitle ?? scanResult['title'] ?? 'Transaksi',
        'description': customDescription ?? scanResult['description'] ?? '',
        'amount':
            (scanResult['amount'] is int)
                ? (scanResult['amount'] as int).toDouble()
                : double.tryParse(scanResult['amount']?.toString() ?? '0') ?? 0,
        'payment_method': scanResult['payment_method'] ?? 'cash',
        'type': scanResult['type'] ?? 'expense',
        'date':
            customDate ??
            scanResult['date'] ??
            DateTime.now().toString().split(' ')[0],
      };

      print('Request Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/transactions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Transaction created from scan');
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
      print('Create Transaction From Scan Error: $e');
      rethrow;
    }
  }

  /// Flow lengkap: Scan struk + langsung create transaksi
  static Future<Map<String, dynamic>> scanAndCreateTransaction({
    required String token,
    required File imageFile,
    String? customTitle,
    String? customCategoryId,
    String? customDate,
    String? customDescription,
  }) async {
    try {
      // Step 1: Scan receipt
      print('📸 Step 1: Scanning receipt...');
      final scanResult = await scanReceipt(token: token, imageFile: imageFile);

      // Step 2: Create transaction from scan result
      print('💾 Step 2: Creating transaction...');
      final transactionResult = await createTransactionFromScan(
        token: token,
        scanResult: scanResult,
        customTitle: customTitle,
        customCategoryId: customCategoryId,
        customDate: customDate,
        customDescription: customDescription,
      );

      return {'scan_result': scanResult, 'transaction': transactionResult};
    } catch (e) {
      print('Scan and Create Transaction Error: $e');
      rethrow;
    }
  }
}
