import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../models/review_model.dart';

class ReviewRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  /// Doc ID is deterministic (`${orderId}_${productId}`) - a repeat call
  /// for the same order+product fails as a duplicate create, which
  /// ReviewRepository.submitReview surfaces as "already reviewed".
  Future<void> submitReview(ReviewModel review) {
    final id = '${review.orderId}_${review.productId}';
    return _firestore.reviews().doc(id).set({
      ...review.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ReviewModel?> getReview(String orderId, String productId) async {
    final doc =
        await _firestore.reviews().doc('${orderId}_$productId').get();
    if (!doc.exists) return null;
    return ReviewModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<List<ReviewModel>> streamReviewsForProduct(String productId) {
    return _firestore
        .reviews()
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                ReviewModel.fromJson(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }
}
