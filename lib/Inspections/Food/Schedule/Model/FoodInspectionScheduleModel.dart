/// Model for GET /api/food/get-inspection-shedules/{last_id?}/{fetched_data_count?}
///
/// Response:
/// {
///   "status": true,
///   "last_schedule_id": 17,
///   "schedules": [ { id, food_permit_id, previous_inspection_id,
///                    inspector_id, job_code, schedule_date,
///                    inspection_status, status, created_at, updated_at,
///                    deleted_at, inspector: {...} } ]
/// }
///
/// Path: lib/Inspections/Food/Schedule/Model/FoodInspectionScheduleModel.dart

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString());
}

String? _toStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool _toBool(dynamic v) =>
    v == true || v == 1 || v == '1' || v.toString().toLowerCase() == 'true';

// ---------------------------------------------------------------------------
// Response wrapper
// ---------------------------------------------------------------------------

class FoodInspectionScheduleResponse {
  final bool success;

  /// "last_schedule_id" from the API (id of the last schedule sent).
  final int? lastScheduleId;
  final List<FoodInspectionScheduleModel> schedules;

  FoodInspectionScheduleResponse({
    required this.success,
    required this.schedules,
    this.lastScheduleId,
  });

  factory FoodInspectionScheduleResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['schedules'] ?? json['data'];
    final list = raw is List ? raw : const [];
    return FoodInspectionScheduleResponse(
      success: _toBool(json['status'] ?? json['success']),
      lastScheduleId: _toInt(json['last_schedule_id']),
      schedules: list
          .whereType<Map>()
          .map((e) =>
              FoodInspectionScheduleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Nested inspector
// ---------------------------------------------------------------------------

class FoodScheduleInspector {
  final int? id;
  final String? firstName;
  final String? lastName;
  final String? nickName;
  final String? email;
  final String? phone;

  const FoodScheduleInspector({
    this.id,
    this.firstName,
    this.lastName,
    this.nickName,
    this.email,
    this.phone,
  });

  factory FoodScheduleInspector.fromJson(Map<String, dynamic> json) =>
      FoodScheduleInspector(
        id: _toInt(json['id']),
        firstName: _toStr(json['first_name']),
        lastName: _toStr(json['last_name']),
        nickName: _toStr(json['nick_name']),
        email: _toStr(json['email']),
        phone: _toStr(json['phone']),
      );

  String get fullName {
    final name = [firstName, lastName]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (name.isNotEmpty) return name;
    return nickName ?? email ?? '';
  }
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

class FoodInspectionScheduleModel {
  //   1 = scheduled (pending), 2 = completed.
  static const int inspectionStatusPending = 1;
  static const int inspectionStatusCompleted = 2;

  final int id;
  final int? foodPermitId;

  /// The inspection this schedule follows up (re-inspection). Null for
  /// a first inspection.
  final int? previousInspectionId;
  final int? inspectorId;
  final String? jobCode;
  final String? scheduleDate; // yyyy-mm-dd
  final int? inspectionStatus;
  final int? status;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final FoodScheduleInspector? inspector;

  // Filled only when read from the DB (LEFT JOIN food permits table).
  final String? businessName;
  final String? permitNumber;
  final String? businessAddress;

  const FoodInspectionScheduleModel({
    required this.id,
    this.foodPermitId,
    this.previousInspectionId,
    this.inspectorId,
    this.jobCode,
    this.scheduleDate,
    this.inspectionStatus,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.inspector,
    this.businessName,
    this.permitNumber,
    this.businessAddress,
  });

  // ---------- API ----------
  factory FoodInspectionScheduleModel.fromJson(Map<String, dynamic> json) {
    final insp = json['inspector'];
    return FoodInspectionScheduleModel(
      id: _toInt(json['id']) ?? 0,
      // Food API should send "food_permit_id"; the others are fallbacks
      // in case the backend reused the mobile-food field name.
      foodPermitId: _toInt(json['food_permit_id'] ??
          json['permit_id'] ??
          json['mobile_food_permit_id']),
      previousInspectionId: _toInt(json['previous_inspection_id']),
      inspectorId: _toInt(json['inspector_id']),
      jobCode: _toStr(json['job_code']),
      scheduleDate: _toStr(json['schedule_date']),
      inspectionStatus: _toInt(json['inspection_status']),
      status: _toInt(json['status']),
      createdAt: _toStr(json['created_at']),
      updatedAt: _toStr(json['updated_at']),
      deletedAt: _toStr(json['deleted_at']),
      inspector: insp is Map
          ? FoodScheduleInspector.fromJson(Map<String, dynamic>.from(insp))
          : null,
    );
  }

  // ---------- DB ----------
  /// Row for the food_inspection_schedules table.
  Map<String, dynamic> toDb() => {
        'id': id,
        'food_permit_id': foodPermitId,
        'previous_inspection_id': previousInspectionId,
        'inspector_id': inspectorId,
        'job_code': jobCode,
        'schedule_date': scheduleDate,
        'inspection_status': inspectionStatus,
        'status': status,
        'inspector_first_name': inspector?.firstName,
        'inspector_last_name': inspector?.lastName,
        'inspector_nick_name': inspector?.nickName,
        'inspector_email': inspector?.email,
        'inspector_phone': inspector?.phone,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  factory FoodInspectionScheduleModel.fromDb(Map<String, Object?> r) {
    final hasInspector = r['inspector_first_name'] != null ||
        r['inspector_last_name'] != null ||
        r['inspector_nick_name'] != null ||
        r['inspector_email'] != null;
    return FoodInspectionScheduleModel(
      id: _toInt(r['id']) ?? 0,
      foodPermitId: _toInt(r['food_permit_id']),
      previousInspectionId: _toInt(r['previous_inspection_id']),
      inspectorId: _toInt(r['inspector_id']),
      jobCode: _toStr(r['job_code']),
      scheduleDate: _toStr(r['schedule_date']),
      inspectionStatus: _toInt(r['inspection_status']),
      status: _toInt(r['status']),
      createdAt: _toStr(r['created_at']),
      updatedAt: _toStr(r['updated_at']),
      deletedAt: _toStr(r['deleted_at']),
      inspector: hasInspector
          ? FoodScheduleInspector(
              id: _toInt(r['inspector_id']),
              firstName: _toStr(r['inspector_first_name']),
              lastName: _toStr(r['inspector_last_name']),
              nickName: _toStr(r['inspector_nick_name']),
              email: _toStr(r['inspector_email']),
              phone: _toStr(r['inspector_phone']),
            )
          : null,
      businessName: _toStr(r['permit_business_name']),
      permitNumber: _toStr(r['permit_permit_number']),
      businessAddress: _toStr(r['permit_business_address']),
    );
  }

  // ---------- Helpers ----------
  DateTime? get scheduleDateTime =>
      scheduleDate == null ? null : DateTime.tryParse(scheduleDate!);

  String get inspectorName => inspector?.fullName ?? '';

  bool get isCompleted => inspectionStatus == inspectionStatusCompleted;

  bool get isReinspection => previousInspectionId != null;

  String get inspectionStatusLabel {
    switch (inspectionStatus) {
      case inspectionStatusPending:
        return 'Scheduled';
      case inspectionStatusCompleted:
        return 'Completed';
      default:
        return inspectionStatus == null ? 'Unknown' : 'Status $inspectionStatus';
    }
  }
}