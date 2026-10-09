import '../data/datasources/banner_remote_ds.dart';
import '../models/banner_model.dart';

export '../models/banner_model.dart';

class BannerRepository {
  final BannerRemoteDS _remoteDS = BannerRemoteDS();

  Stream<List<BannerModel>> streamActiveBanners() =>
      _remoteDS.streamActiveBanners();
}
