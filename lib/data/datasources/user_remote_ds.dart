import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../models/user_model.dart';

class UserRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  /* --------------------------------------------------
     FETCH USER (ONE-TIME)
     -------------------------------------------------- */
  Future<UserModel> getUser(String uid) async {
    final doc = await _firestore.users().doc(uid).get();

    if (!doc.exists) {
      throw Exception('User not found');
    }

    return UserModel.fromJson(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /* --------------------------------------------------
     🔥 STREAM USER (REAL-TIME)
     USED BY AuthWrapper & SellerHome
     -------------------------------------------------- */
  Stream<UserModel?> streamUser(String uid) {
    return _firestore.users().doc(uid).snapshots().map(
      (DocumentSnapshot doc) {
        if (!doc.exists) return null;

        return UserModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      },
    );
  }

  /* --------------------------------------------------
   CREATE USER (FIRST LOGIN) — FIXED
   -------------------------------------------------- */
  Future<void> createUser(UserModel user) async {
    final docRef = _firestore.users().doc(user.uid);
    final doc = await docRef.get();

    // 🔒 Do not overwrite existing users
    if (doc.exists) return;

    await docRef.set({
      'uid': user.uid,

      // BASIC INFO
      'name': user.name.isNotEmpty ? user.name : '',
      'phone': user.phone,
      'societyId': user.societyId.isNotEmpty ? user.societyId : '',
      'flatNumber': user.flatNumber.isNotEmpty ? user.flatNumber : '',

      // 🔒 PROTECTED FIELDS (REQUIRED BY RULES)
      'role': user.role.isNotEmpty ? user.role : 'buyer',
      'sellerStatus': 'inactive',
      'shopId': '',

      // FLOW CONTROL
      'profileCompleted': false,

      // META
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  /* --------------------------------------------------
     UPDATE USER (FULL UPDATE)
     -------------------------------------------------- */
  
  Future<void> updateUser(UserModel user) async {
    await _firestore.users().doc(user.uid).update({
      'name': user.name,
      'phone': user.phone,
      'societyId': user.societyId,
      'flatNumber': user.flatNumber,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /* --------------------------------------------------
     🔹 PARTIAL UPDATE (SELLER FLOW / ADMIN)
     -------------------------------------------------- */
  Future<void> updateUserFields(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await _firestore.users().doc(uid).update({
      ...data,
      'updatedAt': DateTime.now(),
    });
  }

  /* --------------------------------------------------
     🔹 STREAM USERS BY SELLER STATUS (ADMIN)
     -------------------------------------------------- */
  Stream<List<UserModel>> streamUsersBySellerStatus(String status) {
    return _firestore
        .users()
        .where('sellerStatus', isEqualTo: status)
        .snapshots()
        .map(
          (query) => query.docs
              .map(
                (doc) => UserModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }
  /// seller based user
  Future<List<UserModel>> getUsersByRole(String role) async {
  final query = await _firestore
      .users()
      .where('role', isEqualTo: role)
      .get();

  return query.docs
      .map(
        (doc) => UserModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
      .toList();
}
  /* --------------------------------------------------
     ADMIN / INTERNAL USE
     -------------------------------------------------- */
  Future<List<UserModel>> getAllUsers() async {
    final query = await _firestore.users().get();

    return query.docs
        .map(
          (doc) => UserModel.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }
}
