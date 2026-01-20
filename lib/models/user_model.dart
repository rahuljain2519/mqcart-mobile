class UserModel {
  final String uid;
  final String name;
  final String phone;

  // buyer | seller | admin
  final String role;

  final String societyId;
  final String flatNumber; // Flat / Block number for delivery

  // 🆕 SELLER FLOW FIELDS
  final String sellerStatus; // none | pending | active | inactive
  final String? shopId;

  // 🆕 Seller application data (used by admin)
  final Map<String, dynamic>? sellerApplication;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    required this.societyId,
    this.flatNumber = '',

    // 🆕 seller defaults
    this.sellerStatus = 'none',
    this.shopId,

    // 🆕 seller application
    this.sellerApplication,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'buyer',
      societyId: json['societyId'] ?? '',
      flatNumber: json['flatNumber'] ?? '',

      // 🆕 SAFE BACKWARD-COMPATIBLE DEFAULTS
      sellerStatus: json['sellerStatus'] ?? 'none',
      shopId: json['shopId'],

      // 🆕 seller application (nullable & safe)
      sellerApplication:
          json['sellerApplication'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
      'societyId': societyId,
      'flatNumber': flatNumber,

      // 🆕 seller fields
      'sellerStatus': sellerStatus,
      'shopId': shopId,

      // 🆕 seller application (only if exists)
      if (sellerApplication != null)
        'sellerApplication': sellerApplication,

      'updatedAt': DateTime.now(),
    };
  }
}
