/// One operation type from `/mobile-food/operation-types`.
/// Saved in the `mobile_food_operation_types` table.
class MobileFoodOperationTypeModel {
  final int id;
  final String name;

  /// 1 = active, 0 = inactive
  final int status;

  final String? createdAt;
  final String? updatedAt;

  MobileFoodOperationTypeModel({
    required this.id,
    required this.name,
    this.status = 1,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 1;

  /// Works for both the API response and a DB row (same keys).
  factory MobileFoodOperationTypeModel.fromJson(Map<String, dynamic> json) =>
      MobileFoodOperationTypeModel(
        id: _toInt(json['id']) ?? 0,
        name: (json['name'] ?? '').toString(),
        status: _toInt(json['status']) ?? 1,
        createdAt: json['created_at']?.toString(),
        updatedAt: json['updated_at']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Parses `{"status": true, "operationTypes": [...]}`.
  static List<MobileFoodOperationTypeModel> listFromResponse(
      Map<String, dynamic> body) {
    final list = body['operationTypes'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => MobileFoodOperationTypeModel.fromJson(
            Map<String, dynamic>.from(e)))
        .toList();
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    return int.tryParse(v.toString());
  }
}