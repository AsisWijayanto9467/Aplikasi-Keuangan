import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String baseUrl = 'http://10.152.224.235:8000/api/v1'; // Sesuaikan dengan IP server Anda

  // Get greeting awal saat buka chatbot
  static Future<Map<String, dynamic>> getGreeting(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/greeting'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'reply': 'Gagal memuat greeting'};
    } catch (e) {
      print('❌ Chat Service Error (Greeting): $e');
      return {'success': false, 'reply': 'Gagal terhubung ke server'};
    }
  }

  // Kirim pesan ke chatbot
  static Future<Map<String, dynamic>> sendMessage({
    required String token,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'message': message}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'reply': 'Gagal mengirim pesan'};
    } catch (e) {
      print('❌ Chat Service Error (Send): $e');
      return {'success': false, 'reply': 'Gagal terhubung ke server'};
    }
  }
}