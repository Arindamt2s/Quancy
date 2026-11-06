import 'package:quincy/Inspections/Tobacco/Model/TobaccoJson.dart';

/// Checklist from GET /tobacco/get-section-details.
///
/// Path: lib/Inspections/Tobacco/Model/TobaccoSectionModel.dart
///
/// API shape:
///   section[]                         GENERAL, SIGNAGE, …
///     items[]                         top-level questions (parent_id "")
///       children[]                    options / sub-questions (parent_id = item.id)
///         subsection {id, name}       only for product sub-questions
///                                     ("Cigarettes", "Vape Products", …)
///
/// Rules (same as the web form):
/// * status 0 → hidden.
/// * answer_type "yes_no" / "yes_no_na" → YES / NO (/ NA) buttons.
/// * children WITHOUT subsection → checkbox options.
/// * children WITH subsection → grouped under a blue sub-section header,
///   each child is its own YES / NO question labelled with item_id (A, B…).

enum TobaccoAnswerType { yesNo, yesNoNa, none }

/// How a top-level question is shown.
enum TobaccoItemKind {
  /// YES / NO (/ NA). If it has children they are reasons shown on "NO".
  yesNo,

  /// Checkbox options (single choice when the text says "Choose one").
  checkboxes,

  /// Product questions grouped by sub-section.
  productGroups,

  /// Free text (answer_type "" and no options).
  text,
}

TobaccoAnswerType tobaccoAnswerTypeFrom(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'yes_no':
      return TobaccoAnswerType.yesNo;
    case 'yes_no_na':
      return TobaccoAnswerType.yesNoNa;
    default:
      return TobaccoAnswerType.none;
  }
}

// ---------------------------------------------------------------- Section

class TobaccoSectionModel {
  final int id;
  final String name;
  final int status;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  /// Top-level questions (children attached).
  final List<TobaccoItemModel> items;

  TobaccoSectionModel({
    required this.id,
    required this.name,
    this.status = 1,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    List<TobaccoItemModel>? items,
  }) : items = items ?? [];

  bool get isActive => status == 1 && (deletedAt ?? '').isEmpty;

  List<TobaccoItemModel> get activeItems =>
      items.where((e) => e.isActive).toList();

