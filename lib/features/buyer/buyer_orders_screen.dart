import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../repositories/order_repository.dart';
import '../../../repositories/product_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../models/order_model.dart';
import 'buyer_product_detail_screen.dart';

class BuyerOrdersScreen extends StatelessWidget {
  const BuyerOrdersScreen({super.key});

  static const Color mqOrange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    final buyerId = FirebaseAuth.instance.currentUser!.uid;
    final OrderRepository repo = OrderRepository();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Orders',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: repo.streamOrdersByBuyer(buyerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }

          final orders = snapshot.data!;

          final activeOrders = orders.where(
            (o) => o.status == 'placed' || o.status == 'accepted',
          );
          final deliveredOrders =
              orders.where((o) => o.status == 'delivered');
          final rejectedOrders =
              orders.where((o) => o.status == 'rejected');
          final cancelledOrders =
              orders.where((o) => o.status == 'cancelled');

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (activeOrders.isNotEmpty) ...[
                _sectionTitle('ACTIVE ORDERS'),
                ...activeOrders.map((o) => _buildOrderCard(context, o)),
              ],
              if (deliveredOrders.isNotEmpty) ...[
                _sectionTitle('DELIVERED'),
                ...deliveredOrders.map((o) => _buildOrderCard(context, o)),
              ],
              if (rejectedOrders.isNotEmpty) ...[
                _sectionTitle('REJECTED'),
                ...rejectedOrders.map((o) => _buildOrderCard(context, o)),
              ],
              if (cancelledOrders.isNotEmpty) ...[
                _sectionTitle('CANCELLED'),
                ...cancelledOrders.map((o) => _buildOrderCard(context, o)),
              ],
            ],
          );
        },
      ),
    );
  }

  // ---------------------------
  // SECTION TITLE
  // ---------------------------
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // ---------------------------
  // ORDER CARD
  // ---------------------------
  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: mqOrange.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statusChip(order.status),
                Text(
                  _shortOrderId(order.id),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: '₹',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: order.totalAmount.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'from ${order.shopName}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            _orderTimeline(order.status),

            if (order.status == 'rejected' &&
                order.rejectionReason != null &&
                order.rejectionReason!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Declined by the seller: ${order.rejectionReason}',
                  style: const TextStyle(fontSize: 13, color: Colors.red),
                ),
              ),
          ],
        ),
        children: [
          const Divider(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flat: ${order.flatNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Society: ${order.societyName}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------------------
          // CALL STORE (FIXED)
          // ---------------------------
          if (order.status == 'placed' || order.status == 'accepted')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mqOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.call, size: 18),
                label: const Text(
                  'Call Store',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  // shopPhone was never actually collected anywhere in shop
                  // creation/edit (no phone field exists on the form), so
                  // it's empty on every historical order - fall back to the
                  // seller's own account phone, which is always set,
                  // instead of silently doing nothing when tapped.
                  String? phone =
                      order.shopPhone.isNotEmpty ? order.shopPhone : null;
                  if (phone == null) {
                    try {
                      final seller =
                          await UserRepository().getUser(order.sellerId);
                      phone = seller.phone.isNotEmpty ? seller.phone : null;
                    } catch (_) {}
                  }
                  if (phone == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Store phone number not available')),
                      );
                    }
                    return;
                  }

                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Store phone: $phone')),
                    );
                  }
                },
              ),
            ),

          // ---------------------------
          // CANCEL ORDER (buyer, only before the seller accepts)
          // ---------------------------
          if (order.status == 'placed')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => _confirmCancel(context, order),
                child: const Text('Cancel order'),
              ),
            ),

          const Divider(),

          // ITEMS
          ...order.items.map((item) {
            return Builder(
              builder: (ctx) {
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  title: Text(item['optionName'] != null
                      ? "${item['name']} (${item['optionName']})"
                      : item['name']),
                  subtitle: Text(
                    '₹${item['price']} × ${item['quantity']}',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onTap: () async {
                    final productId = item['productId'];
                    if (productId == null) return;

                    final product =
                        await ProductRepository().getProductById(productId);

                    if (product == null) return;

                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            BuyerProductDetailScreen(product: product),
                      ),
                    );
                  },
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  // ---------------------------
  // ORDER TIMELINE
  // ---------------------------
  Widget _orderTimeline(String status) {
    int activeIndex = 0;

    if (status == 'accepted') activeIndex = 1;
    if (status == 'delivered') activeIndex = 2;

    Color activeColor = mqOrange;
    if (status == 'delivered') activeColor = Colors.green;

    return Row(
      children: List.generate(5, (index) {
        if (index.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: index ~/ 2 < activeIndex
                  ? activeColor
                  : Colors.grey.shade300,
            ),
          );
        } else {
          final step = index ~/ 2;
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step <= activeIndex
                  ? activeColor
                  : Colors.grey.shade300,
            ),
          );
        }
      }),
    );
  }

  // ---------------------------
  // STATUS CHIP
  // ---------------------------
  Widget _statusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'placed':
        color = mqOrange;
        label = 'ORDER PLACED';
        break;
      case 'accepted':
        color = Colors.blueGrey;
        label = 'ORDER ACCEPTED';
        break;
      case 'delivered':
        color = Colors.green;
        label = 'DELIVERED';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'REJECTED';
        break;
      case 'cancelled':
        color = Colors.grey;
        label = 'CANCELLED';
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ---------------------------
  // ORDER ID SHORTENER
  // ---------------------------
  String _shortOrderId(String id) {
    if (id.isEmpty || id.length < 6) return '';
    return '#${id.substring(id.length - 6).toUpperCase()}';
  }

  // ---------------------------
  // CANCEL ORDER (buyer-initiated, only while still "placed")
  // ---------------------------
  Future<void> _confirmCancel(BuildContext context, OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          "The seller hasn't accepted it yet. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Restock the same way a seller rejection does - checkout already
    // reduced stock for these items, so leaving it cancelled without
    // putting it back would leak stock on every buyer cancellation.
    await ProductRepository().restockAfterOrderCancel(
      order.items.map((item) {
        return {
          'productId': item['productId'],
          'quantity': item['quantity'],
          if (item['optionName'] != null) 'optionName': item['optionName'],
        };
      }).toList(),
    );
    await OrderRepository().updateOrderStatus(
      orderId: order.id,
      status: 'cancelled',
    );
  }
}
