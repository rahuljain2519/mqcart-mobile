import '../data/datasources/order_remote_ds.dart';
import '../models/order_model.dart';
import '../models/settlement_model.dart';

export '../data/datasources/order_remote_ds.dart'
    show UnsettledSellerTotal, TransactionReportRow;

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
    required String shopPhone,
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
      shopPhone: shopPhone,
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

  /// ---------------------------
  /// ADMIN: MANUAL SETTLEMENT (OPTION A)
  /// ---------------------------
  Future<List<UnsettledSellerTotal>> getUnsettledAmountsBySeller() {
    return _remoteDS.getUnsettledAmountsBySeller();
  }

  Future<void> markOrdersSettled({
    required String sellerId,
    required String shopName,
    required List<String> orderIds,
    required double totalAmount,
    required String settledBy,
    String? note,
  }) {
    return _remoteDS.markOrdersSettled(
      sellerId: sellerId,
      shopName: shopName,
      orderIds: orderIds,
      totalAmount: totalAmount,
      settledBy: settledBy,
      note: note,
    );
  }

  Future<List<SettlementModel>> getSettlementsForSeller(String sellerId) {
    return _remoteDS.getSettlementsForSeller(sellerId);
  }

  /// ---------------------------
  /// ADMIN: TRANSACTION REPORT EXPORT
  /// ---------------------------
  Future<List<TransactionReportRow>> buildTransactionsReport({
    DateTime? startDate,
    DateTime? endDate,
    String? sellerId,
    String? societyId,
    String? paymentMethod,
  }) {
    return _remoteDS.buildTransactionsReport(
      startDate: startDate,
      endDate: endDate,
      sellerId: sellerId,
      societyId: societyId,
      paymentMethod: paymentMethod,
    );
  }

  Future<void> updateOrderSettlementStatus({
    required String orderId,
    required String sellerId,
    required String shopName,
    required double settlementAmount,
    required bool settled,
    required String settledBy,
  }) {
    return _remoteDS.updateOrderSettlementStatus(
      orderId: orderId,
      sellerId: sellerId,
      shopName: shopName,
      settlementAmount: settlementAmount,
      settled: settled,
      settledBy: settledBy,
    );
  }
}
