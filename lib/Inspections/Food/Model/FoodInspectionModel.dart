/// One Food inspection saved on the device (Establishment tab).
/// Row of the FoodInspection table.
class FoodInspectionModel {
  static const String statusIncomplete = 'incomplete';
  static const String statusCompleted = 'completed';

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

  /// yyyy-MM-dd
  final String inspectionDate;

  /// HH:mm (24h)
  final String timeIn;
  final String timeOut;
  final String inspector;
  final String status;
  final int currentStep;
  final String? createdAt;
  final String? updatedAt;

  const FoodInspectionModel({
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

  /// "FI-<userId>-<timestamp>" – unique per device and user.
  static String generateId(int userId) =>
      'FI-$userId-${DateTime.now().millisecondsSinceEpoch}';

  factory FoodInspectionModel.fromMap(Map<String, dynamic> m) =>
      FoodInspectionModel(
        inspectionId: m['inspection_id']?.toString() ?? '',
        userId: (m['user_id'] as num?)?.toInt() ?? 0,
        permitId: (m['permit_id'] as num?)?.toInt(),
        businessName: m['business_name']?.toString() ?? '',
        applicantName: m['applicant_name']?.toString() ?? '',
        permitNumber: m['permit_number']?.toString() ?? '',
        address: m['address']?.toString() ?? '',
        telephone: m['telephone']?.toString() ?? '',
        owner: m['owner']?.toString() ?? '',
        personInCharge: m['person_in_charge']?.toString() ?? '',
        inspectionDate: m['inspection_date']?.toString() ?? '',
        timeIn: m['time_in']?.toString() ?? '',
        timeOut: m['time_out']?.toString() ?? '',
        inspector: m['inspector']?.toString() ?? '',
        status: m['status']?.toString() ?? statusIncomplete,
        currentStep: (m['current_step'] as num?)?.toInt() ?? 0,
        createdAt: m['created_at']?.toString(),
        updatedAt: m['updated_at']?.toString(),
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

  FoodInspectionModel copyWith({
    String? status,
    int? currentStep,
    String? createdAt,
    String? updatedAt,
  }) =>
      FoodInspectionModel(
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