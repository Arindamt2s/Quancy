import 'dart:convert';

import 'package:quincy/Inspections/Tobacco/Model/TobaccoJson.dart';

/// One permit from GET /tobacco/get-permit-list-by-pagination.
///
/// Path: lib/Inspections/Tobacco/Model/TobaccoPermitModel.dart
///
/// Main fields are typed; the whole API object is kept in [raw]
/// (saved as raw_json) so the details popup can show every field.
class TobaccoPermitModel {
  final int id;
  final String? date;
  final String? permitNumber;
  final String? establishmentName;
  final String? businessAddress;
  final String? city;
  final String? state;
  final String? zip;
  final String? phone;
  final String? email;
  final String? mailingAddress;
  final String? applicantName;
  final String? ownerName;
  final String? inspectionDate;

  /// "Active" / "Inactive" …
  final String? status;
  final int isDelete;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final Map<String, dynamic> raw;

  const TobaccoPermitModel({
    required this.id,
    this.date,
    this.permitNumber,
    this.establishmentName,
    this.businessAddress,
    this.city,
    this.state,
    this.zip,
    this.phone,
    this.email,
    this.mailingAddress,
    this.applicantName,
    this.ownerName,
    this.inspectionDate,
    this.status,
    this.isDelete = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.raw = const {},
  });

  /// Same name the other permit models use.
  String? get businessName => establishmentName;

  /// owner_name, else applicant_name.
  String? get displayOwner => ownerName ?? applicantName;

  bool get isDeleted => isDelete == 1 || (deletedAt ?? '').isNotEmpty;

  factory TobaccoPermitModel.fromJson(Map<String, dynamic> j) {
    return TobaccoPermitModel(
      id: tbInt(j['id']) ?? 0,
      date: tbStr(j['date']),
      permitNumber: tbStr(j['permit_number']),
      establishmentName:
          tbStr(j['establishment_name']) ?? tbStr(j['business_name']),
      businessAddress: tbStr(j['business_address']),
      city: tbStr(j['city']),
      state: tbStr(j['state']),
      zip: tbStr(j['zip']),
      phone: tbStr(j['phone']),
      email: tbStr(j['permit_email']) ?? tbStr(j['email']),
      mailingAddress: tbStr(j['mailing_address']),
      applicantName: tbStr(j['applicant_name']),
      ownerName: tbStr(j['owner_name']),
      inspectionDate: tbStr(j['inspection_date']),
      status: tbStr(j['status']),
      isDelete: tbInt(j['isDelete']) ?? 0,
      createdAt: tbStr(j['created_at']),
      updatedAt: tbStr(j['updated_at']),
      deletedAt: tbStr(j['deleted_at']),
      raw: Map<String, dynamic>.from(j),
    );
  }

  /// Row for the tobacco_permits table.
  Map<String, Object?> toDb() => {
        'id': id,
        'date': date,
        'permit_number': permitNumber,
        'establishment_name': establishmentName,
        'business_address': businessAddress,
        'city': city,
        'state': state,
        'zip': zip,
        'phone': phone,
        'permit_email': email,
        'applicant_name': applicantName,
        'owner_name': ownerName,
        'inspection_date': inspectionDate,
        'status': status,
        'isDelete': isDelete,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
        'raw_json': jsonEncode(raw),
      };

  /// From a tobacco_permits row (uses raw_json when it can).
  factory TobaccoPermitModel.fromDb(Map<String, Object?> row) {
    final rawJson = row['raw_json'];
    if (rawJson is String && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          return TobaccoPermitModel.fromJson(
              Map<String, dynamic>.from(decoded));
        }
      } catch (_) {/* fall back to the columns */}
    }
    final m = Map<String, dynamic>.from(row)..remove('raw_json');
    return TobaccoPermitModel.fromJson(m);
  }

  /// Search on business, permit #, address, city, applicant / owner.
  bool matches(String lowerQuery) {
    if (lowerQuery.isEmpty) return true;
    for (final v in [
      establishmentName,
      permitNumber,
      businessAddress,
      city,
      zip,
      applicantName,
      ownerName,
      phone,
    ]) {
      if (v != null && v.toLowerCase().contains(lowerQuery)) return true;
    }
    return false;
  }
}
