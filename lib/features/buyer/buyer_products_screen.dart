import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../services/cart_service.dart';
import 'cart_screen.dart';
import 'buyer_product_detail_screen.dart';

class BuyerProductsScreen extends StatefulWidget {
  final ShopModel shop;

  const BuyerProductsScreen({super.key, required this.shop});

  @override
  State<BuyerProductsScreen> createState() =>
      _BuyerProductsScreenState();
}

class _BuyerProductsScreenState extends State<BuyerProductsScreen> {
  final ProductRepository productRepository = ProductRepository();
  final CartService cartService = CartService.instance;

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqLightOrange = Color(0xFFFFF3E8);

  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [

          /// 🖼️ BANNER + APP BAR (SCROLLS)
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            title: Text(widget.shop.shopName),
            actions: [
              ValueListenableBuilder<int>(
                valueListenable: cartService.cartItemCount,
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
            flexibleSpace: FlexibleSpaceBar(
              background: widget.shop.bannerUrl.isNotEmpty
                  ? Image.network(
                      widget.shop.bannerUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: mqLightOrange,
                      child: const Center(
                        child: Icon(Icons.storefront, size: 48),
                      ),
                    ),
            ),
          ),

          /// 🏪 SHOP HEADER (SCROLLS)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: mqLightOrange,
                    backgroundImage: widget.shop.logoUrl.isNotEmpty
                        ? NetworkImage(widget.shop.logoUrl)
                        : null,
                    child: widget.shop.logoUrl.isEmpty
                        ? Icon(Icons.store, color: mqOrange)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.shop.shopName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                        if (widget.shop.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.shop.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// 🔍 SEARCH BAR (SCROLLS)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
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
          ),

          const SliverToBoxAdapter(child: Divider()),

          /// 🛍️ PRODUCTS GRID (INLINE – UNCHANGED LOGIC)
          StreamBuilder<List<ProductModel>>(
            stream: productRepository
                .streamProductsForShop(widget.shop.shopId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final products = snapshot.data!
                  .where((p) => p.name
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()))
                  .toList();

              if (products.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('No products available in this shop'),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.70,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = products[index];

                      final cartItem = cartService.items
                          .firstWhereOrNull((e) =>
                              e.productId == product.id &&
                              e.optionName == null);

                      final int qty =
                          product.hasOptions ? 0 : (cartItem?.quantity ?? 0);
                      final bool outOfStock =
                          product.stockForOption(null) <= 0;
                      final bool maxReached =
                          product.quantity > 0 &&
                              qty >= product.quantity;

                      /// 🔴 SAME PRODUCT CARD CODE (UNCHANGED)
                      return Container(
                        padding: const EdgeInsets.all(8),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          BuyerProductDetailScreen(
                                              product: product),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: product.coverImage.isNotEmpty
                                      ? Image.network(
                                          product.coverImage,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : Container(
                                          color: mqLightOrange,
                                          child: const Center(
                                            child: Icon(Icons.image),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  product.hasOptions
                                      ? 'from ₹${product.displayPrice.toStringAsFixed(0)}'
                                      : '₹${product.price}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                qty == 0
                                    ? OutlinedButton(
                                        style: OutlinedButton
                                            .styleFrom(
                                          foregroundColor: mqOrange,
                                          side: const BorderSide(
                                              color: mqOrange),
                                        ),
                                        onPressed: outOfStock
                                            ? null
                                            : () {
                                                if (product.hasOptions) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          BuyerProductDetailScreen(
                                                              product: product),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                final result =
                                                    cartService
                                                        .addProduct(
                                                            product);
                                                if (result ==
                                                    AddProductResult
                                                        .multiSellerNotAllowed) {
                                                  ScaffoldMessenger.of(
                                                          context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'You can order from only one seller at a time',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        child: Text(product.hasOptions
                                            ? 'OPTIONS'
                                            : 'ADD'),
                                      )
                                    : Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.remove,
                                                size: 16),
                                            onPressed: () {
                                              cartService
                                                  .decreaseQuantity(
                                                      product.id);
                                            },
                                          ),
                                          Text(
                                            qty.toString(),
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.add,
                                              size: 16,
                                              color: maxReached
                                                  ? Colors.grey
                                                  : mqOrange,
                                            ),
                                            onPressed: maxReached
                                                ? null
                                                : () {
                                                    cartService
                                                        .increaseQuantity(
                                                            product.id);
                                                  },
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: products.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      /// 🟠 BOTTOM CART BAR (UNCHANGED)
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: cartService.cartItemCount,
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
                    style:
                        const TextStyle(fontWeight: FontWeight.bold),
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
