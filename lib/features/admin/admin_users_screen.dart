import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import 'admin_seller_detail_screen.dart';


class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UserRepository userRepository = UserRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sellers')),
      body: StreamBuilder<List<UserModel>>(
        stream: userRepository.streamAllSellers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No sellers found'),
            );
          }

          final sellers = snapshot.data!;

          return ListView.builder(
            itemCount: sellers.length,
            itemBuilder: (context, index) {
              final user = sellers[index];

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    user.name.isEmpty ? '(No Name)' : user.name,
                  ),
                  subtitle: Text(
                    'Status: ${user.sellerStatus}\nSociety: ${user.societyId}',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminSellerDetailScreen(user: user),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
