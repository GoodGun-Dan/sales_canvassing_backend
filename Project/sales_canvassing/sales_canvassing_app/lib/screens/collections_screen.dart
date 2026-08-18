import 'package:flutter/material.dart';
import '../services/collection_service.dart';
import '../widgets/app_drawer_scaffold.dart';
import '../widgets/form_dropdown.dart';
import '../models/invoice.dart';
import '../models/payment_record.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<Invoice> _invoices = [];
  List<PaymentRecord> _paymentHistory = [];
  double _totalOutstanding = 0;
  bool _isLoading = true;
  bool _isLoadingHistory = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Payment form
  Invoice? _selectedInvoice;
  final TextEditingController _amountController = TextEditingController();
  String _selectedPaymentMethod = 'Cash';
  final List<String> _paymentMethods = ['Cash', 'Transfer', 'UPI', 'Wallet'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invoices = await CollectionService.fetchOutstandingInvoices();
      final balance = await CollectionService.fetchOutstandingBalance();

      setState(() {
        _invoices = invoices;
        _totalOutstanding = balance;
        _isLoading = false;
      });

      await _loadPaymentHistory();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await CollectionService.fetchPaymentHistory();
      setState(() {
        _paymentHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _recordPayment() async {
    if (_selectedInvoice == null) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Masukkan jumlah pembayaran yang valid', Colors.red);
      return;
    }

    if (amount > _selectedInvoice!.outstanding) {
      _showSnackBar(
        'Jumlah pembayaran melebihi outstanding (${_formatCurrency(_selectedInvoice!.outstanding)})',
        Colors.red,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await CollectionService.recordPayment(
        orderId: _selectedInvoice!.orderId,
        amount: amount,
        paymentMethod: _selectedPaymentMethod,
      );

      await _loadData();
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Pembayaran berhasil dicatat', Colors.green);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _isSubmitting = false);
      _amountController.clear();
      _selectedInvoice = null;
    }
  }

  void _showPaymentBottomSheet(Invoice invoice) {
    _selectedInvoice = invoice;
    _amountController.clear();
    _selectedPaymentMethod = 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Record Payment',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(invoice.orderNumber,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(invoice.outletName),
                        const SizedBox(height: 4),
                        Text(
                            'Outstanding: ${_formatCurrency(invoice.outstanding)}',
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount',
                      border: OutlineInputBorder(),
                      prefixText: 'Rp ',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  FormDropdown<String>(
                    labelText: 'Payment Method',
                    value: _selectedPaymentMethod,
                    items: _paymentMethods.map((method) {
                      return DropdownMenuItem(
                          value: method, child: Text(method));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => _selectedPaymentMethod = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _recordPayment,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        )}';
  }

  // PERBAIKAN: _formatDate menerima String, bukan DateTime
  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  double _getProgressPercentage(Invoice invoice) {
    final paid = invoice.total - invoice.outstanding;
    if (invoice.total == 0) return 0;
    return (paid / invoice.total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawerScaffold(
      title: 'Collections',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadData, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Colors.blue, Colors.blueAccent]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text('Total Outstanding',
                              style: TextStyle(color: Colors.white70)),
                          Text(_formatCurrency(_totalOutstanding),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(tabs: [
                              Tab(text: 'Outstanding Invoices'),
                              Tab(text: 'Payment History'),
                            ]),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildOutstandingTab(),
                                  _buildPaymentHistoryTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOutstandingTab() {
    if (_invoices.isEmpty) {
      return const Center(child: Text('Tidak ada invoice outstanding'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _invoices.length,
        itemBuilder: (context, index) {
          final invoice = _invoices[index];
          final progress = _getProgressPercentage(invoice);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                ListTile(
                  title: Text(invoice.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(invoice.outletName),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatCurrency(invoice.outstanding),
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(invoice.status),
                        backgroundColor: invoice.status == 'Overdue'
                            ? Colors.red.shade100
                            : Colors.orange.shade100,
                        labelStyle: TextStyle(
                            color: invoice.status == 'Overdue'
                                ? Colors.red
                                : Colors.orange,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor: Colors.grey.shade200,
                              color: progress >= 100
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${progress.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Due: ${_formatDate(invoice.dueDate)}',
                              style: const TextStyle(fontSize: 12)),
                          Text('Total: ${_formatCurrency(invoice.total)}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (invoice.outstanding > 0)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showPaymentBottomSheet(invoice),
                            icon: const Icon(Icons.payment, size: 18),
                            label: const Text('Record Payment'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: const BorderSide(color: Colors.green)),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paymentHistory.isEmpty) {
      return const Center(child: Text('Belum ada history pembayaran'));
    }

    return RefreshIndicator(
      onRefresh: _loadPaymentHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _paymentHistory.length,
        itemBuilder: (context, index) {
          final payment = _paymentHistory[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.payment, color: Colors.green)),
              title: Text(_formatCurrency(payment.amount)),
              subtitle: Text(payment.paymentMethod),
              trailing:
                  Text(_formatDate(payment.paymentDate.toIso8601String())),
            ),
          );
        },
      ),
    );
  }
}
