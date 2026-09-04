import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/datasources/product_remote_ds.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../core/stock_delta.dart';

class ProductRepository {
  final ProductRemoteDS _remoteDS = ProductRemoteDS();
  final FirestoreService _firestore = FirestoreService();

  /// Buyer: get all active products in their society
  Future<List<ProductModel>> getProductsForSociety(String societyId) {
    return _remoteDS.getProductsBySociety(societyId);
  }

  /// Seller: get products under own shop
  Future<List<ProductModel>> getProductsForShop(String shopId) {
    return _remoteDS.getProductsByShop(shopId);
  }

  /// Seller: create product
  Future<void> createProduct({
    required String shopId,
    required String sellerId,
    required String societyId,
    required String name,
    required double price,
    required List<String> images,
    required String coverImage,

    // EXISTING OPTIONAL
    int quantity = 0,
    String category = '',
    String description = '',
    String imageUrl = '',

    // 🆕 DELIVERY (OPTIONAL OVERRIDE)
    String? deliveryUnit,
    int? deliveryMinValue,
    int? deliveryMaxValue,
    int? deliveryMinMinutes,
    int? deliveryMaxMinutes,

    // 🆕 VARIANT OPTIONS
    String? optionLabel,
    List<ProductOption> options = const [],
  }) async {
    final product = ProductModel(
      id: '',
      shopId: shopId,
      sellerId: sellerId,
      societyId: societyId,
      name: name,
      price: price,
      isActive: true,

      quantity: quantity,
      category: category,
      description: description,
      images: images,
      coverImage: coverImage,

      // 🆕 DELIVERY
      deliveryUnit: deliveryUnit,
      deliveryMinValue: deliveryMinValue,
      deliveryMaxValue: deliveryMaxValue,
      deliveryMinMinutes: deliveryMinMinutes,
      deliveryMaxMinutes: deliveryMaxMinutes,

      // 🆕 VARIANT OPTIONS
      optionLabel: optionLabel,
      options: options,
    );

    await validateProductLimit(shopId: product.shopId);
    await _remoteDS.createProduct(product);
    await incrementProductCount(product.shopId);
  }

  /// Seller: update product
  Future<void> updateProduct(ProductModel product) {
    return _remoteDS.updateProduct(product);
  }

  /// Delete product
  Future<void> deleteProduct(String productId) {
    return _remoteDS.deleteProduct(productId);
  }

  /// Buyer: get single product by id
  Future<ProductModel?> getProductById(String productId) async {
    final doc = await _firestore.products().doc(productId).get();

    if (!doc.exists) return null;

    return ProductModel.fromJson(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // 🔄 STREAM PRODUCTS FOR SHOP (AUTO REFRESH)
  Stream<List<ProductModel>> streamProductsForShop(String shopId) {
    return _firestore
        .products()
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map(
          (querySnapshot) => querySnapshot.docs
              .map(
                (doc) => ProductModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // 🔄 STREAM PRODUCTS FOR SOCIETY (BUYER - REALTIME)
  Stream<List<ProductModel>> streamProductsForSociety(String societyId) {
    return _firestore
        .products()
        .where('societyId', isEqualTo: societyId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (querySnapshot) => querySnapshot.docs
              .map(
                (doc) => ProductModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// 🔒 Reduce product stock after successful order (option-aware).
  /// Groups items by productId so two options of one product = one read/write,
  /// and decrements options[i].quantity when the item carries an optionName.
  Future<void> reduceStockAfterOrder(
    List<Map<String, dynamic>> items,
  ) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final entries = groupByProduct(items).entries.toList();

      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final e in entries) {
        snaps.add(await transaction.get(
          FirebaseFirestore.instance.collection('products').doc(e.key),
        ));
      }

      final patches = <Map<String, dynamic>>[];
      for (var i = 0; i < entries.length; i++) {
        if (!snaps[i].exists) throw Exception('Product not found');
        patches.add(
          applyStockDelta(snaps[i].data()!, entries[i].value, -1, validate: true),
        );
      }

      for (var i = 0; i < entries.length; i++) {
        transaction.update(snaps[i].reference, patches[i]);
      }
    });
  }

  /// Stock increase after order cancel
  Future<void> restockAfterOrderCancel(
    List<Map<String, dynamic>> items,
  ) {
    return _remoteDS.restockAfterOrderCancel(items);
  }

  /// Product limit based on plan
  Future<void> validateProductLimit({
    required String shopId,
  }) async {
    final shopDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .get();

    if (!shopDoc.exists) {
      throw Exception('Shop not found');
    }

    final data = shopDoc.data()!;
    final int productCount = data['productCount'] ?? 0;
    final int productLimit = data['productLimit'] ?? 20;

    if (productCount >= productLimit) {
      throw Exception(
        'Product limit reached. Upgrade to VIP plan to add more products.',
      );
    }
  }

  /// keep increasing product count
  Future<void> incrementProductCount(String shopId) async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .update({
      'productCount': FieldValue.increment(1),
    });
  }

  Future<void> decrementProductCount(String shopId) async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .update({
      'productCount': FieldValue.increment(-1),
    });
  }

  Future<void> updateProductStatus({
    required String productId,
    required bool isActive,
  }) {
    return FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update({'isActive': isActive});
  }
}
