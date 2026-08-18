import 'api_client.dart';
import '../models/sales_statistic.dart';

class AnalyticsService {
  static Future<List<SalesStatistic>> fetchDailySales({int days = 7}) async {
    try {
      final data = await ApiClient.get('/analytics/daily-sales?days=$days');
      if (data is List) {
        return data.map((json) => SalesStatistic.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTopProducts(
      {int limit = 5}) async {
    try {
      final data = await ApiClient.get('/analytics/top-products?limit=$limit');
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTopOutlets(
      {int limit = 5}) async {
    try {
      final data = await ApiClient.get('/analytics/top-outlets?limit=$limit');
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> fetchSummary() async {
    try {
      return await ApiClient.getMap('/analytics/summary');
    } catch (e) {
      return {};
    }
  }
}
