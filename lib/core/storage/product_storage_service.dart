import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ProductStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --------------------------------------------------
  // 🔙 LEGACY: Single image upload (DO NOT BREAK)
  // --------------------------------------------------
  Future<String> uploadProductImage({
    required File file,
    required String shopId,
    required String productId,
  }) async {
    final ref = _storage
        .ref()
        .child('products')
        .child(shopId)
        .child('$productId.jpg');

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // --------------------------------------------------
  // 🆕 NEW: Upload with progress (MULTI-IMAGE)
  // --------------------------------------------------
  UploadTask uploadProductImageWithProgress({
    required File file,
    required String shopId,
    required String productId,
    required int index,
  }) {
    final ref = _storage
        .ref()
        .child('products')
        .child(shopId)
        .child(productId)
        .child('image_$index.jpg');

    return ref.putFile(file);
  }

  // --------------------------------------------------
  // 🆕 OPTIONAL: Delete single image (edit product)
  // --------------------------------------------------
  Future<void> deleteProductImage({
    required String shopId,
    required String productId,
    required int index,
  }) async {
    final ref = _storage
        .ref()
        .child('products')
        .child(shopId)
        .child(productId)
        .child('image_$index.jpg');

    await ref.delete();
  }

  // --------------------------------------------------
  // 🆕 OPTIONAL: Delete all images (product delete)
  // --------------------------------------------------
  Future<void> deleteAllProductImages({
    required String shopId,
    required String productId,
  }) async {
    final dirRef = _storage
        .ref()
        .child('products')
        .child(shopId)
        .child(productId);

    final listResult = await dirRef.listAll();
    for (final item in listResult.items) {
      await item.delete();
    }
  }
}
