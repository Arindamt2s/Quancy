/// One Temporary Food inspection (Establishment tab) – a row of the
/// TempFoodInspection table. The selected inspector's id is stored in the
/// separate inspector_id column (see DBManager.setTempFoodInspectionInspectorId).
///
/// Path: lib/Inspections/TempFood/Model/TempFoodInspectionModel.dart
class TempFoodInspectionModel {
  static const String statusIncomplete = 'incomplete';
  static const String statusSubmitted = 'submitted';

  final String inspectionId;
  final int userId;
  final int? permitId;
  final String businessName;
  final String applicantName;
  final String permitNumber;
  final String address;
  final String telephone;
  final String owner;
  final String personInCharge;
  final String inspectionDate; // yyyy-MM-dd
  final String timeIn; // HH:mm
  final String timeOut; // HH:mm
  final String inspector;
  final String status;
  final int currentStep;
  final String? createdAt;
  final String? updatedAt;

  const TempFoodInspectionModel({
    required this.inspectionId,
    required this.userId,
    this.permitId,
    required this.businessName,
    this.applicantName = '',
    this.permitNumber = '',
    this.address = '',
    this.telephone = '',
    this.owner = '',
    this.personInCharge = '',
    required this.inspectionDate,
    required this.timeIn,
    required this.timeOut,
    this.inspector = '',
    this.status = statusIncomplete,
    this.currentStep = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// "TFI-<userId>-<timestamp>"
  static String generateId(int userId) =>
      'TFI-$userId-${DateTime.now().millisecondsSinceEpoch}';

  TempFoodInspectionModel copyWith({
    String? createdAt,
    String? updatedAt,
    int? currentStep,
    String? status,
  }) =>
      TempFoodInspectionModel(
        inspectionId: inspectionId,
        userId: userId,
        permitId: permitId,
        businessName: businessName,
        applicantName: applicantName,
        permitNumber: permitNumber,
        address: address,
        telephone: telephone,
        owner: owner,
        personInCharge: personInCharge,
        inspectionDate: inspectionDate,
        timeIn: timeIn,
        timeOut: timeOut,
        inspector: inspector,
        status: status ?? this.status,
        currentStep: currentStep ?? this.currentStep,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'inspection_id': inspectionId,
        'user_id': userId,
        'permit_id': permitId,
        'business_name': businessName,
        'applicant_name': applicantName,
        'permit_number': permitNumber,
        'address': address,
        'telephone': telephone,
        'owner': owner,
        'person_in_charge': personInCharge,
        'inspection_date': inspectionDate,
        'time_in': timeIn,
        'time_out': timeOut,
        'inspector': inspector,
        'status': status,
        'current_step': currentStep,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  static String _s(Object? v) => v?.toString() ?? '';

  factory TempFoodInspectionModel.fromMap(Map<String, Object?> m) =>
      TempFoodInspectionModel(
        inspectionId: _s(m['inspection_id']),
        userId: (m['user_id'] as num?)?.toInt() ?? 0,
        permitId: (m['permit_id'] as num?)?.toInt(),
        businessName: _s(m['business_name']),
        applicantName: _s(m['applicant_name']),
        permitNumber: _s(m['permit_number']),
        address: _s(m['address']),
        telephone: _s(m['telephone']),
        owner: _s(m['owner']),
        personInCharge: _s(m['person_in_charge']),
        inspectionDate: _s(m['inspection_date']),
        timeIn: _s(m['time_in']),
        timeOut: _s(m['time_out']),
        inspector: _s(m['inspector']),
        status: m['status']?.toString() ?? statusIncomplete,
        currentStep: (m['current_step'] as num?)?.toInt() ?? 0,
        createdAt: m['created_at']?.toString(),
        updatedAt: m['updated_at']?.toString(),
      );
}
