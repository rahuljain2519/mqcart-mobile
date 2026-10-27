import '../data/datasources/review_remote_ds.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final ReviewRemoteDS _remoteDS = ReviewRemoteDS();

  Future<void> submitReview({
    required String orderId,
    required String productId,
    required String shopId,
    required String sellerId,
    required String buyerId,
    required String buyerName,
    required int rating,
    String? comment,
  }) {
    return _remoteDS.submitReview(ReviewModel(
      id: '',
      orderId: orderId,
      productId: productId,
      shopId: shopId,
      sellerId: sellerId,
      buyerId: buyerId,
      buyerName: buyerName,
      rating: rating,
      comment: comment,
    ));
  }

  /// Has this buyer already rated this product from this order? Used to
  /// show "Rated" instead of a rate button, not to gate the write itself.
  Future<ReviewModel?> getReview(String orderId, String productId) {
    return _remoteDS.getReview(orderId, productId);
  }

  Stream<List<ReviewModel>> streamReviewsForProduct(String productId) {
    return _remoteDS.streamReviewsForProduct(productId);
  }
}
