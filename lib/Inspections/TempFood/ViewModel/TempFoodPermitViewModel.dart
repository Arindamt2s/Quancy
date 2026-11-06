import 'package:flutter/foundation.dart';
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/TempFoodApiClient.dart';

import 'package:quincy/API/TempFoodPermitRepository.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodPermitModel.dart';

/// temp-food/get-permit-list → temp_food_permits table → UI.
///
/// Path: lib/Inspections/TempFood/ViewModel/TempFoodPermitViewModel.dart
class TempFoodPermitViewModel extends ChangeNotifier {
  TempFoodPermitViewModel({
    TempFoodPermitRepository? repository,
    DBManager? db,
  })  : _repo = repository ?? TempFoodPermitRepository(),
        _db = db ?? DBManager.instance;

  final TempFoodPermitRepository _repo;
  final DBManager _db;

  List<TempFoodPermitModel> _all = [];
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
  int get totalCount => _all.length;

  /// Every saved permit (ignores the search).
  List<TempFoodPermitModel> get allPermits => List.unmodifiable(_all);

  /// Permits matching the search (business, permit no., address, owner).
  List<TempFoodPermitModel> get permits {
    if (_query.isEmpty) return List.unmodifiable(_all);
    return _all.where((p) {
      return [
        p.businessName,
        p.permitNumber,
        p.businessAddress,
        p.city,
        p.ownerName,
      ].any((f) => f != null && f.toLowerCase().contains(_query));
    }).toList();
  }

  TempFoodPermitModel? byId(int id) {
    for (final p in _all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Saved permits only (no API call).
  Future<void> loadFromDb() async {
    try {
      _all = await _db.getTempFoodPermits();
    } catch (e) {
      debugPrint('⚠️ Temp Food permits DB read error: $e');
    }
    _initialised = true;
    _notify();
  }

  /// API → DB → list. Keeps the saved list when offline.
  Future<void> syncPermits() async {
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
      final list = await _repo.getPermits(token: token);
      debugPrint('🏕️ temp food permits: ${list.length}');
      await _db.saveTempFoodPermits(list);
      _all = await _db.getTempFoodPermits();
    } on NoInternetException {
      _error = 'No internet connection.';
    } on TimeoutApiException {
      _error = 'The server took too long to respond.';
    } on InvalidResponseException {
      _error = 'Unexpected response from the server.';
    } on TempFoodApiException catch (e) {
      _error = e.message;
    } catch (e, st) {
      debugPrint('⚠️ Temp Food permit sync error: $e\n$st');
      _error = 'Could not load temporary food permits.';
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
