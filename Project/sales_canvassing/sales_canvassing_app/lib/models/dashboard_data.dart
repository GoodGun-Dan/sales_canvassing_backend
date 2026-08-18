class DashboardData {
  final List<VisitPlanItem> visitPlan;
  final Metrics metrics;
  final DateTime lastSync;

  DashboardData({
    required this.visitPlan,
    required this.metrics,
    required this.lastSync,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final list = json['visitPlan'];
    final List<VisitPlanItem> planItems = list is List
        ? list
            .map((i) => VisitPlanItem.fromJson(
                  Map<String, dynamic>.from(i as Map),
                ))
            .toList()
        : [];

    return DashboardData(
      visitPlan: planItems,
      metrics: Metrics.fromJson(
        Map<String, dynamic>.from(json['metrics'] as Map? ?? {}),
      ),
      lastSync: DateTime.tryParse(json['lastSync']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class VisitPlanItem {
  final int outletId;
  final String outletName;
  final String address;
  final String priority;
  final String visitTime;
  final String status;
  final double latitude;
  final double longitude;

  VisitPlanItem({
    required this.outletId,
    required this.outletName,
    required this.address,
    required this.priority,
    required this.visitTime,
    required this.status,
    required this.latitude,
    required this.longitude,
  });

  factory VisitPlanItem.fromJson(Map<String, dynamic> json) {
    return VisitPlanItem(
      outletId: _toInt(json['outlet_id']),
      outletName: json['outlet_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'C',
      visitTime: json['visit_time']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'Planned',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class Metrics {
  final double totalSalesToday;
  final double strikeRate;
  final int pendingOrders;

  Metrics({
    required this.totalSalesToday,
    required this.strikeRate,
    required this.pendingOrders,
  });

  factory Metrics.fromJson(Map<String, dynamic> json) {
    return Metrics(
      totalSalesToday: _toDouble(json['totalSalesToday']),
      strikeRate: _toDouble(json['strikeRate']),
      pendingOrders: _toInt(json['pendingOrders']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
