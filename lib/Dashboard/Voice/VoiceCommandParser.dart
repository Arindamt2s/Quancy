import 'package:quincy/Dashboard/Model/InspectionMenu.dart';

enum VoiceAction { open, needCategory, collapse, logout, stop, help, unknown }

class VoiceCommand {
  final VoiceAction action;
  final InspectionMenu? inspection;
  final MenuCategory? category;
  final MenuSubCategory? sub;

  const VoiceCommand(this.action, {this.inspection, this.category, this.sub});
}

class VoiceCommandParser {
  // Inspection id -> spoken words that point to it
  static const Map<int, List<String>> _inspectionKeywords = {
    1: ['food', 'temp', 'temporary', 'mobile', 'restaurant'],
    2: ['tobacco', 'smoke', 'smoking', 'cigarette'],
    3: ['nursing', 'nurse', 'elderly'],
    4: ['pool', 'swimming', 'swim'],
    5: ['complaint', 'complaints', 'complain'],
  };

  // Food Inspection category id -> words
  static const Map<int, List<String>> _foodCategoryKeywords = {
    2: ['temp', 'temporary'],
    3: ['mobile', 'truck', 'van'],
  };

  // Subcategory title (lowercase) -> words
  static const Map<String, List<String>> _subKeywords = {
    'new': ['new', 'create', 'start'],
    'incomplete': ['incomplete', 'in complete', 'pending', 'unfinished', 'not complete', 'not completed'],
    'schedule': ['schedule', 'scheduled', 'schedules', 'appointment'],
  };

  static VoiceCommand parse(
    String raw,
    List<InspectionMenu> menu, {
    InspectionMenu? currentInspection,
    MenuCategory? currentCategory,
  }) {
    final t = _normalize(raw);
    if (t.isEmpty) return const VoiceCommand(VoiceAction.unknown);

    // ---- General commands ----
    if (_has(t, ['logout', 'log out', 'sign out', 'signout'])) {
      return const VoiceCommand(VoiceAction.logout);
    }
    if (_has(t, ['stop', 'bye', 'goodbye', 'good bye', 'close assistant', 'go away', 'thats all', 'that is all'])) {
      return const VoiceCommand(VoiceAction.stop);
    }
    if (_has(t, ['help', 'what can you do', 'commands'])) {
      return const VoiceCommand(VoiceAction.help);
    }
    if (_has(t, ['close', 'collapse', 'go back', 'back', 'hide'])) {
      return const VoiceCommand(VoiceAction.collapse);
    }

    // ---- Inspection ----
    InspectionMenu? inspection;
    for (final entry in _inspectionKeywords.entries) {
      if (_has(t, entry.value)) {
        inspection = _byId(menu, entry.key);
        if (inspection != null) break;
      }
    }
    final fromContext = inspection == null;
    inspection ??= currentInspection;
    if (inspection == null) return const VoiceCommand(VoiceAction.unknown);

    // ---- Category (Food Inspection only) ----
    MenuCategory? category;
    if (inspection.hasCategories) {
      for (final c in inspection.categories) {
        final title = c.title.toLowerCase();
        if (title.contains(' ') && t.contains(title)) {
          category = c;
          break;
        }
      }
      if (category == null && inspection.id == 1) {
        for (final entry in _foodCategoryKeywords.entries) {
          if (_has(t, entry.value)) {
            category = _categoryById(inspection, entry.key);
            break;
          }
        }
      }
      if (category == null && fromContext) category = currentCategory;
    }

    // ---- Subcategory ----
    String? subKey;
    for (final entry in _subKeywords.entries) {
      if (_has(t, entry.value)) {
        subKey = entry.key;
        break;
      }
    }

    MenuSubCategory? sub;
    if (subKey != null) {
      if (inspection.hasCategories && category == null) {
        // "food new" -> Food > Food > New; just "new" with Food Inspection open -> ask which one
        if (!fromContext && _has(t, ['food'])) {
          category = inspection.categories.first;
        } else {
          return VoiceCommand(VoiceAction.needCategory, inspection: inspection);
        }
      }
      final subs = category?.subCategories ?? inspection.subCategories;
      for (final s in subs) {
        if (s.title.toLowerCase() == subKey) {
          sub = s;
          break;
        }
      }
    }

    return VoiceCommand(
      VoiceAction.open,
      inspection: inspection,
      category: category,
      sub: sub,
    );
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _has(String text, List<String> words) => words.any(
        (w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(text),
      );

  static InspectionMenu? _byId(List<InspectionMenu> menu, int id) {
    for (final m in menu) {
      if (m.id == id) return m;
    }
    return null;
  }

  static MenuCategory? _categoryById(InspectionMenu inspection, int id) {
    for (final c in inspection.categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}