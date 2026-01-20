import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../repositories/user_repository.dart';
import '../../repositories/shop_repository.dart';
import '../../models/shop_model.dart';
import '../../services/cart_service.dart';
import '../buyer/cart_screen.dart';
import 'buyer_products_screen.dart';

class BuyerShopsScreen extends StatefulWidget {
  const BuyerShopsScreen({super.key});

  @override
  State<BuyerShopsScreen> createState() => _BuyerShopsScreenState();
}

class _BuyerShopsScreenState extends State<BuyerShopsScreen> {
  String searchQuery = '';

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqLightOrange = Color(0xFFFFF3E8);

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Center(
        child: Text('Please login to view shops in your society'),
      );
    }

    final uid = firebaseUser.uid;
    final userRepository = UserRepository();
    final shopRepository = ShopRepository();

    return Scaffold(
      resizeToAvoidBottomInset: true,

      /// 🛒 CART BADGE
      appBar: AppBar(
        title: const Text('Shops'),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: CartService.instance.cartItemCount,
            builder: (context, count, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CartScreen(),
                        ),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: mqOrange,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            /// 🔍 SEARCH BAR
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (v) => setState(() => searchQuery = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search shops',
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

            Expanded(
              child: FutureBuilder(
                future: userRepository.getUser(uid),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (!userSnapshot.hasData ||
                      userSnapshot.data!.societyId.isEmpty) {
                    return const Center(
                      child: Text(
                          'Please complete your profile to select a society'),
                    );
                  }

                  final societyId = userSnapshot.data!.societyId;

                  return FutureBuilder<List<ShopModel>>(
                    future:
                        shopRepository.getShopsForSociety(societyId),
                    builder: (context, shopSnapshot) {
                      if (shopSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      if (!shopSnapshot.hasData ||
                          shopSnapshot.data!.isEmpty) {
                        return const Center(
                          child:
                              Text('No shops available in your society'),
                        );
                      }

                      final shops = shopSnapshot.data!
                        .where((s) =>
                            s.sellerId != uid && // 🔐 hide own shop
                            s.shopName
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase()))
                        .toList();
                      return GridView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 120),
                        itemCount: shops.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemBuilder: (context, index) {
                          final shop = shops[index];

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BuyerProductsScreen(shop: shop),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        mqOrange.withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor:
                                        mqLightOrange,
                                    backgroundImage:
                                        shop.logoUrl.isNotEmpty
                                            ? NetworkImage(
                                                shop.logoUrl)
                                            : null,
                                    child: shop.logoUrl.isEmpty
                                        ? Icon(Icons.store,
                                            color: mqOrange)
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    shop.shopName,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (shop.description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      shop.description,
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      /// 🟠 VIEW CART BAR (BRAND MATCH)
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: CartService.instance.cartItemCount,
        builder: (context, count, _) {
          if (count == 0) return const SizedBox();

          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.black12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$count item(s) in cart',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mqOrange,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CartScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'View Cart',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
