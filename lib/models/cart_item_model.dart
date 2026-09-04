class CartItemModel {
  final String productId;
  final String name;
  final double price;
  final String imageUrl;
  final String sellerId;

  /// Set when the buyer picked a variant option (e.g. "500g").
  final String? optionName;

  int quantity;

  CartItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
    this.optionName,
    this.quantity = 1,
  });

  /// Cart-line identity: product + option when set.
  String get lineKey =>
      optionName == null ? productId : '$productId|$optionName';

  double get totalPrice => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
      if (optionName != null) 'optionName': optionName,
      'quantity': quantity,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      productId: json['productId'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      sellerId: json['sellerId'],
      optionName: json['optionName'],
      quantity: json['quantity'] ?? 1,
    );
  }
}
