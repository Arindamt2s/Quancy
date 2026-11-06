/// Request body for POST /api/temp-food/inspection (API 1 of 3).
///
/// {
///   "inspection_date": "12/25/2025",
///   "temp_food_permit_id": 1,
///   "schedule_id": 0,
///   "reinspection_date": "12/25/2025",
///   "time_in": "10:00:00",
///   "time_out": "12:00:00",
///   "purpose_id": 1,
///   "operation_type_id": 1,
///   "person_in_charge": "string",
///   "other_information": "string",
///   "violated_provisions": "string",
///   "repeat_violations": "string",
///   "person_in_charge_discussion": "string",
///   "inspector_id": 12,
///   "person_in_charge_sign": "base64",
///   "inspector_sign": "base64",
///   "person_in_charge_sign_date": "12/25/2025",
///   "inspector_sign_date": "12/25/2025"
/// }
///
/// Dates: MM/dd/yyyy   Times: HH:mm:ss
///
/// Path: lib/Inspections/TempFood/Submit/Model/TempFoodInspectionRequest.dart
class TempFoodInspectionRequest {
  final String inspectionDate; // MM/dd/yyyy
  final int tempFoodPermitId;
  final int scheduleId;
  final String reinspectionDate; // MM/dd/yyyy or ''
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
  final String personInChargeSign; // base64 PNG
  final String inspectorSign; // base64 PNG
  final String personInChargeSignDate; // MM/dd/yyyy
  final String inspectorSignDate; // MM/dd/yyyy

  const TempFoodInspectionRequest({
    required this.inspectionDate,
    required this.tempFoodPermitId,
    this.scheduleId = 0,
    this.reinspectionDate = '',
    required this.timeIn,
    required this.timeOut,
    this.purposeId,
    this.operationTypeId,
    this.personInCharge = '',
    this.otherInformation = '',
    this.violatedProvisions = '',
    this.repeatViolations = '',
    this.personInChargeDiscussion = '',
    required this.inspectorId,
    this.personInChargeSign = '',
    this.inspectorSign = '',
    this.personInChargeSignDate = '',
    this.inspectorSignDate = '',
  });

  Map<String, dynamic> toJson() => {
        'inspection_date': inspectionDate,
        'temp_food_permit_id': tempFoodPermitId,
        'schedule_id': scheduleId,
        'reinspection_date': reinspectionDate,
        'time_in': timeIn,
        'time_out': timeOut,
        'purpose_id': purposeId,
        'operation_type_id': operationTypeId,
        'person_in_charge': personInCharge,
        'other_information': otherInformation,
        'violated_provisions': violatedProvisions,
        'repeat_violations': repeatViolations,
        'person_in_charge_discussion': personInChargeDiscussion,
        'inspector_id': inspectorId,
        'person_in_charge_sign': personInChargeSign,
        'inspector_sign': inspectorSign,
        'person_in_charge_sign_date': personInChargeSignDate,
        'inspector_sign_date': inspectorSignDate,
      };

  factory TempFoodInspectionRequest.fromJson(Map<String, dynamic> j) {
    int? toInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '');
    String str(dynamic v) => v?.toString() ?? '';
    return TempFoodInspectionRequest(
      inspectionDate: str(j['inspection_date']),
      tempFoodPermitId: toInt(j['temp_food_permit_id']) ?? 0,
      scheduleId: toInt(j['schedule_id']) ?? 0,
      reinspectionDate: str(j['reinspection_date']),
      timeIn: str(j['time_in']),
      timeOut: str(j['time_out']),
      purposeId: toInt(j['purpose_id']),
      operationTypeId: toInt(j['operation_type_id']),
      personInCharge: str(j['person_in_charge']),
      otherInformation: str(j['other_information']),
      violatedProvisions: str(j['violated_provisions']),
      repeatViolations: str(j['repeat_violations']),
      personInChargeDiscussion: str(j['person_in_charge_discussion']),
      inspectorId: toInt(j['inspector_id']) ?? 0,
      personInChargeSign: str(j['person_in_charge_sign']),
      inspectorSign: str(j['inspector_sign']),
      personInChargeSignDate: str(j['person_in_charge_sign_date']),
      inspectorSignDate: str(j['inspector_sign_date']),
    );
  }
}