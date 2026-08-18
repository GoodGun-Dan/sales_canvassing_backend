class SalesStatistic {
  final DateTime date;
  final double totalSales;
  final int totalOrders;
  final int totalVisits;
  final double strikeRate;

  SalesStatistic({
    required this.date,
    required this.totalSales,
    required this.totalOrders,
    required this.totalVisits,
    required this.strikeRate,
  });

  factory SalesStatistic.fromJson(Map<String, dynamic> json) {
    return SalesStatistic(
      date: DateTime.tryParse(_toString(json['date'])) ?? DateTime.now(),
      totalSales: _toDouble(json['total_sales']),
      totalOrders: _toInt(json['total_orders']),
      totalVisits: _toInt(json['total_visits']),
      strikeRate: _toDouble(json['strike_rate']),
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
}
