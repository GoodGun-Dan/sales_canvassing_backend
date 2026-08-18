import 'api_client.dart';

class VisitService {
  static Future<List<Map<String, dynamic>>> fetchTodayVisits({int? repId}) async {
    final endpoint =
        repId != null ? '/visits/today?rep_id=$repId' : '/visits/today';
    final data = await ApiClient.get(endpoint);
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<void> markMissed(int visitId, String reason) async {
    await ApiClient.post('/visits/$visitId/missed', {'reason': reason});
  }

  static Future<void> reschedule(
    int visitId, {
    required String visitDate,
    String? visitTime,
  }) async {
    await ApiClient.post('/visits/$visitId/reschedule', {
      'visit_date': visitDate,
      if (visitTime != null) 'visit_time': visitTime,
    });
  }
}
