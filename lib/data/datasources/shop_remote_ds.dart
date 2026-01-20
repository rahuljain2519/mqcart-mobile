import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

import '../../services/firestore_service.dart';
import '../../models/shop_model.dart';

class ShopRemoteDS {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get shop by sellerId (one seller = one shop)
  Future<ShopModel?> getShopBySeller(String sellerId) async {
    final query = await _firestore
        .shops()
        .where('sellerId', isEqualTo: sellerId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return ShopModel.fromJson(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// Create shop (IDEMPOTENT & SAFE — NO DUPLICATES)
  /// SHOP IS ALWAYS CREATED INACTIVE
  Future<String> createShop(ShopModel shop) async {
    // 🔒 FIX-1: HARD GUARD — CHECK IF SHOP ALREADY EXISTS
    final existing = await _firestore
        .shops()
        .where('sellerId', isEqualTo: shop.sellerId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // shop already exists → reuse it
      return existing.docs.first.id;
    }

    final data = shop.toJson();

    /// 🔒 FORCE SAFE DEFAULTS (UNCHANGED LOGIC)
    data.addAll({
      'isActive': false,                 // activation controlled by payment
      'activationStatus': 'pending',     // pending | active
      'plan': data['plan'] ?? 'free',    // default plan
      'productLimit': data['productLimit'] ?? 10,
      'productCount': data['productCount'] ?? 0,
      'transactionFeePercent': data['transactionFeePercent'] ?? 0,
    });

    final docRef = await _firestore.shops().add(data);
    return docRef.id;
  }

  /// Update shop (NO CHANGE)
  Future<void> updateShop(ShopModel shop) async {
    await _firestore.shops().doc(shop.shopId).update(shop.toJson());
  }

  /// Buyer: get all ACTIVE shops for a society
  Future<List<ShopModel>> getShopsForSociety(String societyId) async {
    final query = await _firestore
        .shops()
        .where('societyId', isEqualTo: societyId)
        .where('isActive', isEqualTo: true)
        .get();

    return query.docs
        .map(
          (doc) => ShopModel.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  /// Get shop by shopId (Buyer flow)
  Future<ShopModel?> getShopById(String shopId) async {
    final doc = await _firestore.shops().doc(shopId).get();

    if (!doc.exists) return null;

    return ShopModel.fromJson(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// Upload shop image (logo / banner)
  Future<String> uploadShopImage({
    required String shopId,
    required File file,
    required String type, // 'logo' or 'banner'
    required void Function(double progress) onProgress,
  }) async {
    final ref = _storage.ref('shops/$shopId/$type.jpg');

    final uploadTask = ref.putFile(file);

    uploadTask.snapshotEvents.listen((snapshot) {
      final progress =
          snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress(progress);
    });

    final snap = await uploadTask;
    return await snap.ref.getDownloadURL();
  }
}
