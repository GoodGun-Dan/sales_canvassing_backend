import 'package:flutter/material.dart';
import '../models/outlet.dart';
import '../models/product.dart';
import '../models/promotion.dart';
import '../models/cart_item.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/promotion_service.dart';
import '../widgets/app_drawer_scaffold.dart';
import '../widgets/form_dropdown.dart';

class OrderTakingScreen extends StatefulWidget {
  const OrderTakingScreen({super.key});

  @override
  State<OrderTakingScreen> createState() => _OrderTakingScreenState();
}

class _OrderTakingScreenState extends State<OrderTakingScreen> {
  List<Product> _products = [];
  List<Outlet> _outlets = [];
  List<Promotion> _promotions = [];
  final List<CartItem> _cart = [];

  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedOutletId;
  String _selectedPaymentMethod = 'Cash';
  String _selectedOrderType = 'Sales';
  int? _selectedPromotionId;

  final List<String> _paymentMethods = ['Cash', 'Transfer', 'UPI', 'Wallet'];
  final List<String> _orderTypes = ['Sales', 'Pre-order', 'Return', 'FOC'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await AuthService.getUserId();
      final role = await AuthService.getUserRole();

      final products = await OrderService.fetchProducts();
      final outlets = await _loadOutlets(userId, role);
      final promotions = await PromotionService.fetchActive();

      if (!mounted) return;
      setState(() {
        _products = products;
        _outlets = outlets;
        _promotions = promotions;
        _selectedOutletId =
            outlets.isNotEmpty ? outlets.first.outletId : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<List<Outlet>> _loadOutlets(int userId, String role) async {
    final endpoint = role == 'rep' && userId > 0
        ? '/outlets?rep_id=$userId'
        : '/outlets';
    final data = await ApiClient.get(endpoint);
    if (data is List) {
      return data.map((json) => Outlet.fromJson(json)).toList();
    }
    return [];
  }

  Outlet? get _selectedOutlet {
    if (_selectedOutletId == null) return null;
    try {
      return _outlets.firstWhere((o) => o.outletId == _selectedOutletId);
    } catch (_) {
      return null;
    }
  }

  void _addToCart(Product product) {
    if (_selectedOrderType == 'Sales') {
      final inCart = _cart
          .where((item) => item.product.productId == product.productId)
          .fold<int>(0, (sum, item) => sum + item.quantity);
      if (inCart >= product.stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stok van ${product.productName} hanya ${product.stock}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      final index = _cart
          .indexWhere((item) => item.product.productId == product.productId);
      if (index >= 0) {
        _cart[index].quantity++;
      } else {
        _cart.add(CartItem(product: product, quantity: 1));
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.productName} ditambahkan'),
        backgroundColor: Colors.green,
      ),
    );
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + item.subtotal);

  double get _discount {
    if (_selectedOrderType == 'FOC') return _subtotal;
    if (_selectedPromotionId != null) {
      final promo = _promotions
          .where((p) => p.promotionId == _selectedPromotionId)
          .firstOrNull;
      if (promo != null && promo.type == 'Value-based') {
        final minVal = (promo.conditions['min_value'] as num?)?.toDouble() ?? 0;
        if (_subtotal >= minVal) {
          final pct = (promo.reward['discount_percent'] as num?)?.toDouble() ?? 0;
          final amt = (promo.reward['discount_amount'] as num?)?.toDouble() ?? 0;
          if (pct > 0) return _subtotal * pct / 100;
          if (amt > 0) return amt;
        }
      }
    }
    return 0;
  }

  double get _tax {
    if (_selectedOrderType == 'FOC') return 0;
    return (_subtotal - _discount) * 0.10;
  }

  double get _total {
    if (_selectedOrderType == 'FOC') return 0;
    if (_selectedOrderType == 'Return') return _subtotal;
    return _subtotal - _discount + _tax;
  }

  double get _availableCredit {
    final outlet = _selectedOutlet;
    if (outlet == null) return 0;
    return outlet.creditLimit - outlet.outstanding;
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawerScaffold(
      title: 'Order Taking',
      actions: [
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.shopping_cart),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_cart.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: _showCartBottomSheet,
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_outlets.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada outlet di jadwal kunjungan Anda.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final outlet = _selectedOutlet;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Outlet: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: DropdownButton<int>(
                      value: _selectedOutletId,
                      isExpanded: true,
                      items: _outlets
                          .map((o) => DropdownMenuItem(
                                value: o.outletId,
                                child: Text(o.outletName),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedOutletId = v),
                    ),
                  ),
                ],
              ),
              if (outlet != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Credit: Rp ${outlet.creditLimit.toStringAsFixed(0)} | '
                  'Outstanding: Rp ${outlet.outstanding.toStringAsFixed(0)} | '
                  'Tersedia: Rp ${_availableCredit.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _availableCredit < _total && _selectedOrderType != 'FOC'
                        ? Colors.red
                        : Colors.black87,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Tipe: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedOrderType,
                      isExpanded: true,
                      items: _orderTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedOrderType = v ?? 'Sales';
                        if (_selectedOrderType == 'FOC') {
                          _selectedPromotionId = null;
                        }
                      }),
                    ),
                  ),
                ],
              ),
              if (_promotions.isNotEmpty && _selectedOrderType != 'FOC') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedPromotionId,
                  decoration: const InputDecoration(
                    labelText: 'Promosi (opsional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tanpa promosi'),
                    ),
                    ..._promotions.map(
                      (p) => DropdownMenuItem<int?>(
                        value: p.promotionId,
                        child: Text('${p.promotionCode} — ${p.type}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedPromotionId = v),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _products.isEmpty
              ? const Center(child: Text('Tidak ada produk'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Card(
                      child: InkWell(
                        onTap: () => _addToCart(product),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory, size: 40, color: Colors.blue),
                              const SizedBox(height: 8),
                              Text(
                                product.productName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('Rp ${product.price.toStringAsFixed(0)}'),
                              Text(
                                'Stok van: ${product.stock}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: product.stock < 5
                                      ? Colors.red
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  children: [
                    Text(
                      'Keranjang — $_selectedOrderType',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Expanded(
                      child: _cart.isEmpty
                          ? const Center(child: Text('Keranjang kosong'))
                          : ListView.builder(
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final item = _cart[index];
                                return ListTile(
                                  title: Text(item.product.productName),
                                  subtitle: Text(
                                    'Rp ${item.product.price.toStringAsFixed(0)} x ${item.quantity}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, color: Colors.red),
                                        onPressed: () {
                                          setModalState(() => item.quantity--);
                                          if (item.quantity <= 0) _cart.removeAt(index);
                                          setState(() {});
                                        },
                                      ),
                                      Text('${item.quantity}'),
                                      IconButton(
                                        icon: const Icon(Icons.add, color: Colors.green),
                                        onPressed: () {
                                          setModalState(() => item.quantity++);
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    _buildRow('Subtotal', _subtotal),
                    _buildRow('Diskon', -_discount, isNegative: true),
                    _buildRow('Pajak', _tax),
                    _buildRow('Total', _total, isTotal: true),
                    const SizedBox(height: 8),
                    FormDropdown<String>(
                      labelText: 'Metode Pembayaran',
                      value: _selectedPaymentMethod,
                      items: _paymentMethods
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) {
                        setModalState(() => _selectedPaymentMethod = v ?? 'Cash');
                        setState(() => _selectedPaymentMethod = v ?? 'Cash');
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _submitOrder(sheetContext),
                        icon: const Icon(Icons.check),
                        label: const Text('Submit Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitOrder(BuildContext sheetContext) async {
    if (_cart.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang kosong'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedOutletId == null) return;

    if (['Sales', 'Pre-order'].contains(_selectedOrderType) &&
        _total > _availableCredit &&
        (_selectedOutlet?.creditLimit ?? 0) > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Melebihi credit limit. Tersedia: Rp ${_availableCredit.toStringAsFixed(0)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await OrderService.submitOrder(
        outletId: _selectedOutletId!,
        items: _cart,
        total: _total,
        paymentMethod: _selectedPaymentMethod,
        orderType: _selectedOrderType,
        promotionId: _selectedPromotionId,
      );

      if (!mounted) return;
      setState(() {
        _cart.clear();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order ${result['orderType']} berhasil! No: ${result['orderNumber']}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      if (sheetContext.mounted) Navigator.pop(sheetContext);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildRow(String label, double amount,
      {bool isNegative = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(
            '${isNegative ? '-' : ''}Rp ${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isNegative ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
