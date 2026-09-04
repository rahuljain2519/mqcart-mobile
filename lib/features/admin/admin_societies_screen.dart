import 'package:flutter/material.dart';

import '../../models/society_model.dart';
import '../../repositories/society_repository.dart';
import 'create_society_screen.dart';

class AdminSocietiesScreen extends StatelessWidget {
  const AdminSocietiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SocietyRepository societyRepository = SocietyRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Societies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateSocietyScreen(),
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<List<SocietyModel>>(
        stream: societyRepository.streamActiveSocieties(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No societies found'),
            );
          }

          final societies = snapshot.data!;

          return ListView.builder(
            itemCount: societies.length,
            itemBuilder: (context, index) {
              final society = societies[index];

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(society.name),
                  subtitle: Text(society.city),
                  leading: Icon(
                    society.isActive
                        ? Icons.check_circle
                        : Icons.cancel,
                    color:
                        society.isActive ? Colors.green : Colors.red,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Society'),
                          content: Text(
                            'Are you sure you want to delete "${society.name}"?\n\nThis action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await societyRepository
                            .deleteSociety(society.id);

                        // 🔄 Refresh screen
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Society deleted'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
