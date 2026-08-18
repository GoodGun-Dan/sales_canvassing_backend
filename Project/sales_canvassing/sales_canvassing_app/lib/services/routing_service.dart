import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static const _baseUrl = 'http://router.project-osrm.org/route/v1/driving';

  /// Fetches a route between two coordinates using OSRM public API.
  /// Returns a list of [LatLng] points representing the polyline.
  static Future<List<LatLng>> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final url = Uri.parse('$_baseUrl/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch route (status ${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    final List<dynamic> coords = data['routes'][0]['geometry']['coordinates'] as List<dynamic>;
    // OSRM returns [lon, lat] pairs.
    return coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
  }
}
