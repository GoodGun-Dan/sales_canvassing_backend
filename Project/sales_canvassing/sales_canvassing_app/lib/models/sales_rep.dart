class SalesRep {
  final int employeeId;
  final String name;
  final String email;
  final String phone;
  final String username;
  final String role;
  final DateTime joinedDate;
  final bool isActive;
  final int totalVisits;
  final double totalSales;

  SalesRep({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.phone,
    required this.username,
    required this.role,
    required this.joinedDate,
    required this.isActive,
    required this.totalVisits,
    required this.totalSales,
  });

  factory SalesRep.fromJson(Map<String, dynamic> json) {
    return SalesRep(
      employeeId: _toInt(json['employee_id']),
      name: _toString(json['name']),
      email: _toString(json['email']),
      phone: _toString(json['phone']),
      username: _toString(json['username']),
      role: _toString(json['role']),
      joinedDate: _toDateTime(json['joined_date']),
      isActive: json['is_active'] == true,
      totalVisits: _toInt(json['total_visits']),
      totalSales: _toDouble(json['total_sales']),
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

  static String _toString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
