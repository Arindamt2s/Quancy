import 'package:flutter/foundation.dart';
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/mobile_food_repository.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodPermitModel.dart'; // TODO: adjust to your DBManager path


class MobileFoodPermitViewModel extends ChangeNotifier {
  MobileFoodPermitViewModel({MobileFoodPermitRepository? repository})
      : _repository = repository ?? MobileFoodPermitRepository();

  final MobileFoodPermitRepository _repository;
  final DBManager _db = DBManager.instance;

  List<MobileFoodPermitModel> _permits = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;

  List<MobileFoodPermitModel> get permits => _permits;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True when the list shown came from the local DB because the API failed.
  bool get isOffline => _isOffline;

  /// Call API → save to SQLite → load from SQLite.
  /// If the API fails, falls back to whatever is already stored locally.
  Future<void> fetchPermits() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _db.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Session expired. Please log in again.');
      }

      final result = await _repository.getPermitList(token: token);
      if (!result.status) {
        throw Exception('Failed to load permits.');
      }

      await _db.saveMobileFoodPermits(result.permits);
      _permits = await _db.getMobileFoodPermits();
      _isOffline = false;
    } catch (e) {
      debugPrint('❌ fetchPermits error: $e');
      _permits = await _db.getMobileFoodPermits();
      _isOffline = true;
      if (_permits.isEmpty) _errorMessage = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load only from the local DB (no network).
  Future<void> loadLocalPermits() async {
    _permits = await _db.getMobileFoodPermits();
    notifyListeners();
  }

  Future<MobileFoodPermitModel?> getPermitById(int id) =>
      _db.getMobileFoodPermitById(id);

  String _friendlyError(Object e) {
    if (e is NoInternetException) return 'No internet connection.';
    if (e is TimeoutApiException) return 'Request timed out. Please try again.';
    if (e is InvalidResponseException) return 'Invalid response from server.';
    return e.toString().replaceFirst('Exception: ', '');
  }
}