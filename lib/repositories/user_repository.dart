import 'package:firebase_auth/firebase_auth.dart';

import '../data/datasources/user_remote_ds.dart';
import '../data/datasources/seller_application_remote_ds.dart';
import '../models/user_model.dart';

class UserRepository {
  final UserRemoteDS _remoteDS = UserRemoteDS();
  final SellerApplicationRemoteDS _sellerAppDS =
      SellerApplicationRemoteDS();

  /// 🔹 One-time fetch (used in non-reactive flows)
  Future<UserModel> getUser(String uid) {
    return _remoteDS.getUser(uid);
  }

  /// 🔹 REAL-TIME user stream (USED BY AuthWrapper)
  Stream<UserModel?> streamUser(String uid) {
    return _remoteDS.streamUser(uid);
  }

  /// 🔹 Convenience: stream currently logged-in user.
  /// Emits null for guests instead of throwing.
  Stream<UserModel?> streamCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream<UserModel?>.value(null);
    return _remoteDS.streamUser(user.uid);
  }

  /// 🔹 Create user on first login
  Future<void> createUser(UserModel user) {
    return _remoteDS.createUser(user);
  }

  /// 🔹 Update full user profile
  Future<void> updateUser(UserModel user) {
    return _remoteDS.updateUser(user);
  }

  /// 🔹 Partial update (IMPORTANT for seller flow)
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) {
    return _remoteDS.updateUserFields(uid, data);
  }

  /// 🔹 Admin / internal use
  Future<List<UserModel>> getAllUsers() {
    return _remoteDS.getAllUsers();
  }

  /* --------------------------------------------------
     🛍️ SELLER FLOW — ADMIN METHODS
     -------------------------------------------------- */

  /// 🔹 Stream seller applications (pending approval)
  Stream<List<UserModel>> streamSellerRequests() {
    return _remoteDS.streamUsersBySellerStatus('pending');
  }

  /// 🔹 Get all approved sellers
  Future<List<UserModel>> getAllSellers() {
    return _remoteDS.getUsersByRole('seller');
  }

  /// 🔄 Live stream of all sellers (admin list auto-refresh)
  Stream<List<UserModel>> streamAllSellers() {
    return _remoteDS.streamUsersByRole('seller');
  }

  /// 🔹 Approve seller (FINAL FIX)
  Future<void> approveSeller(String uid) async {
    // 1️⃣ Update USER → ACTIVE SELLER
    await _remoteDS.updateUserFields(uid, {
      'role': 'seller',
      'sellerStatus': 'active',
      'shopId': null,
      'approvedAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });

    // 2️⃣ Close SELLER APPLICATION → APPROVED
    await _sellerAppDS.updateApplicationStatus(
      uid,
      status: 'approved',
    );
  }

  /// 🔹 Reject seller (FINAL FIX)
  Future<void> rejectSeller(String uid) async {
    // 1️⃣ Update USER → REJECTED
    await _remoteDS.updateUserFields(uid, {
      'sellerStatus': 'rejected',
      'rejectedAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });

    // 2️⃣ Close SELLER APPLICATION → REJECTED
    await _sellerAppDS.updateApplicationStatus(
      uid,
      status: 'rejected',
    );
  }

  /// 🔹 One-time fetch of currently logged-in user
  /// Used by BuyerHome and other FutureBuilder flows
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) return null;

    return _remoteDS.getUser(firebaseUser.uid);
  }
}
