import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/FoodInspectionReposiratory.dart';

import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/Food/Schedule/Model/FoodInspectionScheduleModel.dart';
// Reuse the same Upcoming / Today / Past / All filter as Mobile Food.
import 'package:quincy/Inspections/MobileFood/Schedule/ViewModel/MobileFoodInspectionScheduleViewModel.dart'
    show ScheduleFilter, ScheduleFilterLabel;

export 'package:quincy/Inspections/MobileFood/Schedule/ViewModel/MobileFoodInspectionScheduleViewModel.dart'
    show ScheduleFilter, ScheduleFilterLabel;

/// API (paged, 200 per call) → repository → DB (food_inspection_schedules) → UI.
///
/// Path: lib/Inspections/Food/Schedule/ViewModel/FoodInspectionScheduleViewModel.dart
class FoodInspectionScheduleViewModel extends ChangeNotifier {
  FoodInspectionScheduleViewModel({
    FoodInspectionScheduleRepository? repository,
    DBManager? db,
    this.inspectorId,
  })  : _repo = repository ?? FoodInspectionScheduleRepository(),
        _db = db ?? DBManager.instance;

  final FoodInspectionScheduleRepository _repo;
  final DBManager _db;

  /// Pass the logged-in inspector's id to show only their schedules.
  final int? inspectorId;

  List<FoodInspectionScheduleModel> _all = [];
  bool _isLoading = false;
  bool _initialised = false;
  String? _error;
  String _query = '';
  ScheduleFilter _filter = ScheduleFilter.upcoming;
  bool _disposed = false;
  int _fetchedCount = 0;

  bool get isLoading => _isLoading;
  bool get initialised => _initialised;
  String? get error => _error;
  String get query => _query;
  ScheduleFilter get filter => _filter;
  bool get hasData => _all.isNotEmpty;
  int get totalCount => _all.length;
  int get fetchedCount => _fetchedCount;
  bool get showingCached => _error != null && _all.isNotEmpty;

  // ---------- Dashboard sync ----------

  /// Loads what is already saved in SQLite (no API call).
  Future<void> loadFromDb() async {
    try {
      _all = await _db.getFoodInspectionSchedules(inspectorId: inspectorId);
    } catch (e) {
      debugPrint('⚠️ Food schedule DB read error: $e');
    }
    _initialised = true;
    _notify();
  }

  /// food/get-inspection-shedules (all pages) → food_inspection_schedules.
  Future<void> syncSchedules() => refresh();

  /// Shows saved rows immediately, then refreshes from the server.
  Future<void> init() async {
    await loadFromDb();
    await refresh();
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    _fetchedCount = 0;
    _notify();

    try {
      final token = await _db.getAccessToken();
      if (token == null || token.isEmpty) {
        _error = 'You are not logged in.';
        return;
      }

      final schedules = await _repo.getAllInspectionSchedules(
        token: token,
        onPage: (n) {
          _fetchedCount = n;
          _notify();
        },
      );
      debugPrint('🍽️ food schedules fetched: ${schedules.length}');

      // Saved only after every page succeeded.
      await _db.saveFoodInspectionSchedules(schedules);
      _all = await _db.getFoodInspectionSchedules(inspectorId: inspectorId);
    } on FoodScheduleFetchFailed {
      _error = 'The server could not return schedules.';
    } on NoInternetException {
      _error = 'No internet connection.';
    } on TimeoutApiException {
      _error = 'The server took too long to respond.';
    } on InvalidResponseException {
      _error = 'Unexpected response from the server.';
    } catch (e, st) {
      debugPrint('⚠️ Food schedule sync error (${e.runtimeType}): $e\n$st');
      final msg = e.toString().trim();
      _error = msg.isEmpty || msg.startsWith('Instance of')
          ? 'Could not load schedules. Please try again.'
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

  void setFilter(ScheduleFilter value) {
    if (_filter == value) return;
    _filter = value;
    _notify();
  }

  /// Filtered + searched list. Past is shown newest first.
  List<FoodInspectionScheduleModel> get schedules {
    final today = _dateOnly(DateTime.now());

    final list = _all.where((s) {
      final d =
          s.scheduleDateTime == null ? null : _dateOnly(s.scheduleDateTime!);
      switch (_filter) {
        case ScheduleFilter.upcoming:
          if (d != null && d.isBefore(today)) return false;
          break;
        case ScheduleFilter.today:
          if (d == null || d != today) return false;
          break;
        case ScheduleFilter.past:
          if (d == null || !d.isBefore(today)) return false;
          break;
        case ScheduleFilter.all:
          break;
      }
      if (_query.isEmpty) return true;
      return [
        s.jobCode,
        s.businessName,
        s.permitNumber,
        s.businessAddress,
        s.inspectorName,
      ].any((f) => f != null && f.toLowerCase().contains(_query));
    }).toList();

    if (_filter == ScheduleFilter.past) return list.reversed.toList();
    return list;
  }

  /// Schedules grouped by schedule_date, keeping list order.
  LinkedHashMap<String, List<FoodInspectionScheduleModel>> get grouped {
    final map = LinkedHashMap<String, List<FoodInspectionScheduleModel>>();
    for (final s in schedules) {
      map.putIfAbsent(s.scheduleDate ?? '', () => []).add(s);
    }
    return map;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}