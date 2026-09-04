import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/order_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/product_repository.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final AudioPlayer _player = AudioPlayer();
  int _lastNewOrderCount = 0;

  static const Color mqOrange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    final sellerId = FirebaseAuth.instance.currentUser!.uid;
    final OrderRepository orderRepository = OrderRepository();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: StreamBuilder<List<OrderModel>>(
          stream: orderRepository.streamOrdersBySeller(sellerId),
          builder: (context, snapshot) {
            final newCount =
                snapshot.data?.where((o) => o.status == 'placed').length ?? 0;

            return Row(
              children: [
                const Text(
                  'Incoming Orders',
                  style: TextStyle(color: Colors.black),
                ),
                const SizedBox(width: 8),
                if (newCount > 0)
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: mqOrange,
                    child: Text(
                      newCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: orderRepository.streamOrdersBySeller(sellerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }

          final orders = snapshot.data!;

          final newOrders =
              orders.where((o) => o.status == 'placed').toList();
          final inProgressOrders =
              orders.where((o) => o.status == 'accepted').toList();
          final deliveredOrders =
              orders.where((o) => o.status == 'delivered').toList();
          final rejectedOrders =
              orders.where((o) => o.status == 'rejected').toList();

          if (newOrders.length > _lastNewOrderCount) {
            _player.play(AssetSource('sounds/new_order.mp3'));
          }
          _lastNewOrderCount = newOrders.length;

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (newOrders.isNotEmpty) ...[
                _sectionTitle('NEW ORDERS'),
                ...newOrders.map(_buildOrderCard),
              ],
              if (inProgressOrders.isNotEmpty) ...[
                _sectionTitle('IN PROGRESS'),
                ...inProgressOrders.map(_buildOrderCard),
              ],
              if (deliveredOrders.isNotEmpty) ...[
                _sectionTitle('DELIVERED'),
                ...deliveredOrders.map(_buildOrderCard),
              ],
              if (rejectedOrders.isNotEmpty) ...[
                _sectionTitle('REJECTED'),
                ...rejectedOrders.map(_buildOrderCard),
              ],
            ],
          );
        },
      ),
    );
  }

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

  Widget _buildOrderCard(OrderModel order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: mqOrange.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          'Order #${order.id.substring(0, 6)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '₹${order.totalAmount.toStringAsFixed(0)} • ${order.status.toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // BUYER DETAILS + CALL
            FutureBuilder<UserModel?>(
              future: UserRepository().getUser(order.buyerId),
              builder: (context, buyerSnap) {
                if (!buyerSnap.hasData) return const SizedBox();

                final buyer = buyerSnap.data!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buyer: ${buyer.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Flat: ${buyer.flatNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      'Society: ${order.societyName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),

                    if (order.status == 'placed' ||
                        order.status == 'accepted')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton.icon(
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('Call Buyer'),
                          onPressed: () async {
                            if (buyer.phone.isEmpty) return;

                            final uri =
                                Uri.parse('tel:${buyer.phone}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        children: [
          const Divider(),
          ...order.items.map((item) {
            return ListTile(
              title: Text(item['optionName'] != null
                  ? "${item['name']} (${item['optionName']})"
                  : item['name']),
              subtitle: Text('₹${item['price']} × ${item['quantity']}'),
            );
          }).toList(),
          const SizedBox(height: 8),
          _OrderActions(order: order),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ---------------------------------
// ORDER ACTIONS (UNCHANGED)
// ---------------------------------
class _OrderActions extends StatelessWidget {
  final OrderModel order;

  const _OrderActions({required this.order});

  static const Color mqOrange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    final OrderRepository repo = OrderRepository();

    if (order.status == 'delivered') {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Order Delivered',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (order.status == 'rejected') {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Order Rejected',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (order.status == 'placed')
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: mqOrange,
            ),
            onPressed: () => repo.updateOrderStatus(
              orderId: order.id,
              status: 'accepted',
            ),
            child: const Text('Accept'),
          ),
        if (order.status == 'placed')
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: () async {
              await ProductRepository().restockAfterOrderCancel(
                order.items.map((item) {
                  return {
                    'productId': item['productId'],
                    'quantity': item['quantity'],
                    if (item['optionName'] != null)
                      'optionName': item['optionName'],
                  };
                }).toList(),
              );

              await repo.updateOrderStatus(
                orderId: order.id,
                status: 'rejected',
              );
            },
            child: const Text('Reject'),
          ),
        if (order.status == 'accepted')
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: mqOrange,
            ),
            onPressed: () => repo.updateOrderStatus(
              orderId: order.id,
              status: 'delivered',
            ),
            child: const Text('Mark Delivered'),
          ),
      ],
    );
  }
}
