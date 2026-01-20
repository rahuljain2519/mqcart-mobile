import '../data/datasources/order_remote_ds.dart';
import '../models/order_model.dart';

class OrderRepository {
  final OrderRemoteDS _remoteDS = OrderRemoteDS();

  /// ---------------------------
  /// BUYER: PLACE ORDER
  /// ---------------------------
  Future<void> placeOrder({
    required String buyerId,
    required String sellerId,
    required String societyId,
    required String flatNumber,      // 🆕
    required String societyName,     // 🆕
    required String shopName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    // 🆕 PAYMENT PARAMS
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    final order = OrderModel(
      id: '',
      buyerId: buyerId,
      sellerId: sellerId,
      societyId: societyId,
      flatNumber: flatNumber,        // 🆕
      societyName: societyName,      // 🆕
      shopName: shopName,
      items: items,
      totalAmount: totalAmount,
      status: 'placed',
      // 🆕 PAYMENT INFO
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
    );

    await _remoteDS.createOrder(order);
  }

  /// ---------------------------
  /// BUYER: STREAM OWN ORDERS
  /// ---------------------------
  Stream<List<OrderModel>> streamOrdersByBuyer(String buyerId) {
    return _remoteDS.streamOrdersByBuyer(buyerId);
  }

  /// ---------------------------
  /// SELLER: STREAM INCOMING ORDERS
  /// ---------------------------
  Stream<List<OrderModel>> streamOrdersBySeller(String sellerId) {
    return _remoteDS.streamOrdersBySeller(sellerId);
  }

  /// ---------------------------
  /// UPDATE ORDER STATUS
  /// ---------------------------
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) {
    return _remoteDS.updateOrderStatus(
      orderId: orderId,
      status: status,
    );
  }
}
