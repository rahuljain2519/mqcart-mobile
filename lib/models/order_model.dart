import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final String societyId;
  final String flatNumber;
  final String societyName;
  final String shopName;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String status; // placed | accepted | delivered

  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  // 🆕 PAYMENT FIELDS (ADD ONLY)
  final String paymentMethod;
  final String paymentStatus;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.societyId,
    required this.shopName,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.flatNumber = '',
    this.societyName = '',
    this.createdAt,
    this.updatedAt,
     // 🆕 SAFE DEFAULTS (CRITICAL)
    this.paymentMethod = 'cod',
    this.paymentStatus = 'pending',
  });

  factory OrderModel.fromJson(Map<String, dynamic> json, String id) {
    return OrderModel(
      id: id,
      buyerId: json['buyerId'],
      sellerId: json['sellerId'],
      societyId: json['societyId'],
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      flatNumber: json['flatNumber'] ?? '',
      societyName: json['societyName'] ?? '',
      shopName: json['shopName'] ?? 'Nearby Store',
      status: json['status'] ?? 'placed',
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      // 🆕 FALLBACK FOR OLD ORDERS
      paymentMethod: json['paymentMethod'] ?? 'cod',
      paymentStatus: json['paymentStatus'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'societyId': societyId,
      'items': items,
      'totalAmount': totalAmount,
      'status': status,
      'flatNumber': flatNumber,
      'societyName': societyName,
      'shopName': shopName,
      // 🆕 PAYMENT DATA
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
