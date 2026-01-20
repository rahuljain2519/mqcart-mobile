import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/product_model.dart';
import '../../../core/storage/product_storage_service.dart';
import 'bulk_product_row.dart';

class BulkUploadService {
  final ProductStorageService _storageService =
      ProductStorageService();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // -----------------------
  // DELIVERY UNIT → MINUTES
  // -----------------------
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

  Future<void> uploadProducts({
    required String shopId,
    required String societyId,
    required List<BulkProductRow> rows,
    required Map<String, List<File>> imageFiles,
    required Function(double progress) onProgress,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final batch = _firestore.batch();
    int completed = 0;
    final total = rows.length;

    for (final row in rows) {
      final productId =
          DateTime.now().millisecondsSinceEpoch.toString();

      // -----------------------
      // UPLOAD IMAGES
      // -----------------------
      final List<String> imageUrls = [];

      final images = imageFiles[row.imagePrefix];

      if (images == null || images.isEmpty) {
        throw Exception(
          'No images found for product "${row.name}" '
          '(prefix: ${row.imagePrefix})',
        );
      }

      for (int i = 0; i < images.length; i++) {
        final snapshot =
            await _storageService.uploadProductImageWithProgress(
          file: images[i],
          shopId: shopId,
          productId: productId,
          index: i,
        );

        final url = await snapshot.ref.getDownloadURL();
        imageUrls.add(url);
      }

      // -----------------------
      // DELIVERY OVERRIDE CHECK
      // -----------------------
      final bool hasDeliveryOverride =
          row.deliveryUnit != null &&
          row.deliveryMin != null &&
          row.deliveryMax != null;

      // -----------------------
      // CREATE PRODUCT MODEL
      // -----------------------
      final coverImage = imageUrls[
          row.coverIndex.clamp(0, imageUrls.length - 1)
        ];
      final product = ProductModel(
        id: productId,
        shopId: shopId,
        sellerId: uid,
        societyId: societyId,
        name: row.name,
        price: row.price,
        quantity: row.quantity,
        category: row.category,
        description: row.description,
        images: imageUrls,
        coverImage: coverImage,
        isActive: row.isActive,

        // 🔥 SAME AS NORMAL PRODUCT UPLOAD
        deliveryUnit: hasDeliveryOverride
            ? row.deliveryUnit
            : null,
        deliveryMinValue: hasDeliveryOverride
            ? row.deliveryMin
            : null,
        deliveryMaxValue: hasDeliveryOverride
            ? row.deliveryMax
            : null,
        deliveryMinMinutes: hasDeliveryOverride
            ? _toMinutes(
                row.deliveryMin!, row.deliveryUnit!)
            : null,
        deliveryMaxMinutes: hasDeliveryOverride
            ? _toMinutes(
                row.deliveryMax!, row.deliveryUnit!)
            : null,
      );

      // -----------------------
      // BATCH SAVE
      // -----------------------
      final ref =
          _firestore.collection('products').doc(productId);
      batch.set(ref, product.toJson());

      completed++;
      onProgress(completed / total);
    }

    await batch.commit();
  }
}
