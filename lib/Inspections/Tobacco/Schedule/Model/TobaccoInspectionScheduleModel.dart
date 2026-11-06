import 'package:quincy/Inspections/Tobacco/Model/TobaccoJson.dart';

/// One schedule from GET /tobacco/get-inspection-schedules-by-pagination.
///
/// Path: lib/Inspections/Tobacco/Schedule/Model/TobaccoInspectionScheduleModel.dart
///
/// The nested "inspector" object is flattened into inspector_* columns.
/// Business name / permit # / address come from a JOIN with tobacco_permits.
class TobaccoInspectionScheduleModel {
  /// inspection_status value that means "done".
  /// ⚠️ Adjust if the backend uses another value.
  static const int inspectionStatusCompleted = 2;

  final int id;
  final int? tobaccoPermitId;
  final int? previousInspectionId;
  final int? inspectorId;
  final String? jobCode;

  /// yyyy-MM-dd
  final String? scheduleDate;
  final int? inspectionStatus;
  final int? status;
  final String? inspectorFirstName;
  final String? inspectorLastName;
  final String? inspectorNickName;
  final String? inspectorEmail;
  final String? inspectorPhone;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  // From the permit JOIN (null when the permit isn't saved locally).
  final String? businessName;
  final String? permitNumber;
  final String? businessAddress;
  final String? city;

  const TobaccoInspectionScheduleModel({
    required this.id,
    this.tobaccoPermitId,
    this.previousInspectionId,
    this.inspectorId,
    this.jobCode,
    this.scheduleDate,
    this.inspectionStatus,
    this.status,
    this.inspectorFirstName,
    this.inspectorLastName,
    this.inspectorNickName,
    this.inspectorEmail,
    this.inspectorPhone,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.businessName,
    this.permitNumber,
    this.businessAddress,
    this.city,
  });

  String get inspectorName => [inspectorFirstName, inspectorLastName]
      .whereType<String>()
      .where((e) => e.isNotEmpty)
      .join(' ');

  bool get isCompleted => inspectionStatus == inspectionStatusCompleted;

  String get inspectionStatusLabel => isCompleted ? 'Completed' : 'Pending';

  bool get isReinspection => (previousInspectionId ?? 0) > 0;

  /// yyyy-MM-dd part only (for grouping / filters).
  String get dateKey {
    final d = scheduleDate ?? '';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  factory TobaccoInspectionScheduleModel.fromJson(Map<String, dynamic> j) {
    final ins = j['inspector'];
    final Map<String, dynamic> i =
        ins is Map ? Map<String, dynamic>.from(ins) : const <String, dynamic>{};
    return TobaccoInspectionScheduleModel(
      id: tbInt(j['id']) ?? 0,
      tobaccoPermitId: tbInt(j['tobacco_permit_id']),
      previousInspectionId: tbInt(j['previous_inspection_id']),
      inspectorId: tbInt(j['inspector_id']),
      jobCode: tbStr(j['job_code']),
      scheduleDate: tbStr(j['schedule_date']),
      inspectionStatus: tbInt(j['inspection_status']),
      status: tbInt(j['status']),
      inspectorFirstName: tbStr(i['first_name']),
      inspectorLastName: tbStr(i['last_name']),
      inspectorNickName: tbStr(i['nick_name']),
      inspectorEmail: tbStr(i['email']),
      inspectorPhone: tbStr(i['phone']),
      createdAt: tbStr(j['created_at']),
      updatedAt: tbStr(j['updated_at']),
      deletedAt: tbStr(j['deleted_at']),
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'tobacco_permit_id': tobaccoPermitId,
        'previous_inspection_id': previousInspectionId,
        'inspector_id': inspectorId,
        'job_code': jobCode,
        'schedule_date': scheduleDate,
        'inspection_status': inspectionStatus,
        'status': status,
        'inspector_first_name': inspectorFirstName,
        'inspector_last_name': inspectorLastName,
        'inspector_nick_name': inspectorNickName,
        'inspector_email': inspectorEmail,
        'inspector_phone': inspectorPhone,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  factory TobaccoInspectionScheduleModel.fromDb(Map<String, Object?> r) =>
      TobaccoInspectionScheduleModel(
        id: tbInt(r['id']) ?? 0,
        tobaccoPermitId: tbInt(r['tobacco_permit_id']),
        previousInspectionId: tbInt(r['previous_inspection_id']),
        inspectorId: tbInt(r['inspector_id']),
        jobCode: tbStr(r['job_code']),
        scheduleDate: tbStr(r['schedule_date']),
        inspectionStatus: tbInt(r['inspection_status']),
        status: tbInt(r['status']),
        inspectorFirstName: tbStr(r['inspector_first_name']),
        inspectorLastName: tbStr(r['inspector_last_name']),
        inspectorNickName: tbStr(r['inspector_nick_name']),
        inspectorEmail: tbStr(r['inspector_email']),
        inspectorPhone: tbStr(r['inspector_phone']),
        createdAt: tbStr(r['created_at']),
        updatedAt: tbStr(r['updated_at']),
        deletedAt: tbStr(r['deleted_at']),
        businessName: tbStr(r['permit_business_name']),
        permitNumber: tbStr(r['permit_permit_number']),
        businessAddress: tbStr(r['permit_business_address']),
        city: tbStr(r['permit_city']),
      );

  bool matches(String lowerQuery) {
    if (lowerQuery.isEmpty) return true;
    for (final v in [
      jobCode,
      businessName,
      permitNumber,
      businessAddress,
      city,
      inspectorName,
      tobaccoPermitId?.toString(),
    ]) {
      if (v != null && v.toLowerCase().contains(lowerQuery)) return true;
    }
    return false;
  }
}
