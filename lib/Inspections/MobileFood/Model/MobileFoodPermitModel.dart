/// Model for a single Mobile Food permit returned by the permits API.
class MobileFoodPermitModel {
  final int id;
  final String date;
  final String permitNumber;
  final String businessName;
  final String businessAddress;
  final String city;
  final String state;
  final String zip;
  final String phone;
  final String email;
  final String applicantName;
  final String applicantAddress;
  final String applicantCity;
  final String applicantState;
  final String applicantZip;
  final String applicantPhone;
  final String applicantEmail;
  final String applicantSignature;
  final String applicantSignatureName;
  final String individualSignature;
  final String individualSignatureName;
  final String receivedDate;
  final String inspectionDate;
  final String approvedBy;
  final String permitIssued;
  final int isDelete;
  final int status;
  final String totalFees;
  final String paymentType;
  final String receiptNumber;
  final String finalComment;
  final String createdAt;
  final String updatedAt;
  final String deletedAt;

  const MobileFoodPermitModel({
    required this.id,
    this.date = '',
    this.permitNumber = '',
    this.businessName = '',
    this.businessAddress = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.phone = '',
    this.email = '',
    this.applicantName = '',
    this.applicantAddress = '',
    this.applicantCity = '',
    this.applicantState = '',
    this.applicantZip = '',
    this.applicantPhone = '',
    this.applicantEmail = '',
    this.applicantSignature = '',
    this.applicantSignatureName = '',
    this.individualSignature = '',
    this.individualSignatureName = '',
    this.receivedDate = '',
    this.inspectionDate = '',
    this.approvedBy = '',
    this.permitIssued = '',
    this.isDelete = 0,
    this.status = 0,
    this.totalFees = '',
    this.paymentType = '',
    this.receiptNumber = '',
    this.finalComment = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.deletedAt = '',
  });

  // ---- Safe converters (API may send null, "", int or string) ----
  static String _s(dynamic v) => v == null ? '' : v.toString();

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Works for both the API JSON and a SQLite row (same snake_case keys).
  factory MobileFoodPermitModel.fromJson(Map<String, dynamic> json) {
    return MobileFoodPermitModel(
      id: _i(json['id']),
      date: _s(json['date']),
      permitNumber: _s(json['permit_number']),
      businessName: _s(json['business_name']),
      businessAddress: _s(json['business_address']),
      city: _s(json['city']),
      state: _s(json['state']),
      zip: _s(json['zip']),
      phone: _s(json['phone']),
      email: _s(json['email']),
      applicantName: _s(json['applicant_name']),
      applicantAddress: _s(json['applicant_address']),
      applicantCity: _s(json['applicant_city']),
      applicantState: _s(json['applicant_state']),
      applicantZip: _s(json['applicant_zip']),
      applicantPhone: _s(json['applicant_phone']),
      applicantEmail: _s(json['applicant_email']),
      applicantSignature: _s(json['applicant_signature']),
      applicantSignatureName: _s(json['applicant_signature_name']),
      individualSignature: _s(json['individual_signature']),
      individualSignatureName: _s(json['individual_signature_name']),
      receivedDate: _s(json['received_date']),
      inspectionDate: _s(json['inspection_date']),
      approvedBy: _s(json['approved_by']),
      permitIssued: _s(json['permit_issued']),
      isDelete: _i(json['isDelete']),
      status: _i(json['status']),
      totalFees: _s(json['total_fees']),
      paymentType: _s(json['payment_type']),
      receiptNumber: _s(json['receipt_number']),
      finalComment: _s(json['final_comment']),
      createdAt: _s(json['created_at']),
      updatedAt: _s(json['updated_at']),
      deletedAt: _s(json['deleted_at']),
    );
  }

  /// Keys match the SQLite column names in DBManager.tableMobileFoodPermit.
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'permit_number': permitNumber,
        'business_name': businessName,
        'business_address': businessAddress,
        'city': city,
        'state': state,
        'zip': zip,
        'phone': phone,
        'email': email,
        'applicant_name': applicantName,
        'applicant_address': applicantAddress,
        'applicant_city': applicantCity,
        'applicant_state': applicantState,
        'applicant_zip': applicantZip,
        'applicant_phone': applicantPhone,
        'applicant_email': applicantEmail,
        'applicant_signature': applicantSignature,
        'applicant_signature_name': applicantSignatureName,
        'individual_signature': individualSignature,
        'individual_signature_name': individualSignatureName,
        'received_date': receivedDate,
        'inspection_date': inspectionDate,
        'approved_by': approvedBy,
        'permit_issued': permitIssued,
        'isDelete': isDelete,
        'status': status,
        'total_fees': totalFees,
        'payment_type': paymentType,
        'receipt_number': receiptNumber,
        'final_comment': finalComment,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  /// "Rolling Bites Food Truck, Quincy, MA 02169"
  String get fullBusinessAddress => [
        businessAddress,
        city,
        [state, zip].where((e) => e.isNotEmpty).join(' '),
      ].where((e) => e.isNotEmpty).join(', ');
}

/// Wrapper for the whole API response: { "status": true, "permits": [...] }
class MobileFoodPermitResponse {
  final bool status;
  final List<MobileFoodPermitModel> permits;

  const MobileFoodPermitResponse({required this.status, required this.permits});

  factory MobileFoodPermitResponse.fromJson(Map<String, dynamic> json) {
    final list = json['permits'];
    return MobileFoodPermitResponse(
      status: json['status'] == true || json['status'] == 1,
      permits: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(MobileFoodPermitModel.fromJson)
              .toList()
          : const [],
    );
  }
}