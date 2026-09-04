import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../core/widgets/mq_network_image.dart';

class SellerShopPreviewScreen extends StatefulWidget {
  final ShopModel shop;

  const SellerShopPreviewScreen({
    super.key,
    required this.shop,
  });

  @override
  State<SellerShopPreviewScreen> createState() =>
      _SellerShopPreviewScreenState();
}

class _SellerShopPreviewScreenState
    extends State<SellerShopPreviewScreen> {
  String searchQuery = '';

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqLightOrange = Color(0xFFFFF3E8);

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.shopName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: const [
          // 🛒 Cart icon shown but DISABLED (visual parity)
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.shopping_cart, color: Colors.grey),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🖼️ SHOP BANNER
            if (shop.bannerUrl.isNotEmpty)
              MQNetworkImage(
                url: shop.bannerUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),

            // 🏪 SHOP HEADER
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: mqLightOrange,
                    backgroundImage: shop.logoUrl.isNotEmpty
                        ? NetworkImage(shop.logoUrl)
                        : null,
                    child: shop.logoUrl.isEmpty
                        ? Icon(Icons.store, color: mqOrange)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shop.shopName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🔍 SEARCH BAR (same as buyer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                onChanged: (v) => setState(() => searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search products in shop',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: mqLightOrange,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 🛍️ PRODUCT GRID (READ ONLY)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('shopId', isEqualTo: shop.shopId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final products = snapshot.data!.docs
                      .map((d) => ProductModel.fromJson(
                            d.data() as Map<String, dynamic>,
                            d.id,
                          ))
                      .where((p) => p.name
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()))
                      .toList();

                  if (products.isEmpty) {
                    return const Center(
                        child: Text('No products found'));
                  }

                  return GridView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];

                      return _productCard(product);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // PRODUCT CARD (ADD DISABLED)
  // ---------------------------
  Widget _productCard(ProductModel product) {
    return Container(
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
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: mqLightOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 40, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('₹${product.price}'),
          const SizedBox(height: 6),

          // 🚫 ADD BUTTON (DISABLED, VISUAL ONLY)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                foregroundColor: mqOrange,
                side: BorderSide(color: mqOrange),
              ),
              child: const Text('ADD'),
            ),
          ),
        ],
      ),
    );
  }
}
