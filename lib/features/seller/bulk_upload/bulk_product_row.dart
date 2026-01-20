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
  });
}
