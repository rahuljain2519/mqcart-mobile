import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../../models/product_model.dart';
import '../../services/cart_service.dart';
import '../buyer/cart_screen.dart';

class BuyerProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const BuyerProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<BuyerProductDetailScreen> createState() =>
      _BuyerProductDetailScreenState();
}

class _BuyerProductDetailScreenState
    extends State<BuyerProductDetailScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqLightOrange = Color(0xFFFFF3E8);

  @override
  Widget build(BuildContext context) {
    final CartService cartService = CartService.instance;

    final List<String> images = widget.product.images.isNotEmpty
        ? widget.product.images
        : [widget.product.coverImage];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🖼️ PRODUCT IMAGES (MULTIPLE SUPPORT)
                SizedBox(
                  height: 240,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final imageUrl = images[index];

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    width: double.infinity,
                                    height: 240,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: mqLightOrange,
                                    child: const Center(
                                      child: Icon(
                                        Icons.image,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),

                      /// 🔘 IMAGE INDICATOR DOTS
                      if (images.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (index) => AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                height: 8,
                                width:
                                    _currentIndex == index ? 16 : 8,
                                decoration: BoxDecoration(
                                  color: _currentIndex == index
                                      ? mqOrange
                                      : Colors.white70,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// 🏷️ PRODUCT NAME
                Text(
                  widget.product.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                /// 💰 PRICE
                Text(
                  '₹${widget.product.price}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: mqOrange,
                      ),
                ),

                const SizedBox(height: 16),

                /// 📝 DESCRIPTION
                Text(
                  widget.product.description.isNotEmpty
                      ? widget.product.description
                      : 'No description provided.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: widget.product.description.isNotEmpty
                            ? Colors.black87
                            : Colors.grey,
                      ),
                ),

                const SizedBox(height: 28),

                /// 🛒 CART CONTROL (MATCHES BUYER HOME EXACTLY)
                ValueListenableBuilder<int>(
                  valueListenable: cartService.cartItemCount,
                  builder: (context, _, __) {
                    final cartItem =
                        cartService.items.firstWhereOrNull(
                      (e) => e.productId == widget.product.id,
                    );

                    final int qty = cartItem?.quantity ?? 0;
                    final bool outOfStock =
                        widget.product.quantity <= 0;
                    final bool maxReached =
                        widget.product.quantity > 0 &&
                            qty >= widget.product.quantity;

                    if (outOfStock) {
                      return const Text(
                        'Out of stock',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }

                    if (qty == 0) {
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon:
                              const Icon(Icons.add_shopping_cart),
                          label: const Text(
                            'Add to Cart',
                            style:
                                TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mqOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            final result = cartService
                                .addProduct(widget.product);

                            if (result ==
                                AddProductResult
                                    .multiSellerNotAllowed) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'You can order from only one seller at a time',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    }

                    return Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: mqLightOrange,
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              cartService.decreaseQuantity(
                                  widget.product.id);
                            },
                          ),
                          Text(
                            qty.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add,
                              color: maxReached
                                  ? Colors.grey
                                  : mqOrange,
                            ),
                            onPressed: maxReached
                                ? null
                                : () {
                                    cartService.increaseQuantity(
                                        widget.product.id);
                                  },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          /// 🟠 CART BAR (SAME PATTERN AS BUYER HOME)
          ValueListenableBuilder<int>(
            valueListenable: cartService.cartItemCount,
            builder: (context, _, __) {
              if (cartService.isEmpty) {
                return const SizedBox();
              }

              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
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
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${cartService.totalItems} Items  ₹${cartService.totalAmount}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mqOrange,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CartScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'View Cart',
                            style:
                                TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
