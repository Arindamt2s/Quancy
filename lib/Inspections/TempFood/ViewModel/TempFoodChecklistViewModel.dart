import 'package:flutter/foundation.dart';
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/TempFoodApiClient.dart';
import 'package:quincy/API/TempFoodItemRepository.dart';
import 'package:quincy/API/TempFoodSectionPartRepository.dart';
import 'package:quincy/API/TempFoodSectionRepository.dart';

import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodSectionModel.dart';

/// temp-food/sections-list + section-parts-list + items-list
/// → temp_food_sections / temp_food_section_parts / temp_food_items
/// → Section → Parts → Items tree for the inspection form.
///
/// Path: lib/Inspections/TempFood/ViewModel/TempFoodChecklistViewModel.dart
class TempFoodChecklistViewModel extends ChangeNotifier {
  TempFoodChecklistViewModel({
    TempFoodSectionRepository? sectionRepo,
    TempFoodSectionPartRepository? partRepo,
    TempFoodItemRepository? itemRepo,
    DBManager? db,
  })  : _sectionRepo = sectionRepo ?? TempFoodSectionRepository(),
        _partRepo = partRepo ?? TempFoodSectionPartRepository(),
        _itemRepo = itemRepo ?? TempFoodItemRepository(),
        _db = db ?? DBManager.instance;

  final TempFoodSectionRepository _sectionRepo;
  final TempFoodSectionPartRepository _partRepo;
  final TempFoodItemRepository _itemRepo;
  final DBManager _db;

  List<TempFoodChecklistSectionNode> _tree = [];
  int _sectionCount = 0;
  int _partCount = 0;
  int _itemCount = 0;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  List<TempFoodChecklistSectionNode> get tree => List.unmodifiable(_tree);
  int get sectionCount => _sectionCount;
  int get partCount => _partCount;
  int get itemCount => _itemCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _itemCount > 0;
  bool get hasLocalData => hasData;

  /// Counts of what is already saved (no API call).
  Future<void> loadLocal() async {
    try {
      _sectionCount = await _db.countRows(DBManager.tableTempFoodSection);
      _partCount = await _db.countRows(DBManager.tableTempFoodSectionPart);
      _itemCount = await _db.countRows(DBManager.tableTempFoodItem);
    } catch (e) {
      debugPrint('⚠️ Temp Food checklist count error: $e');
    }
    _notify();
  }

  /// Section → Parts → Items from SQLite.
  Future<List<TempFoodChecklistSectionNode>> loadTree() async {
    _tree = await _db.getTempFoodChecklistTree();
    return _tree;
  }

  /// Downloads the 3 lists and replaces the saved ones.
  /// Returns true when everything was saved.
  Future<bool> sync() async {
    if (_isLoading) return false;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final token = await _db.getAccessToken();
      if (token == null || token.isEmpty) {
        _error = 'You are not logged in.';
        return false;
      }
      final results = await Future.wait([
        _sectionRepo.getSections(token: token),
        _partRepo.getSectionParts(token: token),
        _itemRepo.getItems(token: token),
      ]);
      final sections = results[0] as List<TempFoodSectionModel>;
      final parts = results[1] as List<TempFoodSectionPartModel>;
      final items = results[2] as List<TempFoodItemModel>;

      await _db.saveTempFoodSections(sections);
      await _db.saveTempFoodSectionParts(parts);
      await _db.saveTempFoodItems(items);

      _sectionCount = sections.length;
      _partCount = parts.length;
      _itemCount = items.length;
      await loadTree();
      debugPrint('🏕️ temp food checklist: $_sectionCount sections, '
          '$_partCount parts, $_itemCount items');
      return true;
    } on NoInternetException {
      _error = 'No internet connection.';
    } on TimeoutApiException {
      _error = 'The server took too long to respond.';
    } on InvalidResponseException {
      _error = 'Unexpected response from the server.';
    } on TempFoodApiException catch (e) {
      _error = e.message;
    } catch (e, st) {
      debugPrint('⚠️ Temp Food checklist sync error: $e\n$st');
      _error = 'Could not load the temporary food checklist.';
    } finally {
      _isLoading = false;
      _notify();
    }
    return false;
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
