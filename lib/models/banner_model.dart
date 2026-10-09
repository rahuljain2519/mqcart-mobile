class BannerModel {
  final String id;
  final String imageUrl;
  final String? linkUrl;
  final int order;
  final bool isActive;

  BannerModel({
    required this.id,
    required this.imageUrl,
    this.linkUrl,
    required this.order,
    required this.isActive,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json, String id) {
    return BannerModel(
      id: id,
      imageUrl: json['imageUrl'] ?? '',
      linkUrl: json['linkUrl'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] == true,
    );
  }
}
