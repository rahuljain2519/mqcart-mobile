import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../models/order_model.dart';

class OrderRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  /// ---------------------------------
  /// CREATE NEW ORDER (BUYER)
  /// ---------------------------------
  Future<void> createOrder(OrderModel order) async {
    final data = order.toJson();

    await _firestore.orders().add({
      ...data,
      'status': order.status.isNotEmpty ? order.status : 'placed',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// =================================================
  /// STREAM ORDERS — BUYER (AUTO REFRESH)
  /// =================================================
  Stream<List<OrderModel>> streamOrdersByBuyer(String buyerId) {
    return _firestore
        .orders()
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OrderModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// =================================================
  /// STREAM ORDERS — SELLER (AUTO REFRESH)
  /// =================================================
  Stream<List<OrderModel>> streamOrdersBySeller(String sellerId) {
    return _firestore
        .orders()
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OrderModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// ---------------------------------
  /// UPDATE ORDER STATUS
  /// ---------------------------------
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _firestore.orders().doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
