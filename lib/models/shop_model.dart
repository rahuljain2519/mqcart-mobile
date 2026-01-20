class ShopModel {
  final String shopId;
  final String sellerId;
  final String societyId;
  final String shopName;

  final String description;
  final String logoUrl;
  final String bannerUrl;
  final String address;
  final String phone;

  // PLAN & LIMIT
  final String plan;
  final int productLimit;
  final int productCount;
  final double transactionFeePercent;
  final bool isActive;
  final bool isVerified;

  // 🆕 DELIVERY CONFIG (AUTHORITATIVE)
  final String deliveryUnit; // minutes | hours | days
  final int deliveryMinValue;
  final int deliveryMaxValue;

  // 🆕 DELIVERY (CANONICAL – MINUTES)
  final int deliveryMinMinutes;
  final int deliveryMaxMinutes;

  ShopModel({
    required this.shopId,
    required this.sellerId,
    required this.societyId,
    required this.shopName,

    this.description = '',
    this.logoUrl = '',
    this.bannerUrl = '',
    this.address = '',
    this.phone = '',

    this.plan = 'free',
    this.productLimit = 10,
    this.productCount = 0,
    this.transactionFeePercent = 0.0,

    this.isActive = false,
    this.isVerified = false,

    // 🆕 SAFE DEFAULTS (BACKWARD COMPATIBLE)
    this.deliveryUnit = 'days',
    this.deliveryMinValue = 2,
    this.deliveryMaxValue = 3,
    this.deliveryMinMinutes = 2880, // 2 days
    this.deliveryMaxMinutes = 4320, // 3 days
  });

  /// Firestore → Model
  factory ShopModel.fromJson(Map<String, dynamic> json, String shopId) {
    return ShopModel(
      shopId: shopId,
      sellerId: json['sellerId'],
      societyId: json['societyId'],
      shopName: json['shopName'],

      description: json['description'] ?? '',
      logoUrl: json['logoUrl'] ?? '',
      bannerUrl: json['bannerUrl'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',

      plan: json['plan'] ?? 'free',
      productLimit: json['productLimit'] ?? 10,
      productCount: json['productCount'] ?? 0,
      transactionFeePercent:
          (json['transactionFeePercent'] ?? 0).toDouble(),

      isActive: json['isActive'] ?? false,
      isVerified: json['isVerified'] ?? false,

      // 🆕 DELIVERY (BACKWARD SAFE)
      deliveryUnit: json['deliveryUnit'] ?? 'days',
      deliveryMinValue: json['deliveryMinValue'] ?? 2,
      deliveryMaxValue: json['deliveryMaxValue'] ?? 3,
      deliveryMinMinutes: json['deliveryMinMinutes'] ?? 2880,
      deliveryMaxMinutes: json['deliveryMaxMinutes'] ?? 4320,
    );
  }

  /// Model → Firestore
  Map<String, dynamic> toJson() {
    return {
      'sellerId': sellerId,
      'societyId': societyId,
      'shopName': shopName,
      'description': description,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'address': address,
      'phone': phone,

      'plan': plan,
      'productLimit': productLimit,
      'productCount': productCount,
      'transactionFeePercent': transactionFeePercent,

      'isActive': isActive,
      'isVerified': isVerified,

      // 🆕 DELIVERY
      'deliveryUnit': deliveryUnit,
      'deliveryMinValue': deliveryMinValue,
      'deliveryMaxValue': deliveryMaxValue,
      'deliveryMinMinutes': deliveryMinMinutes,
      'deliveryMaxMinutes': deliveryMaxMinutes,
    };
  }

  ShopModel copyWith({
    String? shopName,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    String? address,
    String? phone,

    String? plan,
    int? productLimit,
    int? productCount,
    double? transactionFeePercent,

    bool? isActive,
    bool? isVerified,

    String? deliveryUnit,
    int? deliveryMinValue,
    int? deliveryMaxValue,
    int? deliveryMinMinutes,
    int? deliveryMaxMinutes,
  }) {
    return ShopModel(
      shopId: shopId,
      sellerId: sellerId,
      societyId: societyId,
      shopName: shopName ?? this.shopName,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      address: address ?? this.address,
      phone: phone ?? this.phone,

      plan: plan ?? this.plan,
      productLimit: productLimit ?? this.productLimit,
      productCount: productCount ?? this.productCount,
      transactionFeePercent:
          transactionFeePercent ?? this.transactionFeePercent,

      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,

      deliveryUnit: deliveryUnit ?? this.deliveryUnit,
      deliveryMinValue: deliveryMinValue ?? this.deliveryMinValue,
      deliveryMaxValue: deliveryMaxValue ?? this.deliveryMaxValue,
      deliveryMinMinutes:
          deliveryMinMinutes ?? this.deliveryMinMinutes,
      deliveryMaxMinutes:
          deliveryMaxMinutes ?? this.deliveryMaxMinutes,
    );
  }
}
