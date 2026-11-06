/// Master data for the Mobile Food inspection form:
///   Section  →  Section Part  →  Item
///
/// Each model works for both the API JSON and a SQLite row
/// (same snake_case keys).

String _s(dynamic v) => v == null ? '' : v.toString();

int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString()) ?? 0;
}

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

bool _ok(dynamic status) => status == true || status == 1 || status == 'true';

// ---------------------------------------------------------------------------
// Section  (e.g. "FOODBORNE ILLNESS RISK FACTORS AND PUBLIC HEALTH INTERVENTIONS")
// ---------------------------------------------------------------------------

class MobileFoodSectionModel {
  final int id;
  final String name;
  final String points;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String deletedAt;

  const MobileFoodSectionModel({
    required this.id,
    this.name = '',
    this.points = '',
    this.status = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.deletedAt = '',
  });

  factory MobileFoodSectionModel.fromJson(Map<String, dynamic> json) =>
      MobileFoodSectionModel(
        id: _i(json['id']),
        name: _s(json['name']),
        points: _s(json['points']),
        status: _s(json['status']),
        createdAt: _s(json['created_at']),
        updatedAt: _s(json['updated_at']),
        deletedAt: _s(json['deleted_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'points': points,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class MobileFoodSectionResponse {
  final bool status;
  final List<MobileFoodSectionModel> sections;

  const MobileFoodSectionResponse({required this.status, required this.sections});

  factory MobileFoodSectionResponse.fromJson(Map<String, dynamic> json) =>
      MobileFoodSectionResponse(
        status: _ok(json['status']),
        sections:
            _list(json['sections']).map(MobileFoodSectionModel.fromJson).toList(),
      );
}

// ---------------------------------------------------------------------------
// Section Part  (e.g. "Supervision", "Employee Health")
// ---------------------------------------------------------------------------

class MobileFoodSectionPartModel {
  final int id;
  final int foodSectionId;
  final String name;
  final String status;
  final String displayOrder;
  final String createdAt;
  final String updatedAt;
  final String deletedAt;

  const MobileFoodSectionPartModel({
    required this.id,
    required this.foodSectionId,
    this.name = '',
    this.status = '',
    this.displayOrder = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.deletedAt = '',
  });

  factory MobileFoodSectionPartModel.fromJson(Map<String, dynamic> json) =>
      MobileFoodSectionPartModel(
        id: _i(json['id']),
        foodSectionId: _i(json['food_section_id']),
        name: _s(json['name']),
        status: _s(json['status']),
        displayOrder: _s(json['display_order']),
        createdAt: _s(json['created_at']),
        updatedAt: _s(json['updated_at']),
        deletedAt: _s(json['deleted_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'food_section_id': foodSectionId,
        'name': name,
        'status': status,
        'display_order': displayOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class MobileFoodSectionPartResponse {
  final bool status;
  final List<MobileFoodSectionPartModel> sectionParts;

  const MobileFoodSectionPartResponse({
    required this.status,
    required this.sectionParts,
  });

  factory MobileFoodSectionPartResponse.fromJson(Map<String, dynamic> json) =>
      MobileFoodSectionPartResponse(
        status: _ok(json['status']),
        sectionParts: _list(json['sectionParts'] ?? json['section_parts'])
            .map(MobileFoodSectionPartModel.fromJson)
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// Item  (e.g. "1. Person-in-charge present, demonstrates knowledge…")
// ---------------------------------------------------------------------------

class MobileFoodItemModel {
  final int id;
  final int serialNumber;
  final int foodSectionPartId;
  final String name;
  final String point;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String deletedAt;

  const MobileFoodItemModel({
    required this.id,
    required this.foodSectionPartId,
    this.serialNumber = 0,
    this.name = '',
    this.point = '',
    this.status = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.deletedAt = '',
  });

  factory MobileFoodItemModel.fromJson(Map<String, dynamic> json) =>
      MobileFoodItemModel(
        id: _i(json['id']),
        serialNumber: _i(json['serial_number']),
        foodSectionPartId: _i(json['food_section_part_id']),
        name: _s(json['name']),
        point: _s(json['point']),
        status: _s(json['status']),
        createdAt: _s(json['created_at']),
        updatedAt: _s(json['updated_at']),
        deletedAt: _s(json['deleted_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'serial_number': serialNumber,
        'food_section_part_id': foodSectionPartId,
        'name': name,
        'point': point,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class MobileFoodItemResponse {
  final bool status;
  final List<MobileFoodItemModel> items;

  const MobileFoodItemResponse({required this.status, required this.items});

  factory MobileFoodItemResponse.fromJson(Map<String, dynamic> json) =>
      MobileFoodItemResponse(
        status: _ok(json['status']),
        items: _list(json['items']).map(MobileFoodItemModel.fromJson).toList(),
      );
}

// ---------------------------------------------------------------------------
// Tree used by the Inspection Form:  Section → Parts → Items
// Built from one JOIN query (DBManager.getMobileFoodChecklistTree).
// ---------------------------------------------------------------------------

class ChecklistPartNode {
  final MobileFoodSectionPartModel part;
  final List<MobileFoodItemModel> items;

  ChecklistPartNode(this.part, this.items);
}

class ChecklistSectionNode {
  final MobileFoodSectionModel section;
  final List<ChecklistPartNode> parts;

  ChecklistSectionNode(this.section, this.parts);

  int get itemCount => parts.fold(0, (sum, p) => sum + p.items.length);
}