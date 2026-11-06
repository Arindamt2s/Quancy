/// One row of the Temperature Observations tab.
/// Saved in the `MobileFoodTemperature` table.
class MobileFoodTemperatureModel {
  final int? id;
  final String inspectionId;

  /// Position of the row on screen (0 = first row)
  final int sortOrder;

  final String itemLocation;

  /// Temperature in ℉ (whole numbers only). Null = not entered.
  final int? temperature;

  final String? updatedAt;

  MobileFoodTemperatureModel({
    this.id,
    required this.inspectionId,
    required this.sortOrder,
    this.itemLocation = '',
    this.temperature,
    this.updatedAt,
  });

  bool get isEmpty => itemLocation.trim().isEmpty && temperature == null;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'inspection_id': inspectionId,
        'sort_order': sortOrder,
        'item_location': itemLocation,
        'temperature': temperature,
        'updated_at': updatedAt,
      };

  factory MobileFoodTemperatureModel.fromMap(Map<String, dynamic> m) =>
      MobileFoodTemperatureModel(
        id: m['id'] as int?,
        inspectionId: m['inspection_id'] as String,
        sortOrder: m['sort_order'] as int? ?? 0,
        itemLocation: m['item_location'] as String? ?? '',
        temperature: m['temperature'] is int
            ? m['temperature'] as int
            : int.tryParse('${m['temperature'] ?? ''}'),
        updatedAt: m['updated_at'] as String?,
      );
}