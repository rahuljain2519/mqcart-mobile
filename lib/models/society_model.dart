class SocietyModel {
  final String id;
  final String name;
  final String city;
  final bool isActive;

  SocietyModel({
    required this.id,
    required this.name,
    required this.city,
    required this.isActive,
  });

  factory SocietyModel.fromJson(Map<String, dynamic> json, String id) {
    return SocietyModel(
      id: id,
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'city': city,
      'isActive': isActive,
      'createdAt': DateTime.now(),
    };
  }
}
