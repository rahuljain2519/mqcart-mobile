import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../models/order_model.dart';
import '../../models/settlement_model.dart';

class UnsettledSellerTotal {
  final String sellerId;
  final String shopName;
  final List<String> orderIds;
  final double totalAmount;

  UnsettledSellerTotal({
    required this.sellerId,
    required this.shopName,
    required this.orderIds,
    required this.totalAmount,
  });
}

/// One row of the admin transaction report export (see
/// OrderRemoteDS.buildTransactionsReport).
class TransactionReportRow {
  final String orderId;
  final String date;
  final String transactionType;
  final String paymentStatus;
  final String orderStatus;
  final String societyName;
  final String sellerName;
  final String shopName;
  final String bankAccountNumber;
  final String ifscCode;
  final String productDetails;
  final double totalAmount;

  TransactionReportRow({
    required this.orderId,
    required this.date,
    required this.transactionType,
    required this.paymentStatus,
    required this.orderStatus,
    required this.societyName,
    required this.sellerName,
    required this.shopName,
    required this.bankAccountNumber,
    required this.ifscCode,
    required this.productDetails,
    required this.totalAmount,
  });
}

class OrderRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  /// ---------------------------------
  /// CREATE NEW ORDER (BUYER)
  /// ---------------------------------
  Future<void> createOrder(OrderModel order) async {
    final data = order.toJson();

    await _firestore.orders().add({
      ...data,
      'status': order.status.isNotEmpty ? order.status : 'placed',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// =================================================
  /// STREAM ORDERS — BUYER (AUTO REFRESH)
  /// =================================================
  Stream<List<OrderModel>> streamOrdersByBuyer(String buyerId) {
    return _firestore
        .orders()
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OrderModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// =================================================
  /// STREAM ORDERS — SELLER (AUTO REFRESH)
  /// =================================================
  Stream<List<OrderModel>> streamOrdersBySeller(String sellerId) {
    return _firestore
        .orders()
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OrderModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// ---------------------------------
  /// UPDATE ORDER STATUS
  /// ---------------------------------
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _firestore.orders().doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ---------------------------------
  /// MANUAL SETTLEMENT (ADMIN, OPTION A)
  /// Online orders collect 100% into MQ Cart's Razorpay account with no
  /// automatic payout yet (Route is built but not being activated per
  /// seller for now) - admin pays sellers directly and records it here.
  /// Single-field query (paymentMethod only) + client-side filtering on
  /// paymentStatus/settled so this doesn't need a composite index.
  /// ---------------------------------
  Future<List<UnsettledSellerTotal>> getUnsettledAmountsBySeller() async {
    final snap = await _firestore
        .orders()
        .where('paymentMethod', isEqualTo: 'razorpay')
        .get();

    final bySeller = <String, UnsettledSellerTotal>{};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['paymentStatus'] != 'paid' || data['settled'] == true) continue;

      final sellerId = data['sellerId'] as String;
      final amount = (data['totalAmount'] as num).toDouble();
      final existing = bySeller[sellerId];
      if (existing != null) {
        existing.orderIds.add(doc.id);
        bySeller[sellerId] = UnsettledSellerTotal(
          sellerId: sellerId,
          shopName: existing.shopName,
          orderIds: existing.orderIds,
          totalAmount: existing.totalAmount + amount,
        );
      } else {
        bySeller[sellerId] = UnsettledSellerTotal(
          sellerId: sellerId,
          shopName: data['shopName'] ?? '',
          orderIds: [doc.id],
          totalAmount: amount,
        );
      }
    }

    final list = bySeller.values.toList();
    list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return list;
  }

  /// Records that a seller has been paid (by bank transfer, done outside
  /// the app) for a batch of orders, and marks those orders settled so
  /// they drop off future reports.
  Future<void> markOrdersSettled({
    required String sellerId,
    required String shopName,
    required List<String> orderIds,
    required double totalAmount,
    required String settledBy,
    String? note,
  }) async {
    final settlementRef = _firestore.settlements().doc();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(settlementRef, {
      'sellerId': sellerId,
      'shopName': shopName,
      'orderIds': orderIds,
      'totalAmount': totalAmount,
      'note': note ?? '',
      'settledBy': settledBy,
      'settledAt': FieldValue.serverTimestamp(),
    });

    for (final orderId in orderIds) {
      batch.update(_firestore.orders().doc(orderId), {
        'settled': true,
        'settlementId': settlementRef.id,
      });
    }

    await batch.commit();
  }

  /// Past settlements for one seller, most recent first.
  Future<List<SettlementModel>> getSettlementsForSeller(String sellerId) async {
    final snap = await _firestore
        .settlements()
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('settledAt', descending: true)
        .get();
    return snap.docs
        .map((d) => SettlementModel.fromJson(
              d.data() as Map<String, dynamic>,
              d.id,
            ))
        .toList();
  }

  /// Admin-only: every order (optionally date-bounded), enriched with the
  /// seller's name and bank details for a full offline-reconciliation
  /// report. Covers both COD and online orders - transactionType is the
  /// column that tells them apart.
  Future<List<TransactionReportRow>> buildTransactionsReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _firestore.orders();
    if (startDate != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    final snap = await query.get();
    final orders = snap.docs
        .map((d) => {...(d.data() as Map<String, dynamic>), 'id': d.id})
        .toList();

    final sellerIds =
        orders.map((o) => o['sellerId'] as String).toSet().toList();

    final userDocs = await Future.wait(
      sellerIds.map((uid) => _firestore.users().doc(uid).get()),
    );
    final appDocs = await Future.wait(
      sellerIds.map((uid) => _firestore.sellerApplications().doc(uid).get()),
    );

    final nameById = <String, String>{};
    for (var i = 0; i < sellerIds.length; i++) {
      final data = userDocs[i].data() as Map<String, dynamic>?;
      if (data != null) nameById[sellerIds[i]] = data['name'] ?? '';
    }
    final bankById = <String, (String, String)>{};
    for (var i = 0; i < sellerIds.length; i++) {
      final data = appDocs[i].data() as Map<String, dynamic>?;
      if (data != null) {
        bankById[sellerIds[i]] = (
          data['bankAccountNumber'] ?? '',
          data['ifscCode'] ?? '',
        );
      }
    }

    return orders.map((o) {
      final sellerId = o['sellerId'] as String;
      final bank = bankById[sellerId];
      final items = List<Map<String, dynamic>>.from(o['items'] ?? []);
      final createdAt = o['createdAt'];
      return TransactionReportRow(
        orderId: o['id'] ?? '',
        date: createdAt is Timestamp
            ? createdAt.toDate().toIso8601String()
            : '',
        transactionType: o['paymentMethod'] ?? '',
        paymentStatus: o['paymentStatus'] ?? '',
        orderStatus: o['status'] ?? '',
        societyName: o['societyName'] ?? '',
        sellerName: nameById[sellerId] ?? '',
        shopName: o['shopName'] ?? '',
        bankAccountNumber: bank?.$1 ?? '',
        ifscCode: bank?.$2 ?? '',
        productDetails: items
            .map((it) =>
                '${it['name']}${it['optionName'] != null ? ' (${it['optionName']})' : ''} x${it['quantity']} @ ₹${it['price']}')
            .join('; '),
        totalAmount: (o['totalAmount'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }
}
