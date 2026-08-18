import 'api_client.dart';

class UserService {
  static Future<Map<String, dynamic>> getProfile() async {
    return ApiClient.getMap('/auth/profile');
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    return ApiClient.putMap('/auth/profile', {
      'name': name,
      'email': email,
      'phone': phone,
    });
  }

  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return ApiClient.postMap('/auth/change-password', {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }
}
