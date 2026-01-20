import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/payment_service.dart';
import '../../repositories/shop_repository.dart';
import '../../models/shop_model.dart';

class ActivateShopScreen extends StatefulWidget {
  final ShopModel shop;

  const ActivateShopScreen({
    super.key,
    required this.shop,
  });

  @override
  State<ActivateShopScreen> createState() => _ActivateShopScreenState();
}

class _ActivateShopScreenState extends State<ActivateShopScreen> {
  String? _selectedPlan;
  Map<String, dynamic>? _plans;
  bool _processing = false;
  bool _waitingForConfirmation = false;
  bool _freePlanUsed = false;

  /// 🔒 Prevent duplicate enforcement
  bool _limitEnforced = false;

  final PaymentService _paymentService = PaymentService();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _shopStream;

  static const Color mqOrange = Color(0xFFFF6A00);

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadFreePlanStatus();
    _paymentService.init();

    _shopStream = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shop.shopId)
        .snapshots();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    final doc = await FirebaseFirestore.instance
        .collection('platform_config')
        .doc('seller_plans')
        .get();

    if (!doc.exists) {
      throw Exception('Seller plans config missing');
    }

    setState(() {
      _plans = doc.data();
      _selectedPlan = widget.shop.plan;
    });
  }

  Future<void> _loadFreePlanStatus() async {
    final sellerId = FirebaseAuth.instance.currentUser!.uid;

    final snap = await FirebaseFirestore.instance
        .collection('seller_subscriptions')
        .doc(sellerId)
        .get();

    if (snap.exists) {
      setState(() {
        _freePlanUsed = snap.data()?['freePlanUsed'] == true;
      });
    }
  }

  void _showFreePlanBlockedPopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Free Plan Not Available'),
        content: const Text(
          'You have already used the free plan once. '
          'Please choose a paid plan to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _shopStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final shopData = snapshot.data!.data()!;
        final currentPlan = shopData['plan'];
        final planStatus = shopData['planStatus'];

        /// ✅ AUTO-NAVIGATION (RESTORED — SIMPLE & RELIABLE)
        if (_waitingForConfirmation && planStatus == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pop(context, {'activated': true});
          });
        }

        /// 🔒 ENFORCE PRODUCT LIMIT (BACKGROUND, ONCE)
        if (_waitingForConfirmation &&
            planStatus == 'active' &&
            !_limitEnforced) {
          _limitEnforced = true;

          final int productLimit = shopData['productLimit'];

          // Fire-and-forget — DO NOT block UI
          ShopRepository().activateShop(
            shopId: widget.shop.shopId,
            plan: shopData['plan'],
            productLimit: productLimit,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Activate / Upgrade Shop'),
          ),
          body: _plans == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose your seller plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_plans!.containsKey('free')) ...[
                        _planCard('free', currentPlan),
                        const SizedBox(height: 12),
                      ],

                      _planCard('basic', currentPlan),
                      const SizedBox(height: 12),

                      _planCard('pro', currentPlan),
                      const SizedBox(height: 12),

                      _planCard('elite', currentPlan),

                      const Spacer(),

                      if (_waitingForConfirmation)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Payment received. Activating your plan…',
                            style: TextStyle(color: Colors.green),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mqOrange,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _selectedPlan == null ||
                                  _processing ||
                                  _waitingForConfirmation
                              ? null
                              : _onProceed,
                          child: _processing
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _planCard(String planKey, String currentPlan) {
    final plan = _plans![planKey];
    final bool isSelected = _selectedPlan == planKey;
    final bool isCurrent = currentPlan == planKey;

    return InkWell(
      onTap: () {
        if (_waitingForConfirmation) return;
       if (planKey == 'free' && _freePlanUsed) {
          setState(() {
            _selectedPlan = null; // ✅ CLEAR SELECTION
          });
          _showFreePlanBlockedPopup();
          return;
        }
        setState(() {
          _selectedPlan = planKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? mqOrange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? mqOrange.withOpacity(0.05) : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCurrent)
                  const Text(
                    'Current',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              plan['monthlyFee'] == 0
                  ? 'Free'
                  : '₹${plan['monthlyFee']} / month',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload up to ${plan['productLimit']} products',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // PROCEED
  // ---------------------------
  Future<void> _onProceed() async {
    final selectedPlanData = _plans![_selectedPlan];
    final int monthlyFee = selectedPlanData['monthlyFee'];
    final int productLimit = selectedPlanData['productLimit'];
    final sellerId = FirebaseAuth.instance.currentUser!.uid;
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _processing = true;
    });

    try {
      // 🆓 FREE PLAN → ACTIVATE DIRECTLY
      if (monthlyFee == 0) {
        final firestore = FirebaseFirestore.instance;

        // 🔹 Read free plan validity from config
        final freePlanData = _plans!['free'];
        final int? validityDays = freePlanData['validityDays'];

        // 🔹 Calculate expiry (null = lifetime free)
        final Timestamp? expiresAt = validityDays == null
            ? null
            : Timestamp.fromDate(
                DateTime.now().add(Duration(days: validityDays)),
              );

        // 1️⃣ Create / update seller subscription
        await firestore
            .collection('seller_subscriptions')
            .doc(sellerId)
            .set({
          'sellerId': sellerId,
          'shopId': widget.shop.shopId,

          'currentPlan': 'free',
          'status': 'active',

          'productLimit': productLimit,

          'startedAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt, // ✅ NOW CONFIGURABLE

          'autoRenew': false,
          'freePlanUsed': true,
          'lastPaymentId': null,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2️⃣ Update shop (existing behavior — unchanged)
        await ShopRepository().activateShop(
          shopId: widget.shop.shopId,
          plan: 'free',
          productLimit: productLimit,
        );

        if (mounted) {
          Navigator.pop(context, {'activated': true});
        }
        return;
    }



      // 💳 PAID PLAN → START RAZORPAY PAYMENT
      await _paymentService.startSellerActivationPayment(
        sellerId: sellerId,
        shopId: widget.shop.shopId,
        plan: _selectedPlan!,
        monthlyFee: monthlyFee,
        productLimit: productLimit,
        sellerPhone: user?.phoneNumber ?? '',
        sellerEmail: user?.email ?? '',
      );

      setState(() {
        _waitingForConfirmation = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }
}
