class BulkProductRow {
  final String name;
  final double price;
  final int quantity;
  final String category;
  final String description;
  final bool isActive;
  final String imagePrefix;

  // 🆕 DELIVERY
  final String? deliveryUnit; // minutes | hours | days
  final int? deliveryMin;
  final int? deliveryMax;

  // 🆕 COVER IMAGE
  final int coverIndex;

  // 🆕 OPTIONAL STANDARD CATALOG FIELDS (see product_model.dart)
  final String? subcategory;
  final String? brand;
  final double? unitValue;
  final String? unitType;
  final double? mrp;

  BulkProductRow({
    required this.name,
    required this.price,
    required this.quantity,
    required this.category,
    required this.description,
    required this.isActive,
    required this.imagePrefix,
    this.deliveryUnit,
    this.deliveryMin,
    this.deliveryMax,
    this.coverIndex = 0,
    this.subcategory,
    this.brand,
    this.unitValue,
    this.unitType,
    this.mrp,
  });
}
