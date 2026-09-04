import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/product_model.dart';
import '../../core/stock_delta.dart';

class ProductRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  /// Get all active products for a society (BUYER)
  Future<List<ProductModel>> getProductsBySociety(String societyId) async {
    final query = await _firestore
        .products()
        .where('societyId', isEqualTo: societyId)
        .where('isActive', isEqualTo: true)
        .get();

    return query.docs
        .map(
          (doc) => ProductModel.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  /// Get products for a specific shop (SELLER)
  Future<List<ProductModel>> getProductsByShop(String shopId) async {
    final query = await _firestore
        .products()
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .get();

    return query.docs
        .map(
          (doc) => ProductModel.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  /// Create product
  Future<void> createProduct(ProductModel product) async {
    await _firestore.products().add(product.toJson());
  }

  /// Update product
  Future<void> updateProduct(ProductModel product) async {
    await _firestore.products().doc(product.id).update(product.toJson());
  }

  // Delete Product
  Future<void> deleteProduct(String productId) async {
  await _firestore.products().doc(productId).delete();
  }

  /// 🔒 ATOMIC STOCK REDUCTION (TRANSACTION, option-aware)
  Future<void> reduceStockAfterOrder(
    List<Map<String, dynamic>> items,
  ) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final entries = groupByProduct(items).entries.toList();
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final e in entries) {
        snaps.add(await transaction.get(_firestore.products().doc(e.key)
            as DocumentReference<Map<String, dynamic>>));
      }
      final patches = <Map<String, dynamic>>[];
      for (var i = 0; i < entries.length; i++) {
        if (!snaps[i].exists) throw Exception('Product not found');
        patches.add(applyStockDelta(
            snaps[i].data()!, entries[i].value, -1,
            validate: true));
      }
      for (var i = 0; i < entries.length; i++) {
        transaction.update(snaps[i].reference, patches[i]);
      }
    });
  }

  /// Restock after order cancel (option-aware). Missing products are skipped.
  Future<void> restockAfterOrderCancel(
    List<Map<String, dynamic>> items,
  ) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final entries = groupByProduct(items).entries.toList();
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final e in entries) {
        snaps.add(await transaction.get(_firestore.products().doc(e.key)
            as DocumentReference<Map<String, dynamic>>));
      }
      for (var i = 0; i < entries.length; i++) {
        if (!snaps[i].exists) continue;
        transaction.update(
          snaps[i].reference,
          applyStockDelta(snaps[i].data()!, entries[i].value, 1, validate: false),
        );
      }
    });
  }
}
