import 'package:flutter/material.dart';

import '../../repositories/user_repository.dart';
import '../../models/user_model.dart';
import 'admin_seller_review_screen.dart';

class AdminSellerRequestsScreen extends StatelessWidget {
  const AdminSellerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Requests')),
      body: StreamBuilder<List<UserModel>>(
        stream: UserRepository().streamSellerRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('No pending requests'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.phone),
                  trailing: ElevatedButton(
                    child: const Text('Review'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminSellerReviewScreen(user: user),
                        ),
                      );
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
