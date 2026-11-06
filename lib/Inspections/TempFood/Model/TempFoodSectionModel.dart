/// Temporary Food checklist: sections → section parts → items.
/// Same fields as the Food checklist, so the PDF builder can reuse them.
///
/// toJson() keys = DB columns (temp_food_sections / _section_parts / _items)
/// fromJson() reads both the DB columns and the API keys.
///
/// Path: lib/Inspections/TempFood/Model/TempFoodSectionModel.dart

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s == 'null' ? null : s;
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString());
}

/// The DB query keeps only status 'active' (or empty).
/// The API may send 1 / 0 / true / "Active" – normalise them.
String _status(dynamic v) {
  if (v == null) return 'active';
  if (v == true || v == 1 || v.toString() == '1') return 'active';
  if (v == false || v == 0 || v.toString() == '0') return 'inactive';
  final s = v.toString().trim().toLowerCase();
  return s.isEmpty ? 'active' : s;
}

class TempFoodSectionModel {
  final int id;
  final String name;
  final String? points;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  const TempFoodSectionModel({
    required this.id,
    required this.name,
    this.points,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory TempFoodSectionModel.fromJson(Map<String, dynamic> j) =>
      TempFoodSectionModel(
        id: _int(j['id']) ?? 0,
        name: _str(j['name'] ?? j['section_name'] ?? j['title']) ?? '',
        points: _str(j['points'] ?? j['point']),
        status: _status(j['status']),
        createdAt: _str(j['created_at']),
        updatedAt: _str(j['updated_at']),
        deletedAt: _str(j['deleted_at']),
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

class TempFoodSectionPartModel {
  final int id;
  final int sectionId;
  final String name;
  final String status;
  final String? displayOrder;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  const TempFoodSectionPartModel({
    required this.id,
    required this.sectionId,
    required this.name,
    this.status = 'active',
    this.displayOrder,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory TempFoodSectionPartModel.fromJson(Map<String, dynamic> j) =>
      TempFoodSectionPartModel(
        id: _int(j['id']) ?? 0,
        sectionId: _int(j['food_section_id'] ??
                j['temp_food_section_id'] ??
                j['section_id']) ??
            0,
        name: _str(j['name'] ?? j['part_name'] ?? j['title']) ?? '',
        status: _status(j['status']),
        displayOrder: _str(j['display_order']),
        createdAt: _str(j['created_at']),
        updatedAt: _str(j['updated_at']),
        deletedAt: _str(j['deleted_at']),
      );

  /// Same keys as the Food / Mobile Food section-part rows.
  Map<String, dynamic> toJson() => {
        'id': id,
        'food_section_id': sectionId,
        'name': name,
        'status': status,
        'display_order': displayOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class TempFoodItemModel {
  final int id;
  final int? serialNumber;
  final int partId;
  final String name;
  final String? point;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  const TempFoodItemModel({
    required this.id,
    this.serialNumber,
    required this.partId,
    required this.name,
    this.point,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory TempFoodItemModel.fromJson(Map<String, dynamic> j) =>
      TempFoodItemModel(
        id: _int(j['id']) ?? 0,
        serialNumber: _int(j['serial_number'] ?? j['serial_no']),
        partId: _int(j['food_section_part_id'] ??
                j['temp_food_section_part_id'] ??
                j['section_part_id']) ??
            0,
        name: _str(j['name'] ?? j['item_name'] ?? j['title']) ?? '',
        point: _str(j['point'] ?? j['points']),
        status: _status(j['status']),
        createdAt: _str(j['created_at']),
        updatedAt: _str(j['updated_at']),
        deletedAt: _str(j['deleted_at']),
      );

  /// Same keys as the Food / Mobile Food item rows.
  Map<String, dynamic> toJson() => {
        'id': id,
        'serial_number': serialNumber,
        'food_section_part_id': partId,
        'name': name,
        'point': point,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

// ---------------------------------------------------------------------------
// Tree used by the inspection form (one JOIN query in DBManager)
// ---------------------------------------------------------------------------

class TempFoodChecklistPartNode {
  final TempFoodSectionPartModel part;
  final List<TempFoodItemModel> items;

  TempFoodChecklistPartNode(this.part, this.items);
}

class TempFoodChecklistSectionNode {
  final TempFoodSectionModel section;
  final List<TempFoodChecklistPartNode> parts;

  TempFoodChecklistSectionNode(this.section, this.parts);

  int get itemCount => parts.fold(0, (sum, p) => sum + p.items.length);
}
