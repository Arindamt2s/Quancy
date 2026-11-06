import 'package:flutter/foundation.dart';
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/MobileFoodChecklistRepository.dart';

import 'package:quincy/Database/DBManager.dart'; // TODO: adjust to your DBManager path

import 'package:quincy/Inspections/MobileFood/Model/MobileFoodSectionModel.dart';

import 'package:quincy/Utilities/SyncStatus.dart';

/// The three master-data downloads for the Mobile Food inspection form.
enum ChecklistTask { sections, sectionParts, items }

/// Downloads Sections → Section Parts → Items, saves them to SQLite and
/// exposes them (with per-task progress for the smart loader).
class MobileFoodChecklistViewModel extends ChangeNotifier {
  MobileFoodChecklistViewModel({MobileFoodChecklistRepository? repository})
      : _repository = repository ?? MobileFoodChecklistRepository();

  final MobileFoodChecklistRepository _repository;
  final DBManager _db = DBManager.instance;

  // ---------------- Data ----------------
  List<MobileFoodSectionModel> _sections = [];
  List<MobileFoodSectionPartModel> _parts = [];
  List<MobileFoodItemModel> _items = [];

  List<MobileFoodSectionModel> get sections => _sections;
  List<MobileFoodSectionPartModel> get sectionParts => _parts;
  List<MobileFoodItemModel> get items => _items;

  /// True when the form can be built from saved data.
  bool get hasLocalData =>
      _sections.isNotEmpty && _parts.isNotEmpty && _items.isNotEmpty;

  List<MobileFoodSectionPartModel> partsFor(int sectionId) =>
      _parts.where((p) => p.foodSectionId == sectionId).toList();

  List<MobileFoodItemModel> itemsFor(int partId) =>
      _items.where((i) => i.foodSectionPartId == partId).toList();

  // ---------------- Sync state ----------------
  final Map<ChecklistTask, SyncStatus> _status = {
    for (final t in ChecklistTask.values) t: SyncStatus.pending,
  };
  final Map<ChecklistTask, int> _count = {
    for (final t in ChecklistTask.values) t: 0,
  };
  final Map<ChecklistTask, String?> _error = {};

  bool _isSyncing = false;
  DateTime? _lastSynced;

  SyncStatus statusOf(ChecklistTask t) => _status[t]!;
  int countOf(ChecklistTask t) => _count[t]!;
  String? errorOf(ChecklistTask t) => _error[t];
  bool get isSyncing => _isSyncing;
  DateTime? get lastSynced => _lastSynced;

  // ---------------- Public API ----------------

  /// Section → Parts → Items for the Inspection Form (one JOIN query).
  Future<List<ChecklistSectionNode>> loadTree() =>
      _db.getMobileFoodChecklistTree();

  /// Reads whatever is already saved (no network).
  Future<void> loadLocal() async {
    _sections = await _db.getMobileFoodSections();
    _parts = await _db.getMobileFoodSectionParts();
    _items = await _db.getMobileFoodItems();
    _count[ChecklistTask.sections] = _sections.length;
    _count[ChecklistTask.sectionParts] = _parts.length;
    _count[ChecklistTask.items] = _items.length;
    notifyListeners();
  }

  /// Calls the 3 APIs in parallel. Each one is saved to its table as soon as
  /// it arrives. A failed call falls back to the saved data for that table.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    for (final t in ChecklistTask.values) {
      _status[t] = SyncStatus.loading;
      _error[t] = null;
    }
    notifyListeners();

    final token = await _db.getAccessToken();

    if (token == null || token.isEmpty) {
      for (final t in ChecklistTask.values) {
        await _fallback(t, 'Session expired. Please log in again.');
      }
    } else {
      await Future.wait([
        _run(ChecklistTask.sections, () async {
          final r = await _repository.getSections(token: token);
          if (!r.status) throw Exception('Failed to load sections.');
          await _db.saveMobileFoodSections(r.sections);
          return r.sections.length;
        }),
        _run(ChecklistTask.sectionParts, () async {
          final r = await _repository.getSectionParts(token: token);
          if (!r.status) throw Exception('Failed to load section parts.');
          await _db.saveMobileFoodSectionParts(r.sectionParts);
          return r.sectionParts.length;
        }),
        _run(ChecklistTask.items, () async {
          final r = await _repository.getItems(token: token);
          if (!r.status) throw Exception('Failed to load items.');
          await _db.saveMobileFoodItems(r.items);
          return r.items.length;
        }),
      ]);
    }

    await loadLocal();
    if (ChecklistTask.values.any((t) => _status[t] == SyncStatus.done)) {
      _lastSynced = DateTime.now();
    }
    _isSyncing = false;
    notifyListeners();
  }

  // ---------------- Internals ----------------

  Future<void> _run(ChecklistTask task, Future<int> Function() job) async {
    try {
      final count = await job();
      _count[task] = count;
      _status[task] = SyncStatus.done;
      debugPrint('✅ ${task.name}: $count saved');
    } catch (e) {
      debugPrint('❌ ${task.name} sync error: $e');
      await _fallback(task, _friendlyError(e));
    }
    notifyListeners();
  }

  /// API failed → use saved rows if there are any.
  Future<void> _fallback(ChecklistTask task, String message) async {
    final table = switch (task) {
      ChecklistTask.sections => DBManager.tableMobileFoodSection,
      ChecklistTask.sectionParts => DBManager.tableMobileFoodSectionPart,
      ChecklistTask.items => DBManager.tableMobileFoodItem,
    };
    final saved = await _db.countRows(table);
    _count[task] = saved;
    _status[task] = saved > 0 ? SyncStatus.offline : SyncStatus.failed;
    _error[task] = message;
  }

  String _friendlyError(Object e) {
    if (e is NoInternetException) return 'No internet connection.';
    if (e is TimeoutApiException) return 'Request timed out.';
    if (e is InvalidResponseException) return 'Invalid response from server.';
    return e.toString().replaceFirst('Exception: ', '');
  }
}