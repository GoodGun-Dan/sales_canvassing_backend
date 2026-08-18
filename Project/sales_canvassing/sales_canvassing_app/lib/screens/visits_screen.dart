import 'package:flutter/material.dart';
import '../services/visit_service.dart';
import '../widgets/app_drawer_scaffold.dart';

class VisitsScreen extends StatefulWidget {
  final int? repId;

  const VisitsScreen({super.key, this.repId});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  List<Map<String, dynamic>> _visits = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final visits = await VisitService.fetchTodayVisits(repId: widget.repId);
      if (!mounted) return;
      setState(() {
        _visits = visits;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '$e';
      });
    }
  }

  Future<void> _markMissed(Map<String, dynamic> visit) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tandai Missed Visit'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Alasan',
            hintText: 'Contoh: Outlet tutup',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final visitId = visit['visit_id'] is int
          ? visit['visit_id'] as int
          : int.parse(visit['visit_id'].toString());
      await VisitService.markMissed(
        visitId,
        reasonController.text.isEmpty ? 'Missed' : reasonController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit ditandai missed'),
          backgroundColor: Colors.orange,
        ),
      );
      await _loadVisits();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'InProgress':
        return Colors.blue;
      case 'Missed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _visits.isEmpty
                  ? const Center(child: Text('Tidak ada kunjungan hari ini'))
                  : RefreshIndicator(
                      onRefresh: _loadVisits,
                      child: ListView.builder(
                        itemCount: _visits.length,
                        itemBuilder: (context, index) {
                          final v = _visits[index];
                          final status = v['status']?.toString() ?? 'Planned';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(status),
                                child: Text(
                                  v['priority']?.toString() ?? '-',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(v['outlet_name']?.toString() ?? ''),
                              subtitle: Text(
                                '${v['address']}\n'
                                'Jam: ${v['visit_time'] ?? '-'} | $status\n'
                                'Check-in: ${v['check_in_time'] ?? '-'}',
                              ),
                              isThreeLine: true,
                              trailing: status == 'Planned' ||
                                      status == 'InProgress'
                                  ? IconButton(
                                      icon: const Icon(Icons.cancel,
                                          color: Colors.red),
                                      onPressed: () => _markMissed(v),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    );

    if (widget.repId != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kunjungan Hari Ini'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVisits),
          ],
        ),
        body: body,
      );
    }

    return AppDrawerScaffold(
      title: 'Kunjungan Hari Ini',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVisits),
      ],
      body: body,
    );
  }
}
