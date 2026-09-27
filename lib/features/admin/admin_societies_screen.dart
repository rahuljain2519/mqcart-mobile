import 'package:flutter/material.dart';

import '../../models/society_model.dart';
import '../../models/shop_model.dart';
import '../../repositories/society_repository.dart';
import '../../repositories/shop_repository.dart';
import 'create_society_screen.dart';

/// Every shop in a society (active or not), shown once expanded.
class _SocietyShops extends StatelessWidget {
  final String societyId;
  const _SocietyShops({required this.societyId});

  @override
  Widget build(BuildContext context) {
    final shopRepository = ShopRepository();
    return StreamBuilder<List<ShopModel>>(
      stream: shopRepository.streamAllShopsForSociety(societyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Loading shops…'),
          );
        }
        final shops = snapshot.data ?? [];
        if (shops.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('No shops in this society yet.'),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: shops
                .map(
                  (s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.shopName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${s.phone.isEmpty ? 'No phone' : s.phone} · Plan ${s.plan} · ${s.productCount}/${s.productLimit} products',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: s.isActive
                                ? Colors.green.withOpacity(0.12)
                                : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            s.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: s.isActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class AdminSocietiesScreen extends StatefulWidget {
  const AdminSocietiesScreen({super.key});

  @override
  State<AdminSocietiesScreen> createState() => _AdminSocietiesScreenState();
}

class _AdminSocietiesScreenState extends State<AdminSocietiesScreen> {
  String? _expandedSocietyId;

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
                MaterialPageRoute(builder: (_) => const CreateSocietyScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SocietyModel>>(
        stream: societyRepository.streamActiveSocieties(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No societies found'));
          }

          final societies = snapshot.data!;

          return ListView.builder(
            itemCount: societies.length,
            itemBuilder: (context, index) {
              final society = societies[index];

              final isExpanded = _expandedSocietyId == society.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(society.name),
                      subtitle: Text(society.city),
                      leading: Icon(
                        society.isActive ? Icons.check_circle : Icons.cancel,
                        color: society.isActive ? Colors.green : Colors.red,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _expandedSocietyId = isExpanded
                                    ? null
                                    : society.id;
                              });
                            },
                            child: Text(
                              isExpanded ? 'Hide shops' : 'View shops',
                            ),
                          ),
                          IconButton(
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
                                await societyRepository.deleteSociety(
                                  society.id,
                                );

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
                        ],
                      ),
                    ),
                    if (isExpanded) _SocietyShops(societyId: society.id),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
