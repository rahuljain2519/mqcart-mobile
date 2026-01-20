import '../data/datasources/society_remote_ds.dart';
import '../models/society_model.dart';

class SocietyRepository {
  final SocietyRemoteDS _remoteDS = SocietyRemoteDS();

  /// Fetch all active societies
  Future<List<SocietyModel>> getActiveSocieties() {
    return _remoteDS.getSocieties();
  }

  Future<void> createSociety(SocietyModel society) async {
  await _remoteDS.createSociety(society);
  }

/// 🆕 Fetch society by ID (used to show society name)
  Future<SocietyModel?> getSocietyById(String societyId) {
    return _remoteDS.getSocietyById(societyId);
  }
 /// 🆕 Resolve society name by ID (Checkout / Orders)
  Future<String> getSocietyName(String societyId) async {
    final society = await _remoteDS.getSocietyById(societyId);
    return society?.name ?? '';
  }
/// Delete from admin
Future<void> deleteSociety(String societyId) {
  return _remoteDS.deleteSociety(societyId);
}
}
