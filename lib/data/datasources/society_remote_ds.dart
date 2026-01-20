import '../../services/firestore_service.dart';
import '../../models/society_model.dart';

class SocietyRemoteDS {
  final FirestoreService _firestore = FirestoreService();

  /// Get all active societies
  Future<List<SocietyModel>> getSocieties() async {
    final query = await _firestore
        .societies()
        .where('isActive', isEqualTo: true)
        .get();

    return query.docs
        .map(
          (doc) => SocietyModel.fromJson(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  /// Create a new society (admin use)
  Future<void> createSociety(SocietyModel society) async {
    await _firestore.societies().add(society.toJson());
  }
  /// Delete society (admin use)
  Future<void> deleteSociety(String societyId) async {
  await _firestore.societies().doc(societyId).delete();
  }

  /// 🆕 Get society by ID (used to show society name)
  Future<SocietyModel?> getSocietyById(String societyId) async {
    final doc =
        await _firestore.societies().doc(societyId).get();

    if (!doc.exists) return null;

    return SocietyModel.fromJson(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }
}
