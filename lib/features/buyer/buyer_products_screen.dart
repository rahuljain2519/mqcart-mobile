import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/cart_service.dart';
import '../../core/widgets/mq_network_image.dart';
import '../../core/widgets/clear_cart_dialog.dart';
import '../../config/categories.dart';
import 'cart_screen.dart';
import 'buyer_product_detail_screen.dart';
import 'category_scroller.dart';

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
  final Future<UserModel?> _currentUserFuture =
      UserRepository().getCurrentUser();

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqLightOrange = Color(0xFFFFF3E8);

  String searchQuery = '';
  String selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    // The Shops list already scopes to the buyer's own society, so this
    // only triggers when this screen is reached out-of-band - e.g. a
    // lingering entry on the navigation stack after switching societies in
    // Profile - which otherwise let a buyer order from a shop in a
    // different society entirely with no warning (order #3KHKZO).
    return FutureBuilder<UserModel?>(
      future: _currentUserFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null &&
            user.societyId.isNotEmpty &&
            user.societyId != widget.shop.societyId) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.shop.shopName)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_outlined,
                        size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'Not in your society',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "This shop is in a different society than the one on "
                      "your profile, so it isn't available to order from here.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _buildShopScreen(context);
      },
    );
  }

  Widget _buildShopScreen(BuildContext context) {
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
                  ? MQNetworkImage(
                      url: widget.shop.bannerUrl,
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
                  IconButton(
                    icon: const Icon(Icons.call, color: mqOrange),
                    tooltip: 'Call ${widget.shop.shopName}',
                    onPressed: () async {
                      // shop.phone was never actually collected anywhere in
                      // shop creation/edit (no phone field exists on the
                      // form), so it's empty for almost every shop - fall
                      // back to the seller's own account phone, which is
                      // always set, instead of hiding the button entirely.
                      String? phone = widget.shop.phone.isNotEmpty
                          ? widget.shop.phone
                          : null;
                      if (phone == null) {
                        try {
                          final seller = await UserRepository()
                              .getUser(widget.shop.sellerId);
                          phone =
                              seller.phone.isNotEmpty ? seller.phone : null;
                        } catch (_) {}
                      }
                      if (phone == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Store phone number not available')),
                          );
                        }
                        return;
                      }

                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Store phone: $phone')),
                        );
                      }
                    },
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

          /// 🗂️ CATEGORY FILTER (SCROLLS)
          SliverToBoxAdapter(
            child: CategoryScroller(
              selectedCategory: selectedCategory,
              onCategorySelected: (c) =>
                  setState(() => selectedCategory = c),
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
                  .where((p) =>
                      p.name
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()) &&
                      (selectedCategory == 'All' ||
                          normalizeCategory(p.category) == selectedCategory))
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

                      // Rebuilds on every cart change (add/increase/decrease),
                      // not just when the product stream re-emits — otherwise
                      // tapping ADD doesn't visibly update this tile.
                      return ValueListenableBuilder<int>(
                        valueListenable: cartService.cartRevision,
                        builder: (context, revision, _) {
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
                                  child: MQNetworkImage(
                                    url: product.coverImage,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
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
                            if (product.brand != null ||
                                product.packSizeLabel != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  [
                                    if (product.brand != null) product.brand!,
                                    if (product.packSizeLabel != null)
                                      product.packSizeLabel!,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                product.hasDiscount
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '₹${product.price.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '₹${product.mrp!.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
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
                                            : () async {
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
                                                  final cleared =
                                                      await showClearCartDialog(
                                                          context);
                                                  if (cleared) {
                                                    cartService.clearCart();
                                                    cartService
                                                        .addProduct(product);
                                                  }
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
