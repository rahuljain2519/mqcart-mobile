/// One buyer's rating of one product. Doc ID is deterministic
/// (`${orderId}_${productId}`) so a second write for the same order+
/// product simply fails as a duplicate create - no existence query needed
/// before showing a rate button, and firestore.rules (mqcart-web repo)
/// requires the backing order to belong to this buyer and be "delivered",
/// so a review can't be left without a real purchase.
class ReviewModel {
  final String id;
  final String orderId;
  final String productId;
  final String shopId;
  final String sellerId;
  final String buyerId;
  final String buyerName;
  final int rating; // 1-5
  final String? comment;
  final DateTime? createdAt;

  ReviewModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.shopId,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json, String id) {
    return ReviewModel(
      id: id,
      orderId: json['orderId'] ?? '',
      productId: json['productId'] ?? '',
      shopId: json['shopId'] ?? '',
      sellerId: json['sellerId'] ?? '',
      buyerId: json['buyerId'] ?? '',
      buyerName: json['buyerName'] ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'],
      createdAt: json['createdAt'] == null
          ? null
          : (json['createdAt'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'productId': productId,
        'shopId': shopId,
        'sellerId': sellerId,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'rating': rating,
        if (comment != null) 'comment': comment,
      };
}
