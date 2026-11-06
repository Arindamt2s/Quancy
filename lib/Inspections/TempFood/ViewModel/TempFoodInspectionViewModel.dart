import 'package:flutter/foundation.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodInspectionModel.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodPermitModel.dart';

/// Saved Temporary Food inspections (TempFoodInspection table):
/// used by the inspection form and the Incomplete list.
///
/// Path: lib/Inspections/TempFood/ViewModel/TempFoodInspectionViewModel.dart
class TempFoodInspectionViewModel extends ChangeNotifier {
  TempFoodInspectionViewModel({DBManager? db}) : _db = db ?? DBManager.instance;

  final DBManager _db;

  List<TempFoodInspectionModel> _incomplete = [];
  Map<String, int> _answered = {};
  bool _isLoading = false;
  String _query = '';
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String get query => _query;
  int get incompleteCount => _incomplete.length;

  /// Incomplete inspections matching the search, newest first.
  List<TempFoodInspectionModel> get incomplete {
    if (_query.isEmpty) return List.unmodifiable(_incomplete);
    return _incomplete.where((i) {
      return [
        i.businessName,
        i.permitNumber,
        i.address,
        i.inspector,
        i.inspectionId,
      ].any((f) => f.toLowerCase().contains(_query));
    }).toList();
  }

  int answeredCount(String inspectionId) => _answered[inspectionId] ?? 0;

  // ---------- Form ----------

  Future<int?> getLoggedInUserId() => _db.getLoggedInUserId();

  Future<TempFoodPermitModel?> getPermitById(int id) =>
      _db.getTempFoodPermitById(id);

  Future<TempFoodInspectionModel?> getById(String inspectionId) =>
      _db.getTempFoodInspectionById(inspectionId);

  Future<void> saveEstablishment(TempFoodInspectionModel inspection) =>
      _db.saveTempFoodInspection(inspection);

  Future<void> updateStep(String inspectionId, int step) =>
      _db.updateTempFoodInspectionStep(inspectionId, step);

  /// Deletes the inspection, its answers, temperatures, final row and files.
  Future<void> delete(String inspectionId) async {
    await _db.deleteTempFoodInspection(inspectionId);
    _incomplete.removeWhere((i) => i.inspectionId == inspectionId);
    _answered.remove(inspectionId);
    _notify();
  }

  // ---------- Incomplete list ----------

  Future<void> loadIncomplete(int userId) async {
    _isLoading = true;
    _notify();
    try {
      _incomplete = await _db.getIncompleteTempFoodInspections(userId);
      _answered = await _db.getTempFoodAnsweredCounts(userId);
    } catch (e) {
      debugPrint('⚠️ Temp Food incomplete load error: $e');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void setQuery(String value) {
    _query = value.trim().toLowerCase();
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
