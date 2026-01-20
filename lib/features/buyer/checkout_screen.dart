import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/cart_service.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/society_repository.dart';
import '../../repositories/shop_repository.dart';
import '../../models/product_model.dart';
import '../../models/shop_model.dart';
import '../orders/order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

ShopModel? _shop;

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CartService cartService = CartService.instance;
  final OrderRepository orderRepository = OrderRepository();
  final ProductRepository productRepository = ProductRepository();
  final UserRepository userRepository = UserRepository();
  final SocietyRepository societyRepository = SocietyRepository();
  final ShopRepository shopRepository = ShopRepository();

  static const Color mqOrange = Color(0xFFFF6A00);

  String _deliveryAddress = '';
  bool _addressLoading = true;
  bool _loading = false;

  String _deliveryLabel = '';
  bool _deliveryLoading = true;

  String _paymentMethod = 'cod';

  @override
  void initState() {
    super.initState();
    _loadDeliveryAddress();
    _loadDeliveryTime();
  }

  Future<void> _loadDeliveryAddress() async {
    try {
      final buyerId = FirebaseAuth.instance.currentUser!.uid;
      final user = await userRepository.getUser(buyerId);

      if (user.flatNumber.isEmpty || user.societyId.isEmpty) {
        throw Exception('Delivery address incomplete');
      }

      final societyName =
          await societyRepository.getSocietyName(user.societyId);

      setState(() {
        _deliveryAddress = 'Flat ${user.flatNumber}, $societyName';
        _addressLoading = false;
      });
    } catch (_) {
      setState(() {
        _deliveryAddress = '';
        _addressLoading = false;
      });
    }
  }

  Future<void> _loadDeliveryTime() async {
    try {
      if (cartService.items.isEmpty) {
        setState(() => _deliveryLoading = false);
        return;
      }

      final firstItem = cartService.items.first;
      final shop =
          await shopRepository.getMyShop(firstItem.sellerId);

      if (shop == null) {
        throw Exception('Shop not found');
      }

      setState(() {
        _shop = shop;
        _deliveryLabel =
            '${shop.deliveryMinValue}–${shop.deliveryMaxValue} ${shop.deliveryUnit}';
        _deliveryLoading = false;
      });
    } catch (_) {
      setState(() {
        _deliveryLabel = '';
        _deliveryLoading = false;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (cartService.isEmpty || _loading) return;

    if (_shop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop information not loaded')),
      );
      return;
    }

    if (_deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery address not available')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final buyerId = FirebaseAuth.instance.currentUser!.uid;
      final user = await userRepository.getUser(buyerId);

      final firstItem = cartService.items.first;
      final sellerId = firstItem.sellerId;

      final stockItems = cartService.items.map((item) {
        return {
          'productId': item.productId,
          'quantity': item.quantity,
        };
      }).toList();

      await ProductRepository().reduceStockAfterOrder(stockItems);

      await orderRepository.placeOrder(
        buyerId: buyerId,
        sellerId: sellerId,
        societyId: user.societyId,
        flatNumber: user.flatNumber,
        societyName: _deliveryAddress.replaceFirst(
          'Flat ${user.flatNumber}, ',
          '',
        ),
        shopName: _shop!.shopName,
        items: cartService.items.map((item) {
          return {
            'productId': item.productId,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
          };
        }).toList(),
        totalAmount: cartService.totalAmount,
        paymentMethod: _paymentMethod,
        paymentStatus: 'pending',
      );

      cartService.clearCart();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OrderSuccessScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Checkout',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📦 DELIVERY ADDRESS
            if (_addressLoading)
              const Center(child: CircularProgressIndicator())
            else if (_deliveryAddress.isEmpty)
              const Text(
                'Delivery address not found. Please update your profile.',
                style: TextStyle(color: Colors.red),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Address',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(_deliveryAddress),
                  ],
                ),
              ),

            // 🚚 DELIVERY TIME
            if (_deliveryLoading)
              const CircularProgressIndicator()
            else if (_deliveryLabel.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 24),
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
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping,
                        color: mqOrange),
                    const SizedBox(width: 8),
                    Text(
                      'Delivery in $_deliveryLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // 💳 PAYMENT METHOD
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            RadioListTile<String>(
              value: 'cod',
              groupValue: _paymentMethod,
              activeColor: mqOrange,
              onChanged: (_) {
                setState(() {
                  _paymentMethod = 'cod';
                });
              },
              title: const Text('Cash on Delivery'),
              subtitle: const Text('Pay when order is delivered'),
            ),

            RadioListTile<String>(
              value: 'upi',
              groupValue: _paymentMethod,
              onChanged: null,
              title: const Text('UPI / Online Payment'),
              subtitle: const Text('Coming Soon'),
            ),

            const SizedBox(height: 24),

            Text(
              'Total Amount: ₹${cartService.totalAmount}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            /// ✅ ONLY FIX: SAFE AREA WRAP
            SafeArea(
              top: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mqOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _placeOrder,
                        child: const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
