import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';
import '../services/admin_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../models/outlet.dart';
import 'route_planning_screen.dart';
import 'gps_tracking_screen.dart';
import 'stock_screen.dart';
import '../widgets/form_dropdown.dart';

class RepDetailScreen extends StatefulWidget {
  final int repId;
  final String repName;

  const RepDetailScreen(
      {super.key, required this.repId, required this.repName});

  @override
  State<RepDetailScreen> createState() => _RepDetailScreenState();
}

class _RepDetailScreenState extends State<RepDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _dashboardData = {};
  List<dynamic> _orders = [];
  List<dynamic> _payments = [];
  Map<String, dynamic> _analytics = {};
  List<Outlet> _assignedOutlets = [];
  bool _isLoading = true;
  bool _isLoadingOrders = true;
  bool _isLoadingPayments = true;
  bool _isLoadingAnalytics = true;
  bool _isLoadingOutlets = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _userRole = '';

  final List<String> _priorities = ['A', 'B', 'C'];
  final List<String> _storeTypes = [
    'Supermarket',
    'Mini Market',
    'Retail',
    'Warung',
    'Pharmacy'
  ];

  // Controllers untuk form tambah outlet
  final TextEditingController _outletCodeController = TextEditingController();
  final TextEditingController _outletNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _creditLimitController = TextEditingController();
  String _selectedPriority = 'C';
  String _selectedStoreType = 'Supermarket';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadUserRoleAndData();
  }

  Future<void> _loadUserRoleAndData() async {
    _userRole = await AuthService.getUserRole();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _outletCodeController.dispose();
    _outletNameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dashboard = await AdminService.getRepDashboard(widget.repId);
      setState(() {
        _dashboardData = dashboard;
        _isLoading = false;
      });
      _loadOrders();
      _loadPayments();
      _loadAnalytics();
      _loadAssignedOutlets();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await AdminService.getRepOrders(widget.repId);
      setState(() {
        _orders = orders;
        _isLoadingOrders = false;
      });
    } catch (e) {
      setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _loadPayments() async {
    try {
      final payments = await AdminService.getRepPayments(widget.repId);
      setState(() {
        _payments = payments;
        _isLoadingPayments = false;
      });
    } catch (e) {
      setState(() => _isLoadingPayments = false);
    }
  }

  Future<void> _loadAnalytics() async {
    try {
      final analytics =
          await AdminService.getRepAnalytics(widget.repId, days: 7);
      setState(() {
        _analytics = analytics;
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      setState(() => _isLoadingAnalytics = false);
    }
  }

  Future<void> _loadAssignedOutlets() async {
    setState(() => _isLoadingOutlets = true);
    try {
      // Manager sees ALL outlets, sales rep sees only assigned outlets
      final isManager = _userRole == 'manager' || _userRole == 'admin';
      final endpoint = isManager
          ? '/outlets'
          : '/admin/sales-reps/${widget.repId}/outlets';
      
      print('🔍 Loading outlets - Role: $_userRole, Endpoint: $endpoint, IsManager: $isManager');
      
      final data = await ApiClient.get(endpoint);
      print('📊 Outlets data received: $data');
      
      if (data is List) {
        final outlets = data.map((json) => Outlet.fromJson(json)).toList();
        print('✅ Parsed ${outlets.length} outlets');
        setState(() {
          _assignedOutlets = outlets;
          _isLoadingOutlets = false;
        });
      } else {
        print('⚠️ Data is not a list: $data');
        setState(() {
          _assignedOutlets = [];
          _isLoadingOutlets = false;
        });
      }
    } catch (e) {
      print('❌ Error loading outlets: $e');
      setState(() {
        _assignedOutlets = [];
        _isLoadingOutlets = false;
      });
    }
  }

  // =====================================================
  // FORM TAMBAH OUTLET BARU
  // =====================================================
  void _showAddOutletForm() {
    _outletCodeController.clear();
    _outletNameController.clear();
    _addressController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _ownerNameController.clear();
    _phoneController.clear();
    _creditLimitController.clear();
    _selectedPriority = 'C';
    _selectedStoreType = 'Supermarket';

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Tambah Outlet Baru'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _outletCodeController,
                        decoration: const InputDecoration(
                            labelText: 'Outlet Code *',
                            border: OutlineInputBorder()),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _outletNameController,
                        decoration: const InputDecoration(
                            labelText: 'Outlet Name *',
                            border: OutlineInputBorder()),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                            labelText: 'Address *',
                            border: OutlineInputBorder()),
                        maxLines: 2,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latitudeController,
                              decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _longitudeController,
                              decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FormDropdown<String>(
                        labelText: 'Priority',
                        value: _selectedPriority,
                        items: _priorities
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => _selectedPriority = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      FormDropdown<String>(
                        labelText: 'Store Type',
                        value: _selectedStoreType,
                        items: _storeTypes
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => _selectedStoreType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ownerNameController,
                        decoration: const InputDecoration(
                            labelText: 'Owner Name',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                            labelText: 'Phone', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _creditLimitController,
                        decoration: const InputDecoration(
                            labelText: 'Credit Limit',
                            border: OutlineInputBorder(),
                            prefixText: 'Rp '),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.pop(context);
                          await _createOutletAndAssign();
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan & Assign'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =====================================================
  // CREATE OUTLET BARU DAN ASSIGN KE SALES REP
  // =====================================================
  Future<void> _createOutletAndAssign() async {
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final outletData = {
        'outlet_code': _outletCodeController.text.trim(),
        'outlet_name': _outletNameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text),
        'longitude': double.tryParse(_longitudeController.text),
        'priority': _selectedPriority,
        'store_type': _selectedStoreType,
        'owner_name': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'credit_limit': double.tryParse(_creditLimitController.text) ?? 0,
      };

      final createResponse = await ApiClient.post('/outlets', outletData);
      final newOutletId = createResponse['outlet_id'];
      if (newOutletId == null) {
        throw Exception('Gagal membuat outlet');
      }

      await ApiClient.post('/admin/sales-reps/${widget.repId}/assign-outlet',
          {'outlet_id': newOutletId});

      await _loadAssignedOutlets();

      if (!mounted) return;
      Navigator.pop(context);

      messenger.showSnackBar(
        const SnackBar(
            content: Text('Outlet berhasil dibuat dan ditambahkan ke jadwal'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _removeOutletFromRep(Outlet outlet) async {
    // Manager does global deletion, sales rep only removes from assignment
    final isManager = _userRole == 'manager' || _userRole == 'admin';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Outlet'),
        content: isManager
            ? Column(
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
              )
            : Text('Hapus ${outlet.outletName} dari jadwal sales rep?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoadingOutlets = true);
      try {
        if (isManager) {
          // Global deletion - delete outlet completely
          await ApiClient.delete('/outlets/${outlet.outletId}?force=true');
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
                content: Text('Outlet berhasil dihapus dari sistem'),
                backgroundColor: Colors.green),
          );
        } else {
          // Sales rep only removes from assignment
          await ApiClient.delete(
              '/admin/sales-reps/${widget.repId}/remove-outlet/${outlet.outletId}');
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
                content: Text('Outlet dihapus dari jadwal'),
                backgroundColor: Colors.orange),
          );
        }
        await _loadAssignedOutlets();
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoadingOutlets = false);
      }
    }
  }

  // =====================================================
  // DOWNLOAD TEMPLATE EXCEL (DIPERBAIKI UNTUK ANDROID)
  // =====================================================
  Future<void> _downloadTemplate() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await Permission.storage.request().isGranted) {
        final token = await AuthService.getToken();
        final url = Uri.parse(
            '${ApiConfig.baseUrl}/admin/sales-reps/${widget.repId}/stock/download-template');
        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final Directory directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          final String fileName = 'stock_template_rep_${widget.repId}.xlsx';
          final String filePath = '${directory.path}/$fileName';
          final File file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
                content: Text('Template tersimpan di Download/$fileName'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // =====================================================
  // SHOW UPLOAD DIALOG (DIPERBAIKI)
  // =====================================================
  Future<void> _showUploadStockDialog() async {
    if (!mounted) return;
    if (!await Permission.storage.request().isGranted) return;
    if (!mounted) return;
    {
      String? selectedFileName;
      String? selectedFilePath;
      Uint8List? fileBytes;

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Upload Stock Excel'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Upload file Excel untuk update stok sales rep ini.'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                              selectedFileName ?? 'Belum ada file dipilih')),
                      ElevatedButton(
                        onPressed: () async {
                          final pickResult =
                              await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['xlsx', 'xls'],
                            withData: true,
                          );
                          if (pickResult != null) {
                            setModalState(() {
                              selectedFileName = pickResult.files.first.name;
                              fileBytes = pickResult.files.first.bytes;
                              selectedFilePath = pickResult.files.first.path;
                            });
                          }
                        },
                        child: const Text('Pilih File'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Template'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedFileName == null || (fileBytes == null && selectedFilePath == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Pilih file terlebih dahulu'),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        ),
      );

      if (result == true && selectedFileName != null) {
        if (fileBytes != null) {
          await _uploadStockFile(
              fileName: selectedFileName!, fileBytes: fileBytes!);
        } else if (selectedFilePath != null) {
          await _uploadStockFileFromPath(
              fileName: selectedFileName!, filePath: selectedFilePath!);
        }
      }
    }
  }

  // =====================================================
  // UPLOAD STOCK FILE (DIPERBAIKI - TANPA NESTED DIALOG)
  // =====================================================
  Future<void> _uploadStockFile({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await AuthService.getToken();
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/admin/sales-reps/${widget.repId}/stock/upload-excel');

      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final response = http.Response(responseBody, streamedResponse.statusCode);

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        messenger.showSnackBar(
          SnackBar(
              content: Text(jsonResponse['message']),
              backgroundColor: Colors.green),
        );
        setState(() {});
      } else {
        final errorJson = jsonDecode(response.body);
        messenger.showSnackBar(
          SnackBar(
              content: Text(errorJson['error'] ?? 'Upload gagal'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // =====================================================
  // UPLOAD STOCK FILE FROM PATH (FALLBACK)
  // =====================================================
  Future<void> _uploadStockFileFromPath({
    required String fileName,
    required String filePath,
  }) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await AuthService.getToken();
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/admin/sales-reps/${widget.repId}/stock/upload-excel');

      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final response = http.Response(responseBody, streamedResponse.statusCode);

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        messenger.showSnackBar(
          SnackBar(
              content: Text(jsonResponse['message']),
              backgroundColor: Colors.green),
        );
        setState(() {});
      } else {
        final errorJson = jsonDecode(response.body);
        messenger.showSnackBar(
          SnackBar(
              content: Text(errorJson['error'] ?? 'Upload gagal'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    if (value is double) return value.toStringAsFixed(0);
    if (value is int) return value.toString();
    if (value is String) {
      return double.tryParse(value)?.toStringAsFixed(0) ?? value;
    }
    return '0';
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Rp 0';
    double numValue = (value is double)
        ? value
        : (value is int)
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0;
    return 'Rp ${numValue.toStringAsFixed(0)}';
  }

  String _formatTime(dynamic timeValue) {
    if (timeValue == null) return '';
    final String timeStr = timeValue.toString();
    return timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    final String dateStr = dateValue.toString();
    return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.repName} - Details'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'Route', icon: Icon(Icons.route)),
            Tab(text: 'GPS', icon: Icon(Icons.location_on)),
            Tab(text: 'Orders', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Stock', icon: Icon(Icons.inventory)),
            Tab(text: 'Payments', icon: Icon(Icons.payments)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Outlet', icon: Icon(Icons.store)),
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
                          onPressed: _loadAllData,
                          child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(),
                    _buildRouteTab(),
                    GpsTrackingScreen(
                      repId: widget.repId,
                      repName: widget.repName,
                    ),
                    _buildOrdersTab(),
                    _buildStockTab(),
                    _buildPaymentsTab(),
                    _buildAnalyticsTab(),
                    _buildOutletTab(),
                  ],
                ),
    );
  }

  Widget _buildDashboardTab() {
    final metrics = _dashboardData['metrics'] ?? {};
    final visitPlan = _dashboardData['visitPlan'] ?? [];
    final repInfo = _dashboardData['repInfo'] ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('Sales Rep Information',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _infoRow('Name', repInfo['name'] ?? '-'),
                _infoRow('Email', repInfo['email'] ?? '-'),
                _infoRow('Username', repInfo['username'] ?? '-'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('Today\'s Performance',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(children: [
                  _metricCard(
                      'Sales Today',
                      _formatCurrency(metrics['totalSalesToday']),
                      Icons.trending_up,
                      Colors.green),
                  _metricCard(
                      'Strike Rate',
                      '${_formatNumber(metrics['strikeRate'])}%',
                      Icons.percent,
                      Colors.orange),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('Today\'s Visit Plan',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                visitPlan.isEmpty
                    ? const Center(child: Text('No visits planned for today'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visitPlan.length,
                        itemBuilder: (context, index) {
                          final item = visitPlan[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item['priority'] == 'A'
                                  ? Colors.green
                                  : item['priority'] == 'B'
                                      ? Colors.orange
                                      : Colors.blue,
                              child: Text(item['priority'] ?? 'C'),
                            ),
                            title: Text(item['outlet_name'] ?? ''),
                            subtitle: Text(item['address'] ?? ''),
                            trailing: Text(_formatTime(item['visit_time'])),
                          );
                        },
                      ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTab() {
    return FutureBuilder(
      future: ApiClient.get('/outlets?rep_id=${widget.repId}'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final outlets = snapshot.data as List?;
        if (outlets == null || outlets.isEmpty) {
          return const Center(child: Text('Tidak ada outlet yang di-assign'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: outlets.length,
          itemBuilder: (context, index) {
            final outlet = outlets[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: outlet['priority'] == 'A'
                      ? Colors.green
                      : outlet['priority'] == 'B'
                          ? Colors.orange
                          : Colors.blue,
                  child: Text(outlet['priority'] ?? 'C'),
                ),
                title: Text(outlet['outlet_name'] ?? ''),
                subtitle: Text(outlet['address'] ?? ''),
                trailing: const Icon(Icons.navigation),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoutePlanningScreen(
                        selectedOutletId: outlet['outlet_id'],
                        selectedOutletName: outlet['outlet_name'],
                        selectedOutletLat:
                            (outlet['latitude'] as num).toDouble(),
                        selectedOutletLng:
                            (outlet['longitude'] as num).toDouble(),
                        repId: widget.repId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return const Center(child: Text('No orders found'));
    }
    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(order['order_number'] ?? ''),
            subtitle: Text(order['outlet_name'] ?? ''),
            trailing: Text(_formatCurrency(order['total'])),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_isLoadingPayments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_payments.isEmpty) {
      return const Center(child: Text('No payments found'));
    }
    return ListView.builder(
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.payment, color: Colors.green),
            title: Text(_formatCurrency(payment['amount'])),
            subtitle: Text(payment['payment_method'] ?? ''),
            trailing: Text(_formatDate(payment['payment_date'])),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = _analytics['summary'] ?? {};
    final topProducts = _analytics['topProducts'] ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            _metricCard('Total Sales', _formatCurrency(summary['total_sales']),
                Icons.attach_money, Colors.blue),
            _metricCard('Total Orders', _formatNumber(summary['total_orders']),
                Icons.shopping_cart, Colors.purple),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _metricCard('Total Visits', _formatNumber(summary['total_visits']),
                Icons.location_on, Colors.orange),
            _metricCard(
                'Strike Rate',
                '${_formatNumber(summary['strike_rate'])}%',
                Icons.percent,
                Colors.green),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('Top Products',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                topProducts.isEmpty
                    ? const Center(child: Text('No data'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: topProducts.length,
                        itemBuilder: (context, index) {
                          final product = topProducts[index];
                          return ListTile(
                            title: Text(product['product_name'] ?? ''),
                            trailing: Text(
                                '${_formatNumber(product['total_quantity'])} units'),
                          );
                        },
                      ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTab() {
    return Column(
      children: [
        if (_userRole == 'admin' || _userRole == 'manager')
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _showUploadStockDialog,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Stock Excel'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ),
        Expanded(child: StockScreen(repId: widget.repId)),
      ],
    );
  }

  Widget _buildOutletTab() {
    final isManager = _userRole == 'manager' || _userRole == 'admin';
    
    print('🏗️ Building Outlet Tab - Role: $_userRole, IsManager: $isManager, Outlets count: ${_assignedOutlets.length}, Loading: $_isLoadingOutlets');

    if (_isLoadingOutlets) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Debug info header
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey.shade200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Role: $_userRole', style: const TextStyle(fontSize: 12)),
              Text('Outlets: ${_assignedOutlets.length}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        if (isManager)
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _showAddOutletForm,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Outlet Baru'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        Expanded(
          child: _assignedOutlets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(isManager 
                          ? 'Belum ada outlet di sistem' 
                          : 'Belum ada outlet yang di-assign'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadAssignedOutlets,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAssignedOutlets,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _assignedOutlets.length,
                    itemBuilder: (context, index) {
                      final outlet = _assignedOutlets[index];
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
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.navigation,
                                    color: Colors.green),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RoutePlanningScreen(
                                        selectedOutletId: outlet.outletId,
                                        selectedOutletName: outlet.outletName,
                                        selectedOutletLat: outlet.latitude,
                                        selectedOutletLng: outlet.longitude,
                                        repId: widget.repId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeOutletFromRep(outlet),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
}
