import 'package:cloud_firestore/cloud_firestore.dart';

/// A record of an admin manually paying a seller their share of a batch of
/// online orders (Option A - fully manual settlement, no Razorpay Route
/// payout). Created by OrderRemoteDS.markOrdersSettled.
class SettlementModel {
  final String id;
  final String sellerId;
  final String shopName;
  final List<String> orderIds;
  final double totalAmount;
  final String? note;
  final Timestamp? settledAt;
  final String settledBy;

  SettlementModel({
    required this.id,
    required this.sellerId,
    required this.shopName,
    required this.orderIds,
    required this.totalAmount,
    required this.settledBy,
    this.note,
    this.settledAt,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json, String id) {
    return SettlementModel(
      id: id,
      sellerId: json['sellerId'] ?? '',
      shopName: json['shopName'] ?? '',
      orderIds: List<String>.from(json['orderIds'] ?? []),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      note: json['note'],
      settledAt: json['settledAt'],
      settledBy: json['settledBy'] ?? '',
    );
  }
}
