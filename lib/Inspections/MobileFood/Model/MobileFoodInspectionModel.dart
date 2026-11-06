/// One Mobile Food inspection (Establishment step) stored in the
/// `MobileFoodInspection` table.
class MobileFoodInspectionModel {
  static const String statusIncomplete = 'incomplete';
  static const String statusCompleted = 'completed';

  /// Unique id, e.g. "MFI-12-1728281234567"
  final String inspectionId;

  /// Logged-in user who created the inspection
  final int userId;

  /// Permit this inspection was started from (null if entered manually)
  final int? permitId;

  final String businessName;
  final String applicantName;
  final String permitNumber;
  final String address;
  final String telephone;
  final String owner;
  final String personInCharge;

  /// Stored as "yyyy-MM-dd"
  final String inspectionDate;

  /// Stored as 24h "HH:mm"
  final String timeIn;
  final String timeOut;

  final String inspector;
  final String status;
  final int currentStep;
  final String createdAt;
  final String updatedAt;

  const MobileFoodInspectionModel({
    required this.inspectionId,
    required this.userId,
    this.permitId,
    this.businessName = '',
    this.applicantName = '',
    this.permitNumber = '',
    this.address = '',
    this.telephone = '',
    this.owner = '',
    this.personInCharge = '',
    this.inspectionDate = '',
    this.timeIn = '',
    this.timeOut = '',
    this.inspector = '',
    this.status = statusIncomplete,
    this.currentStep = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  /// Creates a new unique inspection id for the given user.
  static String generateId(int userId) =>
      'MFI-$userId-${DateTime.now().millisecondsSinceEpoch}';

  static String _s(dynamic v) => v == null ? '' : v.toString();
  static int _i(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  factory MobileFoodInspectionModel.fromMap(Map<String, dynamic> map) {
    final permit = map['permit_id'];
    return MobileFoodInspectionModel(
      inspectionId: _s(map['inspection_id']),
      userId: _i(map['user_id']),
      permitId: permit == null ? null : _i(permit),
      businessName: _s(map['business_name']),
      applicantName: _s(map['applicant_name']),
      permitNumber: _s(map['permit_number']),
      address: _s(map['address']),
      telephone: _s(map['telephone']),
      owner: _s(map['owner']),
      personInCharge: _s(map['person_in_charge']),
      inspectionDate: _s(map['inspection_date']),
      timeIn: _s(map['time_in']),
      timeOut: _s(map['time_out']),
      inspector: _s(map['inspector']),
      status: map['status'] == null ? statusIncomplete : _s(map['status']),
      currentStep: _i(map['current_step']),
      createdAt: _s(map['created_at']),
      updatedAt: _s(map['updated_at']),
    );
  }

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

  MobileFoodInspectionModel copyWith({
    String? status,
    int? currentStep,
    String? createdAt,
    String? updatedAt,
  }) {
    return MobileFoodInspectionModel(
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
  }
}