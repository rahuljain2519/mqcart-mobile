import '../../services/firestore_service.dart';
import '../../models/banner_model.dart';

/// Admin-managed landing page banners (same `banners` collection the web
/// admin's Banners page writes to) - public read, admin-only write.
class BannerRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  // isActive filtered client-side rather than as a .where() clause -
  // combined with .orderBy('order') on a different field, that needs a
  // composite index Firestore doesn't have here, which fails the listener
  // silently and the carousel never appears. Collection is tiny, so
  // sorting server-side and filtering here is simpler than deploying one.
  Stream<List<BannerModel>> streamActiveBanners() {
    return _firestore
        .banners()
        .orderBy('order')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => BannerModel.fromJson(
                    d.data() as Map<String, dynamic>,
                    d.id,
                  ))
              .where((b) => b.isActive)
              .toList(),
        );
  }
}
