import 'package:flutter/material.dart';
import 'package:mqcart/features/buyer/cart_screen.dart';

import 'buyer_product_detail_screen.dart';

import '../../repositories/product_repository.dart';
import '../../repositories/user_repository.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/cart_service.dart';
import 'category_scroller.dart';

class BuyerHome extends StatefulWidget {
  const BuyerHome({super.key});

  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  String searchQuery = '';
  String selectedCategory = 'All';

  final CartService cartService = CartService.instance;

  static const Color mqOrange = Color(0xFFFF6A00);
  static const Color mqLightOrange = Color(0xFFFFF3E8);

  final List<String> _searchHints = [
    'Search milk',
    'Search bread',
    'Search fruits',
    'Search cake',
    'Search snacks',
  ];
  int _hintIndex = 0;

  @override
  void initState() {
    super.initState();

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return false;

      if (searchQuery.isEmpty) {
        setState(() {
          _hintIndex = (_hintIndex + 1) % _searchHints.length;
        });
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final productRepo = ProductRepository();
    final userRepo = UserRepository();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            /// 🔍 SEARCH BAR
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (v) => setState(() => searchQuery = v),
                decoration: InputDecoration(
                  hintText:
                      searchQuery.isEmpty ? _searchHints[_hintIndex] : null,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: const Icon(Icons.mic),
                  filled: true,
                  fillColor: mqLightOrange,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            /// 🟡 CATEGORY ROW (UNCHANGED)
            CategoryScroller(
              selectedCategory: selectedCategory,
              onCategorySelected: (cat) {
                setState(() {
                  selectedCategory = cat;
                });
              },
            ),

            const SizedBox(height: 8),

            Expanded(
              child: FutureBuilder<UserModel?>(
                future: userRepo.getCurrentUser(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final user = userSnap.data!;
                  if (user.societyId.isEmpty) {
                    return const Center(
                        child: Text('Please complete your profile'));
                  }

                  /// ✅ REALTIME PRODUCTS BY SOCIETY
                  return StreamBuilder<List<ProductModel>>(
                    stream: productRepo
                        .streamProductsForSociety(user.societyId),
                    builder: (context, productSnap) {
                      if (!productSnap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      /// ✅ FINAL FILTER LOGIC (UNCHANGED)
                      final products = productSnap.data!.where((p) {
                        final matchesSearch = searchQuery.isEmpty ||
                            p.name
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase());

                        if (selectedCategory == 'All') {
                          return matchesSearch;
                        }

                        final productCategory =
                            p.category.toLowerCase().trim();
                        final selectedCat =
                            selectedCategory.toLowerCase().trim();

                        final matchesCategory =
                            productCategory.isNotEmpty &&
                            productCategory.contains(selectedCat);

                        return matchesSearch && matchesCategory;
                      }).toList();

                      if (products.isEmpty) {
                        return const Center(
                          child: Text(
                            'No products found',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      }

                      return Stack(
                        children: [
                          GridView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 120),
                            itemCount: products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.70,
                            ),
                            itemBuilder: (context, index) {
                              final product = products[index];

                              final qty = cartService.contains(product.id)
                                  ? cartService.items
                                      .firstWhere((e) =>
                                          e.productId == product.id)
                                      .quantity
                                  : 0;

                              final bool outOfStock =
                                  product.quantity <= 0;
                              final bool maxReached =
                                  product.quantity > 0 &&
                                      qty >= product.quantity;

                              return InkWell(
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
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            mqOrange.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset:
                                            const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                          child: product.coverImage
                                                  .isNotEmpty
                                              ? Image.network(
                                                  product.coverImage,
                                                  fit: BoxFit.cover,
                                                  width:
                                                      double.infinity,
                                                )
                                              : const Icon(
                                                  Icons.image,
                                                  size: 48,
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '₹${product.price}',
                                                  style:
                                                      const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                                qty == 0
                                                    ? OutlinedButton(
                                                        style:
                                                            OutlinedButton
                                                                .styleFrom(
                                                          foregroundColor:
                                                              mqOrange,
                                                          side:
                                                              const BorderSide(
                                                                  color:
                                                                      mqOrange),
                                                        ),
                                                        onPressed:
                                                            outOfStock
                                                                ? null
                                                                : () {
                                                                      final result =
                    cartService.addProduct(product);

                if (result ==
                    AddProductResult.multiSellerNotAllowed) {
                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                          const SnackBar(
                                                                            content: Text(
                                                                              'You can order from only one seller at a time',
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }
                                                                    },
                                                        child:
                                                            const Text(
                                                                'ADD'),
                                                      )
                                                    : Row(
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons
                                                                    .remove),
                                                            onPressed:
                                                                () {
                                                              cartService
                                                                  .decreaseQuantity(
                                                                      product
                                                                          .id);
                                                            },
                                                          ),
                                                          Text(qty
                                                              .toString()),
                                                          IconButton(
                                                            icon: Icon(
                                                              Icons.add,
                                                              color: maxReached
                                                                  ? Colors
                                                                      .grey
                                                                  : mqOrange,
                                                            ),
                                                            onPressed:
                                                                maxReached
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
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          /// 🟠 CART BAR (UNCHANGED LOGIC)
                          ValueListenableBuilder<int>(
                            valueListenable:
                                cartService.cartItemCount,
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
                                    padding:
                                        const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 6,
                                          color: Colors.black12,
                                          offset:
                                              Offset(0, -2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        Text(
                                          '${cartService.totalItems} Items  ₹${cartService.totalAmount}',
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold),
                                        ),
                                        ElevatedButton(
                                          style:
                                              ElevatedButton.styleFrom(
                                            backgroundColor:
                                                mqOrange,
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
                                            style: TextStyle(
                                                color:
                                                    Colors.white),
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
                      );
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
}
