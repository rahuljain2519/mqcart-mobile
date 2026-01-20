import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../seller/seller_order_root_screen.dart';
import '../buyer/buyer_orders_screen.dart';
import '../auth/login_screen.dart';
import '../../repositories/user_repository.dart';

class OrdersRouter extends StatelessWidget {
  const OrdersRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    // 🔓 Not logged in
    if (firebaseUser == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please login to view your orders'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                );
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }

    // 🔐 Logged in → decide by role
    return FutureBuilder(
      future: UserRepository().getUser(firebaseUser.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data!;

        if (user.role == 'seller') {
          return const SellerOrdersRootScreen();
        }

        // buyer / admin
        return const BuyerOrdersScreen();
      },
    );
  }
}
