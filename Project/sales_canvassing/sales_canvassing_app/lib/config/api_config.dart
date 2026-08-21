import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Konfigurasi API terpusat
class ApiConfig {
  // true = Railway (Production)
  // false = Localhost (Development)
  static const bool useProduction = true;

  // URL Railway
  static const String productionUrl =
      'https://salescanvassingbackend-production.up.railway.app/api';

  static const String _envHost = String.fromEnvironment('API_HOST');

  static const int port = int.fromEnvironment(
    'API_PORT',
    defaultValue: 3000,
  );

  static String get host {
    if (_envHost.isNotEmpty) return _envHost;

    if (kIsWeb) return 'localhost';

    try {
      if (Platform.isAndroid) {
        return '10.0.2.2';
      }
    } catch (_) {}

    return 'localhost';
  }

  static String get localUrl => 'http://$host:$port/api';

  static String get baseUrl => useProduction ? productionUrl : localUrl;
}
