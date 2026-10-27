import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final String societyId;
  final String flatNumber;
  final String societyName;
  final String shopName;
  final String shopPhone;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String status; // placed | accepted | delivered | rejected | cancelled
  /// Set when status is 'rejected' - why the seller declined the order.
  final String? rejectionReason;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  // Per-status timestamps - set once, the first time each transition
  // happens (see OrderRemoteDS.updateOrderStatus/rejectOrder). Only the
  // one matching the order's current status is ever populated.
  final Timestamp? acceptedAt;
  final Timestamp? deliveredAt;
  final Timestamp? rejectedAt;
  final Timestamp? cancelledAt;
  // 🆕 PAYMENT FIELDS (ADD ONLY)
  final String paymentMethod;
  final String paymentStatus;
  /// Set for "razorpay" orders once the webhook confirms payment - absent
  /// for "cod". Denormalized onto the order so support/refund lookups
  /// don't need buyer_order_payments too.
  final String? razorpayPaymentId;

  // Manual settlement (Option A - see AdminSettlementsScreen). Only
  // meaningful for paymentMethod 'razorpay' orders; COD orders are never
  // settled through this since the seller already collected cash directly.
  final bool settled;
  final String? settlementId;

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
    this.shopPhone = '',
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.deliveredAt,
    this.rejectedAt,
    this.cancelledAt,
     // 🆕 SAFE DEFAULTS (CRITICAL)
    this.paymentMethod = 'cod',
    this.paymentStatus = 'pending',
    this.razorpayPaymentId,
    this.settled = false,
    this.settlementId,
    this.rejectionReason,
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
      shopPhone: json['shopPhone'] ?? '',
      status: json['status'] ?? 'placed',
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      acceptedAt: json['acceptedAt'],
      deliveredAt: json['deliveredAt'],
      rejectedAt: json['rejectedAt'],
      cancelledAt: json['cancelledAt'],
      // 🆕 FALLBACK FOR OLD ORDERS
      paymentMethod: json['paymentMethod'] ?? 'cod',
      paymentStatus: json['paymentStatus'] ?? 'pending',
      razorpayPaymentId: json['razorpayPaymentId'],
      settled: json['settled'] ?? false,
      settlementId: json['settlementId'],
      rejectionReason: json['rejectionReason'],
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
      'shopPhone': shopPhone,
      // 🆕 PAYMENT DATA
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
