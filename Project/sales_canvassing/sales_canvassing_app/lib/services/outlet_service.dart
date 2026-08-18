import 'api_client.dart';
import '../models/outlet.dart';

class OutletService {
  static Future<List<Outlet>> fetchOutlets() async {
    try {
      final data = await ApiClient.get('/outlets');
      if (data is List) {
        return data.map((json) => Outlet.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load outlets: $e');
    }
  }

  static Future<Map<String, dynamic>> createOutlet(Outlet outlet) async {
    try {
      return await ApiClient.postMap('/outlets', outlet.toJson());
    } catch (e) {
      throw Exception('Failed to create outlet: $e');
    }
  }

  static Future<Map<String, dynamic>> updateOutlet(
      int id, Outlet outlet) async {
    try {
      return await ApiClient.putMap('/outlets/$id', outlet.toJson());
    } catch (e) {
      throw Exception('Failed to update outlet: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteOutlet(int id, {bool force = false}) async {
    try {
      final endpoint = force ? '/outlets/$id?force=true' : '/outlets/$id';
      return await ApiClient.deleteMap(endpoint);
    } catch (e) {
      throw Exception('Failed to delete outlet: $e');
    }
  }
}
