import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                _sectionTitle('Danger Zone'),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete Seller'),
                  onPressed: () => _confirmDeleteSeller(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSeller(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this seller?'),
        content: const Text(
          'This permanently removes their shop, every product, seller '
          'application, subscription, payment records, and uploaded '
          'documents (KYC, shop images, product photos). They go back to '
          'being a plain buyer with the same account — this cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete permanently',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseFunctions.instance
          .httpsCallable('adminDeleteSeller')
          .call({'uid': user.uid});

      if (context.mounted) {
        Navigator.pop(context); // close the loading dialog
        Navigator.pop(context); // back to the seller list
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close the loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete seller: $e')),
        );
      }
    }
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
