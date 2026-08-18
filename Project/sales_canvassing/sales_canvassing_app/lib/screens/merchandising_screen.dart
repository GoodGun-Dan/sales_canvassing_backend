import 'package:flutter/material.dart';
import '../services/visit_service.dart';
import '../services/merchandising_service.dart';
import '../widgets/app_drawer_scaffold.dart';

class MerchandisingScreen extends StatefulWidget {
  const MerchandisingScreen({super.key});

  @override
  State<MerchandisingScreen> createState() => _MerchandisingScreenState();
}

class _MerchandisingScreenState extends State<MerchandisingScreen> {
  List<Map<String, dynamic>> _visits = [];
  int? _selectedVisitId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final _planogramController = TextEditingController(text: '80');
  final _shelfShareController = TextEditingController(text: '70');
  final _notesController = TextEditingController();
  bool _posmPlacement = false;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  @override
  void dispose() {
    _planogramController.dispose();
    _shelfShareController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadVisits() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final visits = await VisitService.fetchTodayVisits();
      final inProgress = visits
          .where((v) =>
              v['status'] == 'InProgress' || v['status'] == 'Completed')
          .toList();

      if (!mounted) return;
      setState(() {
        _visits = inProgress;
        _selectedVisitId = inProgress.isNotEmpty
            ? inProgress.first['visit_id'] as int?
            : null;
        _isLoading = false;
      });

      if (_selectedVisitId != null) {
        await _loadExistingAudit(_selectedVisitId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExistingAudit(int visitId) async {
    try {
      final audit = await MerchandisingService.fetchByVisit(visitId);
      if (audit == null || !mounted) return;
      setState(() {
        _planogramController.text =
            audit['planogram_score']?.toString() ?? '80';
        _shelfShareController.text = audit['shelf_share']?.toString() ?? '70';
        _posmPlacement = audit['posm_placement'] == true;
        _notesController.text = audit['notes']?.toString() ?? '';
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_selectedVisitId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kunjungan yang sudah check-in'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await MerchandisingService.submit(
        visitId: _selectedVisitId!,
        planogramScore: int.tryParse(_planogramController.text) ?? 0,
        shelfShare: int.tryParse(_shelfShareController.text) ?? 0,
        posmPlacement: _posmPlacement,
        notes: _notesController.text,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audit merchandising tersimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawerScaffold(
      title: 'Merchandising Audit',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVisits),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _visits.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada kunjungan InProgress/Completed hari ini.\n'
                    'Lakukan check-in di GPS terlebih dahulu.',
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _selectedVisitId,
                        decoration: const InputDecoration(
                          labelText: 'Kunjungan / Outlet',
                          border: OutlineInputBorder(),
                        ),
                        items: _visits
                            .map(
                              (v) => DropdownMenuItem(
                                value: v['visit_id'] as int,
                                child: Text(v['outlet_name']?.toString() ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (v) async {
                          setState(() => _selectedVisitId = v);
                          if (v != null) await _loadExistingAudit(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _planogramController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Planogram Score (0-100)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _shelfShareController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Shelf Share % (0-100)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('POSM Placement'),
                        value: _posmPlacement,
                        onChanged: (v) => setState(() => _posmPlacement = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Catatan',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Simpan Audit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
