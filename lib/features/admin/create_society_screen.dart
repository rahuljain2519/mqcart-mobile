import 'package:flutter/material.dart';

import '../../models/society_model.dart';
import '../../repositories/society_repository.dart';

class CreateSocietyScreen extends StatefulWidget {
  const CreateSocietyScreen({super.key});

  @override
  State<CreateSocietyScreen> createState() =>
      _CreateSocietyScreenState();
}

class _CreateSocietyScreenState extends State<CreateSocietyScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  final SocietyRepository _societyRepository = SocietyRepository();
  bool _loading = false;

  Future<void> _createSociety() async {
    if (_nameController.text.isEmpty ||
        _cityController.text.isEmpty) {
      return;
    }

    setState(() => _loading = true);

    final society = SocietyModel(
      id: '',
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      isActive: true,
    );

    await _societyRepository.createSociety(society);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Society'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Society Name'),
            ),
            TextField(
              controller: _cityController,
              decoration:
                  const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _createSociety,
                    child: const Text('Create Society'),
                  ),
          ],
        ),
      ),
    );
  }
}
