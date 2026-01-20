import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CartStorageService {
  static const _cartKey = 'mq_cart';

  static Future<void> saveCart(Map<String, dynamic> cartJson) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_cartKey, jsonEncode(cartJson));
  }

  static Future<Map<String, dynamic>> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_cartKey);
    if (data == null) return {};
    return jsonDecode(data);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_cartKey);
  }
}
