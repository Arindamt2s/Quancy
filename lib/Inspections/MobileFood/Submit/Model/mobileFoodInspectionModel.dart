// lib/data/models/mobile_food_inspection_models.dart

/// Request body for POST /mobile-food/inspection
class MobileFoodInspectionRequest {
  final String inspectionDate; // MM/dd/yyyy
  final int estId;
  final int? scheduleId;
  final String? reinspectionDate; // MM/dd/yyyy
  final String timeIn; // HH:mm:ss
  final String timeOut; // HH:mm:ss
  final int? purposeId;
  final int? operationTypeId;
  final String personInCharge;
  final String otherInformation;
  final String violatedProvisions;
  final String repeatViolations;
  final String personInChargeDiscussion;
  final int inspectorId;
  final String personInChargeSign; // base64
  final String inspectorSign; // base64
  final String personInChargeSignDate; // MM/dd/yyyy
  final String inspectorSignDate; // MM/dd/yyyy

  MobileFoodInspectionRequest({
    required this.inspectionDate,
    required this.estId,
    this.scheduleId,
    this.reinspectionDate,
    required this.timeIn,
    required this.timeOut,
    this.purposeId,
    this.operationTypeId,
    required this.personInCharge,
    required this.otherInformation,
    required this.violatedProvisions,
    required this.repeatViolations,
    required this.personInChargeDiscussion,
    required this.inspectorId,
    required this.personInChargeSign,
    required this.inspectorSign,
    required this.personInChargeSignDate,
    required this.inspectorSignDate,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      "inspection_date": inspectionDate,
      "est_id": estId,
      "schedule_id": scheduleId,
      "reinspection_date": reinspectionDate,
      "time_in": timeIn,
      "time_out": timeOut,
      "purpose_id": purposeId,
      "operation_type_id": operationTypeId,
      "person_in_charge": personInCharge,
      "other_information": otherInformation,
      "violated_provisions": violatedProvisions,
      "repeat_violations": repeatViolations,
      "person_in_charge_discussion": personInChargeDiscussion,
      "inspector_id": inspectorId,
      "person_in_charge_sign": personInChargeSign,
      "inspector_sign": inspectorSign,
      "person_in_charge_sign_date": personInChargeSignDate,
      "inspector_sign_date": inspectorSignDate,
    };
    // Don't send nulls (e.g. schedule_id when not scheduled)
    map.removeWhere((_, v) => v == null);
    return map;
  }
}

/// Response of POST /mobile-food/inspection
/// POST /food/inspection (and /mobile-food/inspection) response:
/// {
///   "status": true,
///   "inspectionID": 123,
///   "permit_id": 45
/// }
class MobileFoodInspectionResponse {
  /// "status"
  final bool success;

  /// "inspectionID" – server inspection id, used by
  /// /food/inspection-item and /food/item-temperature.
  final int? inspectionId;

  /// "permit_id"
  final int? permitId;

  /// "message" (only sent on errors, if at all)
  final String? message;

  const MobileFoodInspectionResponse({
    required this.success,
    this.inspectionId,
    this.permitId,
    this.message,
  });

  factory MobileFoodInspectionResponse.fromJson(Map<String, dynamic> json) =>
      MobileFoodInspectionResponse(
        success: _toBool(json['status']),
        inspectionId: _toInt(json['inspectionID']),
        permitId: _toInt(json['permit_id']),
        message: json['message']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'status': success,
        'inspectionID': inspectionId,
        'permit_id': permitId,
      };

  static bool _toBool(dynamic v) =>
      v == true || v == 1 || v?.toString().toLowerCase() == 'true';

  /// Accepts 123, "123" or 123.0.
  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }
}

class MobileFoodInspectionResponseData {
  final int? inspectionId;
  final int? permitId;

  MobileFoodInspectionResponseData({this.inspectionId, this.permitId});

  factory MobileFoodInspectionResponseData.fromJson(Map<String, dynamic> json) {
    return MobileFoodInspectionResponseData(
      inspectionId: _toInt(json['inspectionID'] ?? json['inspection_id']),
      permitId: _toInt(json['permit_id']),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}