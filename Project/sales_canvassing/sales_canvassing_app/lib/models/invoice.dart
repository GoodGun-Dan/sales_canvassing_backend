class Invoice {
  final int orderId;
  final String orderNumber;
  final String outletName;
  final double total;
  final double paidAmount;
  final double outstanding;
  final String dueDate;
  final String status;

  Invoice({
    required this.orderId,
    required this.orderNumber,
    required this.outletName,
    required this.total,
    required this.paidAmount,
    required this.outstanding,
    required this.dueDate,
    required this.status,
  });

  double get progress {
    if (total <= 0) return 0;
    return (paidAmount / total) * 100;
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      orderId: _toInt(json['order_id']),
      orderNumber: _toString(json['order_number']),
      outletName: _toString(json['outlet_name']),
      total: _toDouble(json['total']),
      paidAmount: _toDouble(json['paid_amount']),
      outstanding: _toDouble(json['outstanding']),
      dueDate: _toString(json['due_date']),
      status: _toString(json['status']),
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
