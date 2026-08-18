class PaymentRecord {
  final int paymentId;
  final int orderId;
  final double amount;
  final String paymentMethod;
  final DateTime paymentDate;
  final String referenceNumber;

  PaymentRecord({
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    required this.referenceNumber,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      paymentId: _toInt(json['payment_id']),
      orderId: _toInt(json['order_id']),
      amount: _toDouble(json['amount']),
      paymentMethod: _toString(json['payment_method']),
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date']) ?? DateTime.now()
          : DateTime.now(),
      referenceNumber: _toString(json['reference_number']),
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
