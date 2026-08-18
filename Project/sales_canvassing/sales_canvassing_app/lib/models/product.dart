class Product {
  final int productId;
  final String productCode;
  final String productName;
  final double price;
  final int stock;
  final String unitName;

  Product({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.price,
    required this.stock,
    required this.unitName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: _toInt(json['product_id']),
      productCode: _toString(json['product_code']),
      productName: _toString(json['product_name']),
      price: _toDouble(json['price']),
      stock: _toInt(json['stock']),
      unitName: _toString(json['unit_name']),
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
