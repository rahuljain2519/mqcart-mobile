import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../repositories/shop_repository.dart';
import '../../repositories/user_repository.dart';
import '../../models/shop_model.dart';

class SellerOnboardingScreen extends StatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  State<SellerOnboardingScreen> createState() =>
      _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends State<SellerOnboardingScreen> {
  final TextEditingController _shopNameController =
      TextEditingController();

  final ShopRepository _shopRepository = ShopRepository();
  final UserRepository _userRepository = UserRepository();
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;

  // ----------------------------
  // DELIVERY CONFIG STATE
  // ----------------------------
  String _deliveryUnit = 'days'; // minutes | hours | days
  final TextEditingController _deliveryMinController =
      TextEditingController(text: '2');
  final TextEditingController _deliveryMaxController =
      TextEditingController(text: '3');

  int _toMinutes(int value, String unit) {
    switch (unit) {
      case 'minutes':
        return value;
      case 'hours':
        return value * 60;
      case 'days':
        return value * 1440;
      default:
        return value;
    }
  }

  // ----------------------------
  // LOGO STATE
  // ----------------------------
  File? _logoFile;
  double _logoProgress = 0;
  String _logoUrl = '';

  // ----------------------------
  // BANNER STATE
  // ----------------------------
  File? _bannerFile;
  double _bannerProgress = 0;
  String _bannerUrl = '';

  // ----------------------------
  // IMAGE PICKERS
  // ----------------------------

  Future<void> _pickLogo() async {
    final XFile? picked =
        await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 82,
        );

    if (picked != null) {
      setState(() {
        _logoFile = File(picked.path);
        _logoProgress = 0;
        _logoUrl = '';
      });
    }
  }

  Future<void> _pickBanner() async {
    final XFile? picked =
        await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 82,
        );

    if (picked != null) {
      setState(() {
        _bannerFile = File(picked.path);
        _bannerProgress = 0;
        _bannerUrl = '';
      });
    }
  }

  // ----------------------------
  // DELETE (UI ONLY)
  // ----------------------------

  void _deleteLogo() {
    setState(() {
      _logoFile = null;
      _logoProgress = 0;
      _logoUrl = '';
    });
  }

  void _deleteBanner() {
    setState(() {
      _bannerFile = null;
      _bannerProgress = 0;
      _bannerUrl = '';
    });
  }

  // ----------------------------
  // CREATE SHOP FLOW (FINAL FIX)
  // ----------------------------

  Future<void> _createShop() async {
    if (_shopNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name is required')),
      );
      return;
    }

    final int? minVal =
        int.tryParse(_deliveryMinController.text);
    final int? maxVal =
        int.tryParse(_deliveryMaxController.text);

    if (minVal == null ||
        maxVal == null ||
        minVal <= 0 ||
        maxVal < minVal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid delivery time')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final String uid =
          FirebaseAuth.instance.currentUser!.uid;

      final user = await _userRepository.getUser(uid);

      // ✅ FINAL & CORRECT SAFETY CHECK
      if (user.role != 'seller' || user.sellerStatus != 'approved') {
        throw Exception('Seller not approved');
      }

      // 1️⃣ Create shop
      final String shopId = await _shopRepository.createShop(
        sellerId: uid,
        societyId: user.societyId,
        shopName: _shopNameController.text.trim(),
      );

      // 2️⃣ Upload logo
      if (_logoFile != null) {
        _logoUrl = await _shopRepository.uploadShopImage(
          shopId: shopId,
          file: _logoFile!,
          type: 'logo',
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _logoProgress = p);
          },
        );
      }

      // 3️⃣ Upload banner
      if (_bannerFile != null) {
        _bannerUrl = await _shopRepository.uploadShopImage(
          shopId: shopId,
          file: _bannerFile!,
          type: 'banner',
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _bannerProgress = p);
          },
        );
      }

      // 4️⃣ Update shop with images + delivery config
      final ShopModel updatedShop = ShopModel(
        shopId: shopId,
        sellerId: uid,
        societyId: user.societyId,
        shopName: _shopNameController.text.trim(),
        description: '',
        logoUrl: _logoUrl,
        bannerUrl: _bannerUrl,
        address: '',
        phone: '',
        isActive: false,
        isVerified: false,

        // 🆕 DELIVERY CONFIG
        deliveryUnit: _deliveryUnit,
        deliveryMinValue: minVal,
        deliveryMaxValue: maxVal,
        deliveryMinMinutes: _toMinutes(minVal, _deliveryUnit),
        deliveryMaxMinutes: _toMinutes(maxVal, _deliveryUnit),
      );

      await _shopRepository.updateShop(updatedShop);

      // 5️⃣ Link shop to user
      await _userRepository.updateUserFields(uid, {
        'shopId': shopId,
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ----------------------------
  // UI
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Shop'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _shopNameController,
              decoration:
                  const InputDecoration(labelText: 'Shop Name'),
            ),

            const SizedBox(height: 24),

            const Text(
              'Delivery Time',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _deliveryUnit,
              decoration:
                  const InputDecoration(labelText: 'Delivery Unit'),
              items: const [
                DropdownMenuItem(
                    value: 'minutes', child: Text('Minutes')),
                DropdownMenuItem(
                    value: 'hours', child: Text('Hours')),
                DropdownMenuItem(
                    value: 'days', child: Text('Days')),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() => _deliveryUnit = val);
              },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _deliveryMinController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Minimum'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _deliveryMaxController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Maximum'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text('Shop Logo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (_logoFile != null)
              Stack(
                children: [
                  Image.file(_logoFile!, height: 100),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _deleteLogo,
                    ),
                  ),
                ],
              )
            else
              OutlinedButton(
                onPressed: _pickLogo,
                child: const Text('Upload Logo'),
              ),

            if (_logoProgress > 0 && _logoProgress < 1)
              LinearProgressIndicator(value: _logoProgress),

            const SizedBox(height: 24),

            const Text('Shop Banner',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (_bannerFile != null)
              Stack(
                children: [
                  Image.file(
                    _bannerFile!,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _deleteBanner,
                    ),
                  ),
                ],
              )
            else
              OutlinedButton(
                onPressed: _pickBanner,
                child: const Text('Upload Banner'),
              ),

            if (_bannerProgress > 0 && _bannerProgress < 1)
              LinearProgressIndicator(value: _bannerProgress),

            const SizedBox(height: 32),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createShop,
                      child: const Text('Create Shop'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}