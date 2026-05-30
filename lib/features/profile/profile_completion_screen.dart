import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../models/society_model.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/society_repository.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final UserModel user;
  final bool isEditMode;

  const ProfileCompletionScreen({
    super.key,
    required this.user,
    this.isEditMode = false,
  });

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _flatController;

  final UserRepository _userRepository = UserRepository();
  final SocietyRepository _societyRepository = SocietyRepository();

  String _role = 'buyer';
  String? _selectedSocietyId;

  bool _loading = false;
  late Future<List<SocietyModel>> _societiesFuture;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(text: widget.user.name);
    _phoneController =
        TextEditingController(text: widget.user.phone); // +91XXXXXXXXXX
    _flatController =
        TextEditingController(text: widget.user.flatNumber);

    _role = (widget.user.role == 'seller') ? 'seller' : 'buyer';

    _selectedSocietyId =
        widget.user.societyId.isNotEmpty ? widget.user.societyId : null;

    _societiesFuture = _societyRepository.getActiveSocieties();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _flatController.dispose();
    super.dispose();
  }

  /* --------------------------------------------------
     SAVE PROFILE (PHONE IS TRUSTED & LOCKED)
     -------------------------------------------------- */
  Future<void> _saveProfile() async {
    if (_loading) return;

    final name = _nameController.text.trim();
    final flat = _flatController.text.trim();

    if (name.isEmpty) {
      _showError('Name is required');
      return;
    }

    if (flat.isEmpty) {
      _showError('Please enter flat / block number');
      return;
    }

    if (_selectedSocietyId == null) {
      _showError('Please select your society');
      return;
    }

    setState(() => _loading = true);

    try {
      final updatedUser = UserModel(
        uid: widget.user.uid,
        name: name,
        phone: widget.user.phone, // 🔒 DO NOT MODIFY
        role: _role,
        societyId: _selectedSocietyId!,
        flatNumber: flat,
      );

      await _userRepository.updateUser(updatedUser);

      if (mounted && widget.isEditMode) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to save profile. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Please complete your profile to continue',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),

                /// 🔒 PHONE NUMBER (READ-ONLY, NO VALIDATION)
                TextField(
                  controller: _phoneController,
                  enabled: false,
                  maxLength: null,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    helperText:
                        'Phone number cannot be changed once verified',
                    counterText: '',
                  ),
                ),

                /// 🆕 Flat / Block number
                TextField(
                  controller: _flatController,
                  decoration: const InputDecoration(
                    labelText: 'Flat / Block Number',
                    hintText: 'Eg: A-1204',
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  initialValue: _role.toUpperCase(),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                  ),
                ),

                const SizedBox(height: 16),

                FutureBuilder<List<SocietyModel>>(
                  future: _societiesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text(
                        'No societies available. Please contact admin.',
                      );
                    }

                    final societies = snapshot.data!;

                    return DropdownButtonFormField<String>(
                      value: _selectedSocietyId,
                      decoration: const InputDecoration(
                        labelText: 'Select Society',
                      ),
                      items: societies
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text('${s.name} (${s.city})'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedSocietyId = value);
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('Continue'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
