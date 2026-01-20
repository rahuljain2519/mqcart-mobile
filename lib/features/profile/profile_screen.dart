import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../repositories/user_repository.dart';
import '../../repositories/society_repository.dart';
import '../../models/user_model.dart';
import '../../models/society_model.dart';
import '../../data/datasources/seller_application_remote_ds.dart';
import '../../models/seller_application_model.dart';

import '../seller/seller_application_screen.dart';
import 'profile_completion_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color mqOrange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    final uid = firebaseUser.uid;
    final userRepository = UserRepository();
    final societyRepository = SocietyRepository();
    final sellerAppDS = SellerApplicationRemoteDS();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<UserModel>(
        future: userRepository.getUser(uid),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnap.hasData) {
            return const Center(child: Text('Profile data not found'));
          }

          final user = userSnap.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // =========================
                // PROFILE HEADER
                // =========================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF8C42),
                        Color(0xFFFF6A00),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: mqOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: const TextStyle(
                                color: mqOrange,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _infoTile(
                  icon: Icons.phone,
                  label: 'Phone',
                  value: user.phone,
                ),

                FutureBuilder<SocietyModel?>(
                  future: societyRepository.getSocietyById(user.societyId),
                  builder: (_, societySnap) {
                    return _infoTile(
                      icon: Icons.apartment,
                      label: 'Society',
                      value: societySnap.data?.name ?? 'Not assigned',
                    );
                  },
                ),

                _infoTile(
                  icon: Icons.home,
                  label: 'Flat / Block',
                  value: user.flatNumber,
                ),

                const SizedBox(height: 24),

                // =========================
                // EDIT PROFILE
                // =========================
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mqOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileCompletionScreen(
                            user: user,
                            isEditMode: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // =========================
                // SELLER SECTION (STREAM BASED)
                // =========================
                StreamBuilder<SellerApplicationModel?>(
                  stream: sellerAppDS.streamMyApplication(uid),
                  builder: (context, appSnap) {
                    // 🔹 NO APPLICATION
                    if (!appSnap.hasData) {
                      return OutlinedButton.icon(
                        icon: const Icon(Icons.store),
                        label: const Text('Become a Seller'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mqOrange,
                          side: const BorderSide(color: mqOrange),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SellerApplicationScreen(),
                            ),
                          );
                        },
                      );
                    }

                    final app = appSnap.data!;

                    if (app.status == 'pending') {
                      return _statusBox(
                        'Your seller application is under review',
                        mqOrange,
                      );
                    }

                    if (app.status == 'rejected') {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _statusBox(
                            'Your seller application was rejected',
                            Colors.red,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Re-Apply as Seller'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: mqOrange,
                              side: const BorderSide(color: mqOrange),
                              minimumSize:
                                  const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SellerApplicationScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    }

                    return const SizedBox();
                  },
                ),

                const SizedBox(height: 20),

                // =========================
                // LOGOUT
                // =========================
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// =========================
/// STATUS BOX
/// =========================
Widget _statusBox(String message, Color color) {
  return Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// =========================
/// INFO TILE
/// =========================
Widget _infoTile({
  required IconData icon,
  required String label,
  required String value,
}) {
  const Color mqOrange = Color(0xFFFF6A00);

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: mqOrange.withOpacity(0.12),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, color: mqOrange),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
