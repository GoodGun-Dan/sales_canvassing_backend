import 'package:flutter/material.dart';
import '../models/promotion.dart';
import '../services/promotion_service.dart';
import '../services/api_client.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<Promotion> _promotions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Ambil semua promosi (aktif + tidak aktif) agar manager bisa lihat riwayat
      final list = await PromotionService.fetchAll();
      if (!mounted) return;
      setState(() {
        _promotions = list;
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

  Future<void> _showAddDialog() async {
    final codeController = TextEditingController();
    final descController = TextEditingController();
    String type = 'Value-based';
    final minValueController = TextEditingController(text: '100000');
    final discountPercentController = TextEditingController(text: '10');
    final startController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
    final endController = TextEditingController(
      text: DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promosi Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Kode Promosi'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'Quantity-based', child: Text('Quantity-based')),
                  DropdownMenuItem(value: 'Value-based', child: Text('Value-based')),
                  DropdownMenuItem(value: 'Time-bound', child: Text('Time-bound')),
                  DropdownMenuItem(value: 'Outlet-specific', child: Text('Outlet-specific')),
                ],
                onChanged: (v) => type = v ?? type,
                decoration: const InputDecoration(labelText: 'Tipe'),
              ),
              TextField(
                controller: minValueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Min nilai order (Rp)'),
              ),
              TextField(
                controller: discountPercentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Diskon %'),
              ),
              TextField(
                controller: startController,
                decoration: const InputDecoration(labelText: 'Start (YYYY-MM-DD)'),
              ),
              TextField(
                controller: endController,
                decoration: const InputDecoration(labelText: 'End (YYYY-MM-DD)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    try {
      await PromotionService.create({
        'promotion_code': codeController.text,
        'description': descController.text,
        'type': type,
        'conditions': {
          'min_value': double.tryParse(minValueController.text) ?? 0,
        },
        'reward': {
          'discount_percent': double.tryParse(discountPercentController.text) ?? 0,
        },
        'start_date': startController.text,
        'end_date': endController.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promosi ditambahkan'), backgroundColor: Colors.green),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deactivatePromotion(Promotion promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan Promosi'),
        content: Text('Apakah Anda yakin ingin menonaktifkan promosi "${promo.promotionCode}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoading = true);
      try {
        // Gunakan DELETE endpoint yang baru
        await ApiClient.delete('/promotions/${promo.promotionId}');
        await _load();
        messenger.showSnackBar(
          const SnackBar(content: Text('Promosi dinonaktifkan'), backgroundColor: Colors.orange),
        );
      } catch (e) {
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
        title: const Text('Kelola Promosi'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _promotions.isEmpty
              ? const Center(child: Text('Belum ada promosi'))
              : ListView.builder(
                  itemCount: _promotions.length,
                  itemBuilder: (context, index) {
                    final p = _promotions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      // Promosi tidak aktif ditampilkan dengan warna lebih pudar
                      color: p.isActive ? null : Colors.grey.shade100,
                      child: ListTile(
                        title: Text(
                          '${p.promotionCode} — ${p.type}',
                          style: TextStyle(
                            color: p.isActive ? null : Colors.grey,
                            decoration: p.isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          '${p.description}\n${p.startDate} s/d ${p.endDate}\n'
                          '${p.isActive ? "✅ Aktif" : "❌ Nonaktif"}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              p.isActive ? Icons.check_circle : Icons.cancel,
                              color: p.isActive ? Colors.green : Colors.grey,
                            ),
                            if (p.isActive) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Nonaktifkan',
                                onPressed: () => _deactivatePromotion(p),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
