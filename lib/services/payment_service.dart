import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../config/razorpay_config.dart';
import '../../data/datasources/seller_payment_remote_ds.dart';

class PaymentService {
  final Razorpay _razorpay = Razorpay();
  final SellerPaymentRemoteDS _paymentRemoteDS =
      SellerPaymentRemoteDS();

  /// Firestore payment document ID
   String? _paymentDocId;

  /// Call from initState
  void init() {
    _razorpay.on(
        Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(
        Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  /// Call from dispose
  void dispose() {
    _razorpay.clear();
  }

  /// MAIN ENTRY POINT
  /// This now follows the Razorpay Orders API flow
  Future<void> startSellerActivationPayment({
    required String sellerId,
    required String shopId,
    required String plan,
    required int monthlyFee,
    required int productLimit,
    required String sellerPhone,
    required String sellerEmail,
  }) async {

     // 🔒 HARD GUARD (prevents double tap + rebuild issues)
    if (_paymentDocId != null) {
      return;
    }
    /// 1️⃣ Create Firestore payment record (SOURCE OF TRUTH)
    _paymentDocId =
        await _paymentRemoteDS.createActivationPayment(
      sellerId: sellerId,
      shopId: shopId,
      plan: plan,
      monthlyFee: monthlyFee,
      productLimit: productLimit,
    );

    /// 2️⃣ Ask backend to create Razorpay ORDER
    final createOrder =
        FirebaseFunctions.instance.httpsCallable(
      'createSellerOrder',
    );

    final response = await createOrder.call({
      'paymentDocId': _paymentDocId,
    });

    final String orderId = response.data['orderId'];

    /// 3️⃣ Open Razorpay using order_id (AUTO-CAPTURE ENABLED)
    final options = {
      'key': RazorpayConfig.keyId,
      'order_id': orderId,
      'name': RazorpayConfig.companyName,
      'description': RazorpayConfig.description,
      'prefill': {
        'contact': sellerPhone,
        'email': sellerEmail,
      },
      'notes': {
        'paymentDocId': _paymentDocId,
        'sellerId': sellerId,
      },
    };

    _razorpay.open(options);
  }

  /// Razorpay SUCCESS
  /// ⚠️ DO NOT update Firestore here
  /// ⚠️ DO NOT call backend
  /// Webhook will handle everything
  void _handlePaymentSuccess(
      PaymentSuccessResponse response) {
    // Intentionally left blank
    // Final confirmation happens via webhook (payment.captured)
  }

  /// Razorpay FAILURE
  Future<void> _handlePaymentError(
    PaymentFailureResponse response) async {

  if (_paymentDocId == null) return;

  await _paymentRemoteDS.markPaymentFailed(
    paymentDocId: _paymentDocId!,
    failureReason:
        response.message ?? 'Payment cancelled',
  );

  // reset so user can retry
  _paymentDocId = null;
}
}
