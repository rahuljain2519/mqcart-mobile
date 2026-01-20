import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';

import '../buyer/buyer_home.dart';
import '../seller/seller_home.dart';
import '../admin/admin_home.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    // Guest → Buyer browsing
    if (firebaseUser == null) {
      return const BuyerHome();
    }

    return FutureBuilder<UserModel?>(
      future: UserRepository().getUser(firebaseUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user == null) return const BuyerHome();

        switch (user.role) {
          case 'admin':
            return const AdminHome();
          case 'seller':
            return const SellerHome();
          default:
            return const BuyerHome();
        }
      },
    );
  }
}
