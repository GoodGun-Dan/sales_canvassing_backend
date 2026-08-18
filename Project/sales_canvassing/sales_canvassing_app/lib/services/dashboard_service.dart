import 'api_client.dart';
import '../models/dashboard_data.dart';

class DashboardService {
  static Future<DashboardData> fetchDashboard() async {
    try {
      final data = await ApiClient.get('/dashboard');
      return DashboardData.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load dashboard: $e');
    }
  }
}
