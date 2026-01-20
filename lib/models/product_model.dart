class ProductModel {
  final String id;
  final String shopId;
  final String sellerId;
  final String societyId;

  final String name;
  final double price;
  final int quantity;
  final String category;
  final String description;

  // ✅ IMAGES (FINAL)
  final List<String> images;
  final String coverImage;

  final bool isActive;

  // 🆕 OPTIONAL DELIVERY OVERRIDE (CANONICAL – MINUTES)
  final int? deliveryMinMinutes;
  final int? deliveryMaxMinutes;

  // 🆕 OPTIONAL DELIVERY DISPLAY (UI ONLY)
  final String? deliveryUnit; // minutes | hours | days
  final int? deliveryMinValue;
  final int? deliveryMaxValue;

  ProductModel({
    required this.id,
    required this.shopId,
    required this.sellerId,
    required this.societyId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.category,
    required this.description,
    required this.images,
    required this.coverImage,
    this.isActive = true,

    // 🆕 DELIVERY (OPTIONAL)
    this.deliveryMinMinutes,
    this.deliveryMaxMinutes,
    this.deliveryUnit,
    this.deliveryMinValue,
    this.deliveryMaxValue,
  });

  // -----------------------------
  // Firestore → Model
  // -----------------------------
  factory ProductModel.fromJson(
    Map<String, dynamic> json,
    String id,
  ) {
    final List<String> images =
        (json['images'] as List?)?.cast<String>() ?? [];

    final String coverImage =
        json['coverImage'] ??
        (images.isNotEmpty ? images.first : '');

    return ProductModel(
      id: id,
      shopId: json['shopId'],
      sellerId: json['sellerId'],
      societyId: json['societyId'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] ?? 0,
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      images: images,
      coverImage: coverImage,
      isActive: json['isActive'] ?? true,

      // 🆕 DELIVERY (BACKWARD SAFE)
      deliveryMinMinutes: json['deliveryMinMinutes'],
      deliveryMaxMinutes: json['deliveryMaxMinutes'],
      deliveryUnit: json['deliveryUnit'],
      deliveryMinValue: json['deliveryMinValue'],
      deliveryMaxValue: json['deliveryMaxValue'],
    );
  }

  // -----------------------------
  // Model → Firestore
  // -----------------------------
  Map<String, dynamic> toJson() {
    return {
      'shopId': shopId,
      'sellerId': sellerId,
      'societyId': societyId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'category': category,
      'description': description,
      'images': images,
      'coverImage': coverImage,
      'isActive': isActive,

      // 🆕 DELIVERY (ONLY IF OVERRIDE EXISTS)
      if (deliveryMinMinutes != null)
        'deliveryMinMinutes': deliveryMinMinutes,
      if (deliveryMaxMinutes != null)
        'deliveryMaxMinutes': deliveryMaxMinutes,
      if (deliveryUnit != null)
        'deliveryUnit': deliveryUnit,
      if (deliveryMinValue != null)
        'deliveryMinValue': deliveryMinValue,
      if (deliveryMaxValue != null)
        'deliveryMaxValue': deliveryMaxValue,
    };
  }

  // -----------------------------
  // copyWith
  // -----------------------------
  ProductModel copyWith({
    String? name,
    double? price,
    int? quantity,
    String? category,
    String? description,
    List<String>? images,
    String? coverImage,
    bool? isActive,

    // 🆕 DELIVERY
    int? deliveryMinMinutes,
    int? deliveryMaxMinutes,
    String? deliveryUnit,
    int? deliveryMinValue,
    int? deliveryMaxValue,
  }) {
    return ProductModel(
      id: id,
      shopId: shopId,
      sellerId: sellerId,
      societyId: societyId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      description: description ?? this.description,
      images: images ?? this.images,
      coverImage: coverImage ?? this.coverImage,
      isActive: isActive ?? this.isActive,

      deliveryMinMinutes:
          deliveryMinMinutes ?? this.deliveryMinMinutes,
      deliveryMaxMinutes:
          deliveryMaxMinutes ?? this.deliveryMaxMinutes,
      deliveryUnit: deliveryUnit ?? this.deliveryUnit,
      deliveryMinValue:
          deliveryMinValue ?? this.deliveryMinValue,
      deliveryMaxValue:
          deliveryMaxValue ?? this.deliveryMaxValue,
    );
  }
}
