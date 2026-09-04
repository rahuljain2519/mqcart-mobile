import 'package:flutter/material.dart'; // 🆕 REQUIRED for ValueNotifier

import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import 'cart_storage_service.dart';

enum AddProductResult {
  success,
  multiSellerNotAllowed,
}

class CartService {
  CartService._internal();
  static final CartService instance = CartService._internal();

  /// Key = cart-line key (productId, plus "|option" when a variant option is chosen)
  final Map<String, CartItemModel> _items = {};

  /// 🔔 GLOBAL CART COUNT NOTIFIER (USED FOR BADGE)
  final ValueNotifier<int> cartItemCount = ValueNotifier<int>(0);

  /// 🔔 GLOBAL CART CHANGE NOTIFIER (USED FOR UI REFRESH)
  final ValueNotifier<int> cartRevision = ValueNotifier<int>(0);

  static String keyFor(String productId, [String? optionName]) =>
      optionName == null ? productId : '$productId|$optionName';

  /// ------------------------
  /// READ OPERATIONS
  /// ------------------------

  List<CartItemModel> get items => _items.values.toList();

  bool get isEmpty => _items.isEmpty;

  int get totalItems =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0, (sum, item) => sum + item.totalPrice);

  /// True if this product (any option, or a specific option) is in the cart.
  bool contains(String productId, {String? optionName}) {
    if (optionName != null) return _items.containsKey(keyFor(productId, optionName));
    return _items.values.any((i) => i.productId == productId);
  }

  int quantityOf(String productId, {String? optionName}) =>
      _items[keyFor(productId, optionName)]?.quantity ?? 0;

  /// 🔒 CURRENT CART SELLER (DERIVED)
  String? get cartSellerId {
    if (_items.isEmpty) return null;
    return _items.values.first.sellerId;
  }

  /// ------------------------
  /// WRITE OPERATIONS
  /// ------------------------

  AddProductResult addProduct(ProductModel product, {String? optionName}) {
    final existingSellerId = cartSellerId;

    if (existingSellerId != null && existingSellerId != product.sellerId) {
      return AddProductResult.multiSellerNotAllowed;
    }

    final key = keyFor(product.id, optionName);

    if (_items.containsKey(key)) {
      _items[key]!.quantity += 1;
    } else {
      _items[key] = CartItemModel(
        productId: product.id,
        name: product.name,
        price: product.priceForOption(optionName),
        imageUrl: product.coverImage,
        sellerId: product.sellerId,
        optionName: optionName,
      );
    }

    _persist();
    _notify();
    return AddProductResult.success;
  }

  void increaseQuantity(String productId, {String? optionName}) {
    final key = keyFor(productId, optionName);
    if (_items.containsKey(key)) {
      _items[key]!.quantity += 1;
      _persist();
      _notify();
    }
  }

  void decreaseQuantity(String productId, {String? optionName}) {
    final key = keyFor(productId, optionName);
    if (!_items.containsKey(key)) return;

    final item = _items[key]!;

    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _items.remove(key);
    }
    _persist();
    _notify();
  }

  void removeProduct(String productId, {String? optionName}) {
    _items.remove(keyFor(productId, optionName));
    _persist();
    _notify();
  }

  void clearCart() {
    _items.clear();
    _persist();
    _notify();
  }

  /// ------------------------
  /// PERSISTENCE
  /// ------------------------

  void loadFromStorage(Map<String, dynamic> json) {
    _items.clear();

    json.forEach((key, value) {
      final item = CartItemModel.fromJson(
        Map<String, dynamic>.from(value),
      );
      _items[item.lineKey] = item;
    });

    _notify();
  }

  Map<String, dynamic> toJson() {
    return _items.map((key, item) => MapEntry(key, item.toJson()));
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
          if (item.optionName != null) 'optionName': item.optionName,
        };
      }).toList(),
      'totalAmount': totalAmount,
      'status': 'placed',
      'createdAt': DateTime.now(),
    };
  }
}
