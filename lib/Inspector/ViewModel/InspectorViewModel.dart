// lib/Inspections/Inspector/ViewModel/InspectorViewModel.dart
//
// Inspector list: GET /inspector → "inspectors" table → UI.
//
//   final vm = context.read<InspectorViewModel>();
//   await vm.loadFromDb();        // saved list (works offline)
//   await vm.syncInspectors();    // API → DB → refresh
//   vm.inspectors / vm.names / vm.findByName('John Smith')

import 'package:flutter/foundation.dart';
import 'package:quincy/API/InspectorLocalReposiratory.dart';


import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspector/Model/InspectorModel.dart';


class InspectorViewModel extends ChangeNotifier {
  InspectorViewModel({InspectorRepository? repository, DBManager? db})
      : _repo = repository ?? InspectorRepository(),
        _db = db ?? DBManager.instance;

  final InspectorRepository _repo;
  final DBManager _db;

  List<InspectorModel> _inspectors = [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  /// Active inspectors, sorted by name.
  List<InspectorModel> get inspectors => List.unmodifiable(_inspectors);

  /// Display names for a dropdown ("First Last").
  List<String> get names => _inspectors
      .map((i) => i.fullName)
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList();

  bool get isLoading => _isLoading;

  /// Last sync error (null = OK). The saved list is kept on error.
  String? get error => _error;

  bool get hasData => _inspectors.isNotEmpty;

  // ---------------- Load / Sync ----------------

  /// Reads the saved list from the inspectors table.
  Future<void> loadFromDb() async {
    try {
      _inspectors = await _db.getInspectors();
    } catch (e) {
      debugPrint('❌ Load inspectors from DB error: $e');
    }
    _notify();
  }

  /// GET /inspector → replaces the table → reloads the list.
  /// Returns true when the server list was saved.
  Future<bool> syncInspectors({String? token}) async {
    if (_isLoading) return false;
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final result = await _repo.fetchInspectors(token: token);
      if (!result.isSuccess) {
        _error = result.error ?? 'Could not load inspectors.';
        // keep the saved list so the app still works offline
        if (_inspectors.isEmpty) await loadFromDb();
        return false;
      }

      await _db.saveInspectors(result.data ?? const []);
      _inspectors = await _db.getInspectors();
      debugPrint('✅ Inspectors synced: ${_inspectors.length}');
      return true;
    } catch (e) {
      _error = 'Could not save inspectors: $e';
      debugPrint('❌ Sync inspectors error: $e');
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  // ---------------- Lookups ----------------

  InspectorModel? findById(int? id) {
    if (id == null) return null;
    for (final i in _inspectors) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Case-insensitive match on "First Last" (or nick name).
  InspectorModel? findByName(String? name) {
    final n = name?.trim().toLowerCase() ?? '';
    if (n.isEmpty) return null;
    for (final i in _inspectors) {
      if (i.fullName.toLowerCase() == n || i.nickName.toLowerCase() == n) {
        return i;
      }
    }
    return null;
  }

  // ---------------- Internals ----------------

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}