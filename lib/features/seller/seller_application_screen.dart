import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/seller_application_model.dart';
import '../../data/datasources/seller_application_remote_ds.dart';
import '../../repositories/society_repository.dart';
import '../../models/society_model.dart';
import '../../config/categories.dart';

class SellerApplicationScreen extends StatefulWidget {
  const SellerApplicationScreen({super.key});

  @override
  State<SellerApplicationScreen> createState() =>
      _SellerApplicationScreenState();
}

class _SellerApplicationScreenState extends State<SellerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // 🔹 Controllers
  final _shopNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _panController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _gstinController = TextEditingController();
  final _registrationController = TextEditingController();
  final _flatBlockController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  final _bankAccountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankNameController = TextEditingController();

  // 🔹 Document files
  File? _panFile;
  File? _aadhaarFile;
  File? _gstFile;

  // 🔹 Upload UI states (ADD)
  bool _panUploading = false;
  bool _aadhaarUploading = false;
  bool _gstUploading = false;

  bool _panUploaded = false;
  bool _aadhaarUploaded = false;
  bool _gstUploaded = false;

  // 🔽 Dropdown values
  String? _category;
  String _businessType = 'Individual';

  String? _selectedSocietyId;
  SocietyModel? _selectedSociety;

  final _remoteDS = SellerApplicationRemoteDS();
  final _societyRepo = SocietyRepository();

  bool _loading = false;

  // Individual / proprietorship use personal ID (PAN + Aadhaar); registered
  // entities use GSTIN + a registration number instead.
  bool get _personal =>
      _businessType == 'Individual' || _businessType == 'Proprietorship';

  final List<String> _categories = kShopCategories;

  final List<String> _businessTypes = [
    'Individual',
    'Proprietorship',
    'Partnership',
    'Private Limited',
    'LLP',
  ];

  Future<File?> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  Future<String> _uploadDocument({
    required File file,
    required String societyId,
    required String sellerId,
    required String docType,
  }) async {
    final ref = FirebaseStorage.instance.ref(
      'seller_documents/$societyId/$sellerId/$docType.${file.path.split('.').last}',
    );

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _saveDocumentUrl({
    required String societyId,
    required String sellerId,
    required String docType,
    required String url,
  }) async {
    await FirebaseFirestore.instance
        .collection('societies')
        .doc(societyId)
        .collection('sellers')
        .doc(sellerId)
        .set({
          'documents.$docType': url,
          'documentStatus': 'pending',
        }, SetOptions(merge: true));
  }

  /* --------------------------------------------------
     SUBMIT
     -------------------------------------------------- */

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    final aad = _aadhaarController.text.trim();

    try {
      final application = SellerApplicationModel(
        uid: user.uid,
        shopName: _shopNameController.text.trim(),
        category: _category!,
        description: _descriptionController.text.trim(),
        businessType: _businessType,
        panNumber: _panController.text.trim().toUpperCase(),
        aadhaarLast4:
            _personal && aad.length >= 4 ? aad.substring(aad.length - 4) : '',
        gstin: _gstinController.text.trim().isEmpty
            ? null
            : _gstinController.text.trim(),
        registrationNumber: _personal || _registrationController.text.trim().isEmpty
            ? null
            : _registrationController.text.trim(),
        addressLine:
            'Flat: ${_flatBlockController.text.trim()}, Society: ${_selectedSociety!.name}',
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        bankAccountNumber: _bankAccountController.text.trim().isEmpty
            ? null
            : _bankAccountController.text.trim(),
        ifscCode: _ifscController.text.trim().isEmpty
            ? null
            : _ifscController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _remoteDS.submitApplication(application);

      final sellerId = user.uid;
      final societyId = _selectedSocietyId!;

      if (_panFile != null) {
        final url = await _uploadDocument(
          file: _panFile!,
          societyId: societyId,
          sellerId: sellerId,
          docType: 'pan',
        );
        await _saveDocumentUrl(
          societyId: societyId,
          sellerId: sellerId,
          docType: 'pan',
          url: url,
        );
      }

      if (_aadhaarFile != null) {
        final url = await _uploadDocument(
          file: _aadhaarFile!,
          societyId: societyId,
          sellerId: sellerId,
          docType: 'aadhaar',
        );
        await _saveDocumentUrl(
          societyId: societyId,
          sellerId: sellerId,
          docType: 'aadhaar',
          url: url,
        );
      }

      if (_gstFile != null) {
        final url = await _uploadDocument(
          file: _gstFile!,
          societyId: societyId,
          sellerId: sellerId,
          docType: 'gst',
        );
        await _saveDocumentUrl(
          societyId: societyId,
          sellerId: sellerId,
          docType: 'gst',
          url: url,
        );
      }


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller application submitted successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      _showError('Submission failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /* --------------------------------------------------
     UI
     -------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Application')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _field(
                _shopNameController,
                'Proposed Shop Name',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Shop name is required' : null,
              ),

              _dropdown(
                label: 'What do you sell?',
                value: _category,
                items: _categories,
                validator: (v) =>
                    v == null ? 'Category is required' : null,
                onChanged: (v) => setState(() => _category = v),
              ),

              _dropdown(
                label: 'Business Type',
                value: _businessType,
                items: _businessTypes,
                validator: (v) =>
                    v == null ? 'Business type is required' : null,
                onChanged: (v) =>
                    setState(() => _businessType = v ?? 'Individual'),
              ),

              const Divider(),

              _field(
                _panController,
                _personal ? 'PAN Number' : 'Business PAN',
                validator: (v) =>
                    v == null || v.length != 10 ? 'Enter valid PAN' : null,
              ),
             ElevatedButton(
                  onPressed: _panUploading
                      ? null
                      : () async {
                          setState(() => _panUploading = true);
                          final file = await _pickDocument();
                          if (file != null) {
                            _panFile = file;
                            _panUploaded = true;
                          }
                          setState(() => _panUploading = false);
                        },
                  child: _panUploading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_panUploaded ? 'PAN Uploaded ✅' : 'Upload PAN Document'),
                ),
              if (_personal) ...[
                _field(
                  _aadhaarController,
                  'Aadhaar Number (12 digits)',
                  keyboard: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Aadhaar is required';
                    }
                    if (!RegExp(r'^\d{12}$').hasMatch(v)) {
                      return 'Aadhaar must be 12 digits';
                    }
                    return null;
                  },
                ),
                ElevatedButton(
                  onPressed: _aadhaarUploading
                      ? null
                      : () async {
                          setState(() => _aadhaarUploading = true);
                          final file = await _pickDocument();
                          if (file != null) {
                            _aadhaarFile = file;
                            _aadhaarUploaded = true;
                          }
                          setState(() => _aadhaarUploading = false);
                        },
                  child: _aadhaarUploading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _aadhaarUploaded
                              ? 'Aadhaar Uploaded ✅'
                              : 'Upload Aadhaar Document',
                        ),
                ),
              ],

              _field(
                _gstinController,
                _personal ? 'GSTIN (Optional)' : 'GSTIN',
                validator: (v) => _personal
                    ? null
                    : (v == null || v.trim().length < 15
                        ? 'GSTIN is required for a registered business'
                        : null),
              ),

              if (!_personal)
                _field(
                  _registrationController,
                  'Registration / CIN number (optional)',
                ),

              ElevatedButton(
                onPressed: _gstUploading
                    ? null
                    : () async {
                        setState(() => _gstUploading = true);
                        final file = await _pickDocument();
                        if (file != null) {
                          _gstFile = file;
                          _gstUploaded = true;
                        }
                        setState(() => _gstUploading = false);
                      },
                child: _gstUploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_gstUploaded
                        ? 'Document Uploaded ✅'
                        : (_personal
                            ? 'Upload GST Document'
                            : 'Upload GST / Incorporation Certificate')),
              ),
              const Divider(),

              _field(
                _flatBlockController,
                'Flat / Block Number',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Address is required' : null,
              ),

              FutureBuilder<List<SocietyModel>>(
                future: _societyRepo.getActiveSocieties(),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final societies = snapshot.data!;

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Society',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedSocietyId,
                    validator: (v) =>
                        v == null ? 'Society is required' : null,
                    items: societies
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSocietyId = value;
                        _selectedSociety =
                            societies.firstWhere((s) => s.id == value);
                      });
                    },
                  );
                },
              ),

              _field(
                _stateController,
                'State',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'State is required' : null,
              ),

              _field(
                _cityController,
                'City',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'City is required' : null,
              ),

              _field(
                _pincodeController,
                'Pincode',
                validator: (v) =>
                    v == null || v.length != 6 ? 'Enter valid pincode' : null,
              ),

              const Divider(),

              _field(_bankAccountController, 'Bank Account Number (Optional)'),
              _field(_ifscController, 'IFSC (Optional)'),
              _field(_bankNameController, 'Account Holder Name (Optional)'),

              const SizedBox(height: 24),

              _loading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Submit Application'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  /* --------------------------------------------------
     REUSABLE WIDGETS
     -------------------------------------------------- */
  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: '',
        ).copyWith(labelText: label),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: value,
        validator: validator,
        items: items
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
