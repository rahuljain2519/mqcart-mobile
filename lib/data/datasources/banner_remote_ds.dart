import '../../services/firestore_service.dart';
import '../../models/banner_model.dart';

/// Admin-managed landing page banners (same `banners` collection the web
/// admin's Banners page writes to) - public read, admin-only write.
class BannerRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  Stream<List<BannerModel>> streamActiveBanners() {
    return _firestore
        .banners()
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => BannerModel.fromJson(
                    d.data() as Map<String, dynamic>,
                    d.id,
                  ))
              .toList(),
        );
  }
}
