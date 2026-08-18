import 'package:flutter/material.dart';
import '../services/stock_service.dart';
import '../models/stock_item.dart';
import '../services/api_client.dart';
import '../widgets/app_drawer_scaffold.dart';

class StockScreen extends StatefulWidget {
  final int? repId; // Untuk admin yang melihat stock sales rep tertentu

  const StockScreen({super.key, this.repId});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<StockItem> _allStockItems = [];
  List<StockItem> _filteredStockItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  int _totalDistributorStock = 0;
  int _totalVanStock = 0;
  int _totalOutletStock = 0;
  int _criticalCount = 0;
  int _lowCount = 0;
  int _goodCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<StockItem> stock;

      // Jika ada repId (admin melihat stock sales rep tertentu)
      if (widget.repId != null) {
        final data = await ApiClient.get('/stock?rep_id=${widget.repId}');
        if (data is List) {
          stock = data.map((json) => StockItem.fromJson(json)).toList();
        } else {
          stock = [];
        }
      } else {
        // Sales rep melihat stock sendiri
        stock = await StockService.fetchStock();
      }

      setState(() {
        _allStockItems = stock;
        _calculateSummary();
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data stok: $e';
      });
    }
  }

  void _calculateSummary() {
    _totalDistributorStock = 0;
    _totalVanStock = 0;
    _totalOutletStock = 0;
    _criticalCount = 0;
    _lowCount = 0;
    _goodCount = 0;

    for (var item in _allStockItems) {
      _totalDistributorStock += item.distributorStock;
      _totalVanStock += item.vanStock;
      _totalOutletStock += item.outletStock;

      switch (item.status) {
        case 'Critical':
          _criticalCount++;
          break;
        case 'Low':
          _lowCount++;
          break;
        case 'Good':
          _goodCount++;
          break;
      }
    }
  }

  void _applyFilter() {
    List<StockItem> filtered = List.from(_allStockItems);

    if (_selectedFilter != 'All') {
      filtered =
          filtered.where((item) => item.status == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.productName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              item.productCode
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    setState(() => _filteredStockItems = filtered);
  }

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
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
                        onPressed: _loadStock,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStock,
                  child: Column(
                    children: [
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cari produk...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onChanged: (value) {
                            _searchQuery = value;
                            _applyFilter();
                          },
                        ),
                      ),
                      // Summary Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _buildSummaryCard(
                                'Distributor',
                                _formatNumber(_totalDistributorStock),
                                Icons.warehouse,
                                Colors.blue),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                                'Van',
                                _formatNumber(_totalVanStock),
                                Icons.local_shipping,
                                Colors.orange),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                                'Outlet',
                                _formatNumber(_totalOutletStock),
                                Icons.store,
                                Colors.green),
                          ],
                        ),
                      ),
                      // Critical Alert
                      if (_criticalCount > 0)
                        Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$_criticalCount produk stok kritis! Segera restock.',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: _selectedFilter == 'All',
                              onSelected: (_) {
                                setState(() => _selectedFilter = 'All');
                                _applyFilter();
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Critical'),
                              selected: _selectedFilter == 'Critical',
                              onSelected: (_) {
                                setState(() => _selectedFilter = 'Critical');
                                _applyFilter();
                              },
                              backgroundColor: Colors.red.shade50,
                              selectedColor: Colors.red.shade100,
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text('Low ($_lowCount)'),
                              selected: _selectedFilter == 'Low',
                              onSelected: (_) {
                                setState(() => _selectedFilter = 'Low');
                                _applyFilter();
                              },
                              backgroundColor: Colors.orange.shade50,
                              selectedColor: Colors.orange.shade100,
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text('Good ($_goodCount)'),
                              selected: _selectedFilter == 'Good',
                              onSelected: (_) {
                                setState(() => _selectedFilter = 'Good');
                                _applyFilter();
                              },
                              backgroundColor: Colors.green.shade50,
                              selectedColor: Colors.green.shade100,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Stock List
                      Expanded(
                        child: _filteredStockItems.isEmpty
                            ? const Center(child: Text('Tidak ada data stok'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _filteredStockItems.length,
                                itemBuilder: (context, index) {
                                  final item = _filteredStockItems[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ExpansionTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            item.statusColor.withValues(alpha: 0.2),
                                        child: Icon(Icons.inventory,
                                            color: item.statusColor),
                                      ),
                                      title: Text(item.productName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle:
                                          Text('Code: ${item.productCode}'),
                                      trailing: Chip(
                                        label: Text(item.status),
                                        backgroundColor:
                                            item.statusColor.withValues(alpha: 0.2),
                                        labelStyle: TextStyle(
                                            color: item.statusColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            children: [
                                              _buildStockRow(
                                                  'Distributor Stock',
                                                  _formatNumber(
                                                      item.distributorStock),
                                                  Colors.blue),
                                              const Divider(),
                                              _buildStockRow(
                                                  'Van Stock',
                                                  _formatNumber(item.vanStock),
                                                  Colors.orange),
                                              const Divider(),
                                              _buildStockRow(
                                                  'Outlet Stock',
                                                  _formatNumber(
                                                      item.outletStock),
                                                  Colors.green),
                                              if (item.status == 'Critical')
                                                const Padding(
                                                  padding:
                                                      EdgeInsets.only(top: 8),
                                                  child: Text(
                                                      '⚠️ Stok kritis! Segera lakukan restock.',
                                                      style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12)),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );

    if (widget.repId != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Stock Management'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStock),
          ],
        ),
        body: content,
      );
    }

    return AppDrawerScaffold(
      title: 'Stock Management',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStock),
      ],
      body: content,
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
