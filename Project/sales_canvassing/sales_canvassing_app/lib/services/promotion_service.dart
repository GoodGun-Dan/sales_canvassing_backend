import 'api_client.dart';
import '../models/promotion.dart';

class PromotionService {
  static Future<List<Promotion>> fetchActive() async {
    final data = await ApiClient.get('/promotions?active=true');
    if (data is List) {
      return data.map((e) => Promotion.fromJson(e)).toList();
    }
    return [];
  }

  static Future<List<Promotion>> fetchAll() async {
    final data = await ApiClient.get('/promotions?active=false');
    if (data is List) {
      return data.map((e) => Promotion.fromJson(e)).toList();
    }
    return [];
  }

  static Future<void> create(Map<String, dynamic> body) async {
    await ApiClient.post('/promotions', body);
  }
}
