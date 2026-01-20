import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/product_model.dart';

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

  /// 🔒 ATOMIC STOCK REDUCTION (TRANSACTION)
  Future<void> reduceStockAfterOrder(
    List<Map<String, dynamic>> items,
  ) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    await db.runTransaction((transaction) async {
      for (final item in items) {
        final String productId = item['productId'];
        final int orderedQty = item['quantity'];

        final productRef = _firestore.products().doc(productId);
        final snapshot = await transaction.get(productRef);

        if (!snapshot.exists) {
          throw Exception('Product not found');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final int currentQty = data['quantity'] ?? 0;

        if (currentQty < orderedQty) {
          throw Exception(
            'Insufficient stock for ${data['name']}',
          );
        }

        transaction.update(productRef, {
          'quantity': currentQty - orderedQty,
        });
      }
    });
  }

  /// restock product after order cancel
  Future<void> restockAfterOrderCancel(
  List<Map<String, dynamic>> items,
) async {
  final firestore = FirebaseFirestore.instance;

  await firestore.runTransaction((transaction) async {
    // 1️⃣ READ ALL DOCS FIRST
    final Map<DocumentReference, int> updates = {};

    for (final item in items) {
      final productId = item['productId'] as String;
      final qty = item['quantity'] as int;

      final ref = firestore.collection('products').doc(productId);
      final snap = await transaction.get(ref);

      if (!snap.exists) continue;

      final data = snap.data() as Map<String, dynamic>;
      final currentStock = (data['quantity'] ?? 0) as int;

      updates[ref] = currentStock + qty;
    }

    // 2️⃣ APPLY ALL UPDATES AFTER READS
    for (final entry in updates.entries) {
      transaction.update(entry.key, {
        'quantity': entry.value,
      });
    }
  });
}
}
