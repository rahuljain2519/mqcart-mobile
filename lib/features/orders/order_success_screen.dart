import 'package:flutter/material.dart';
import '../buyer/buyer_orders_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});

  static const Color mqOrange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Order Placed',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ SUCCESS ICON
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: mqOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: mqOrange,
                size: 72,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Order Confirmed!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Your order has been placed successfully.\nYou’ll receive updates shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 36),

            // 👉 View Orders (PRIMARY CTA)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mqOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  // This screen only ever follows a BUYER checkout, even
                  // for a user who also happens to have a seller role -
                  // going through the role-based OrdersRouter sent
                  // seller-buyers to their Incoming Orders screen instead
                  // of the purchase they just made.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BuyerOrdersScreen(),
                    ),
                  );
                },
                child: const Text(
                  'View My Orders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 👉 Continue Shopping (SECONDARY CTA)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: mqOrange,
                  side: const BorderSide(color: mqOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  );
                },
                child: const Text(
                  'Continue Shopping',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
