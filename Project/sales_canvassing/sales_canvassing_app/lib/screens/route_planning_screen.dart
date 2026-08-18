import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer_scaffold.dart';
import '../services/routing_service.dart';

class RoutePlanningScreen extends StatefulWidget {
  final int? selectedOutletId;
  final String? selectedOutletName;
  final double? selectedOutletLat;
  final double? selectedOutletLng;
  final int? repId;

  const RoutePlanningScreen({
    super.key,
    this.selectedOutletId,
    this.selectedOutletName,
    this.selectedOutletLat,
    this.selectedOutletLng,
    this.repId,
  });

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  List<dynamic> _outlets = [];
  bool _isLoading = true;
  bool _isGettingLocation = true;
  String? _errorMessage;
  Position? _currentPosition;
  int _currentUserId = 0;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final userId = await AuthService.getUserId();
    final role = await AuthService.getUserRole();
    setState(() {
      _currentUserId = userId;
      _userRole = role;
    });
    _initLocationAndLoad();
  }

  Future<void> _initLocationAndLoad() async {
    await _getCurrentLocation();
    await _loadOutlets();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Aktifkan GPS Anda';
            _isGettingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Izin lokasi ditolak';
              _isGettingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Izin lokasi ditolak permanen';
            _isGettingLocation = false;
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _isGettingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mendapat lokasi: $e';
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _loadOutlets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String endpoint;
      if (widget.repId != null) {
        endpoint = '/outlets?rep_id=${widget.repId}';
      } else if (_userRole == 'rep') {
        endpoint = '/outlets?rep_id=$_currentUserId';
      } else {
        endpoint = '/outlets';
      }

      final data = await ApiClient.get(endpoint);
      if (data != null && data is List) {
        setState(() {
          _outlets = List<dynamic>.from(data);
          _isLoading = false;
        });
        _createMarkers();
        _createRouteToSelectedOutlet();
      } else {
        throw Exception('Data is null or not a list');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _createMarkers() {
    if (!mounted) return;
    _markers.clear();

    if (_currentPosition != null) {
      _markers.add(Marker(
        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
          child: const Icon(Icons.my_location, color: Colors.white, size: 20),
        ),
      ));
    }

    for (var outlet in _outlets) {
      final lat = _toDouble(outlet['latitude']);
      final lng = _toDouble(outlet['longitude']);
      if (lat == 0.0 && lng == 0.0) continue;
      final priority = outlet['priority'] ?? 'C';
      Color markerColor = priority == 'A'
          ? Colors.green
          : (priority == 'B' ? Colors.orange : Colors.blue);
      _markers.add(Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
          child: Center(
              child: Text(priority,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
        ),
      ));
    }

    if (widget.selectedOutletLat != null && widget.selectedOutletLng != null) {
      _markers.add(Marker(
        point: LatLng(widget.selectedOutletLat!, widget.selectedOutletLng!),
        width: 60,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3)),
          child: const Icon(Icons.location_on, color: Colors.white, size: 32),
        ),
      ));
    }
    setState(() {});
  }

  Future<void> _createRouteToSelectedOutlet() async {
    if (!mounted || _currentPosition == null || widget.selectedOutletLat == null) return;

    try {
      final routePoints = await RoutingService.getRoute(
        startLat: _currentPosition!.latitude,
        startLng: _currentPosition!.longitude,
        endLat: widget.selectedOutletLat!,
        endLng: widget.selectedOutletLng!,
      );

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          points: routePoints.isNotEmpty
              ? routePoints
              : [LatLng(_currentPosition!.latitude, _currentPosition!.longitude), LatLng(widget.selectedOutletLat!, widget.selectedOutletLng!)],
          color: Colors.green,
          strokeWidth: 5,
        ));
      });
    } catch (_) {
      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          points: [LatLng(_currentPosition!.latitude, _currentPosition!.longitude), LatLng(widget.selectedOutletLat!, widget.selectedOutletLng!)],
          color: Colors.green,
          strokeWidth: 5,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawerScaffold(
      title: 'Route Planning',
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _outlets.clear();
                _markers.clear();
                _polylines.clear();
              });
              _initLocationAndLoad();
            })
      ],
      body: _isGettingLocation || _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _initLocationAndLoad,
                          child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _outlets.isEmpty
                  ? const Center(child: Text('Tidak ada outlet yang di-assign'))
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.green.shade50,
                          child: Row(children: [
                            const Icon(Icons.info, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(widget.selectedOutletName != null
                                    ? '📍 Rute menuju: ${widget.selectedOutletName}'
                                    : '📌 Pilih outlet dari daftar')),
                          ]),
                        ),
                        Expanded(
                          flex: 2,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentPosition != null
                                  ? LatLng(_currentPosition!.latitude,
                                      _currentPosition!.longitude)
                                  : const LatLng(-6.2088, 106.8456),
                              initialZoom: 13,
                            ),
                            children: [
                              TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.example.sales_canvassing_app'),
                              PolylineLayer(polylines: _polylines),
                              MarkerLayer(markers: _markers),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _outlets.length,
                            itemBuilder: (context, index) {
                              final outlet = _outlets[index];
                              final lat = _toDouble(outlet['latitude']);
                              final lng = _toDouble(outlet['longitude']);
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: outlet['priority'] == 'A'
                                        ? Colors.green
                                        : outlet['priority'] == 'B'
                                            ? Colors.orange
                                            : Colors.blue,
                                    child: Text(outlet['priority'] ?? 'C'),
                                  ),
                                  title: Text(outlet['outlet_name'] ?? ''),
                                  subtitle: Text(outlet['address'] ?? ''),
                                  trailing: const Icon(Icons.navigation),
                                  onTap: (lat == 0.0 && lng == 0.0)
                                      ? null
                                      : () {
                                          Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      RoutePlanningScreen(
                                                        selectedOutletId:
                                                            outlet['outlet_id'],
                                                        selectedOutletName:
                                                            outlet[
                                                                'outlet_name'],
                                                        selectedOutletLat: lat,
                                                        selectedOutletLng: lng,
                                                        repId: widget.repId,
                                                      )));
                                        },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
