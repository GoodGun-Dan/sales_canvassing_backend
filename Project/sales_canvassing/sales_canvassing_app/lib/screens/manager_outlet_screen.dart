import 'package:flutter/material.dart';
import '../services/outlet_service.dart';
import '../services/auth_service.dart';
import '../models/outlet.dart';
import '../widgets/app_drawer_scaffold.dart';

class ManagerOutletScreen extends StatefulWidget {
  const ManagerOutletScreen({super.key});

  @override
  State<ManagerOutletScreen> createState() => _ManagerOutletScreenState();
}

class _ManagerOutletScreenState extends State<ManagerOutletScreen> {
  List<Outlet> _outlets = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final outlets = await OutletService.fetchOutlets();
      setState(() {
        _outlets = outlets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _confirmDelete(Outlet outlet) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Outlet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hapus ${outlet.outletName}?'),
            const SizedBox(height: 8),
            const Text(
              'Outlet ini akan dihapus dari semua sales rep dan kunjungan yang terkait akan dibatalkan.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoading = true);
      try {
        await OutletService.deleteOutlet(outlet.outletId, force: true);
        await _loadOutlets();
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(
          content: Text('Outlet berhasil dihapus dari semua sales rep'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawerScaffold(
      title: 'Kelola Outlet (Manager)',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadOutlets,
        ),
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
                        onPressed: _loadOutlets,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOutlets,
                  child: _outlets.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('Tidak ada outlet')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _outlets.length,
                          itemBuilder: (context, index) {
                            final outlet = _outlets[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: outlet.priority == 'A'
                                      ? Colors.green
                                      : outlet.priority == 'B'
                                          ? Colors.orange
                                          : Colors.blue,
                                  child: Text(outlet.priority),
                                ),
                                title: Text(outlet.outletName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(outlet.address),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: ${outlet.outletCode} | Type: ${outlet.storeType}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(outlet),
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(outlet.outletName),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _detailRow('Code', outlet.outletCode),
                                            _detailRow('Address', outlet.address),
                                            _detailRow('Priority', outlet.priority),
                                            _detailRow('Store Type', outlet.storeType),
                                            _detailRow('Owner', outlet.ownerName),
                                            _detailRow('Phone', outlet.phone),
                                            _detailRow(
                                              'Credit Limit',
                                              'Rp ${outlet.creditLimit.toStringAsFixed(0)}',
                                            ),
                                            if (outlet.latitude != null)
                                              _detailRow(
                                                'Location',
                                                '${outlet.latitude}, ${outlet.longitude}',
                                              ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Tutup'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
