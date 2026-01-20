import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/shop_repository.dart';
import '../../repositories/user_repository.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../services/push_notification_service.dart';

import '../../core/seller_guard.dart';

import 'seller_onboarding_screen.dart';
import 'seller_products_screen.dart';
import 'seller_order_root_screen.dart';
import 'edit_shop_screen.dart';
import 'activate_shop_screen.dart';
import 'seller_shop_preview_screen.dart';

class SellerHome extends StatefulWidget {
  const SellerHome({super.key});

  @override
  State<SellerHome> createState() => _SellerHomeState();
}

class _SellerHomeState extends State<SellerHome> {
  Future<ShopModel?>? _shopFuture;

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqLightOrange = Color(0xFFFFE1CC);

  bool _pushInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPushOnce();
  }

  Future<void> _initPushOnce() async {
    if (_pushInitialized) return;

    final user = await UserRepository().getCurrentUser();
    if (user == null) return;

    if (!SellerGuard.isSeller(user)) return;
    if (user.shopId == null) return;

    _pushInitialized = true;
    await PushNotificationService.initSellerPush();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserRepository().streamCurrentUser(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = userSnapshot.data!;

        if (SellerGuard.needsOnboarding(user)) {
          return const SellerOnboardingScreen();
        }

        if (!SellerGuard.isSeller(user)) {
          return const Center(child: Text('Seller access unavailable'));
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('shops')
              .doc(user.shopId)
              .snapshots(),
          builder: (context, shopSnapshot) {
            if (shopSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!shopSnapshot.hasData || !shopSnapshot.data!.exists) {
              return const SellerOnboardingScreen();
            }

            final shop = ShopModel.fromJson(
              shopSnapshot.data!.data()!,
              shopSnapshot.data!.id,
            );

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _storeHeader(shop),

                  if (shop.isActive) ...[
                    const SizedBox(height: 10),
                    _planInfo(context, shop),
                  ],

                  if (!shop.isActive) ...[
                    const SizedBox(height: 12),
                    _activationBanner(context, shop),
                  ],

                  const SizedBox(height: 16),
                  _todaySnapshot(shop.sellerId),
                  const SizedBox(height: 20),
                  _actionGrid(context, shop),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // STORE HEADER
  // ---------------------------
  Widget _storeHeader(ShopModel shop) {
    final isActive = shop.isActive;

    return Container(
      decoration: BoxDecoration(
        color: mqLightOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Icon(Icons.store, color: mqOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.shopName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // PLAN INFO + UPGRADE
  // ---------------------------
  Widget _planInfo(BuildContext context, ShopModel shop) {
    final planLabel = shop.plan?.toUpperCase() ?? 'NOT SELECTED';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Plan: $planLabel  •  Limit: ${shop.productLimit} products',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivateShopScreen(shop: shop),
                ),
              );

              if (result != null && result['activated'] == true) {
                setState(() {
                  _shopFuture = ShopRepository().getMyShop(shop.sellerId);
                });
              }
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // ACTIVATION BANNER
  // ---------------------------
  Widget _activationBanner(BuildContext context, ShopModel shop) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your shop is inactive',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Activate your shop to start receiving orders.',
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: mqOrange,
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivateShopScreen(shop: shop),
                ),
              );

              if (result != null && result['activated'] == true) {
                setState(() {
                  _shopFuture = ShopRepository().getMyShop(shop.sellerId);
                });
              }
            },
            child: const Text('Activate Shop'),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // TODAY SNAPSHOT
  // ---------------------------
  Widget _todaySnapshot(String sellerId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final todayOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: sellerId)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .snapshots();

    final allOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: todayOrdersStream,
      builder: (context, todaySnapshot) {
        if (!todaySnapshot.hasData) {
          return const SizedBox(
            height: 110,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final todayDocs = todaySnapshot.data!.docs;
        final totalOrdersToday = todayDocs.length;
        final pendingToday =
            todayDocs.where((d) => d['status'] == 'placed').length;

        return StreamBuilder<QuerySnapshot>(
          stream: allOrdersStream,
          builder: (context, allSnapshot) {
            if (!allSnapshot.hasData) {
              return const SizedBox(
                height: 110,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            double totalEarnings = 0;
            for (final d in allSnapshot.data!.docs) {
              if (d['status'] != 'cancelled') {
                totalEarnings += (d['totalAmount'] ?? 0).toDouble();
              }
            }

            return SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _statCard(
                    icon: Icons.receipt_long,
                    label: 'Orders Today',
                    value: totalOrdersToday.toString(),
                    iconColor: Colors.grey,
                  ),
                  _statCard(
                    icon: Icons.currency_rupee,
                    label: 'Total Earnings',
                    value: '₹${totalEarnings.toStringAsFixed(0)}',
                    iconColor: mqOrange,
                  ),
                  _statCard(
                    icon: Icons.timer,
                    label: 'Pending',
                    value: pendingToday.toString(),
                    iconColor: Colors.amber,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: mqOrange.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _actionGrid(BuildContext context, ShopModel shop) {
  final isActive = shop.isActive;

  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    children: [
      _actionCard(
        Icons.inventory,
        'Products',
        'Add / Update',
        mqOrange,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SellerProductsScreen(shop: shop),
          ),
        ),
      ),
      _actionCard(
        Icons.shopping_bag,
        'Orders',
        isActive ? 'View & Manage' : 'Activate shop first',
        isActive ? mqOrange : Colors.grey,
        isActive
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SellerOrdersRootScreen(),
                  ),
                )
            : () {},
      ),
      _actionCard(
        Icons.storefront,
        'Shop Settings',
        'Profile & Timings',
        mqOrange,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditShopScreen(shop: shop),
          ),
        ),
      ),
      _actionCard(
        Icons.bar_chart,
        'Insights',
        'Coming Soon',
        Colors.grey,
        () {},
      ),

      // ✅ NEW — SHOP PREVIEW (ADDED, NOTHING REMOVED)
      _actionCard(
        Icons.visibility,
        'Shop Preview',
        'View as Customer',
        Colors.blue,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SellerShopPreviewScreen(shop: shop),
          ),
        ),
      ),
    ],
  );
}

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
