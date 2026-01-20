import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/shop_model.dart';
import '../../repositories/shop_repository.dart';

class EditShopScreen extends StatefulWidget {
  final ShopModel shop;

  const EditShopScreen({super.key, required this.shop});

  @override
  State<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  final ShopRepository _repo = ShopRepository();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;

  // ----------------------------
  // DELIVERY STATE
  // ----------------------------
  late String _deliveryUnit;
  late TextEditingController _deliveryMinCtrl;
  late TextEditingController _deliveryMaxCtrl;

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

  // ----------------------------
  // BANNER STATE
  // ----------------------------
  File? _bannerFile;
  double _bannerProgress = 0;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(text: widget.shop.shopName);
    _descCtrl = TextEditingController(text: widget.shop.description);

    // DELIVERY INIT
    _deliveryUnit = widget.shop.deliveryUnit;
    _deliveryMinCtrl =
        TextEditingController(text: widget.shop.deliveryMinValue.toString());
    _deliveryMaxCtrl =
        TextEditingController(text: widget.shop.deliveryMaxValue.toString());
  }

  // ----------------------------
  // PICK IMAGE
  // ----------------------------

  Future<void> _pickLogo() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    setState(() {
      _logoFile = File(img.path);
      _logoProgress = 0;
    });
  }

  Future<void> _pickBanner() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    setState(() {
      _bannerFile = File(img.path);
      _bannerProgress = 0;
    });
  }

  // ----------------------------
  // SAVE
  // ----------------------------

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final int? minVal = int.tryParse(_deliveryMinCtrl.text);
      final int? maxVal = int.tryParse(_deliveryMaxCtrl.text);

      if (minVal == null ||
          maxVal == null ||
          minVal <= 0 ||
          maxVal < minVal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid delivery time')),
        );
        setState(() => _saving = false);
        return;
      }

      String logoUrl = widget.shop.logoUrl;
      String bannerUrl = widget.shop.bannerUrl;

      if (_logoFile != null) {
        logoUrl = await _repo.uploadShopImage(
          shopId: widget.shop.shopId,
          file: _logoFile!,
          type: 'logo',
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _logoProgress = p);
          },
        );
      }

      if (_bannerFile != null) {
        bannerUrl = await _repo.uploadShopImage(
          shopId: widget.shop.shopId,
          file: _bannerFile!,
          type: 'banner',
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _bannerProgress = p);
          },
        );
      }

      final updatedShop = ShopModel(
        shopId: widget.shop.shopId,
        sellerId: widget.shop.sellerId,
        societyId: widget.shop.societyId,
        shopName: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
        address: widget.shop.address,
        phone: widget.shop.phone,
        isActive: widget.shop.isActive,
        isVerified: widget.shop.isVerified,

        // DELIVERY UPDATE
        deliveryUnit: _deliveryUnit,
        deliveryMinValue: minVal,
        deliveryMaxValue: maxVal,
        deliveryMinMinutes: _toMinutes(minVal, _deliveryUnit),
        deliveryMaxMinutes: _toMinutes(maxVal, _deliveryUnit),
      );

      await _repo.updateShop(updatedShop);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ----------------------------
  // UI
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Shop')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Shop Name'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
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
                DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                DropdownMenuItem(value: 'hours', child: Text('Hours')),
                DropdownMenuItem(value: 'days', child: Text('Days')),
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
                    controller: _deliveryMinCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Minimum'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _deliveryMaxCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Maximum'),
                  ),
                ),
              ],
            ),

            TextButton.icon(
              onPressed: () {
                Share.share(
                  'Delivery time: ${_deliveryMinCtrl.text}-${_deliveryMaxCtrl.text} $_deliveryUnit',
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share Delivery Time'),
            ),

            const SizedBox(height: 24),

            const Text('Shop Logo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (_logoFile != null)
              Image.file(_logoFile!, height: 100)
            else if (widget.shop.logoUrl.isNotEmpty)
              Image.network(widget.shop.logoUrl, height: 100),

            TextButton(
              onPressed: _pickLogo,
              child: const Text('Change Logo'),
            ),

            if (_logoProgress > 0 && _logoProgress < 1)
              LinearProgressIndicator(value: _logoProgress),

            const SizedBox(height: 24),

            const Text('Shop Banner',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (_bannerFile != null)
              Image.file(
                _bannerFile!,
                height: 140,
                fit: BoxFit.cover,
              )
            else if (widget.shop.bannerUrl.isNotEmpty)
              Image.network(
                widget.shop.bannerUrl,
                height: 140,
                fit: BoxFit.cover,
              ),

            TextButton(
              onPressed: _pickBanner,
              child: const Text('Change Banner'),
            ),

            if (_bannerProgress > 0 && _bannerProgress < 1)
              LinearProgressIndicator(value: _bannerProgress),

            const SizedBox(height: 32),

            _saving
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save Changes'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
