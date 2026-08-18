import 'package:flutter/material.dart';
import '../widgets/app_drawer_scaffold.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';
import '../models/sales_statistic.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<SalesStatistic> _dailySales = [];
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _topOutlets = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  bool _isLoadingProducts = true;
  bool _isLoadingOutlets = true;
  String? _errorMessage;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadDailySales(),
        _loadSummary(),
        _loadTopProducts(),
        _loadTopOutlets(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _loadDailySales() async {
    try {
      final data = await AnalyticsService.fetchDailySales(days: _selectedDays);
      setState(() => _dailySales = data);
    } catch (_) {}
  }

  Future<void> _loadSummary() async {
    try {
      final data = await AnalyticsService.fetchSummary();
      setState(() => _summary = data);
    } catch (_) {}
  }

  Future<void> _loadTopProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final data = await AnalyticsService.fetchTopProducts();
      setState(() {
        _topProducts = data;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadTopOutlets() async {
    setState(() => _isLoadingOutlets = true);
    try {
      final data = await AnalyticsService.fetchTopOutlets();
      setState(() {
        _topOutlets = data;
        _isLoadingOutlets = false;
      });
    } catch (e) {
      setState(() => _isLoadingOutlets = false);
    }
  }

  void _changePeriod(int days) {
    if (_selectedDays == days) return;
    setState(() {
      _selectedDays = days;
      _loadData();
    });
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Rp 0';
    double numValue = (value is double)
        ? value
        : (value is int)
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0.0;
    return 'Rp ${numValue.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        )}';
  }

  String _formatNumber(dynamic value) {
    return (value ?? 0).toString();
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawerScaffold(
      title: 'Analytics',
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
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Period Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildPeriodChip(7, '7 Hari'),
                            const SizedBox(width: 8),
                            _buildPeriodChip(14, '14 Hari'),
                            const SizedBox(width: 8),
                            _buildPeriodChip(30, '30 Hari'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Summary Cards
                        Row(
                          children: [
                            _buildSummaryCard(
                                'Total Sales',
                                _formatCurrency(_summary['total_sales']),
                                Icons.attach_money,
                                Colors.blue),
                            _buildSummaryCard(
                                'Total Orders',
                                _formatNumber(_summary['total_orders']),
                                Icons.shopping_cart,
                                Colors.green),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSummaryCard(
                                'Total Visits',
                                _formatNumber(_summary['total_visits']),
                                Icons.location_on,
                                Colors.orange),
                            _buildSummaryCard(
                                'Strike Rate',
                                '${_formatNumber(_summary['strike_rate'])}%',
                                Icons.percent,
                                Colors.purple),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Sales Chart
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Daily Sales Trend',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: _dailySales.isEmpty
                                      ? const Center(
                                          child: Text('Tidak ada data'))
                                      : BarChart(
                                          BarChartData(
                                            alignment:
                                                BarChartAlignment.spaceAround,
                                            maxY: _dailySales.isEmpty
                                                ? 0
                                                : (_dailySales
                                                        .map(
                                                            (e) => e.totalSales)
                                                        .reduce((a, b) =>
                                                            a > b ? a : b) *
                                                    1.2),
                                            barGroups: _dailySales
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final index = entry.key;
                                              final data = entry.value;
                                              return BarChartGroupData(
                                                x: index,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: data.totalSales,
                                                    color: Colors.blue,
                                                    width: 20,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                            titlesData: FlTitlesData(
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  // PERBAIKAN: date adalah DateTime, bukan String
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    if (value.toInt() >= 0 &&
                                                        value.toInt() <
                                                            _dailySales
                                                                .length) {
                                                      final date = _dailySales[
                                                              value.toInt()]
                                                          .date;
                                                      return Text(
                                                        '${date.day}/${date.month}',
                                                        style: const TextStyle(
                                                            fontSize: 10),
                                                      );
                                                    }
                                                    return const Text('');
                                                  },
                                                  reservedSize: 30,
                                                ),
                                              ),
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 50,
                                                  getTitlesWidget:
                                                      (value, meta) => Text(
                                                          _formatCurrency(
                                                              value),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      10)),
                                                ),
                                              ),
                                              topTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                      showTitles: false)),
                                              rightTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                      showTitles: false)),
                                            ),
                                            borderData:
                                                FlBorderData(show: false),
                                            gridData:
                                                const FlGridData(show: true),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Top Products
                        const Text('Top Products',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _isLoadingProducts
                            ? const Center(child: CircularProgressIndicator())
                            : _topProducts.isEmpty
                                ? const Center(child: Text('No data'))
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _topProducts.length,
                                    itemBuilder: (context, index) {
                                      final product = _topProducts[index];
                                      return Card(
                                        child: ListTile(
                                          leading: CircleAvatar(
                                              child: Text('${index + 1}')),
                                          title: Text(
                                              product['product_name'] ?? ''),
                                          subtitle: Text(
                                              '${_formatNumber(product['total_quantity'])} units'),
                                          trailing: Text(_formatCurrency(
                                              product['total_sales'])),
                                        ),
                                      );
                                    },
                                  ),
                        const SizedBox(height: 16),
                        // Top Outlets
                        const Text('Top Outlets',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _isLoadingOutlets
                            ? const Center(child: CircularProgressIndicator())
                            : _topOutlets.isEmpty
                                ? const Center(child: Text('No data'))
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _topOutlets.length,
                                    itemBuilder: (context, index) {
                                      final outlet = _topOutlets[index];
                                      return Card(
                                        child: ListTile(
                                          leading: CircleAvatar(
                                              child: Text('${index + 1}')),
                                          title:
                                              Text(outlet['outlet_name'] ?? ''),
                                          subtitle: Text(
                                              '${_formatNumber(outlet['total_visits'])} visits'),
                                          trailing: Text(_formatCurrency(
                                              outlet['total_sales'])),
                                        ),
                                      );
                                    },
                                  ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPeriodChip(int days, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedDays == days,
      onSelected: (_) => _changePeriod(days),
      selectedColor: Colors.blue.shade100,
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
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
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
