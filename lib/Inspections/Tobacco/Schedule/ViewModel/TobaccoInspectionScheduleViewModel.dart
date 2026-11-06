import 'package:flutter/foundation.dart';
import 'package:quincy/API/TobaccoRepository.dart';

import 'package:quincy/Inspections/Tobacco/Schedule/Model/TobaccoInspectionScheduleModel.dart';
import 'package:quincy/Inspections/Tobacco/TobaccoDeps.dart';

enum TobaccoScheduleFilter { upcoming, today, past, all }

extension TobaccoScheduleFilterLabel on TobaccoScheduleFilter {
  String get label {
    switch (this) {
      case TobaccoScheduleFilter.upcoming:
        return 'Upcoming';
      case TobaccoScheduleFilter.today:
        return 'Today';
      case TobaccoScheduleFilter.past:
        return 'Past';
      case TobaccoScheduleFilter.all:
        return 'All';
    }
  }
}

/// Tobacco inspection schedules: offline-first, search + date filter,
/// grouped by schedule date.
///
/// Path: lib/Inspections/Tobacco/Schedule/ViewModel/TobaccoInspectionScheduleViewModel.dart
class TobaccoInspectionScheduleViewModel extends ChangeNotifier {
  TobaccoInspectionScheduleViewModel({
    this.inspectorId,
    TobaccoRepository? repository,
  }) : _repo = repository ?? TobaccoRepository();

  /// Only this inspector's schedules (null = all saved).
  final int? inspectorId;
  final TobaccoRepository _repo;

  List<TobaccoInspectionScheduleModel> _all = const [];
  String _query = '';
  TobaccoScheduleFilter _filter = TobaccoScheduleFilter.all;

  bool initialised = false;
  bool isLoading = false;
  int fetchedCount = 0;
  String? error;
  bool _disposed = false;

  String get query => _query;
  TobaccoScheduleFilter get filter => _filter;
  bool get hasData => _all.isNotEmpty;
  int get totalCount => _all.length;

  /// Last sync failed but saved schedules are shown.
  bool get showingCached => error != null && hasData;

  List<TobaccoInspectionScheduleModel> get schedules => _all;

  TobaccoInspectionScheduleModel? byId(int id) {
    for (final s in _all) {
      if (s.id == id) return s;
    }
    return null;
  }

  void setQuery(String q) {
    if (q == _query) return;
    _query = q;
    _notify();
  }

  void setFilter(TobaccoScheduleFilter f) {
    if (f == _filter) return;
    _filter = f;
    _notify();
  }

  /// schedule date (yyyy-MM-dd, '' = no date) → schedules.
  /// Past is newest first; the others oldest first.
  Map<String, List<TobaccoInspectionScheduleModel>> get grouped {
    final q = _query.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool inFilter(TobaccoInspectionScheduleModel s) {
      if (_filter == TobaccoScheduleFilter.all) return true;
      final d = DateTime.tryParse(s.dateKey);
      if (d == null) return false;
      final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
      switch (_filter) {
        case TobaccoScheduleFilter.upcoming:
          return diff >= 0;
        case TobaccoScheduleFilter.today:
          return diff == 0;
        case TobaccoScheduleFilter.past:
          return diff < 0;
        case TobaccoScheduleFilter.all:
          return true;
      }
    }

    final list = _all.where((s) => inFilter(s) && s.matches(q)).toList();
    if (_filter == TobaccoScheduleFilter.past) {
      list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    }
    final map = <String, List<TobaccoInspectionScheduleModel>>{};
    for (final s in list) {
      map.putIfAbsent(s.dateKey, () => []).add(s);
    }
    return map;
  }

  Future<void> loadFromDb() async {
    try {
      _all = await _repo.getSavedSchedules(inspectorId: inspectorId);
    } catch (e) {
      debugPrint('⚠️ Tobacco schedules DB error: $e');
    }
    initialised = true;
    _notify();
  }

  /// Downloads schedules (and permits first, if none are saved, so the
  /// cards can show business names). Keeps saved data on failure.
  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    fetchedCount = 0;
    error = null;
    _notify();
    try {
      final permitCount =
          await DBManager.instance.countRows(DBManager.tableTobaccoPermit);
      if (permitCount == 0) {
        try {
          await _repo.syncPermits();
        } catch (e) {
          debugPrint('⚠️ Tobacco permits (for schedules) error: $e');
        }
      }
      await _repo.syncSchedules(onProgress: (n) {
        fetchedCount = n;
        _notify();
      });
      _all = await _repo.getSavedSchedules(inspectorId: inspectorId);
    } catch (e) {
      error = e.toString();
      debugPrint('⚠️ Tobacco schedules sync error: $e');
    } finally {
      isLoading = false;
      initialised = true;
      _notify();
    }
  }

  /// Same name the other schedule view models use (Dashboard sync).
  Future<void> syncSchedules() => refresh();

  /// DB first, then API.
  Future<void> init() async {
    await loadFromDb();
    await refresh();
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
