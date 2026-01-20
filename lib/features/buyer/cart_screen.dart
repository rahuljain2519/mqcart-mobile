import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../../services/cart_service.dart';
import '../../models/cart_item_model.dart';
import '../../models/product_model.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static const Color mqOrange = Color(0xFFFF6A00);

  void _syncCartWithStock(
    CartService cartService,
    List<ProductModel> products,
  ) {
    final stockMap = {
      for (final p in products) p.id: p.quantity,
    };

    for (final item in List<CartItemModel>.from(cartService.items)) {
      final liveStock = stockMap[item.productId] ?? 0;

      if (liveStock <= 0) {
        cartService.removeProduct(item.productId);
      } else if (item.quantity > liveStock) {
        final diff = item.quantity - liveStock;
        for (int i = 0; i < diff; i++) {
          cartService.decreaseQuantity(item.productId);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CartService cartService = CartService.instance;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Cart',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cartService.clearCart();
              Navigator.pop(context);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),

      /// 🔁 REALTIME PRODUCT STOCK (LOGIC UNCHANGED)
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final products = snapshot.data!.docs
                .map(
                  (d) => ProductModel.fromJson(
                    d.data() as Map<String, dynamic>,
                    d.id,
                  ),
                )
                .toList();

            _syncCartWithStock(cartService, products);
          }

          return ValueListenableBuilder<int>(
            valueListenable: cartService.cartItemCount,
            builder: (context, _, __) {
              final items = cartService.items;

              if (items.isEmpty) {
                return const Center(
                  child: Text('Your cart is empty'),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final CartItemModel item = items[index];

                        final ProductModel? product = snapshot.data?.docs
                            .map(
                              (d) => ProductModel.fromJson(
                                d.data() as Map<String, dynamic>,
                                d.id,
                              ),
                            )
                            .firstWhereOrNull(
                              (p) => p.id == item.productId,
                            );

                        final int liveStock = product?.quantity ?? 0;
                        final bool maxReached =
                            item.quantity >= liveStock;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image, size: 32),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${item.price} × ${item.quantity}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      cartService.decreaseQuantity(
                                          item.productId);
                                    },
                                  ),
                                  Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
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
                                                item.productId);
                                          },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  /// 🟠 BOTTOM SUMMARY (SAFE AREA FIX APPLIED)
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total: ₹${cartService.totalAmount}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mqOrange,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CheckoutScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
