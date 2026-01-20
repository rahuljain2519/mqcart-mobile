import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ShopStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload shop logo
  /// Path: /shops/{shopId}/logo.jpg
  Future<String> uploadShopLogo({
    required String shopId,
    required File file,
  }) async {
    final ref = _storage.ref().child('shops/$shopId/logo.jpg');

    await ref.putFile(file);

    return await ref.getDownloadURL();
  }

  /// Upload shop banner
  /// Path: /shops/{shopId}/banner.jpg
  Future<String> uploadShopBanner({
    required String shopId,
    required File file,
  }) async {
    final ref = _storage.ref().child('shops/$shopId/banner.jpg');

    await ref.putFile(file);

    return await ref.getDownloadURL();
  }
}
