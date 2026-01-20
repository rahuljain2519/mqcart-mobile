import 'package:flutter/material.dart'; // 🆕 REQUIRED for ValueNotifier

import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import 'cart_storage_service.dart';

class CartService {
  CartService._internal();
  static final CartService instance = CartService._internal();

  /// Key = product.id
  final Map<String, CartItemModel> _items = {};

  /// 🔔 GLOBAL CART COUNT NOTIFIER (USED FOR BADGE)
  final ValueNotifier<int> cartItemCount = ValueNotifier<int>(0);

  /// 🔔 GLOBAL CART CHANGE NOTIFIER (USED FOR UI REFRESH)
  final ValueNotifier<int> cartRevision = ValueNotifier<int>(0);

  /// ------------------------
  /// READ OPERATIONS
  /// ------------------------

  List<CartItemModel> get items => _items.values.toList();

  bool get isEmpty => _items.isEmpty;

  int get totalItems =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0, (sum, item) => sum + item.totalPrice);

  bool contains(String productId) => _items.containsKey(productId);

  /// 🔒 CURRENT CART SELLER (DERIVED)
  String? get cartSellerId {
    if (_items.isEmpty) return null;
    return _items.values.first.sellerId;
  }

  /// ------------------------
  /// WRITE OPERATIONS
  /// ------------------------

  void addProduct(ProductModel product) {
    final existingSellerId = cartSellerId;

    // 🔒 SINGLE SELLER ENFORCEMENT
    if (existingSellerId != null &&
        existingSellerId != product.sellerId) {
      throw Exception('MULTI_SELLER_CART_NOT_ALLOWED');
    }

    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += 1;
    } else {
      _items[product.id] = CartItemModel(
        productId: product.id,
        name: product.name,
        price: product.price,
        imageUrl: product.coverImage,
        sellerId: product.sellerId,
      );
    }
    _persist();
    _notify(); // 🆕
  }

  void increaseQuantity(String productId) {
    if (_items.containsKey(productId)) {
      _items[productId]!.quantity += 1;
      _persist();
      _notify(); // 🆕
    }
  }

  void decreaseQuantity(String productId) {
    if (!_items.containsKey(productId)) return;

    final item = _items[productId]!;

    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _items.remove(productId);
    }
    _persist();
    _notify(); // 🆕
  }

  void removeProduct(String productId) {
    _items.remove(productId);
    _persist();
    _notify(); // 🆕
  }

  void clearCart() {
    _items.clear();
    _persist();
    _notify(); // 🆕
  }

  /// ------------------------
  /// PERSISTENCE
  /// ------------------------

  void loadFromStorage(Map<String, dynamic> json) {
    _items.clear();

    json.forEach((key, value) {
      _items[key] = CartItemModel.fromJson(
        Map<String, dynamic>.from(value),
      );
    });

    _notify(); // 🆕 ENSURE BADGE SYNC ON APP START
  }

  Map<String, dynamic> toJson() {
    return _items.map((key, item) {
      return MapEntry(key, item.toJson());
    });
  }

  void _persist() {
    CartStorageService.saveCart(toJson());
  }

  /// 🔔 NOTIFY ALL LISTENERS (BADGE, UI)
  void _notify() {
    final count = totalItems;

    // 🔔 Force rebuild even when count stays the same (e.g. 0 → 0)
    if (cartItemCount.value == count) {
      cartItemCount.value = -1; // temporary dummy value
    }

    cartItemCount.value = count;
    cartRevision.value++;
  }

  /// ------------------------
  /// CHECKOUT PAYLOAD
  /// ------------------------

  Map<String, dynamic> buildCheckoutPayload({
    required String buyerId,
    required String societyId,
  }) {
    if (_items.isEmpty) {
      throw Exception('Cart is empty');
    }

    // Single-seller checkout (current app logic)
    final sellerId = _items.values.first.sellerId;

    return {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'societyId': societyId,
      'items': _items.values.map((item) {
        return {
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'sellerId': item.sellerId,
        };
      }).toList(),
      'totalAmount': totalAmount,
      'status': 'placed',
      'createdAt': DateTime.now(),
    };
  }
}
