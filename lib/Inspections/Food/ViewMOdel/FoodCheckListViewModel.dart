import 'package:flutter/foundation.dart';
import 'package:quincy/API/FoodCheckListReposiratory.dart';

import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/Food/Model/FoodSectionModel.dart';

/// Food checklist (Sections → Parts → Items), offline-first.
///
/// * [sync] downloads the 3 lists and replaces the local tables.
///   Call it from the Dashboard (with internet), like Mobile Food.
/// * [loadTree] reads the tree from the database (works offline).
class FoodChecklistViewModel extends ChangeNotifier {
  FoodChecklistViewModel({FoodChecklistApiRepository? api})
      : _api = api ?? FoodChecklistApiRepository();

  final FoodChecklistApiRepository _api;
  final DBManager _db = DBManager.instance;

  List<FoodChecklistSectionNode> _tree = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;

  List<FoodChecklistSectionNode> get tree => _tree;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;
  bool get hasData => _tree.isNotEmpty;

  /// Same name as MobileFoodChecklistViewModel, for the Dashboard.
  bool get hasLocalData => hasData;

  /// Counts for the Dashboard sync loader.
  int get sectionCount => _tree.length;
  int get partCount => _tree.fold(0, (s, n) => s + n.parts.length);
  int get itemCount => _tree.fold(0, (s, n) => s + n.itemCount);

  /// Loads what is already saved (Dashboard "prepare" step).
  Future<void> loadLocal() async {
    try {
      await loadTree();
    } catch (e) {
      debugPrint('❌ Load Food checklist error: $e');
    }
  }

  /// Tree from the database.
  Future<List<FoodChecklistSectionNode>> loadTree() async {
    _tree = await _db.getFoodChecklistTree();
    notifyListeners();
    return _tree;
  }

  /// Downloads sections, parts and items. The local tables are only
  /// replaced when ALL three calls succeed, so a failed sync never leaves
  /// a half-filled checklist. Returns true on success.
  Future<bool> sync({String? token}) async {
    if (_isLoading) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.fetchSections(token: token),
        _api.fetchSectionParts(token: token),
        _api.fetchItems(token: token),
      ]);

      final failed = results.where((r) => !r.isSuccess).toList();
      if (failed.isNotEmpty) {
        _error = failed.first.error;
        _isOffline = failed.any((r) => r.isOffline);
        await loadTree(); // keep showing what is saved
        return false;
      }

      await _db.saveFoodSections(
          results[0].data! as List<FoodSectionModel>);
      await _db.saveFoodSectionParts(
          results[1].data! as List<FoodSectionPartModel>);
      await _db.saveFoodItems(results[2].data! as List<FoodItemModel>);

      _isOffline = false;
      await loadTree();
      debugPrint('✅ Food checklist synced: ${_tree.length} sections, '
          '$itemCount items');
      return true;
    } catch (e) {
      debugPrint('❌ Food checklist sync error: $e');
      _error = 'Could not sync the Food checklist.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}