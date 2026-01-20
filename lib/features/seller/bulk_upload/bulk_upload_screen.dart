import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';

import '../../../repositories/user_repository.dart';
import 'bulk_product_row.dart';
import 'bulk_upload_service.dart';

class BulkUploadScreen extends StatefulWidget {
  final String shopId;

  const BulkUploadScreen({super.key, required this.shopId});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  File? _csvFile;
  File? _zipFile;

  final List<BulkProductRow> _rows = [];
  final Map<String, List<String>> _imageMap = {};
  final Map<String, List<File>> _imageFileMap = {};
  final List<String> _errors = [];
  String normalizePrefix(String value) {
  return value
      .replaceAll('\uFEFF', '') // BOM
      .replaceAll(RegExp(r'\s+'), '') // invisible whitespace
      .trim()
      .toLowerCase();
  }

  bool _csvLoaded = false;
  bool _zipLoaded = false;

  bool _uploading = false;
  double _progress = 0;

  bool get _isReady =>
      _rows.isNotEmpty &&
      _imageMap.isNotEmpty &&
      _errors.isEmpty &&
      !_uploading;

  // -----------------------------
  // PICK CSV
  // -----------------------------
  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return;

    _csvFile = File(result.files.single.path!);
    _csvLoaded = false;

    await _parseCsv();

    _csvLoaded = true;
    _runValidationIfReady();
  }

  // -----------------------------
  // PICK ZIP
  // -----------------------------
  Future<void> _pickZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null) return;

    _zipFile = File(result.files.single.path!);
    _zipLoaded = false;

    await _extractZip();

    _zipLoaded = true;
    _runValidationIfReady();
  }

  // -----------------------------
  // PARSE CSV
  // -----------------------------
  Future<void> _parseCsv() async {
    _rows.clear();
    _errors.clear();

    final content = await _csvFile!.readAsString();
    final csvData = const CsvToListConverter().convert(content);

    if (csvData.length <= 1) {
      _errors.add('CSV has no data rows');
      setState(() {});
      return;
    }

    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];

      try {
        String clean(dynamic v) =>
            v.toString().replaceAll('\uFEFF', '').trim();

        _rows.add(
          BulkProductRow(
            name: clean(row[0]),
            price: double.parse(clean(row[1])),
            quantity: int.parse(clean(row[2])),
            category: clean(row[3]),
            description: clean(row[4]),
            isActive: clean(row[5]).toLowerCase() == 'true',
            imagePrefix: normalizePrefix(row[6].toString()),

            // OPTIONAL DELIVERY TIME
            deliveryUnit: row.length > 7 && clean(row[7]).isNotEmpty
                ? clean(row[7]).toLowerCase()
                : null,
            deliveryMin: row.length > 8 && clean(row[8]).isNotEmpty
                ? int.parse(clean(row[8]))
                : null,
            deliveryMax: row.length > 9 && clean(row[9]).isNotEmpty
                ? int.parse(clean(row[9]))
                : null,

            coverIndex: row.length > 10 && clean(row[10]).isNotEmpty
                ? int.parse(clean(row[10]))
                : 0,
          ),
        );
      } catch (_) {
        _errors.add('Invalid row at line ${i + 1}');
      }
    }

    setState(() {});
  }

  // -----------------------------
  // EXTRACT ZIP
  // -----------------------------
  Future<void> _extractZip() async {
    _imageMap.clear();
    _imageFileMap.clear();

    final bytes = await _zipFile!.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await Directory.systemTemp.createTemp();

    for (final file in archive) {
      if (!file.isFile) continue;

      final name = file.name.toLowerCase();
      if (!name.endsWith('.jpg') && !name.endsWith('.png')) {
        continue;
      }

      // SAME PREFIX LOGIC AS OLD CODE
      final prefix = normalizePrefix(
          name.split('_').first,
        );

      _imageMap.putIfAbsent(prefix, () => []);
      _imageMap[prefix]!.add(name);

      final fileNameOnly = name.split('/').last;
      final outFile = File('${tempDir.path}/$fileNameOnly');
      await outFile.writeAsBytes(file.content as List<int>);

      _imageFileMap.putIfAbsent(prefix, () => []);
      _imageFileMap[prefix]!.add(outFile);
    }

    setState(() {});
  }

  // -----------------------------
  // VALIDATION (RUN ONCE)
  // -----------------------------
  void _runValidationIfReady() {
    if (_csvLoaded && _zipLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validate();
      });
    }
  }

  void _validate() {
    _errors.clear();

    for (final row in _rows) {
      if (!_imageMap.containsKey(row.imagePrefix)) {
        _errors.add(
          'Missing images for product: ${row.name} (${row.imagePrefix})',
        );
      } else if (_imageMap[row.imagePrefix]!.length > 4) {
        _errors.add(
          'More than 4 images for prefix: ${row.imagePrefix}',
        );
      }
    }

    for (final prefix in _imageMap.keys) {
      final exists = _rows.any((r) => r.imagePrefix == prefix);
      if (!exists) {
        _errors.add(
          'Images found but no CSV row for prefix: $prefix',
        );
      }
    }

    setState(() {});
  }

  // -----------------------------
  // START UPLOAD
  // -----------------------------
  Future<void> _startUpload() async {
    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      final user = await UserRepository().streamCurrentUser().first;

      if (user == null || user.societyId.isEmpty) {
        throw Exception('Unable to resolve societyId');
      }

      await BulkUploadService().uploadProducts(
        shopId: widget.shopId,
        societyId: user.societyId,
        rows: _rows,
        imageFiles: _imageFileMap,
        onProgress: (p) => setState(() => _progress = p),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bulk upload completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Upload Products')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Steps:\n'
              '1. Upload products.csv\n'
              '2. Upload images.zip\n'
              '3. Image names: prefix_index.jpg (milk_1.jpg)\n'
              '4. Maximum 4 images per product',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

            _filePicker(
              'Select products.csv',
              Icons.upload_file,
              _csvFile?.path.split('/').last,
              _csvFile == null ? _pickCsv : null,
            ),

            const SizedBox(height: 12),

            _filePicker(
              'Select images.zip',
              Icons.folder_zip,
              _zipFile?.path.split('/').last,
              _zipFile == null ? _pickZip : null,
            ),

            const SizedBox(height: 16),

            if (_errors.isNotEmpty) _errorBox(),

            if (_errors.isEmpty && _rows.isNotEmpty) _preview(),

            if (_uploading) _progressBar(),

            if (_isReady)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload Products'),
                  onPressed: _startUpload,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filePicker(
    String label,
    IconData icon,
    String? fileName,
    VoidCallback? onPressed,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: fileName != null ? Text(fileName) : null,
        trailing: onPressed != null
            ? ElevatedButton(onPressed: onPressed, child: const Text('Choose'))
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _errorBox() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _errors
              .map(
                (e) => Text('❌ $e',
                    style: const TextStyle(color: Colors.red)),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _preview() {
    return Expanded(
      child: ListView.builder(
        itemCount: _rows.length,
        itemBuilder: (_, i) {
          final row = _rows[i];
          final count = _imageMap[row.imagePrefix]?.length ?? 0;

          return ListTile(
            leading: Icon(
              count > 0 ? Icons.check_circle : Icons.error,
              color: count > 0 ? Colors.green : Colors.red,
            ),
            title: Text(row.name),
            subtitle: Text('₹${row.price} • Qty ${row.quantity} • $count images'),
          );
        },
      ),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 6),
          Text('Uploading ${(100 * _progress).toInt()}%'),
        ],
      ),
    );
  }
}
