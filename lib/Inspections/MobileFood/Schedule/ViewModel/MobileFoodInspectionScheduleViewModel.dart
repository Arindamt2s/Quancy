import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/MobileFoodInspectionScheduleReposiratory.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/MobileFood/Schedule/Model/MobileFoodInspectionscheduleModel.dart';


enum ScheduleFilter { upcoming, today, past, all }

extension ScheduleFilterLabel on ScheduleFilter {
  String get label {
    switch (this) {
      case ScheduleFilter.upcoming:
        return 'Upcoming';
      case ScheduleFilter.today:
        return 'Today';
      case ScheduleFilter.past:
        return 'Past';
      case ScheduleFilter.all:
        return 'All';
    }
  }
}

/// API → repository → DB (mobile_food_inspection_schedules) → UI.
/// Same flow as the permit ViewModel: the repository only calls the API,
/// this ViewModel saves the result and reads it back from SQLite.
class MobileFoodInspectionScheduleViewModel extends ChangeNotifier {
  MobileFoodInspectionScheduleViewModel({
    MobileFoodInspectionScheduleRepository? repository,
    DBManager? db,
    this.inspectorId,
  })  : _repo = repository ?? MobileFoodInspectionScheduleRepository(),
        _db = db ?? DBManager.instance;

  final MobileFoodInspectionScheduleRepository _repo;
  final DBManager _db;

  /// Pass the logged-in inspector's id to show only their schedules.
  final int? inspectorId;

  List<MobileFoodInspectionScheduleModel> _all = [];
  bool _isLoading = false;
  bool _initialised = false;
  String? _error;
  String _query = '';
  ScheduleFilter _filter = ScheduleFilter.upcoming;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  bool get initialised => _initialised;
  String? get error => _error;
  String get query => _query;
  ScheduleFilter get filter => _filter;
  bool get hasData => _all.isNotEmpty;

  /// All saved schedules (ignores search / filter) – for the sync loader.
  int get totalCount => _all.length;

  /// True when the last refresh failed but saved rows are shown.
  bool get showingCached => _error != null && _all.isNotEmpty;

  // ---------- Used by the Dashboard sync (same pattern as other VMs) ----------

  /// Loads what is already saved in SQLite (no API call).
  Future<void> loadFromDb() async {
    try {
      _all = await _db.getMobileFoodInspectionSchedules(
          inspectorId: inspectorId);
    } catch (e) {
      debugPrint('⚠️ Schedule DB read error: $e');
    }
    _initialised = true;
    _notify();
  }

  /// get-inspection-schedules → mobile_food_inspection_schedules table.
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
    _notify();

    try {
      final token = await _db.getAccessToken();
      if (token == null || token.isEmpty) {
        _error = 'You are not logged in.';
        return;
      }

      final response = await _repo.getInspectionSchedules(token: token);
      debugPrint('📅 status=${response.success}, '
          'schedules=${response.schedules.length}');

      if (!response.success) {
        _error = 'The server could not return schedules.';
        return;
      }

      await _db.saveMobileFoodInspectionSchedules(response.schedules);
      _all = await _db.getMobileFoodInspectionSchedules(
          inspectorId: inspectorId);
    } on NoInternetException {
      _error = 'No internet connection.';
    } on TimeoutApiException {
      _error = 'The server took too long to respond.';
    } on InvalidResponseException {
      _error = 'Unexpected response from the server.';
    } catch (e, st) {
      debugPrint('⚠️ Schedule sync error (${e.runtimeType}): $e\n$st');
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
  List<MobileFoodInspectionScheduleModel> get schedules {
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

    if (_filter == ScheduleFilter.past) {
      return list.reversed.toList();
    }
    return list;
  }

  /// Schedules grouped by schedule_date, keeping list order.
  LinkedHashMap<String, List<MobileFoodInspectionScheduleModel>> get grouped {
    final map =
        LinkedHashMap<String, List<MobileFoodInspectionScheduleModel>>();
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