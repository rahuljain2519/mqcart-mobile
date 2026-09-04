/// A selectable option within one listing — e.g. name "500g", price 120, qty 30.
class ProductOption {
  final String name;
  final double price;
  final int quantity;

  ProductOption({
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) => ProductOption(
        name: json['name'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  ProductOption copyWith({double? price, int? quantity}) => ProductOption(
        name: name,
        price: price ?? this.price,
        quantity: quantity ?? this.quantity,
      );
}

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

  // 🆕 OPTIONAL VARIANT OPTIONS (weight / size / colour in one listing).
  // Empty => simple product. With options: buyer picks one; that option's
  // price + quantity apply. Root price = cheapest option, root quantity = sum.
  final String? optionLabel;
  final List<ProductOption> options;

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

    // 🆕 VARIANT OPTIONS
    this.optionLabel,
    this.options = const [],
  });

  bool get hasOptions => options.isNotEmpty;

  /// Cheapest option price, or the plain price.
  double get displayPrice =>
      hasOptions ? options.map((o) => o.price).reduce((a, b) => a < b ? a : b) : price;

  double priceForOption(String? name) {
    if (!hasOptions || name == null) return price;
    for (final o in options) {
      if (o.name == name) return o.price;
    }
    return price;
  }

  int stockForOption(String? name) {
    if (!hasOptions) return quantity;
    if (name == null) {
      return options.fold(0, (s, o) => s + o.quantity);
    }
    for (final o in options) {
      if (o.name == name) return o.quantity;
    }
    return 0;
  }

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

      // 🆕 VARIANT OPTIONS (BACKWARD SAFE)
      optionLabel: json['optionLabel'],
      options: (json['options'] as List?)
              ?.map((e) =>
                  ProductOption.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
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

      // 🆕 VARIANT OPTIONS
      'optionLabel': hasOptions ? (optionLabel ?? 'Option') : '',
      'options': options.map((o) => o.toJson()).toList(),
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

    // 🆕 VARIANT OPTIONS
    String? optionLabel,
    List<ProductOption>? options,
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

      optionLabel: optionLabel ?? this.optionLabel,
      options: options ?? this.options,
    );
  }
}
