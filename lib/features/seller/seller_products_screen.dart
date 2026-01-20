import 'package:flutter/material.dart';

import '../../models/shop_model.dart';
import '../../repositories/product_repository.dart';
import '../../models/product_model.dart';
import 'add_edit_product_screen.dart';
import '../seller/bulk_upload/bulk_upload_screen.dart';

class SellerProductsScreen extends StatelessWidget {
  final ShopModel shop;

  const SellerProductsScreen({
    super.key,
    required this.shop,
  });

  @override
  Widget build(BuildContext context) {
    final ProductRepository productRepository = ProductRepository();
    final bool isActive = shop.isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        actions: [
          // ➕ ADD PRODUCT (ACTIVATION + LIMIT CHECK)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: isActive
                ? () async {
                    try {
                      await productRepository.validateProductLimit(
                        shopId: shop.shopId,
                      );

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditProductScreen(
                            shopId: shop.shopId,
                          ),
                        ),
                      );

                      if (result == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Product saved successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                : () {
                    _showActivationRequired(context);
                  },
          ),

          // ⋮ BULK UPLOAD
          PopupMenuButton<String>(
            onSelected: isActive
                ? (value) async {
                    if (value == 'bulk_upload') {
                      try {
                        await productRepository.validateProductLimit(
                          shopId: shop.shopId,
                        );

                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BulkUploadScreen(
                              shopId: shop.shopId,
                            ),
                          ),
                        );

                        if (result == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bulk upload completed'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  }
                : (_) {
                    _showActivationRequired(context);
                  },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'bulk_upload',
                child: Text('Bulk Upload'),
              ),
            ],
          ),
        ],
      ),

      body: StreamBuilder<List<ProductModel>>(
        stream: productRepository.streamProductsForShop(shop.shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No products added yet'));
          }

          final products = snapshot.data!;

          // ✅ ACTIVE PRODUCT COUNT
          final int activeCount =
              products.where((p) => p.isActive).length;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];

              String imageUrl = '';
              if (product.coverImage.isNotEmpty) {
                imageUrl = product.coverImage;
              } else if (product.images.isNotEmpty) {
                imageUrl = product.images.first;
              }

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _imagePlaceholder(),
                              )
                            : _imagePlaceholder(),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('₹${product.price}'),
                            Text(
                              'Stock: ${product.quantity}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              product.isActive ? '● Active' : '● Hidden',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.isActive
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ✅ UPDATED PRODUCT ACTION MENU
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditProductScreen(
                                  shopId: shop.shopId,
                                  product: product,
                                ),
                              ),
                            );

                            if (result == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Product updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }

                          if (value == 'delete') {
                            await productRepository
                                .deleteProduct(product.id);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Product deleted'),
                                ),
                              );
                            }
                          }

                          if (value == 'activate') {
                            if (activeCount >= shop.productLimit) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Product limit reached (${shop.productLimit})',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            await productRepository.updateProductStatus(
                              productId: product.id,
                              isActive: true,
                            );
                          }

                          if (value == 'deactivate') {
                            await productRepository.updateProductStatus(
                              productId: product.id,
                              isActive: false,
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          if (product.isActive)
                            const PopupMenuItem(
                              value: 'deactivate',
                              child: Text('Hide'),
                            )
                          else
                            const PopupMenuItem(
                              value: 'activate',
                              child: Text('Activate'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showActivationRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activate your shop to add products'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.image,
        color: Colors.grey,
      ),
    );
  }
}
