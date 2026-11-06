import 'package:flutter/foundation.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoSectionModel.dart';
import 'package:quincy/API/TobaccoRepository.dart';

/// Tobacco checklist (get-section-details) for the Dashboard sync:
/// loads what is saved, downloads the latest, and gives counts.
///
/// Path: lib/Inspections/Tobacco/ViewModel/TobaccoChecklistViewModel.dart
class TobaccoChecklistViewModel extends ChangeNotifier {
  TobaccoChecklistViewModel({TobaccoRepository? repository})
      : _repo = repository ?? TobaccoRepository();

  final TobaccoRepository _repo;

  List<TobaccoSectionModel> _sections = const [];
  bool isLoading = false;
  String? error;
  bool _disposed = false;

  List<TobaccoSectionModel> get sections => _sections;
  bool get hasData => _sections.isNotEmpty;

  int get sectionCount => _sections.length;

  /// Sub-sections ("Cigarettes", "Vape Products" …).
  int get subSectionCount {
    final ids = <int>{};
    for (final s in _sections) {
      for (final i in s.items) {
        for (final c in i.flatten()) {
          if (c.subSectionId != null) ids.add(c.subSectionId!);
        }
      }
    }
    return ids.length;
  }

  /// Every item row (questions, options, product sub-questions).
  int get itemCount =>
      _sections.fold(0, (n, s) => n + s.items.fold(0, (m, i) => m + i.flatten().length));

  Future<void> loadLocal() async {
    try {
      _sections = await _repo.getSavedChecklist();
    } catch (e) {
      debugPrint('⚠️ Tobacco checklist DB error: $e');
    }
    _notify();
  }

  Future<void> sync() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    _notify();
    try {
      await _repo.syncChecklist();
      _sections = await _repo.getSavedChecklist();
    } catch (e) {
      error = e.toString();
      debugPrint('⚠️ Tobacco checklist sync error: $e');
    } finally {
      isLoading = false;
      _notify();
    }
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
