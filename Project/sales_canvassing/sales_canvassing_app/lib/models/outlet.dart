class Outlet {
  final int outletId;
  final String outletCode;
  final String outletName;
  final String address;
  final double? latitude;
  final double? longitude;
  final String priority;
  final String storeType;
  final String ownerName;
  final String phone;
  final double creditLimit;
  final double outstanding;

  Outlet({
    required this.outletId,
    required this.outletCode,
    required this.outletName,
    required this.address,
    this.latitude,
    this.longitude,
    required this.priority,
    required this.storeType,
    required this.ownerName,
    required this.phone,
    required this.creditLimit,
    required this.outstanding,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      outletId: _toInt(json['outlet_id']),
      outletCode: _toString(json['outlet_code']),
      outletName: _toString(json['outlet_name']),
      address: _toString(json['address']),
      latitude: _toDoubleNullable(json['latitude']),
      longitude: _toDoubleNullable(json['longitude']),
      priority: _toString(json['priority']),
      storeType: _toString(json['store_type']),
      ownerName: _toString(json['owner_name']),
      phone: _toString(json['phone']),
      creditLimit: _toDouble(json['credit_limit']),
      outstanding: _toDouble(json['rep_outstanding'] ?? json['outstanding']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _toDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String _toString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'outlet_code': outletCode,
      'outlet_name': outletName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'priority': priority,
      'store_type': storeType,
      'owner_name': ownerName,
      'phone': phone,
      'credit_limit': creditLimit,
    };
  }
}
