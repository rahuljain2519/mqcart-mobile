import 'dart:io';

import '../data/datasources/shop_remote_ds.dart';
import '../models/shop_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopRepository {
  final ShopRemoteDS _remoteDS = ShopRemoteDS();

  /// ---------------------------------
  /// SELLER: GET OWN SHOP
  /// ---------------------------------
  /// One seller → one shop
  Future<ShopModel?> getMyShop(String sellerId) {
    return _remoteDS.getShopBySeller(sellerId);
  }

  /// ---------------------------------
  /// SELLER: CREATE SHOP
  /// ---------------------------------
  /// ✅ RETURNS shopId (required for onboarding)
  Future<String> createShop({
    required String sellerId,
    required String societyId,
    required String shopName,
  }) async {
    final shop = ShopModel(
      shopId: '', // Firestore will generate ID
      sellerId: sellerId,
      societyId: societyId,
      shopName: shopName,

      // safe defaults
      description: '',
      logoUrl: '',
      bannerUrl: '',
      address: '',
      phone: '',

      isActive: true,
      isVerified: false,
    );

    final String shopId = await _remoteDS.createShop(shop);

    if (shopId.isEmpty) {
      throw Exception('Failed to create shop. shopId is empty.');
    }

    return shopId;
  }

  /// ---------------------------------
  /// SELLER / ADMIN: UPDATE SHOP
  /// ---------------------------------
  /// Used for updating name, description, logoUrl, bannerUrl, etc.
  Future<void> updateShop(ShopModel shop) {
    return _remoteDS.updateShop(shop);
  }

  /// ---------------------------------
  /// SELLER: UPLOAD SHOP IMAGE
  /// ---------------------------------
  /// type = 'logo' | 'banner'
  /// Emits upload progress (0 → 1)
  Future<String> uploadShopImage({
    required String shopId,
    required File file,
    required String type,
    required void Function(double progress) onProgress,
  }) {
    return _remoteDS.uploadShopImage(
      shopId: shopId,
      file: file,
      type: type,
      onProgress: onProgress,
    );
  }

  /// ---------------------------------
  /// BUYER: GET SHOPS FOR SOCIETY
  /// ---------------------------------
  Future<List<ShopModel>> getShopsForSociety(String societyId) {
    return _remoteDS.getShopsForSociety(societyId);
  }

  /// 🔄 Live stream of active shops for a society (auto-refresh)
  Stream<List<ShopModel>> streamShopsForSociety(String societyId) {
    return _remoteDS.streamShopsForSociety(societyId);
  }

  /// ---------------------------------
  /// BUYER: GET SHOP BY ID
  /// ---------------------------------
  Future<ShopModel?> getShopById(String shopId) {
    return _remoteDS.getShopById(shopId);
  }

  /// ---------------------------------
  /// ADMIN: ACTIVATE / UPGRADE / DOWNGRADE SHOP
  /// 🔒 PLAN IS THE SOURCE OF TRUTH
  /// 🔒 ENFORCES PRODUCT LIMIT
  /// ---------------------------------
  Future<void> activateShop({
    required String shopId,
    required String plan,
    required int productLimit,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final shopRef = firestore.collection('shops').doc(shopId);

    // 1️⃣ Update shop plan & limit
    batch.update(shopRef, {
      'isActive': true,
      'activationStatus': 'active',
      'plan': plan,
      'productLimit': productLimit,
    });

    // 2️⃣ Fetch ACTIVE products ordered by creation
    final productsSnap = await firestore
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt')
        .get();

    // Firestore batch safety
    if (productsSnap.docs.length > 450) {
      throw Exception(
          'Too many products to enforce limit in a single batch.');
    }

    // 3️⃣ Disable extra products beyond plan limit
    for (int i = 0; i < productsSnap.docs.length; i++) {
      if (i >= productLimit) {
        batch.update(productsSnap.docs[i].reference, {
          'isActive': false,
        });
      }
    }

    await batch.commit();
  }

  /// ---------------------------------
  /// ADMIN: TOGGLE SHOP + CASCADE PRODUCTS
  /// ---------------------------------
  Future<void> toggleShopWithProducts({
    required String shopId,
    required bool makeActive,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final shopRef = firestore.collection('shops').doc(shopId);

    // 1️⃣ Update shop
    batch.update(shopRef, {
      'isActive': makeActive,
      'status': makeActive ? 'ACTIVE' : 'INACTIVE',
    });

    // 2️⃣ Fetch products
    final productsSnap = await firestore
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .get();

    if (productsSnap.docs.length > 450) {
      throw Exception(
          'Too many products to update in a single batch.');
    }

    // 3️⃣ Cascade product visibility
    for (final doc in productsSnap.docs) {
      batch.update(doc.reference, {
        'isActive': makeActive,
      });
    }

    await batch.commit();
  }
}
