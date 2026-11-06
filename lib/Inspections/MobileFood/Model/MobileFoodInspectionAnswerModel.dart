/// One checklist item answer of a Mobile Food inspection.
/// Saved in the `MobileFoodInspectionAnswer` table
/// (one row per inspection_id + item_id).
class MobileFoodInspectionAnswerModel {
  /// Photos allowed per item
  static const int photoSlots = 4;

  final String inspectionId;
  final int itemId;

  /// OUT / IN / NO / NA (null = not answered)
  final String? result;

  /// Corrected on site (only with OUT)
  final bool cos;

  /// Repeat violation (only with OUT)
  final bool repeat;

  final String comment;

  /// Photo file paths, one per slot (null = empty slot).
  /// In the DB they are stored relative to the photo folder;
  /// in memory they are absolute paths (see MobileFoodAnswerRepository).
  final List<String?> photos;

  final String? updatedAt;

  MobileFoodInspectionAnswerModel({
    required this.inspectionId,
    required this.itemId,
    this.result,
    this.cos = false,
    this.repeat = false,
    this.comment = '',
    List<String?>? photos,
    this.updatedAt,
  }) : photos = _normalizePhotos(photos);

  static List<String?> _normalizePhotos(List<String?>? src) {
    final out = List<String?>.filled(photoSlots, null);
    if (src == null) return out;
    for (var i = 0; i < photoSlots && i < src.length; i++) {
      final p = src[i];
      out[i] = (p == null || p.trim().isEmpty) ? null : p;
    }
    return out;
  }

  /// Nothing selected, typed or photographed → row can be deleted.
  bool get isEmpty =>
      result == null &&
      !cos &&
      !repeat &&
      comment.trim().isEmpty &&
      photos.every((p) => p == null);

  MobileFoodInspectionAnswerModel copyWithPhotos(List<String?> newPhotos) =>
      MobileFoodInspectionAnswerModel(
        inspectionId: inspectionId,
        itemId: itemId,
        result: result,
        cos: cos,
        repeat: repeat,
        comment: comment,
        photos: newPhotos,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'inspection_id': inspectionId,
        'item_id': itemId,
        'result': result,
        'cos': cos ? 1 : 0,
        'repeat_violation': repeat ? 1 : 0,
        'comment': comment,
        'photo_1': photos[0],
        'photo_2': photos[1],
        'photo_3': photos[2],
        'photo_4': photos[3],
        'updated_at': updatedAt,
      };

  factory MobileFoodInspectionAnswerModel.fromMap(Map<String, dynamic> m) =>
      MobileFoodInspectionAnswerModel(
        inspectionId: m['inspection_id'] as String,
        itemId: m['item_id'] as int,
        result: m['result'] as String?,
        cos: (m['cos'] as int? ?? 0) == 1,
        repeat: (m['repeat_violation'] as int? ?? 0) == 1,
        comment: m['comment'] as String? ?? '',
        photos: [
          m['photo_1'] as String?,
          m['photo_2'] as String?,
          m['photo_3'] as String?,
          m['photo_4'] as String?,
        ],
        updatedAt: m['updated_at'] as String?,
      );
}