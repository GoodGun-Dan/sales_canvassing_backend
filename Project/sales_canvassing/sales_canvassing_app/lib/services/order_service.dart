import 'api_client.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class OrderService {
  static Future<List<Product>> fetchProducts() async {
    final data = await ApiClient.get('/products');
    if (data is List) {
      return data.map((json) => Product.fromJson(json)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> submitOrder({
    required int outletId,
    required List<CartItem> items,
    required double total,
    required String paymentMethod,
    required String orderType,
    int? promotionId,
  }) async {
    return ApiClient.postMap('/orders', {
      'outletId': outletId,
      'orderType': orderType,
      if (promotionId != null) 'promotionId': promotionId,
      'items': items
          .map(
            (item) => {
              'productId': item.product.productId,
              'quantity': item.quantity,
              'price': item.product.price,
            },
          )
          .toList(),
      'total': total,
      'paymentMethod': paymentMethod,
    });
  }
}
