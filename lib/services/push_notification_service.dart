import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationService {
  static Future<void> initSellerPush() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    if (Platform.isIOS || Platform.isAndroid) {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final token = await messaging.getToken();
    if (token == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    // ✅ Store token in users collection
    await userRef.set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );

    // 🔄 Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      userRef.set(
        {'fcmToken': newToken},
        SetOptions(merge: true),
      );
    });
  }
}
