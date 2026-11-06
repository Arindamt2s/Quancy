import 'package:flutter/foundation.dart';
import 'package:quincy/API/mobileFoodOPerationTypesRespiratory.dart';

// TODO: fix these imports if the files live somewhere else in your project.
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeModel.dart';


/// Downloads operation types (via MobileFoodOperationTypesRepository), saves
/// them in `mobile_food_operation_types`, and reads them back for the UI.
class MobileFoodOperationTypeViewModel extends ChangeNotifier {
  final DBManager _db;
  final MobileFoodOperationTypesRepository _repo;

  MobileFoodOperationTypeViewModel({
    DBManager? db,
    MobileFoodOperationTypesRepository? repo,
  })  : _db = db ?? DBManager.instance,
        _repo = repo ?? MobileFoodOperationTypesRepository();

  List<MobileFoodOperationTypeModel> _operationTypes = [];
  List<MobileFoodOperationTypeModel> get operationTypes => _operationTypes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// operation-types API → save to DB → load from DB.
  /// Returns true when the server list was saved. If the call fails
  /// (e.g. offline) the previously saved list is still loaded.
  Future<bool> syncOperationTypes() async {
    _isLoading = true;
    _error = null;
    _notify();

    var synced = false;
    try {
      final token = await _db.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No access token – user not logged in');
      }

      debugPrint('🌐 Calling operation-types API…');
      final list = await _repo.getOperationTypes(token: token);

      await _db.saveMobileFoodOperationTypes(list);
      debugPrint('✅ Operation types saved to DB: ${list.length}');
      synced = true;
    } catch (e) {
      _error = 'Could not download operation types.';
      debugPrint('❌ Operation types sync error: $e');
    }

    await loadFromDb(notify: false);
    _isLoading = false;
    _notify();
    return synced;
  }

  /// Reads the saved (active) operation types from the DB.
  Future<List<MobileFoodOperationTypeModel>> loadFromDb(
      {bool notify = true}) async {
    try {
      _operationTypes = await _db.getMobileFoodOperationTypes();
    } catch (e) {
      debugPrint('❌ Load operation types error: $e');
      _operationTypes = [];
    }
    if (notify) _notify();
    return _operationTypes;
  }
}