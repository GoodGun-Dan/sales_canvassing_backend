import 'api_client.dart';

class MerchandisingService {
  static Future<Map<String, dynamic>?> fetchByVisit(int visitId) async {
    final data = await ApiClient.get('/merchandising/$visitId');
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  static Future<void> submit({
    required int visitId,
    required int planogramScore,
    required int shelfShare,
    required bool posmPlacement,
    String? notes,
  }) async {
    await ApiClient.post('/merchandising', {
      'visitId': visitId,
      'planogram_score': planogramScore,
      'shelf_share': shelfShare,
      'posm_placement': posmPlacement,
      'notes': notes,
    });
  }
}
