import 'package:latlong2/latlong.dart';
import '../models/outlet.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ApiService {
  static Future<List<Outlet>> fetchOutlets() async {
    final userId = await AuthService.getUserId();
    final role = await AuthService.getUserRole();
    final endpoint = role == 'rep' && userId > 0
        ? '/outlets?rep_id=$userId'
        : '/outlets';
    final data = await ApiClient.get(endpoint);

    if (data is List) {
      return data.map((e) => Outlet.fromJson(e)).toList();
    }
    throw Exception('Gagal memuat outlet');
  }

  static Future<List<LatLng>> fetchRoutePoints() async {
    final data = await ApiClient.get('/route');

    if (data is List) {
      return data
          .map((p) => LatLng(
                (p['latitude'] as num).toDouble(),
                (p['longitude'] as num).toDouble(),
              ))
          .toList();
    }
    throw Exception('Gagal memuat rute');
  }

  static Future<List<Geofence>> fetchGeofences() async {
    final data = await ApiClient.get('/geofences');

    if (data is List) {
      return data.map((e) => Geofence.fromJson(e)).toList();
    }
    throw Exception('Gagal memuat geofence');
  }
}

class Geofence {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radius;

  Geofence.fromJson(Map<String, dynamic> json)
      : id = json['id'].toString(),
        name = json['name'] ?? '',
        lat = (json['lat'] is int
            ? (json['lat'] as int).toDouble()
            : (json['lat'] as double?) ?? 0.0),
        lng = (json['lng'] is int
            ? (json['lng'] as int).toDouble()
            : (json['lng'] as double?) ?? 0.0),
        radius = (json['radius'] is int
            ? (json['radius'] as int).toDouble()
            : (json['radius'] as double?) ?? 50.0);
}
