import 'api_client.dart';
import '../models/invoice.dart';
import '../models/payment_record.dart';

class CollectionService {
  static Future<List<Invoice>> fetchOutstandingInvoices() async {
    try {
      final data = await ApiClient.get('/collections/outstanding');
      if (data is List) {
        return data.map((json) => Invoice.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load invoices: $e');
    }
  }

  static Future<double> fetchOutstandingBalance() async {
    try {
      final data = await ApiClient.getMap('/collections/balance');
      return _toDouble(data['total_outstanding']);
    } catch (e) {
      final invoices = await fetchOutstandingInvoices();
      return invoices.fold<double>(0, (sum, inv) => sum + inv.outstanding);
    }
  }

  static Future<Map<String, dynamic>> recordPayment({
    required int orderId,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
  }) async {
    return await ApiClient.postMap('/collections/pay', {
      'orderId': orderId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'referenceNumber': referenceNumber ?? '',
    });
  }

  static Future<List<PaymentRecord>> fetchPaymentHistory() async {
    try {
      final data = await ApiClient.get('/collections/history');
      if (data is List) {
        return data.map((json) => PaymentRecord.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
