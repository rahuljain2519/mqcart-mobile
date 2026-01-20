import 'package:flutter/material.dart';

import 'admin_societies_screen.dart';
import 'admin_users_screen.dart';
import 'admin_seller_requests_screen.dart';
import 'admin_analytics_home.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqBg = Color(0xFFF6F7FB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mqBg,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // --------------------------------------------------
            // 🔹 QUICK ACTIONS
            // --------------------------------------------------
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _AdminActionCard(
                  icon: Icons.apartment,
                  label: 'Manage Societies',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminSocietiesScreen(),
                      ),
                    );
                  },
                ),
                _AdminActionCard(
                  icon: Icons.people,
                  label: 'Manage Users',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminUsersScreen(),
                      ),
                    );
                  },
                ),
                // ✅ NEW: ANALYTICS ENTRY
                _AdminActionCard(
                  icon: Icons.analytics,
                  label: 'Analytics',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminAnalyticsHome(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // 🛍️ SELLER APPLICATIONS
            // --------------------------------------------------
            const Text(
              'Seller Applications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _AdminActionCard(
              icon: Icons.storefront,
              label: 'Seller Requests',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminSellerRequestsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// 🔹 REUSABLE ADMIN CARD (MQ CART FINAL STYLE)
// --------------------------------------------------
class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const Color mqOrange = Color(0xFFFF6A00);

  const _AdminActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: mqOrange.withOpacity(0.15),
              child: Icon(
                icon,
                color: mqOrange,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
