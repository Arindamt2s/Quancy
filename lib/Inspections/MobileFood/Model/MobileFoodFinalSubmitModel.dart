/// Final Submit tab of a Mobile Food inspection.
/// Saved in the `MobileFoodInspectionFinal` table (one row per inspection).
class MobileFoodFinalSubmitModel {
  final String inspectionId;

  /// yyyy-MM-dd
  final String? reinspectionDate;

  final String? purpose;
  final int? operationTypeId;
  final String? operationTypeName;

  final String discussion;
  final String otherInformation;

  /// Signature PNG file path (relative to the photo folder in the DB,
  /// absolute in memory – see MobileFoodAnswerRepository).
  final String? picSignature;

  /// yyyy-MM-dd, set when the person-in-charge signs
  final String? picSignDate;
  final String picName;

  final String? inspectorSignature;
  final String? inspectorSignDate;
  final String inspectorName;

  final String? updatedAt;

  MobileFoodFinalSubmitModel({
    required this.inspectionId,
    this.reinspectionDate,
    this.purpose,
    this.operationTypeId,
    this.operationTypeName,
    this.discussion = '',
    this.otherInformation = '',
    this.picSignature,
    this.picSignDate,
    this.picName = '',
    this.inspectorSignature,
    this.inspectorSignDate,
    this.inspectorName = '',
    this.updatedAt,
  });

  /// Same data with different signature paths.
  MobileFoodFinalSubmitModel withSignatures({
    required String? pic,
    required String? inspector,
  }) =>
      MobileFoodFinalSubmitModel(
        inspectionId: inspectionId,
        reinspectionDate: reinspectionDate,
        purpose: purpose,
        operationTypeId: operationTypeId,
        operationTypeName: operationTypeName,
        discussion: discussion,
        otherInformation: otherInformation,
        picSignature: pic,
        picSignDate: picSignDate,
        picName: picName,
        inspectorSignature: inspector,
        inspectorSignDate: inspectorSignDate,
        inspectorName: inspectorName,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'inspection_id': inspectionId,
        'reinspection_date': reinspectionDate,
        'purpose': purpose,
        'operation_type_id': operationTypeId,
        'operation_type_name': operationTypeName,
        'discussion': discussion,
        'other_information': otherInformation,
        'pic_signature': picSignature,
        'pic_sign_date': picSignDate,
        'pic_name': picName,
        'inspector_signature': inspectorSignature,
        'inspector_sign_date': inspectorSignDate,
        'inspector_name': inspectorName,
        'updated_at': updatedAt,
      };

  factory MobileFoodFinalSubmitModel.fromMap(Map<String, dynamic> m) =>
      MobileFoodFinalSubmitModel(
        inspectionId: m['inspection_id'] as String,
        reinspectionDate: _str(m['reinspection_date']),
        purpose: _str(m['purpose']),
        operationTypeId: m['operation_type_id'] is int
            ? m['operation_type_id'] as int
            : int.tryParse('${m['operation_type_id'] ?? ''}'),
        operationTypeName: _str(m['operation_type_name']),
        discussion: m['discussion'] as String? ?? '',
        otherInformation: m['other_information'] as String? ?? '',
        picSignature: _str(m['pic_signature']),
        picSignDate: _str(m['pic_sign_date']),
        picName: m['pic_name'] as String? ?? '',
        inspectorSignature: _str(m['inspector_signature']),
        inspectorSignDate: _str(m['inspector_sign_date']),
        inspectorName: m['inspector_name'] as String? ?? '',
        updatedAt: _str(m['updated_at']),
      );

  /// Empty text → null
  static String? _str(dynamic v) {
    final s = v?.toString();
    return (s == null || s.trim().isEmpty) ? null : s;
  }
}