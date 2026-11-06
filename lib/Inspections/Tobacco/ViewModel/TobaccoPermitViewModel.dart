import 'package:flutter/foundation.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoPermitModel.dart';
import 'package:quincy/API/TobaccoRepository.dart';

/// Tobacco permits list (offline-first).
///
/// Path: lib/Inspections/Tobacco/ViewModel/TobaccoPermitViewModel.dart
///
/// Same API as TempFoodPermitViewModel so the Dashboard can own one
/// instance and pass it to TobaccoPermitListScreen.
class TobaccoPermitViewModel extends ChangeNotifier {
  TobaccoPermitViewModel({TobaccoRepository? repository})
      : _repo = repository ?? TobaccoRepository();

  final TobaccoRepository _repo;

  List<TobaccoPermitModel> _all = const [];
  List<TobaccoPermitModel>? _filtered;
  String _query = '';

  bool initialised = false;
  bool isLoading = false;
  String? error;
  bool _disposed = false;

  int get totalCount => _all.length;
  bool get hasData => _all.isNotEmpty;
  String get query => _query;

  /// Filtered by the current search.
  List<TobaccoPermitModel> get permits =>
      _filtered ??= _query.isEmpty
          ? _all
          : _all.where((p) => p.matches(_query)).toList();

  TobaccoPermitModel? byId(int id) {
    for (final p in _all) {
      if (p.id == id) return p;
    }
    return null;
  }

  void setQuery(String q) {
    final v = q.trim().toLowerCase();
    if (v == _query) return;
    _query = v;
    _filtered = null;
    _notify();
  }

  /// Saved permits from SQLite.
  Future<void> loadFromDb() async {
    try {
      _setAll(await _repo.getSavedPermits());
    } catch (e) {
      debugPrint('⚠️ Tobacco permits DB error: $e');
    }
    initialised = true;
    _notify();
  }

  /// Downloads permits; keeps the saved ones if it fails (offline).
  Future<void> syncPermits() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    _notify();
    try {
      await _repo.syncPermits();
      _setAll(await _repo.getSavedPermits());
    } catch (e) {
      error = e.toString();
      debugPrint('⚠️ Tobacco permits sync error: $e');
    } finally {
      isLoading = false;
      initialised = true;
      _notify();
    }
  }

  /// DB first, then API.
  Future<void> init() async {
    await loadFromDb();
    await syncPermits();
  }

  void _setAll(List<TobaccoPermitModel> list) {
    _all = list;
    _filtered = null;
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
