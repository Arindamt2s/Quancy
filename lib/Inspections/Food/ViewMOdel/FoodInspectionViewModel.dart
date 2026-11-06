import 'package:flutter/foundation.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/Food/Model/FoodInspectionModel.dart';
import 'package:quincy/Inspections/Food/Model/FoodPermitModel.dart';

/// Food inspections saved on the device (Establishment tab + progress)
/// and the Incomplete list.
class FoodInspectionViewModel extends ChangeNotifier {
  final DBManager _db = DBManager.instance;

  List<FoodInspectionModel> _incomplete = [];
  Map<String, int> _answeredCounts = {};
  bool _isLoading = false;
  String _query = '';
  bool _disposed = false;

  bool get isLoading => _isLoading;
  int get totalCount => _incomplete.length;
  bool get hasData => _incomplete.isNotEmpty;

  /// Incomplete inspections filtered by the search text.
  List<FoodInspectionModel> get incomplete {
    if (_query.isEmpty) return _incomplete;
    return _incomplete.where((i) {
      return [
        i.businessName,
        i.permitNumber,
        i.address,
        i.inspectionId,
        i.inspector,
      ].any((v) => v.toLowerCase().contains(_query));
    }).toList();
  }

  /// Number of checklist items answered in [inspectionId].
  int answeredCount(String inspectionId) => _answeredCounts[inspectionId] ?? 0;

  void setQuery(String q) {
    _query = q.trim().toLowerCase();
    _notify();
  }

  Future<int?> getLoggedInUserId() => _db.getLoggedInUserId();

  Future<FoodPermitModel?> getPermitById(int id) => _db.getFoodPermitById(id);

  Future<FoodInspectionModel?> getById(String inspectionId) =>
      _db.getFoodInspectionById(inspectionId);

  Future<void> saveEstablishment(FoodInspectionModel inspection) async {
    await _db.saveFoodInspection(inspection);
    _notify();
  }

  Future<void> updateStep(String inspectionId, int step) =>
      _db.updateFoodInspectionStep(inspectionId, step);

  /// Incomplete Food inspections of [userId] (newest first).
  Future<void> loadIncomplete(int userId) async {
    _isLoading = true;
    _notify();
    try {
      _incomplete = await _db.getIncompleteFoodInspections(userId);
      _answeredCounts = await _db.getFoodAnsweredCounts(userId);
    } catch (e) {
      debugPrint('❌ Load incomplete Food inspections error: $e');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Deletes the inspection with its answers, temperatures, final row
  /// and photo / signature files.
  Future<void> delete(String inspectionId) async {
    await _db.deleteFoodInspection(inspectionId);
    _incomplete.removeWhere((i) => i.inspectionId == inspectionId);
    _answeredCounts.remove(inspectionId);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}