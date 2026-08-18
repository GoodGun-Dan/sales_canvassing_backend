import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/app_drawer_scaffold.dart';
import '../services/api_client.dart';

class GpsTrackingScreen extends StatefulWidget {
  final int? repId;
  final String? repName;

  const GpsTrackingScreen({super.key, this.repId, this.repName});

  @override
  State<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

class _GpsTrackingScreenState extends State<GpsTrackingScreen> {
  late MapController _mapController;
  final List<Marker> _markers = [];
  final List<Polygon> _geofencePolygons = [];
  final List<dynamic> _geofences = [];
  Position? _currentPosition;
  bool _isTracking = false;
  bool _isLoading = true;
  bool _isVisitBusy = false;
  String? _errorMessage;
  String? _lastCheckInStatus;
  int? _activeVisitId;
  String? _activeOutletName;

  // Informasi lokasi realtime
  DateTime? _lastLocationUpdate;
  bool _isLiveLocation = false;
  bool _waitingForLocation = false;

  // Titik default (Jakarta) dipakai sebagai center peta saat belum ada lokasi sales
  static const LatLng _defaultCenter = LatLng(-6.2088, 106.8456);

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.repId != null) {
      // Mode Manager: tampilkan lokasi sales rep, polling setiap 10 detik
      _loadRepLocation();
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _loadRepLocation();
      });
    } else {
      // Mode Sales: tampilkan lokasi diri sendiri
      _initLocation();
    }
    _loadGeofences();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Ambil lokasi sales rep dari backend (mode Manager).
  /// Backend akan cek last_lat/last_lng (live, dikirim setiap 30 detik oleh app sales)
  /// lalu fallback ke lokasi check-in terakhir hari ini.
  Future<void> _loadRepLocation() async {
    try {
      final data =
          await ApiClient.get('/admin/sales-reps/${widget.repId}/location');
      if (!mounted) return;

      if (data != null &&
          data['latitude'] != null &&
          data['longitude'] != null) {
        final double lat = (data['latitude'] as num).toDouble();
        final double lng = (data['longitude'] as num).toDouble();
        final bool isLive = data['is_live'] == true;
        final String? lastUpdateStr = data['last_update'] as String?;

        // Buat Position dummy dari data backend
        final pos = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        setState(() {
          _currentPosition = pos;
          _isLoading = false;
          _errorMessage = null;
          _waitingForLocation = false;
          _isLiveLocation = isLive;
          _lastLocationUpdate = lastUpdateStr != null
              ? DateTime.tryParse(lastUpdateStr)?.toLocal()
              : DateTime.now();
          _updateMarker(pos);
        });

        // Pindahkan kamera ke posisi sales
        try {
          _mapController.move(LatLng(lat, lng), 16.0);
        } catch (_) {}
      } else {
        // Belum ada lokasi hari ini — tampilkan peta dengan default center,
        // terus polling (jangan tampilkan error, cukup banner "menunggu")
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
            _waitingForLocation = true;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _waitingForLocation = _currentPosition == null;
        // Hanya tampilkan error kalau belum pernah dapat lokasi sama sekali
        if (_currentPosition == null) {
          _errorMessage = 'Gagal memuat lokasi: $e';
        }
      });
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _errorMessage = 'Aktifkan GPS Anda');
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _errorMessage = 'Izin lokasi ditolak');
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _errorMessage = 'Izin lokasi ditolak permanen');
      }
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _isLoading = false;
          _updateMarker(pos);
        });
        _startTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal mendapat lokasi: $e');
      }
    }
  }

  void _startTracking() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (!mounted || !_isTracking) return;
      setState(() {
        _currentPosition = position;
        _updateMarker(position);
      });
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    });
    if (mounted) {
      setState(() => _isTracking = true);
    }
  }

  void _updateMarker(Position pos) {
    _markers.clear();
    _markers.add(
      Marker(
        point: LatLng(pos.latitude, pos.longitude),
        width: 48,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: widget.repId != null ? Colors.red : Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
          ),
          child: Icon(
            widget.repId != null ? Icons.person_pin : Icons.navigation,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Future<void> _loadGeofences() async {
    try {
      final endpoint = widget.repId != null
          ? '/geofences?rep_id=${widget.repId}'
          : '/geofences';
      final data = await ApiClient.get(endpoint);
      if (!mounted) return;
      setState(() {
        _geofences
          ..clear()
          ..addAll(data is List ? data : []);
      });
      _createGeofencePolygons();
    } catch (e) {
      debugPrint('Error loading geofences: $e');
    }
  }

  void _createGeofencePolygons() {
    _geofencePolygons.clear();
    for (var gf in _geofences) {
      final center = LatLng(
        (gf['lat'] as num).toDouble(),
        (gf['lng'] as num).toDouble(),
      );
      final radius = (gf['radius'] as num).toDouble();
      _geofencePolygons.add(_buildCirclePolygon(center, radius));
    }
    if (mounted) setState(() {});
  }

  Polygon _buildCirclePolygon(LatLng center, double radius) {
    const int steps = 32;
    final List<LatLng> points = [];
    const double metersPerDegree = 111320.0;

    for (int i = 0; i < steps; i++) {
      double angle = (i * 2 * pi) / steps;
      double deltaLat = (radius / metersPerDegree) * sin(angle);
      double deltaLng =
          (radius / (metersPerDegree * cos(center.latitude * pi / 180))) *
              cos(angle);
      points.add(
        LatLng(center.latitude + deltaLat, center.longitude + deltaLng),
      );
    }

    return Polygon(
      points: points,
      color: Colors.blue.withValues(alpha: 0.2),
      borderColor: Colors.blue,
      borderStrokeWidth: 2,
    );
  }

  Future<void> _checkIn(int outletId, String outletName) async {
    if (_currentPosition == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tunggu GPS...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isVisitBusy = true);

    try {
      final result = await ApiClient.post('/visits/checkin', {
        'outletId': outletId,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'visitReason': 'Regular Sales Call',
      });

      if (!mounted) return;
      setState(() {
        _lastCheckInStatus = '✅ ${result['message']}';
        _isVisitBusy = false;
        _activeVisitId = result['visitId'] is int
            ? result['visitId']
            : int.tryParse(result['visitId'].toString());
        _activeOutletName = outletName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Check-in berhasil'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastCheckInStatus = '❌ $e';
        _isVisitBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _checkOut() async {
    if (_activeVisitId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada kunjungan aktif untuk check-out'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isVisitBusy = true);

    try {
      final result = await ApiClient.post('/visits/checkout', {
        'visitId': _activeVisitId,
      });

      if (!mounted) return;
      setState(() {
        _isVisitBusy = false;
        _activeVisitId = null;
        _activeOutletName = null;
        _lastCheckInStatus = '✅ ${result['message']}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Check-out berhasil'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVisitBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Titik tengah peta: gunakan posisi sales jika sudah ada, sinon default Jakarta
    final LatLng mapCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultCenter;

    final mapBody = _isLoading
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
                      onPressed:
                          widget.repId != null ? _loadRepLocation : _initLocation,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // ── Banner "menunggu lokasi" (hanya mode Manager, saat belum ada lokasi) ──
                  if (widget.repId != null && _waitingForLocation)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.shade100,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Menunggu lokasi ${widget.repName ?? 'sales'}... '
                              'Update otomatis setiap 10 detik.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Peta (selalu tampil) ──
                  Expanded(
                    flex: 3,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: mapCenter,
                        initialZoom: _currentPosition != null ? 16 : 13,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.sales_canvassing_app',
                        ),
                        PolygonLayer(polygons: _geofencePolygons),
                        MarkerLayer(markers: _markers),
                      ],
                    ),
                  ),

                  // ── Panel Info Bawah ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.repId != null) ...[
                          // ── Mode Manager ──
                          Text(
                            'Memantau: ${widget.repName ?? 'Sales'}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoColumn(
                                'Status Lokasi',
                                _waitingForLocation
                                    ? 'Menunggu...'
                                    : _isLiveLocation
                                        ? '🟢 Live'
                                        : '🔵 Check-in',
                              ),
                              _infoColumn(
                                'Update Terakhir',
                                _formatTime(_lastLocationUpdate),
                              ),
                              _infoColumn(
                                'Target Outlet',
                                '${_geofences.length}',
                              ),
                            ],
                          ),
                          if (!_waitingForLocation &&
                              _currentPosition != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}, '
                              'Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ] else ...[
                          // ── Mode Sales ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoColumn(
                                'Speed',
                                _currentPosition != null
                                    ? '${_currentPosition!.speed.toStringAsFixed(1)} km/h'
                                    : '-',
                              ),
                              _infoColumn(
                                'Accuracy',
                                _currentPosition != null
                                    ? '${_currentPosition!.accuracy.toStringAsFixed(0)} m'
                                    : '-',
                              ),
                              _infoColumn(
                                'Outlet',
                                _geofences.isNotEmpty
                                    ? '${_geofences.length}'
                                    : '0',
                              ),
                            ],
                          ),
                          if (_lastCheckInStatus != null) ...[
                            const SizedBox(height: 8),
                            Text(_lastCheckInStatus!),
                          ],
                          if (_activeVisitId != null &&
                              _activeOutletName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Kunjungan aktif: $_activeOutletName (ID: $_activeVisitId)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _isVisitBusy ? null : _checkOut,
                              icon: const Icon(Icons.logout),
                              label: const Text('Check-out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (_geofences.isEmpty)
                            const Text(
                              'Tidak ada outlet di jadwal kunjungan hari ini.',
                              textAlign: TextAlign.center,
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _geofences.map((gf) {
                                final outletId = gf['id'] is int
                                    ? gf['id'] as int
                                    : int.parse(gf['id'].toString());
                                final name =
                                    gf['name']?.toString() ?? 'Outlet';
                                return ElevatedButton(
                                  onPressed: _isVisitBusy
                                      ? null
                                      : () => _checkIn(outletId, name),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text('Check-in $name'),
                                );
                              }).toList(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );

    if (widget.repId != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('GPS: ${widget.repName ?? 'Sales'}'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: mapBody,
      );
    }

    return AppDrawerScaffold(
      title: 'GPS Tracking & Geofencing',
      actions: [
        IconButton(
          icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
          onPressed: () => setState(() => _isTracking = !_isTracking),
        ),
      ],
      body: mapBody,
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
