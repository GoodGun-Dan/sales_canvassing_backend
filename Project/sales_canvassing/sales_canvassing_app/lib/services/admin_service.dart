import 'api_client.dart';
import '../models/sales_rep.dart';

class AdminService {
  static Future<List<SalesRep>> getSalesReps() async {
    try {
      final data = await ApiClient.get('/admin/sales-reps');
      if (data is List) {
        return data.map((json) => SalesRep.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load sales reps: $e');
    }
  }

  static Future<Map<String, dynamic>> getRepDashboard(int repId) async {
    try {
      return await ApiClient.getMap('/admin/sales-reps/$repId/dashboard');
    } catch (e) {
      throw Exception('Failed to load rep dashboard: $e');
    }
  }

  static Future<List<dynamic>> getRepOrders(int repId) async {
    try {
      final data = await ApiClient.get('/admin/sales-reps/$repId/orders');
      if (data is List) return data;
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getRepPayments(int repId) async {
    try {
      final data = await ApiClient.get('/admin/sales-reps/$repId/payments');
      if (data is List) return data;
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getRepAnalytics(int repId,
      {int days = 7}) async {
    try {
      return await ApiClient.getMap(
          '/admin/sales-reps/$repId/analytics?days=$days');
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> addSalesRep({
    required String name,
    required String email,
    required String phone,
    required String username,
    required String password,
  }) async {
    return await ApiClient.postMap('/admin/sales-reps', {
      'name': name,
      'email': email,
      'phone': phone,
      'username': username,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> updateSalesRep({
    required int id,
    required String name,
    required String email,
    required String phone,
    required String username,
    bool? isActive,
  }) async {
    return await ApiClient.putMap('/admin/sales-reps/$id', {
      'name': name,
      'email': email,
      'phone': phone,
      'username': username,
      'is_active': isActive,
    });
  }

  static Future<Map<String, dynamic>> deleteSalesRep(int id) async {
    return await ApiClient.deleteMap('/admin/sales-reps/$id');
  }
}
