import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Core collections
  CollectionReference users() => _db.collection('users');
  CollectionReference societies() => _db.collection('societies');
  CollectionReference shops() => _db.collection('shops');
  CollectionReference products() => _db.collection('products');
  CollectionReference orders() => _db.collection('orders');
  CollectionReference sellerApplications() => _db.collection('seller_applications');
  CollectionReference sellerActivationPayments() => _db.collection('seller_activation_payments');
}
