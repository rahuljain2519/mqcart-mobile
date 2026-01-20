import 'package:flutter/material.dart';

import 'admin_analytics_overview.dart';
//import 'admin_analytics_sellers.dart';
//import 'admin_analytics_societies.dart';

class AdminAnalyticsHome extends StatelessWidget {
  const AdminAnalyticsHome({super.key});

  static const Color mqOrange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _AnalyticsCard(
              icon: Icons.dashboard,
              label: 'Overview',
              onTap: () => _go(context, const AdminAnalyticsOverview()),
            ),
            // _AnalyticsCard(
            //   icon: Icons.store,
            //   label: 'Sellers',
            //   onTap: () => _go(context, const AdminAnalyticsSellers()),
            // ),
            // _AnalyticsCard(
            //   icon: Icons.apartment,
            //   label: 'Societies',
            //   onTap: () => _go(context, const AdminAnalyticsSocieties()),
            // ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _AnalyticsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnalyticsCard({
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
              color: Colors.black.withOpacity(0.05),
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
              backgroundColor: Colors.orange.withOpacity(0.15),
              child: Icon(icon, color: Colors.orange, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
