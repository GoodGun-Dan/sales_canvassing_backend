import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../services/auth_service.dart';

/// Upload stock per sales rep. Wajib menyertakan [repId] dari admin.
class StockUploadScreen extends StatefulWidget {
  final int repId;
  final String? repName;

  const StockUploadScreen({
    super.key,
    required this.repId,
    this.repName,
  });

  @override
  State<StockUploadScreen> createState() => _StockUploadScreenState();
}

class _StockUploadScreenState extends State<StockUploadScreen> {
  bool _isUploading = false;
  String? _selectedFileName;
  String? _uploadMessage;
  bool _isSuccess = false;
  List<String> _errors = [];

  Future<void> _downloadTemplate() async {
    try {
      final token = await AuthService.getToken();
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/admin/sales-reps/${widget.repId}/stock/download-template',
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template berhasil diunduh'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Gagal download template');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (pickResult == null) return;

      if (!mounted) return;
      setState(() {
        _selectedFileName = pickResult.files.first.name;
        _isUploading = true;
        _uploadMessage = null;
        _errors = [];
      });

      final token = await AuthService.getToken();
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/admin/sales-reps/${widget.repId}/stock/upload-excel',
      );

      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      final file = pickResult.files.first;
      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path!),
        );
      } else {
        throw Exception('File tidak dapat dibaca');
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final response = http.Response(responseBody, streamedResponse.statusCode);

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
          setState(() {
            _isUploading = false;
            _isSuccess = true;
            _uploadMessage = jsonResponse['message']?.toString();
            if (jsonResponse['errors'] != null) {
              _errors = List<String>.from(jsonResponse['errors']);
            }
          });
        } catch (e) {
          setState(() {
            _isUploading = false;
            _isSuccess = false;
            _uploadMessage = 'Gagal memparse response server: $e';
          });
        }
      } else {
        try {
          final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
          setState(() {
            _isUploading = false;
            _isSuccess = false;
            _uploadMessage = errorJson['error']?.toString() ?? 'Upload gagal';
          });
        } catch (e) {
          // If response is not JSON (e.g., HTML error page)
          setState(() {
            _isUploading = false;
            _isSuccess = false;
            _uploadMessage = 'Server error (${response.statusCode}): Response bukan JSON';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _isSuccess = false;
        _uploadMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.repName != null
        ? 'Upload Stock — ${widget.repName}'
        : 'Upload Stock via Excel';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.upload_file, size: 48, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text(
                      'Upload stok untuk Sales Rep #${widget.repId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Format: nama_barang, product_code, distributor_stock, van_stock, outlet_stock\n'
                      'Isi kolom stok sesuai lokasi penyimpanan untuk setiap produk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _downloadTemplate,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Template'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickAndUploadFile,
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedFileName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text('File: $_selectedFileName'),
                      ),
                    if (_isUploading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                    if (_uploadMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _uploadMessage!,
                          style: TextStyle(
                            color: _isSuccess ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    if (_errors.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detail error:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            ..._errors.map(
                              (err) => Text(
                                '• $err',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