  factory TobaccoSectionModel.fromJson(Map<String, dynamic> j,
      {int sortOrder = 0}) {
    return TobaccoSectionModel(
      id: tbInt(j['id']) ?? 0,
      name: tbStr(j['name']) ?? '',
      status: tbInt(j['status']) ?? 1,
      sortOrder: sortOrder,
      createdAt: tbStr(j['created_at']),
      updatedAt: tbStr(j['updated_at']),
      deletedAt: tbStr(j['deleted_at']),
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'name': name,
        'status': status,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  factory TobaccoSectionModel.fromDb(Map<String, Object?> r) =>
      TobaccoSectionModel(
        id: tbInt(r['id']) ?? 0,
        name: tbStr(r['name']) ?? '',
        status: tbInt(r['status']) ?? 1,
        sortOrder: tbInt(r['sort_order']) ?? 0,
        createdAt: tbStr(r['created_at']),
        updatedAt: tbStr(r['updated_at']),
        deletedAt: tbStr(r['deleted_at']),
      );
}

// ------------------------------------------------------------- Sub-section

class TobaccoSubSectionModel {
  final int id;
  final int sectionId;
  final String name;
  final int status;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  const TobaccoSubSectionModel({
    required this.id,
    required this.sectionId,
    required this.name,
    this.status = 1,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory TobaccoSubSectionModel.fromJson(Map<String, dynamic> j) =>
      TobaccoSubSectionModel(
        id: tbInt(j['id']) ?? 0,
        sectionId: tbInt(j['section_id']) ?? 0,
        name: tbStr(j['name']) ?? '',
        status: tbInt(j['status']) ?? 1,
        createdAt: tbStr(j['created_at']),
        updatedAt: tbStr(j['updated_at']),
        deletedAt: tbStr(j['deleted_at']),
      );

  Map<String, Object?> toDb() => {
        'id': id,
        'section_id': sectionId,
        'name': name,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  factory TobaccoSubSectionModel.fromDb(Map<String, Object?> r) =>
      TobaccoSubSectionModel.fromJson(Map<String, dynamic>.from(r));
}

// -------------------------------------------------------------------- Item

class TobaccoItemModel {
  final int id;
  final int sectionId;
  final int? subSectionId;

  /// API "item_id": the web number ("1", "2") or letter ("A", "B").
  final String? itemLabel;
  final int? parentId;
  final String name;
  final String? answerTypeRaw;
  final int status;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  TobaccoSubSectionModel? subsection;
  final List<TobaccoItemModel> children;

  TobaccoItemModel({
    required this.id,
    required this.sectionId,
    this.subSectionId,
    this.itemLabel,
    this.parentId,
    required this.name,
    this.answerTypeRaw,
    this.status = 1,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.subsection,
    List<TobaccoItemModel>? children,
  }) : children = children ?? [];

  bool get isActive => status == 1 && (deletedAt ?? '').isEmpty;

  TobaccoAnswerType get answerType => tobaccoAnswerTypeFrom(answerTypeRaw);

  bool get hasNa => answerType == TobaccoAnswerType.yesNoNa;

  List<TobaccoItemModel> get activeChildren =>
      children.where((e) => e.isActive).toList();

  /// "Choose one best store type:" → only one checkbox at a time.
  bool get isSingleChoice => name.trim().toLowerCase().startsWith('choose one');

  /// "Other:" / "Other :" options get a text box when checked.
  bool get isOtherOption => name.trim().toLowerCase().startsWith('other');

  TobaccoItemKind get kind {
    final kids = activeChildren;
    if (kids.isNotEmpty && kids.any((c) => c.subSectionId != null)) {
      return TobaccoItemKind.productGroups;
    }
    if (answerType != TobaccoAnswerType.none) {
      return TobaccoItemKind.yesNo;
    }
    if (kids.isNotEmpty) return TobaccoItemKind.checkboxes;
    return TobaccoItemKind.text;
  }

  /// Product children grouped by sub-section, in API order.
  List<TobaccoProductGroup> get productGroups {
    final groups = <TobaccoProductGroup>[];
    for (final c in activeChildren) {
      final key = c.subSectionId ?? -1;
      if (groups.isEmpty || groups.last.key != key) {
        groups.add(TobaccoProductGroup(
          key: key,
          title: c.subsection?.name ?? '',
          items: [],
        ));
      }
      groups.last.items.add(c);
    }
    return groups;
  }

  /// [counter] gives every item (children too) a global sort order.
  factory TobaccoItemModel.fromJson(Map<String, dynamic> j,
      {required int Function() counter}) {
    final sub = j['subsection'];
    final item = TobaccoItemModel(
      id: tbInt(j['id']) ?? 0,
      sectionId: tbInt(j['section_id']) ?? 0,
      subSectionId: tbInt(j['sub_section_id']),
      itemLabel: tbStr(j['item_id']),
      parentId: tbInt(j['parent_id']),
      name: tbStr(j['name']) ?? '',
      answerTypeRaw: tbStr(j['answer_type']),
      status: tbInt(j['status']) ?? 1,
      sortOrder: counter(),
      createdAt: tbStr(j['created_at']),
      updatedAt: tbStr(j['updated_at']),
      deletedAt: tbStr(j['deleted_at']),
      subsection: sub is Map
          ? TobaccoSubSectionModel.fromJson(Map<String, dynamic>.from(sub))
          : null,
    );
    final kids = j['children'];
    if (kids is List) {
      for (final k in kids) {
        if (k is Map) {
          item.children.add(TobaccoItemModel.fromJson(
              Map<String, dynamic>.from(k),
              counter: counter));
        }
      }
    }
    return item;
  }

  /// Row for tobacco_items (children are separate rows linked by parent_id).
  Map<String, Object?> toDb() => {
        'id': id,
        'section_id': sectionId,
        'sub_section_id': subSectionId,
        'item_label': itemLabel,
        'parent_id': parentId,
        'name': name,
        'answer_type': answerTypeRaw,
        'status': status,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  factory TobaccoItemModel.fromDb(Map<String, Object?> r) => TobaccoItemModel(
        id: tbInt(r['id']) ?? 0,
        sectionId: tbInt(r['section_id']) ?? 0,
        subSectionId: tbInt(r['sub_section_id']),
        itemLabel: tbStr(r['item_label']),
        parentId: tbInt(r['parent_id']),
        name: tbStr(r['name']) ?? '',
        answerTypeRaw: tbStr(r['answer_type']),
        status: tbInt(r['status']) ?? 1,
        sortOrder: tbInt(r['sort_order']) ?? 0,
        createdAt: tbStr(r['created_at']),
        updatedAt: tbStr(r['updated_at']),
        deletedAt: tbStr(r['deleted_at']),
      );

  /// This item and all its children, flattened.
  Iterable<TobaccoItemModel> flatten() sync* {
    yield this;
    for (final c in children) {
      yield* c.flatten();
    }
  }
}

class TobaccoProductGroup {
  final int key;
  final String title;
  final List<TobaccoItemModel> items;
  TobaccoProductGroup(
      {required this.key, required this.title, required this.items});
}

// ------------------------------------------------------------ API parsing

/// Everything one section-details call returns, flattened for SQLite.
class TobaccoChecklistData {
  final List<TobaccoSectionModel> sections;
  final List<TobaccoSubSectionModel> subSections;
  final List<TobaccoItemModel> items;

  TobaccoChecklistData(this.sections, this.subSections, this.items);

  bool get isEmpty => sections.isEmpty;

  factory TobaccoChecklistData.fromResponse(Map<String, dynamic> json) {
    final sections = <TobaccoSectionModel>[];
    final subs = <int, TobaccoSubSectionModel>{};
    final items = <TobaccoItemModel>[];
    var order = 0;
    int next() => order++;

    final list = json['section'] ?? json['sections'] ?? json['data'];
    if (list is List) {
      for (var i = 0; i < list.length; i++) {
        final s = list[i];
        if (s is! Map) continue;
        final sm = Map<String, dynamic>.from(s);
        sections.add(TobaccoSectionModel.fromJson(sm, sortOrder: i));
        final its = sm['items'];
        if (its is! List) continue;
        for (final it in its) {
          if (it is! Map) continue;
          final item = TobaccoItemModel.fromJson(
              Map<String, dynamic>.from(it),
              counter: next);
          for (final f in item.flatten()) {
            items.add(f);
            final sub = f.subsection;
            if (sub != null) subs[sub.id] = sub;
          }
        }
      }
    }
    return TobaccoChecklistData(sections, subs.values.toList(), items);
  }

  /// Rebuilds sections → items → children from flat (DB) rows.
  static List<TobaccoSectionModel> buildTree(
    List<TobaccoSectionModel> sections,
    List<TobaccoSubSectionModel> subSections,
    List<TobaccoItemModel> items,
  ) {
    final subById = {for (final s in subSections) s.id: s};
    final byId = <int, TobaccoItemModel>{};
    final sorted = [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final it in sorted) {
      if (it.subSectionId != null) it.subsection = subById[it.subSectionId];
      byId[it.id] = it;
    }
    final sectionById = {for (final s in sections) s.id: s};
    for (final s in sections) {
      s.items.clear();
    }
    for (final it in sorted) {
      final parent = it.parentId == null ? null : byId[it.parentId];
      if (parent != null) {
        parent.children.add(it);
      } else {
        sectionById[it.sectionId]?.items.add(it);
      }
    }
    return [...sections]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}
