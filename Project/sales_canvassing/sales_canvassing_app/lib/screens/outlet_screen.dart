import 'package:flutter/material.dart';
import '../services/outlet_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../models/outlet.dart';
import '../widgets/app_drawer_scaffold.dart';
import '../widgets/form_dropdown.dart';

class OutletScreen extends StatefulWidget {
  const OutletScreen({super.key});

  @override
  State<OutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<OutletScreen> {
  List<Outlet> _outlets = [];
  bool _isLoading = true;
  bool _isManager = false;
  String? _errorMessage;

  final List<String> _priorities = ['A', 'B', 'C'];
  final List<String> _storeTypes = [
    'Supermarket',
    'Mini Market',
    'Retail',
    'Warung',
    'Pharmacy'
  ];
  String _userRole = '';
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final role = await AuthService.getUserRole();
    setState(() {
      _userRole = role;
      _isManager = role == 'manager' || role == 'admin';
    });
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Backend membaca role dari JWT token, bukan dari query param
      // rep_id param dikirim untuk compatibility tapi backend pakai req.user.employee_id
      final data = await ApiClient.get('/outlets');

      if (data is List) {
        final outlets = data.map((json) => Outlet.fromJson(json)).toList();
        setState(() {
          _outlets = outlets;
          _isLoading = false;
        });
      } else {
        setState(() {
          _outlets = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _showOutletForm({Outlet? outlet}) async {
    final bool isEditing = outlet != null;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final TextEditingController codeController =
        TextEditingController(text: outlet?.outletCode ?? '');
    final TextEditingController nameController =
        TextEditingController(text: outlet?.outletName ?? '');
    final TextEditingController addressController =
        TextEditingController(text: outlet?.address ?? '');
    final TextEditingController latController =
        TextEditingController(text: outlet?.latitude?.toString() ?? '');
    final TextEditingController lngController =
        TextEditingController(text: outlet?.longitude?.toString() ?? '');
    final TextEditingController ownerController =
        TextEditingController(text: outlet?.ownerName ?? '');
    final TextEditingController phoneController =
        TextEditingController(text: outlet?.phone ?? '');
    final TextEditingController creditController =
        TextEditingController(text: outlet?.creditLimit.toString() ?? '0');

    String selectedPriority = outlet?.priority ?? 'C';
    String selectedStoreType = outlet?.storeType ?? 'Supermarket';

    final Outlet? result = await showDialog<Outlet>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Outlet' : 'Tambah Outlet'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(
                              labelText: 'Outlet Code',
                              border: OutlineInputBorder()),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                              labelText: 'Outlet Name',
                              border: OutlineInputBorder()),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressController,
                          decoration: const InputDecoration(
                              labelText: 'Address',
                              border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: TextFormField(
                                    controller: latController,
                                    decoration: const InputDecoration(
                                        labelText: 'Latitude',
                                        border: OutlineInputBorder()),
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: TextFormField(
                                    controller: lngController,
                                    decoration: const InputDecoration(
                                        labelText: 'Longitude',
                                        border: OutlineInputBorder()),
                                    keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FormDropdown<String>(
                          labelText: 'Priority',
                          value: selectedPriority,
                          items: _priorities
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedPriority = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        FormDropdown<String>(
                          labelText: 'Store Type',
                          value: selectedStoreType,
                          items: _storeTypes
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedStoreType = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: ownerController,
                            decoration: const InputDecoration(
                                labelText: 'Owner Name',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: creditController,
                            decoration: const InputDecoration(
                                labelText: 'Credit Limit',
                                border: OutlineInputBorder(),
                                prefixText: 'Rp '),
                            keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final Outlet newOutlet = Outlet(
                        outletId: outlet?.outletId ?? 0,
                        outletCode: codeController.text.trim(),
                        outletName: nameController.text.trim(),
                        address: addressController.text.trim(),
                        latitude: double.tryParse(latController.text),
                        longitude: double.tryParse(lngController.text),
                        priority: selectedPriority,
                        storeType: selectedStoreType,
                        ownerName: ownerController.text.trim(),
                        phone: phoneController.text.trim(),
                        creditLimit:
                            double.tryParse(creditController.text) ?? 0,
                        outstanding: outlet?.outstanding ?? 0,
                      );
                      Navigator.pop(context, newOutlet);
                    }
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text(isEditing ? 'Update' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoading = true);
      try {
        if (isEditing) {
          await OutletService.updateOutlet(outlet.outletId, result);
        } else {
          await OutletService.createOutlet(result);
        }
        await _loadOutlets();
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
            content: Text(isEditing ? 'Outlet updated' : 'Outlet created'),
            backgroundColor: Colors.green));
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
    // Placeholder for future analytics reload after changes

    codeController.dispose();
    nameController.dispose();
    addressController.dispose();
    latController.dispose();
    lngController.dispose();
    ownerController.dispose();
    phoneController.dispose();
    creditController.dispose();
  }

  Future<void> _confirmDelete(Outlet outlet) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Outlet'),
        content: Text('Delete ${outlet.outletName}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (result == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoading = true);
      try {
        await OutletService.deleteOutlet(outlet.outletId);
        await _loadOutlets();
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(
            content: Text('Outlet deleted'), backgroundColor: Colors.green));
      } catch (e) {
        if (!mounted) return;
        final error = e.toString();

        // Check if error is about active visits
        if (error.contains('active visit') || error.contains('active_visits')) {
          final forceResult = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Outlet Has Active Visits'),
              content: const Text(
                  'This outlet has active visit plans. Do you want to cancel the visits and delete the outlet?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    child: const Text('Force Delete')),
              ],
            ),
          );

          if (forceResult == true) {
            try {
              await OutletService.deleteOutlet(outlet.outletId, force: true);
              await _loadOutlets();
              if (!mounted) return;
              messenger.showSnackBar(const SnackBar(
                  content: Text('Outlet deleted and visits canceled'),
                  backgroundColor: Colors.green));
            } catch (forceError) {
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(
                  content: Text('Error: $forceError'),
                  backgroundColor: Colors.red));
              setState(() => _isLoading = false);
            }
          } else {
            setState(() => _isLoading = false);
          }
        } else {
          messenger.showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
        }
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
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawerScaffold(
      title: 'Outlet Management',
      actions: [
        if (_isManager)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showOutletForm(),
          ),
        if (_userRole == 'rep')
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: 'Create Order',
            onPressed: () => _showCreateOrderForm(),
          ),
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
                          child: const Text('Coba Lagi')),
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
                                        style: const TextStyle(fontSize: 12)),
                                    if (_isManager) ...[
                                      const SizedBox(height: 4),
                                      // Placeholder analytics row
                                      Row(
                                        children: const [
                                          Icon(Icons.show_chart,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text('Sales: --, Visits: --',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: _isManager
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () =>
                                                _showOutletForm(outlet: outlet),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.analytics),
                                            color: Colors.purple,
                                            tooltip: 'View Analytics',
                                            onPressed: () =>
                                                _showAnalytics(outlet),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _confirmDelete(outlet),
                                          ),
                                        ],
                                      )
                                    : _userRole == 'rep'
                                        ? IconButton(
                                            icon: const Icon(
                                                Icons.add_shopping_cart),
                                            tooltip: 'Create Order',
                                            onPressed: () =>
                                                _createOrder(outlet),
                                          )
                                        : null,
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
                                            _detailRow(
                                                'Code', outlet.outletCode),
                                            _detailRow(
                                                'Address', outlet.address),
                                            _detailRow(
                                                'Priority', outlet.priority),
                                            _detailRow(
                                                'Store Type', outlet.storeType),
                                            _detailRow(
                                                'Owner', outlet.ownerName),
                                            _detailRow('Phone', outlet.phone),
                                            _detailRow('Credit Limit',
                                                'Rp ${outlet.creditLimit.toStringAsFixed(0)}'),
                                            if (outlet.latitude != null)
                                              _detailRow('Location',
                                                  '${outlet.latitude}, ${outlet.longitude}'),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Close'))
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

  // Placeholder methods for manager/sales actions
  Future<void> _showAnalytics(Outlet outlet) async {
    // TODO: implement analytics view
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Analytics'),
        content: const Text('Analytics feature not implemented yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateOrderForm() async {
    // TODO: implement order creation UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create Order not implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _createOrder(Outlet outlet) async {
    // TODO: implement order creation logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create Order action not implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
