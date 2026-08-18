import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'services/api_client.dart';
import 'login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_dashboard.dart' hide LoginScreen;
import 'screens/supervisor_dashboard.dart';
import 'screens/route_planning_screen.dart';
import 'screens/gps_tracking_screen.dart';
import 'screens/order_taking_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/outlet_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/visits_screen.dart';
import 'screens/merchandising_screen.dart';
import 'services/auth_service.dart';

/// Key untuk membuka drawer dari layar anak di MainNavigation.
final GlobalKey<ScaffoldState> mainNavScaffoldKey = GlobalKey<ScaffoldState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SalesCanvas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data == true) {
          return const RoleBasedNavigator();
        }
        return const LoginScreen();
      },
    );
  }
}

class RoleBasedNavigator extends StatelessWidget {
  const RoleBasedNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AuthService.getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = snapshot.data ?? 'rep';
        if (role == 'admin' || role == 'manager') {
          return const AdminDashboard();
        }
        if (role == 'supervisor') {
          return const SupervisorDashboard();
        }
        return const MainNavigation();
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  String _userName = '';
  String _userRole = '';

  static final List<Widget> _screens = [
    const DashboardScreen(),
    const VisitsScreen(),
    const RoutePlanningScreen(),
    const GpsTrackingScreen(),
    const OrderTakingScreen(),
    const StockScreen(),
    const CollectionsScreen(),
    const AnalyticsScreen(),
    const MerchandisingScreen(),
    const OutletScreen(),
    const SettingsScreen(),
  ];

  Timer? _liveLocationTimer;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final name = await AuthService.getUserName();
    final role = await AuthService.getUserRole();
    if (!mounted) return;
    setState(() {
      _userName = name;
      _userRole = role;
    });
    // Only start location updates for sales reps
    if (role == 'rep') {
      _startLiveLocationUpdates();
    }
  }

  @override
  void dispose() {
    _liveLocationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLiveLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location service is disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied forever');
      return;
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      _sendCurrentLocation();
      _liveLocationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _sendCurrentLocation();
      });
    }
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ApiClient.post('/visits/location', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      debugPrint('Live location updated: ${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      debugPrint('Error sending live location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: mainNavScaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName.isEmpty ? 'Sales User' : _userName,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    _userRole.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.dashboard, 'Dashboard', 0),
            _buildDrawerItem(Icons.event, 'Kunjungan', 1),
            _buildDrawerItem(Icons.route, 'Route Planning', 2),
            _buildDrawerItem(Icons.location_on, 'GPS Tracking', 3),
            _buildDrawerItem(Icons.shopping_cart, 'Order Taking', 4),
            _buildDrawerItem(Icons.inventory, 'Stock Management', 5),
            _buildDrawerItem(Icons.payments, 'Collections', 6),
            _buildDrawerItem(Icons.analytics, 'Analytics', 7),
            _buildDrawerItem(Icons.storefront, 'Merchandising', 8),
            _buildDrawerItem(Icons.store, 'Outlet Management', 9),
            _buildDrawerItem(Icons.settings, 'Settings', 10),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final navigator = Navigator.of(context);
                await AuthService.logout();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final selected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.blue : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? Colors.blue : Colors.black,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }
}
