import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'rep_detail_screen.dart';
import 'manager_outlet_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  Map<String, dynamic>? _team;
  List<dynamic> _members = [];
  bool _isLoading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final name = await AuthService.getUserName();
      final data = await ApiClient.get('/supervisor/team-dashboard');
      if (!mounted) return;
      setState(() {
        _userName = name;
        _team = data['team'] as Map<String, dynamic>?;
        _members = data['members'] is List ? data['members'] : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Kelola Outlet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManagerOutletScreen(),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await AuthService.logout();
              if (!mounted) return;
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, $_userName',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _team?['team_name']?.toString() ?? 'Tim Sales',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          Text('Anggota tim: ${_members.length}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Performa Hari Ini',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_members.isEmpty)
                    const Text('Tidak ada data anggota tim')
                  else
                    ..._members.map((m) {
                      final sales = (m['total_sales'] as num?)?.toDouble() ?? 0;
                      final visits = m['total_visits'] ?? 0;
                      final missed = m['missed_visits'] ?? 0;
                      final orders = m['total_orders'] ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(m['name']?.toString() ?? ''),
                          subtitle: Text(
                            'Kunjungan: $visits | Missed: $missed | Order: $orders\n'
                            'Sales: Rp ${sales.toStringAsFixed(0)}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RepDetailScreen(
                                  repId: m['employee_id'] as int,
                                  repName: m['name']?.toString() ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
