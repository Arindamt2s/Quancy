import 'package:flutter/foundation.dart';
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/FoodPermitReposiratory.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/Food/Model/FoodPermitModel.dart';


/// API → repository → DB (food_permits) → UI.
/// Same flow as the Mobile Food permit / schedule ViewModels.
class FoodPermitViewModel extends ChangeNotifier {
  FoodPermitViewModel({FoodPermitRepository? repository, DBManager? db})
      : _repo = repository ?? FoodPermitRepository(),
        _db = db ?? DBManager.instance;

  final FoodPermitRepository _repo;
  final DBManager _db;

  List<FoodPermitModel> _all = [];
  bool _isLoading = false;
  bool _initialised = false;
  String? _error;
  String _query = '';
  bool _disposed = false;

  bool get isLoading => _isLoading;
  bool get initialised => _initialised;
  String? get error => _error;
  String get query => _query;
  bool get hasData => _all.isNotEmpty;

  /// Last API call failed (saved list may still be shown).
  bool get isOffline => _error != null;

  /// All saved permits (ignores search) – for the sync loader.
  int get totalCount => _all.length;
  List<FoodPermitModel> get allPermits => List.unmodifiable(_all);

  /// Searched list.
  List<FoodPermitModel> get permits {
    if (_query.isEmpty) return _all;
    return _all.where((p) {
      return [
        p.businessName,
        p.permitNumber,
        p.businessAddress,
        p.city,
        p.ownerName,
        p.phone,
        p.establishmentType,
      ].any((f) => f != null && f.toLowerCase().contains(_query));
    }).toList();
  }

  // ---------- Used by the Dashboard sync ----------

  /// Loads what is already saved in SQLite (no API call).
  Future<void> loadFromDb() async {
    try {
      _all = await _db.getFoodPermits();
    } catch (e) {
      debugPrint('⚠️ Food permit DB read error: $e');
    }
    _initialised = true;
    _notify();
  }

  /// get-permit-list (food) → food_permits table.
  Future<void> syncPermits() => refresh();

  /// Shows saved rows immediately, then refreshes from the server.
  Future<void> init() async {
    await loadFromDb();
    await refresh();
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final token = await _db.getAccessToken();
      if (token == null || token.isEmpty) {
        _error = 'You are not logged in.';
        return;
      }

      final response = await _repo.getPermitList(token: token);
      debugPrint('🍽️ success=${response.success}, '
          'permits=${response.permits.length}');

      if (!response.success) {
        _error = 'The server could not return food permits.';
        return;
      }

      await _db.saveFoodPermits(response.permits);
      _all = await _db.getFoodPermits();
      debugPrint('✅ Food permits saved: ${_all.length}');
    } on NoInternetException {
      _error = 'No internet connection.';
    } on TimeoutApiException {
      _error = 'The server took too long to respond.';
    } on InvalidResponseException {
      _error = 'Unexpected response from the server.';
    } catch (e, st) {
      debugPrint('⚠️ Food permit sync error (${e.runtimeType}): $e\n$st');
      final msg = e.toString().trim();
      _error = msg.isEmpty || msg.startsWith('Instance of')
          ? 'Could not load food permits. Please try again.'
          : msg;
    } finally {
      _isLoading = false;
      _initialised = true;
      _notify();
    }
  }

  void setQuery(String value) {
    _query = value.trim().toLowerCase();
    _notify();
  }

  FoodPermitModel? byId(int id) {
    for (final p in _all) {
      if (p.id == id) return p;
    }
    return null;
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