import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';
import '../models/dashboard_data.dart';
import '../widgets/app_drawer_scaffold.dart';
import 'route_planning_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _futureDashboard;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  void _loadDashboard() {
    _futureDashboard = DashboardService.fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawerScaffold(
      title: 'Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() {
              _loadDashboard();
            });
          },
        ),
      ],
      body: FutureBuilder<DashboardData>(
        future: _futureDashboard,
        builder: (BuildContext context, AsyncSnapshot<DashboardData> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadDashboard();
                      });
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final DashboardData data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _loadDashboard();
                });
                await _futureDashboard;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Performance',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildMetricCard(
                                'Sales Today',
                                _formatRupiah(data.metrics.totalSalesToday),
                                Icons.trending_up,
                                Colors.green,
                              ),
                              _buildMetricCard(
                                'Strike Rate',
                                '${data.metrics.strikeRate.toStringAsFixed(1)}%',
                                Icons.percent,
                                Colors.orange,
                              ),
                              _buildMetricCard(
                                'Pending Sync',
                                data.metrics.pendingOrders.toString(),
                                Icons.sync_problem,
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Visit Plan',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          data.visitPlan.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text('Tidak ada kunjungan hari ini'),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: data.visitPlan.length,
                                  itemBuilder: (context, index) {
                                    final item = data.visitPlan[index];
                                    String timeString = item.visitTime;
                                    if (timeString.length > 5) {
                                      timeString = timeString.substring(0, 5);
                                    }
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: item.priority == 'A'
                                            ? Colors.green
                                            : item.priority == 'B'
                                                ? Colors.orange
                                                : Colors.blue,
                                        child: Text(item.priority),
                                      ),
                                      title: Text(item.outletName),
                                      subtitle:
                                          Text('${item.address} • $timeString'),
                                      trailing: Chip(
                                        label: Text(item.status),
                                        backgroundColor:
                                            item.status == 'Completed'
                                                ? Colors.green.shade100
                                                : item.status == 'InProgress'
                                                    ? Colors.orange.shade100
                                                    : Colors.grey.shade200,
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                RoutePlanningScreen(
                                              selectedOutletId: item.outletId,
                                              selectedOutletName:
                                                  item.outletName,
                                              selectedOutletLat: item.latitude,
                                              selectedOutletLng: item.longitude,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sync Status',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                  'Last sync: ${_formatDateTime(data.lastSync)}'),
                            ],
                          ),
                          const Chip(
                            label: Text('Online'),
                            backgroundColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: Text('No data'));
          }
        },
      ),
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  String _formatRupiah(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
