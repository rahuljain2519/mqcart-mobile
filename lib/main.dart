import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';

// 🛒 CART IMPORTS
import 'services/cart_service.dart';
import 'services/cart_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

   // 🛒 Load cart from local storage (ONCE)
  final cartJson = await CartStorageService.loadCart();
  CartService.instance.loadFromStorage(cartJson);

  
  runApp(const MarketplaceApp());
}
