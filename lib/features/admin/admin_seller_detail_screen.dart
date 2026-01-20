import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../repositories/shop_repository.dart';

class AdminSellerDetailScreen extends StatelessWidget {
  final UserModel user;

  const AdminSellerDetailScreen({
    super.key,
    required this.user,
  });

  static const Color mqOrange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    final ShopRepository shopRepository = ShopRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<ShopModel?>(
          future: shopRepository.getMyShop(user.uid),
          builder: (context, snapshot) {
            final shop = snapshot.data;

            return ListView(
              children: [
                /// 🧑 SELLER INFO
                _sectionTitle('Seller Information'),
                _infoTile('Name', user.name.isEmpty ? '(No Name)' : user.name),
                _infoTile('Phone', user.phone),
                _infoTile('Role', user.role.toUpperCase()),
                _infoTile('Seller Status', user.sellerStatus.toUpperCase()),
                _infoTile('Society ID', user.societyId),

                const SizedBox(height: 24),

                /// 🏪 SHOP INFO
                _sectionTitle('Shop Information'),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (shop == null)
                  _emptyState(
                    'Shop not created yet',
                    'Seller is approved but has not created a shop.',
                  )
                else ...[
                  _infoTile('Shop Name', shop.shopName),
                  _infoTile(
                    'Shop Status',
                    shop.isActive ? 'ACTIVE' : 'INACTIVE',
                    valueColor:
                        shop.isActive ? Colors.green : Colors.red,
                  ),
                  _infoTile(
                    'Verification',
                    shop.isVerified ? 'VERIFIED' : 'NOT VERIFIED',
                  ),
                  _infoTile(
                    'Plan',
                    (shop.plan ?? 'Not Selected').toUpperCase(),
                  ),
                  _infoTile(
                    'Product Limit',
                    shop.productLimit.toString(),
                  ),
                  _infoTile(
                    'Products Added',
                    shop.productCount.toString(),
                  ),
                  _infoTile(
                    'Transaction Fee %',
                    (shop as dynamic).transactionFeePercent?.toString() ?? '0',
                  ),
                  const SizedBox(height: 12),

                  /// 🔁 ACTIVATE / DEACTIVATE TOGGLE
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Shop Active',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      shop.isActive
                          ? 'Shop is visible to buyers'
                          : 'Shop is hidden from buyers',
                    ),
                    activeColor: mqOrange,
                    value: shop.isActive,
                    onChanged: (value) async {
                      await shopRepository.toggleShopWithProducts(
                          shopId: shop.shopId,
                          makeActive: value,
                        );

                      // force refresh
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// ---------------------------
  /// UI HELPERS
  /// ---------------------------

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoTile(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: valueColor,
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mqOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
        ],
      ),
    );
  }
}
