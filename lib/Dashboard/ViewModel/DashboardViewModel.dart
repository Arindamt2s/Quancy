import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quincy/Dashboard/Model/InspectionMenu.dart';

class DashboardViewModel extends ChangeNotifier {
  // ---------------- Menu data ----------------
  List<InspectionMenu> _menu = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<InspectionMenu> get menu => _menu;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadMenu() async {
    if (_menu.isNotEmpty) return; // already loaded

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final jsonString =
          await rootBundle.loadString('assets/data/dashboard_menu.json');
      final Map<String, dynamic> data = jsonDecode(jsonString);

      _menu = (data['inspections'] as List)
          .map((e) => InspectionMenu.fromJson(e))
          .toList();
    } catch (e) {
      _errorMessage = 'Failed to load menu';
      debugPrint('❌ Menu load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------- Expansion state (used by voice commands) ----------------
  int? _expandedInspectionId;
  int? _expandedCategoryId;
  int _expandVersion = 0;

  int? get expandedInspectionId => _expandedInspectionId;
  int? get expandedCategoryId => _expandedCategoryId;
  int get expandVersion => _expandVersion;

  InspectionMenu? get expandedInspection {
    for (final m in _menu) {
      if (m.id == _expandedInspectionId) return m;
    }
    return null;
  }

  MenuCategory? get expandedCategory {
    final inspection = expandedInspection;
    if (inspection == null) return null;
    for (final c in inspection.categories) {
      if (c.id == _expandedCategoryId) return c;
    }
    return null;
  }

  /// Manual tap on an inspection tile: remember state only (no rebuild,
  /// so the tile's own expand animation isn't interrupted).
  void onInspectionToggled(int id, bool expanded) {
    if (expanded) {
      if (_expandedInspectionId != id) _expandedCategoryId = null;
      _expandedInspectionId = id;
    } else if (_expandedInspectionId == id) {
      _expandedInspectionId = null;
      _expandedCategoryId = null;
    }
  }

  /// Manual tap on a category tile (Food / Temp Food / Mobile Food).
  void onCategoryToggled(int inspectionId, int categoryId, bool expanded) {
    if (expanded) {
      _expandedInspectionId = inspectionId;
      _expandedCategoryId = categoryId;
    } else if (_expandedCategoryId == categoryId) {
      _expandedCategoryId = null;
    }
  }

  /// Voice command: open exactly this inspection (and category), close others.
  void expandTo({required int inspectionId, int? categoryId}) {
    _expandedInspectionId = inspectionId;
    _expandedCategoryId = categoryId;
    _expandVersion++;
    notifyListeners();
  }

  /// Voice command: collapse everything.
  void collapseAll() {
    _expandedInspectionId = null;
    _expandedCategoryId = null;
    _expandVersion++;
    notifyListeners();
  }

  /// Call on logout so the next user starts with a clean dashboard.
  void reset() {
    _expandedInspectionId = null;
    _expandedCategoryId = null;
    _expandVersion = 0;
    notifyListeners();
  }
}