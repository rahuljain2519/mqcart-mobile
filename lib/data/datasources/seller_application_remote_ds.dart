import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../models/seller_application_model.dart';

class SellerApplicationRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  /// ---------------------------------
  /// SUBMIT SELLER APPLICATION
  /// ---------------------------------
  Future<void> submitApplication(SellerApplicationModel app) async {
    // 1️⃣ Create seller application
    // NOTE: documentId = uid (correct design)
    await _firestore
        .sellerApplications()
        .doc(app.uid)
        .set(app.toJson());

    // 2️⃣ Mark user as pending seller
    await _firestore.users().doc(app.uid).update({
      'sellerStatus': 'pending',
    });
  }

  /// ---------------------------------
  /// STREAM MY SELLER APPLICATION (USER)
  /// 🔥 REQUIRED FOR AUTO-REFRESH PROFILE
  /// ---------------------------------
  Stream<SellerApplicationModel?> streamMyApplication(String uid) {
    return _firestore
        .sellerApplications()
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;

          return SellerApplicationModel.fromJson(
            doc.data() as Map<String, dynamic>,
          );
        });
  }

  /// ---------------------------------
  /// STREAM PENDING APPLICATIONS (ADMIN)
  /// ---------------------------------
  Stream<List<SellerApplicationModel>> streamPendingApplications() {
    return _firestore
        .sellerApplications()
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (query) => query.docs.map((doc) {
            return SellerApplicationModel.fromJson(
              doc.data() as Map<String, dynamic>,
            );
          }).toList(),
        );
  }

  /// ---------------------------------
  /// GET MY SELLER APPLICATION (USER)
  /// (Used in non-stream scenarios)
  /// ---------------------------------
  Future<SellerApplicationModel?> getMyApplication(String uid) async {
    final doc =
        await _firestore.sellerApplications().doc(uid).get();

    if (!doc.exists) return null;

    return SellerApplicationModel.fromJson(
      doc.data() as Map<String, dynamic>,
    );
  }

  /// ---------------------------------
  /// UPDATE SELLER APPLICATION STATUS (ADMIN)
  /// ---------------------------------
  Future<void> updateApplicationStatus(
    String uid, {
    required String status,
  }) async {
    // 1️⃣ Update seller application
    await _firestore.sellerApplications().doc(uid).update({
      'status': status,
      'updatedAt': DateTime.now(),
      if (status == 'approved') 'approvedAt': DateTime.now(),
      if (status == 'rejected') 'rejectedAt': DateTime.now(),
    });

    // 2️⃣ Sync user sellerStatus (CRITICAL)
    await _firestore.users().doc(uid).update({
      'sellerStatus': status,
    });
  }
}
