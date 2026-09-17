import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../config/razorpay_config.dart';
import '../data/datasources/buyer_order_payment_remote_ds.dart';

/// Buyer-order counterpart of PaymentService (seller activation). Kept as
/// its own class with its own Razorpay instance rather than folded into
/// PaymentService — the two flows run on different screens with different
/// pending-payment state, and keeping them separate means this addition
/// can't affect the existing, working seller-activation flow at all.
class BuyerPaymentService {
  final Razorpay _razorpay = Razorpay();
  final BuyerOrderPaymentRemoteDS _paymentRemoteDS =
      BuyerOrderPaymentRemoteDS();

  String? _paymentDocId;
  void Function(String message)? _onError;

  /// Call from initState.
  void init() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  /// Call from dispose.
  void dispose() {
    _razorpay.clear();
  }

  /// MAIN ENTRY POINT. Returns the pre-generated order id the caller
  /// should watch for (created by the webhook once payment is captured —
  /// see razorpayWebhook's buyer_order_payments branch).
  Future<String> startBuyerOrderPayment({
    required String orderId,
    required String buyerId,
    required String sellerId,
    required String shopId,
    required String societyId,
    required String flatNumber,
    required String societyName,
    required String shopName,
    required String shopPhone,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String buyerPhone,
    void Function(String message)? onError,
  }) async {
    if (_paymentDocId != null) {
      return orderId;
    }
    _onError = onError;

    /// 1️⃣ Create Firestore payment record (SOURCE OF TRUTH)
    _paymentDocId = await _paymentRemoteDS.createPendingPayment(
      buyerId: buyerId,
      sellerId: sellerId,
      shopId: shopId,
      societyId: societyId,
      flatNumber: flatNumber,
      societyName: societyName,
      shopName: shopName,
      shopPhone: shopPhone,
      items: items,
      totalAmount: totalAmount,
      orderId: orderId,
    );

    /// 2️⃣ Ask backend to create the Razorpay ORDER
    final createOrder = FirebaseFunctions.instance.httpsCallable(
      'createBuyerOrderPayment',
    );

    final response = await createOrder.call({
      'paymentDocId': _paymentDocId,
    });

    final String razorpayOrderId = response.data['orderId'];

    /// 3️⃣ Open Razorpay using order_id (AUTO-CAPTURE ENABLED)
    final options = {
      'key': RazorpayConfig.keyId,
      'order_id': razorpayOrderId,
      'name': RazorpayConfig.companyName,
      'description': 'Order payment',
      'prefill': {
        'contact': buyerPhone,
      },
      'notes': {
        'paymentDocId': _paymentDocId,
        'buyerId': buyerId,
        'orderId': orderId,
      },
    };

    _razorpay.open(options);

    return orderId;
  }

  /// Razorpay SUCCESS — intentionally a no-op, same as the seller flow.
  /// Final confirmation happens via razorpayWebhook (payment.captured),
  /// which is what actually creates the orders/{orderId} doc.
  void _handlePaymentSuccess(PaymentSuccessResponse response) {}

  /// Razorpay FAILURE
  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    if (_paymentDocId == null) return;

    await _paymentRemoteDS.markPaymentFailed(
      paymentDocId: _paymentDocId!,
      failureReason: response.message ?? 'Payment cancelled',
    );

    final message = response.message ?? 'Payment cancelled';
    _paymentDocId = null;
    _onError?.call(message);
  }
}
