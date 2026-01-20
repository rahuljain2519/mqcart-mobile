import 'package:cloud_firestore/cloud_firestore.dart';

class SellerPaymentRemoteDS {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// STEP 1: Create payment record BEFORE opening Razorpay
  Future<String> createActivationPayment({
    required String sellerId,
    required String shopId,
    required String plan,          // 999 / 2499 / 4999 or PLAN_999
    required int monthlyFee,       // 999 / 2499 / 4999
    required int productLimit,     // 5 / 20 / 50
  }) async {
    final docRef =
        _firestore.collection('seller_activation_payments').doc();

    await docRef.set({
      'sellerId': sellerId,
      'shopId': shopId,
      'plan': plan,
      'monthlyFee': monthlyFee,
      'productLimit': productLimit,
      'gateway': 'razorpay',
      'status': 'initiated', // initiated | success | failed | verified
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id; // internal payment reference
  }

  /// STEP 2: Mark frontend payment success (NOT VERIFIED)
  Future<void> markPaymentSuccess({
    required String paymentDocId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
  }) async {
    await _firestore
        .collection('seller_activation_payments')
        .doc(paymentDocId)
        .update({
      'status': 'success',
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'paidAt': FieldValue.serverTimestamp(),
    });
  }

  /// STEP 3: Mark payment failure
  Future<void> markPaymentFailed({
    required String paymentDocId,
    required String failureReason,
  }) async {
    await _firestore
        .collection('seller_activation_payments')
        .doc(paymentDocId)
        .update({
      'status': 'failed',
      'failureReason': failureReason,
      'failedAt': FieldValue.serverTimestamp(),
    });
  }
}
