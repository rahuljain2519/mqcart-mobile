import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'profile_screen.dart';
import '../auth/login_screen.dart';

class ProfileRouter extends StatelessWidget {
  const ProfileRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please login to view your profile',
              textAlign: TextAlign.center,
            ),
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

    return ProfileScreen();
  }
}
