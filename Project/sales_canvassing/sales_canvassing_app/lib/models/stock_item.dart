import 'package:flutter/material.dart';

class StockItem {
  final int productId;
  final String productName;
  final String productCode;
  final int distributorStock;
  final int vanStock;
  final int outletStock;
  final int minStock;

  StockItem({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.distributorStock,
    required this.vanStock,
    required this.outletStock,
    required this.minStock,
  });

  int get totalStock => distributorStock + vanStock + outletStock;

  String get status {
    if (distributorStock < minStock) return 'Critical';
    if (vanStock < 10) return 'Low';
    return 'Good';
  }

  Color get statusColor {
    if (distributorStock < minStock) return Colors.red;
    if (vanStock < 10) return Colors.orange;
    return Colors.green;
  }

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      productId: _toInt(json['product_id']),
      productName: _toString(json['product_name']),
      productCode: _toString(json['product_code']),
      distributorStock: _toInt(json['distributor_stock']),
      vanStock: _toInt(json['van_stock']),
      outletStock: _toInt(json['outlet_stock']),
      minStock: _toInt(json['min_stock']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _toString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }
}
