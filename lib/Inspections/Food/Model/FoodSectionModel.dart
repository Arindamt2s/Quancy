/// Food checklist models: Section → Section Part → Item
///   GET /food/sections-list       → "sections"
///   GET /food/section-parts-list  → "sectionParts"
///   GET /food/items-list          → "items"
/// Local table columns use the same names as the API keys.

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _str(dynamic v) => v?.toString();

// ---------------- Section ----------------

class FoodSectionModel {
  final int id;
  final String name;
  final String? points;
  final String? status;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  const FoodSectionModel({
    required this.id,
    this.name = '',
    this.points,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory FoodSectionModel.fromJson(Map<String, dynamic> j) => FoodSectionModel(
        id: _int(j['id']) ?? 0,
        name: _str(j['name']) ?? '',
        points: _str(j['points']),
        status: _str(j['status']),
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

// ---------------- Section part (sub-category) ----------------

class FoodSectionPartModel {
  final int id;
  final int foodSectionId;
  final String name;
  final String? status;
  final String? displayOrder;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  const FoodSectionPartModel({
    required this.id,
    required this.foodSectionId,
    this.name = '',
    this.status,
    this.displayOrder,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory FoodSectionPartModel.fromJson(Map<String, dynamic> j) =>
      FoodSectionPartModel(
        id: _int(j['id']) ?? 0,
        foodSectionId: _int(j['food_section_id']) ?? 0,
        name: _str(j['name']) ?? '',
        status: _str(j['status']),
        displayOrder: _str(j['display_order']),
        createdAt: _str(j['created_at']),
        updatedAt: _str(j['updated_at']),
        deletedAt: _str(j['deleted_at']),
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

// ---------------- Item (question) ----------------

class FoodItemModel {
  final int id;
  final int? serialNumber;
  final int foodSectionPartId;
  final String name;
  final String? point;
  final String? status;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  const FoodItemModel({
    required this.id,
    required this.foodSectionPartId,
    this.serialNumber,
    this.name = '',
    this.point,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory FoodItemModel.fromJson(Map<String, dynamic> j) => FoodItemModel(
        id: _int(j['id']) ?? 0,
        serialNumber: _int(j['serial_number']),
        foodSectionPartId: _int(j['food_section_part_id']) ?? 0,
        name: _str(j['name']) ?? '',
        point: _str(j['point']),
        status: _str(j['status']),
        createdAt: _str(j['created_at']),
        updatedAt: _str(j['updated_at']),
        deletedAt: _str(j['deleted_at']),
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

// ---------------- Tree (built by one JOIN query) ----------------

class FoodChecklistPartNode {
  final FoodSectionPartModel part;
  final List<FoodItemModel> items;

  FoodChecklistPartNode(this.part, this.items);
}

class FoodChecklistSectionNode {
  final FoodSectionModel section;
  final List<FoodChecklistPartNode> parts;

  FoodChecklistSectionNode(this.section, this.parts);

  int get itemCount => parts.fold(0, (sum, p) => sum + p.items.length);
}