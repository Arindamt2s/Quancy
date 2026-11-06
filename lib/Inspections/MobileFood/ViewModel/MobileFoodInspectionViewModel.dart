import 'package:flutter/foundation.dart';
import 'package:quincy/Database/DBManager.dart'; // TODO: adjust to your DBManager path
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionModel.dart';

class MobileFoodInspectionViewModel extends ChangeNotifier {
  final DBManager _db = DBManager.instance;

  List<MobileFoodInspectionModel> _incomplete = [];
  bool _isLoading = false;

  List<MobileFoodInspectionModel> get incompleteInspections => _incomplete;
  bool get isLoading => _isLoading;

  /// Loads the logged-in user's incomplete inspections from the DB.
  Future<void> loadIncomplete() async {
    _isLoading = true;
    notifyListeners();

    final userId = await _db.getLoggedInUserId();
    _incomplete = userId == null
        ? []
        : await _db.getIncompleteMobileFoodInspections(userId);

    _isLoading = false;
    notifyListeners();
  }

  Future<int?> getLoggedInUserId() => _db.getLoggedInUserId();

  Future<MobileFoodInspectionModel?> getById(String inspectionId) =>
      _db.getMobileFoodInspectionById(inspectionId);

  /// Insert or update the Establishment data.
  Future<void> saveEstablishment(MobileFoodInspectionModel inspection) async {
    await _db.saveMobileFoodInspection(inspection);
    debugPrint('💾 Saved inspection ${inspection.inspectionId}');
  }

  Future<void> updateStep(String inspectionId, int step) =>
      _db.updateMobileFoodInspectionStep(inspectionId, step);

  Future<void> delete(String inspectionId) async {
    await _db.deleteMobileFoodInspection(inspectionId);
    _incomplete.removeWhere((i) => i.inspectionId == inspectionId);
    notifyListeners();
  }

  
}