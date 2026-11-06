import 'dart:convert';

/// Model for GET /food/get-permit-list
///
/// The exact response shape wasn't shared yet, so parsing is tolerant:
///  - success flag: "status" or "success"
///  - list key: data / permits / permitList / permit_list / foodPermits /
///    food_permits (also Laravel pagination: data.data)
///  - each field tries the common key names (see [_pick] calls)
///  - the whole permit object is kept in [rawJson], so nothing is lost and
///    the details sheet can show every field the API sends.

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString());
}

String? _toStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s == 'null' ? null : s;
}

bool _toBool(dynamic v) =>
    v == true || v == 1 || v == '1' || v.toString().toLowerCase() == 'true';

/// First non-empty value among [keys].
dynamic _pick(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) return v;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Response wrapper
// ---------------------------------------------------------------------------

class FoodPermitResponse {
  final bool success;
  final List<FoodPermitModel> permits;

  FoodPermitResponse({required this.success, required this.permits});

  factory FoodPermitResponse.fromJson(Map<String, dynamic> json) {
    dynamic raw = _pick(json, const [
      'data',
      'permits',
      'permitList',
      'permit_list',
      'foodPermits',
      'food_permits',
    ]);
    // Laravel pagination: { data: { data: [...] } }
    if (raw is Map && raw['data'] is List) raw = raw['data'];
    final list = raw is List ? raw : const [];

    final flag = json['status'] ?? json['success'];
    return FoodPermitResponse(
      // No flag at all but a list is present → treat as success.
      success: flag == null ? raw is List : _toBool(flag),
      permits: list
          .whereType<Map>()
          .map((e) => FoodPermitModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Food permit
// ---------------------------------------------------------------------------

class FoodPermitModel {
  final int id;
  final String? permitNumber;
  final String? businessName;
  final String? businessAddress;
  final String? city;
  final String? state;
  final String? zip;
  final String? phone;
  final String? email;
  final String? ownerName;
  final String? establishmentType;
  final String? inspectionDate;
  final int? status;
  final int isDelete;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  /// Full permit object exactly as the API sent it.
  final String rawJson;

  const FoodPermitModel({
    required this.id,
    this.permitNumber,
    this.businessName,
    this.businessAddress,
    this.city,
    this.state,
    this.zip,
    this.phone,
    this.email,
    this.ownerName,
    this.establishmentType,
    this.inspectionDate,
    this.status,
    this.isDelete = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.rawJson = '{}',
  });

  // ---------- API ----------
  factory FoodPermitModel.fromJson(Map<String, dynamic> j) {
    return FoodPermitModel(
      id: _toInt(j['id']) ?? 0,
      permitNumber: _toStr(_pick(j, const [
        'permit_number',
        'permit_no',
        'permitNo',
        'permit_num',
        'license_number',
      ])),
      businessName: _toStr(_pick(j, const [
        'business_name',
        'establishment_name',
        'dba_name',
        'dba',
        'name',
      ])),
      businessAddress: _toStr(_pick(j, const [
        'business_address',
        'establishment_address',
        'address',
        'street_address',
      ])),
      city: _toStr(_pick(j, const ['city', 'business_city'])),
      state: _toStr(_pick(j, const ['state', 'business_state'])),
      zip: _toStr(_pick(j, const ['zip', 'zip_code', 'business_zip'])),
      phone: _toStr(_pick(j, const [
        'phone',
        'business_phone',
        'telephone',
        'phone_number',
      ])),
      email: _toStr(_pick(j, const ['email', 'business_email'])),
      ownerName: _toStr(_pick(j, const [
        'owner_name',
        'owner',
        'applicant_name',
        'person_in_charge',
      ])),
      establishmentType: _toStr(_pick(j, const [
        'establishment_type',
        'business_type',
        'type',
        'category',
      ])),
      inspectionDate: _toStr(j['inspection_date']),
      status: _toInt(j['status']),
      isDelete: _toInt(j['isDelete'] ?? j['is_delete']) ?? 0,
      createdAt: _toStr(j['created_at']),
      updatedAt: _toStr(j['updated_at']),
      deletedAt: _toStr(j['deleted_at']),
      rawJson: jsonEncode(j),
    );
  }

  // ---------- DB ----------
  Map<String, dynamic> toDb() => {
        'id': id,
        'permit_number': permitNumber,
        'business_name': businessName,
        'business_address': businessAddress,
        'city': city,
        'state': state,
        'zip': zip,
        'phone': phone,
        'email': email,
        'owner_name': ownerName,
        'establishment_type': establishmentType,
        'inspection_date': inspectionDate,
        'status': status,
        'isDelete': isDelete,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
        'raw_json': rawJson,
      };

  factory FoodPermitModel.fromDb(Map<String, Object?> r) => FoodPermitModel(
        id: _toInt(r['id']) ?? 0,
        permitNumber: _toStr(r['permit_number']),
        businessName: _toStr(r['business_name']),
        businessAddress: _toStr(r['business_address']),
        city: _toStr(r['city']),
        state: _toStr(r['state']),
        zip: _toStr(r['zip']),
        phone: _toStr(r['phone']),
        email: _toStr(r['email']),
        ownerName: _toStr(r['owner_name']),
        establishmentType: _toStr(r['establishment_type']),
        inspectionDate: _toStr(r['inspection_date']),
        status: _toInt(r['status']),
        isDelete: _toInt(r['isDelete']) ?? 0,
        createdAt: _toStr(r['created_at']),
        updatedAt: _toStr(r['updated_at']),
        deletedAt: _toStr(r['deleted_at']),
        rawJson: (r['raw_json'] as String?) ?? '{}',
      );

  // ---------- Helpers ----------

  /// Every field the API sent (for the details sheet).
  Map<String, dynamic> get raw {
    try {
      final d = jsonDecode(rawJson);
      return d is Map ? Map<String, dynamic>.from(d) : {};
    } catch (_) {
      return {};
    }
  }

  String get displayName =>
      businessName ?? (permitNumber != null ? 'Permit $permitNumber' : 'Permit #$id');

  /// "12 Main St, Quincy, MA 02169"
  String get fullAddress {
    final cityLine = [
      city,
      [state, zip].where((e) => e != null).join(' '),
    ].where((e) => e != null && e.isNotEmpty).join(', ');
    return [businessAddress, cityLine]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');
  }
}