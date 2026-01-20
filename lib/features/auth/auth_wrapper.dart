import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../repositories/user_repository.dart';
import 'login_screen.dart';
import '../profile/profile_completion_screen.dart';
import '../home/main_shell.dart';
import '../../core/auth_intent.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 🔐 1. Listen to Firebase Auth state
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Not logged in
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        final uid = authSnapshot.data!.uid;

        // 🔥 2. Listen to Firestore user document
        return StreamBuilder(
          stream: UserRepository().streamUser(uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || userSnapshot.data == null) {
              return const LoginScreen();
            }

            final user = userSnapshot.data!;

            /* --------------------------------------------------
               🧾 PROFILE COMPLETION CHECK (ALL ROLES)
               -------------------------------------------------- */
            final nameEmpty = user.name.trim().isEmpty;
            final phoneEmpty = user.phone.trim().isEmpty;

            if (nameEmpty || phoneEmpty) {
              return ProfileCompletionScreen(
                user: user,
                isEditMode: true,
              );
            }

            /* --------------------------------------------------
               🧭 ENTER APP (ADMIN + BUYER + OTHER SELLERS)
               -------------------------------------------------- */
            final pendingIndex = AuthIntent.pendingTabIndex;
            AuthIntent.pendingTabIndex = null;

            return MainShell(
              initialIndex: pendingIndex ?? 0,
            );
          },
        );
      },
    );
  }
}
