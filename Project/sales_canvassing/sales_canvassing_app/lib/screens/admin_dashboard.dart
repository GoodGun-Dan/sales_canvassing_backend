import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../models/sales_rep.dart';
import 'rep_detail_screen.dart';
import 'add_edit_rep_screen.dart';
import 'settings_screen.dart';
import 'stock_upload_screen.dart';
import 'promotions_screen.dart';
import 'products_admin_screen.dart';
import 'visits_screen.dart';
import 'manager_outlet_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<SalesRep> _salesReps = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _userName = '';
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadSalesReps();
  }

  Future<void> _loadUserInfo() async {
    final name = await AuthService.getUserName();
    final role = await AuthService.getUserRole();
    setState(() {
      _userName = name;
      _userRole = role;
    });
  }

  Future<void> _loadSalesReps() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reps = await AdminService.getSalesReps();
      setState(() {
        _salesReps = reps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _addSalesRep() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditRepScreen()),
    );
    if (result == true) {
      _loadSalesReps();
    }
  }

  Future<void> _editSalesRep(SalesRep rep) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditRepScreen(rep: rep)),
    );
    if (result == true) {
      _loadSalesReps();
    }
  }

  void _openVisitsForRep() {
    if (_salesReps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada sales rep')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Lihat kunjungan hari ini',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ..._salesReps.map(
                (rep) => ListTile(
                  title: Text(rep.name),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VisitsScreen(repId: rep.employeeId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openStockUploadForRep() {
    if (_salesReps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada sales rep. Tambahkan dulu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Pilih Sales Rep untuk upload stok',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ..._salesReps.map(
                (rep) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(rep.name),
                  subtitle: Text(rep.username),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockUploadScreen(
                          repId: rep.employeeId,
                          repName: rep.name,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteSalesRep(SalesRep rep) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sales Rep'),
        content: Text('Delete ${rep.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoading = true);
      try {
        await AdminService.deleteSalesRep(rep.employeeId);
        await _loadSalesReps();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Sales rep deleted'),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Team Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSalesReps,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    _userRole.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Sales Team'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Upload Stock Excel'),
              onTap: () {
                Navigator.pop(context);
                _openStockUploadForRep();
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_offer),
              title: const Text('Kelola Promosi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PromotionsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Kelola Produk'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductsAdminScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Kelola Outlet'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagerOutletScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Kunjungan Tim'),
              onTap: () {
                Navigator.pop(context);
                _openVisitsForRep();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final navigator = Navigator.of(context);
                await AuthService.logout();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
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
                        onPressed: _loadSalesReps,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Sales Reps: ${_salesReps.length}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addSalesRep,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Sales Rep'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _salesReps.isEmpty
                          ? const Center(
                              child: Text('No sales representatives found'))
                          : ListView.builder(
                              itemCount: _salesReps.length,
                              itemBuilder: (context, index) {
                                final rep = _salesReps[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: rep.isActive
                                          ? Colors.green
                                          : Colors.red,
                                      child: Text(rep.name
                                          .substring(0, 1)
                                          .toUpperCase()),
                                    ),
                                    title: Text(
                                      rep.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: rep.isActive
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(rep.email),
                                        Text(
                                          'Username: ${rep.username} | Visits: ${rep.totalVisits}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility,
                                              color: Colors.blue),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RepDetailScreen(
                                                        repId: rep.employeeId,
                                                        repName: rep.name),
                                              ),
                                            );
                                          },
                                        ),
                                        if (_userRole == 'admin' || _userRole == 'manager')
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.orange),
                                            onPressed: () => _editSalesRep(rep),
                                          ),
                                        if (_userRole == 'admin' || _userRole == 'manager')
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _deleteSalesRep(rep),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

// Temporary placeholder for LoginScreen
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Login Screen')));
}
