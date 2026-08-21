import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userRoleKey = 'user_role';
  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';

  static String get baseUrl => ApiConfig.baseUrl;

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveUserInfo({
    required String role,
    required String name,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRoleKey, role);
    await prefs.setString(_userNameKey, name);
    await prefs.setInt(_userIdKey, userId);
  }

  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey) ?? 'rep';
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey) ?? 'User';
  }

  static Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey) ?? 0;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userIdKey);
  }

  static int _parseUserId(Map<String, dynamic> user) {
    final dynamic raw = user['id'] ?? user['employee_id'];
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = Map<String, dynamic>.from(data['user'] as Map);
        final userId = _parseUserId(user);
        if (userId <= 0) {
          return {
            'success': false,
            'error':
                'Login berhasil tetapi ID user tidak valid. Coba login ulang.',
          };
        }
        await saveToken(data['token']);
        await saveUserInfo(
          role: user['role']?.toString() ?? 'rep',
          name: user['name']?.toString() ?? 'User',
          userId: userId,
        );
        return {'success': true, 'user': user};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException') || msg.contains('timed out')) {
        return {
          'success': false,
          'error':
              'Server tidak merespons ($baseUrl). Pastikan backend jalan (npm start). '
                  'HP fisik: flutter run --dart-define=API_HOST=IP_PC_ANDA',
        };
      }
      return {
        'success': false,
        'error':
            'Tidak bisa hubungi server di $baseUrl. Jalankan backend (npm start) dan periksa IP/API_HOST.',
      };
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      print('📧 Forgot password request to: $baseUrl/auth/forgot-password');
      print('📧 Email: $email');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      print('📧 Response status: ${response.statusCode}');
      print('📧 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'code': data['code']
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send verification code'
        };
      }
    } on Exception catch (e) {
      print('❌ Forgot password error: $e');
      print('❌ Base URL: $baseUrl');
      return {
        'success': false,
        'error': 'Tidak bisa hubungi server di $baseUrl. Error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyCode(
      String email, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'code': code}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'employee_id': data['employee_id']
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Invalid verification code'
        };
      }
    } on Exception catch (e) {
      return {
        'success': false,
        'error': 'Tidak bisa hubungi server. Pastikan backend jalan.',
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String code, String newPassword) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'email': email, 'code': code, 'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to reset password'
        };
      }
    } on Exception catch (e) {
      return {
        'success': false,
        'error': 'Tidak bisa hubungi server. Pastikan backend jalan.',
      };
    }
  }
}
