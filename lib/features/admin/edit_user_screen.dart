import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/society_repository.dart';
import '../../models/society_model.dart';

class EditUserScreen extends StatefulWidget {
  final UserModel user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late String _role;
  late String _societyId;

  final UserRepository _userRepository = UserRepository();
  final SocietyRepository _societyRepository = SocietyRepository();

  late Future<List<SocietyModel>> _societiesFuture;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _societyId = widget.user.societyId;
    _societiesFuture = _societyRepository.getActiveSocieties();
  }

  Future<void> _save() async {
    final updated = UserModel(
      uid: widget.user.uid,
      name: widget.user.name,
      phone: widget.user.phone,
      role: _role,
      societyId: _societyId,
    );

    await _userRepository.updateUser(updated);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit User')),
      body: FutureBuilder<List<SocietyModel>>(
        future: _societiesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final societies = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('User: ${widget.user.uid}'),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                    DropdownMenuItem(value: 'seller', child: Text('Seller')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v!),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _societyId,
                  decoration:
                      const InputDecoration(labelText: 'Society'),
                  items: societies
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} (${s.city})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _societyId = v!),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
