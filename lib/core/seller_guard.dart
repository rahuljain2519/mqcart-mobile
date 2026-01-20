import '../models/user_model.dart';

class SellerGuard {
  /// Can show "Become a Seller" button
  static bool canApply(UserModel user) {
    return user.role == 'buyer' && user.sellerStatus == 'none';
  }

  /// Seller application already submitted
  static bool isPending(UserModel user) {
    return user.sellerStatus == 'pending';
  }

  /// Approved seller but shop not created → ONBOARDING
  static bool needsOnboarding(UserModel user) {
    return user.role == 'seller'
        && user.sellerStatus == 'approved'
        && (user.shopId == null || user.shopId!.isEmpty);
  }

  /// Seller with shop (dashboard allowed)
  static bool isSeller(UserModel user) {
    return user.role == 'seller'
        && user.shopId != null
        && user.shopId!.isNotEmpty;
  }

  /// Backward compatibility (DO NOT REMOVE YET)
  static bool isActive(UserModel user) {
    return user.sellerStatus == 'active' || isSeller(user);
  }
}
