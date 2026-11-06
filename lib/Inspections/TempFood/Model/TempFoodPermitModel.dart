import 'dart:convert';

/// Temporary Food permit from GET /temp-food/get-permit-list
///
/// Response:
/// {
///   "status": true,
///   "permits": [
///     {
///       "id": 1, "permit_number": "TP-000001-22", "event": "Family Fun Day",
///       "date": "2022-07-03", "last_date_of_enent": "",
///       "organization_applying": "Houghs Neck Community Council",
///       "hours_from": "10:00:00", "hours_to": "13:00:00",
///       "location": "Edgewater Drive Beach", "city": "Quincy",
///       "state": "MA", "zip": "02169", "email": "",
///       "how_food_transported": "...", "bathrooms": 2,
///       "handwashing_facilities": 2, "contact_person": "Aaron Cavin",
///       "address": "133 Darrow Street", "addr_city": "Quincy",
///       "addr_state": "MA", "addr_zip": "02169", "phone": "617-750-5398",
///       "caterer_name": "...", "caterer_address": "...", "caterer_city": "...",
///       "caterer_state": "...", "caterer_zip": "...", "persons_served": "",
///       "approved_by": "", "approved_by_date": "", "status": "Active",
///       "isDelete": 0, "final_comment": "", "applicant_signature": "",
///       "applicant_signature_name": "", "created_at": "...",
///       "updated_at": "...", "deleted_at": ""
///     }
///   ]
/// }
///
/// Saved in temp_food_permits: the main fields as columns (for search /
/// sort) + the full API object in raw_json, so no field is lost.
///
/// Path: lib/Inspections/TempFood/Model/TempFoodPermitModel.dart

/// "" / "null" / "0000-00-00" → null
String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null' || s.startsWith('0000-00-00')) return null;
  return s;
}

/// 2 / "2" / 2.0 / "" → int or null
int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString().trim());
}

class TempFoodPermitModel {
  // ---- Permit ----
  final int id;
  final String? permitNumber; // permit_number
  final String? event; // event
  final String? date; // date (first day of the event)
  final String? lastDateOfEvent; // last_date_of_enent (API spelling)
  final String? organizationApplying; // organization_applying
  final String? hoursFrom; // hours_from  "10:00:00"
  final String? hoursTo; // hours_to    "13:00:00"

  // ---- Event location ----
  final String? location; // location
  final String? city;
  final String? state;
  final String? zip;

  // ---- Food / facilities ----
  final String? howFoodTransported; // how_food_transported
  final int? bathrooms;
  final int? handwashingFacilities; // handwashing_facilities
  final int? personsServed; // persons_served

  // ---- Contact / applicant ----
  final String? contactPerson; // contact_person
  final String? email;
  final String? phone;
  final String? address; // applicant address
  final String? addrCity; // addr_city
  final String? addrState; // addr_state
  final String? addrZip; // addr_zip

  // ---- Caterer ----
  final String? catererName;
  final String? catererAddress;
  final String? catererCity;
  final String? catererState;
  final String? catererZip;

  // ---- Approval ----
  final String? approvedBy; // approved_by
  final String? approvedByDate; // approved_by_date
  final String? finalComment; // final_comment
  final String? applicantSignature; // applicant_signature
  final String? applicantSignatureName; // applicant_signature_name

  // ---- Record ----
  final String? status; // "Active"
  final int isDelete;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  /// The complete API object (used for "More details").
  final Map<String, dynamic> raw;

  const TempFoodPermitModel({
    required this.id,
    this.permitNumber,
    this.event,
    this.date,
    this.lastDateOfEvent,
    this.organizationApplying,
    this.hoursFrom,
    this.hoursTo,
    this.location,
    this.city,
    this.state,
    this.zip,
    this.howFoodTransported,
    this.bathrooms,
    this.handwashingFacilities,
    this.personsServed,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.addrCity,
    this.addrState,
    this.addrZip,
    this.catererName,
    this.catererAddress,
    this.catererCity,
    this.catererState,
    this.catererZip,
    this.approvedBy,
    this.approvedByDate,
    this.finalComment,
    this.applicantSignature,
    this.applicantSignatureName,
    this.status,
    this.isDelete = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.raw = const {},
  });

  // ---------- API ----------
  factory TempFoodPermitModel.fromJson(Map<String, dynamic> j) =>
      TempFoodPermitModel(
        id: _int(j['id']) ?? 0,
        permitNumber: _str(j['permit_number']),
        event: _str(j['event']),
        date: _str(j['date']),
        // API key is spelled "last_date_of_enent"
        lastDateOfEvent:
            _str(j['last_date_of_enent'] ?? j['last_date_of_event']),
        organizationApplying: _str(j['organization_applying']),
        hoursFrom: _str(j['hours_from']),
        hoursTo: _str(j['hours_to']),
        location: _str(j['location']),
        city: _str(j['city']),
        state: _str(j['state']),
        zip: _str(j['zip']),
        howFoodTransported: _str(j['how_food_transported']),
        bathrooms: _int(j['bathrooms']),
        handwashingFacilities: _int(j['handwashing_facilities']),
        personsServed: _int(j['persons_served']),
        contactPerson: _str(j['contact_person']),
        email: _str(j['email']),
        phone: _str(j['phone']),
        address: _str(j['address']),
        addrCity: _str(j['addr_city']),
        addrState: _str(j['addr_state']),
        addrZip: _str(j['addr_zip']),
        catererName: _str(j['caterer_name']),
        catererAddress: _str(j['caterer_address']),
        catererCity: _str(j['caterer_city']),
        catererState: _str(j['caterer_state']),
        catererZip: _str(j['caterer_zip']),
        approvedBy: _str(j['approved_by']),
        approvedByDate: _str(j['approved_by_date']),
        finalComment: _str(j['final_comment']),
        applicantSignature: _str(j['applicant_signature']),
        applicantSignatureName: _str(j['applicant_signature_name']),
        status: _str(j['status']),
        isDelete: _int(j['isDelete'] ?? j['is_delete']) ?? 0,
        createdAt: _str(j['created_at']),
        updatedAt: _str(j['updated_at']),
        deletedAt: _str(j['deleted_at']),
        raw: Map<String, dynamic>.from(j),
      );

  /// Same keys as the API.
  Map<String, dynamic> toJson() => {
        'id': id,
        'permit_number': permitNumber,
        'event': event,
        'date': date,
        'last_date_of_enent': lastDateOfEvent,
        'organization_applying': organizationApplying,
        'hours_from': hoursFrom,
        'hours_to': hoursTo,
        'location': location,
        'city': city,
        'state': state,
        'zip': zip,
        'email': email,
        'how_food_transported': howFoodTransported,
        'bathrooms': bathrooms,
        'handwashing_facilities': handwashingFacilities,
        'contact_person': contactPerson,
        'address': address,
        'addr_city': addrCity,
        'addr_state': addrState,
        'addr_zip': addrZip,
        'phone': phone,
        'caterer_name': catererName,
        'caterer_address': catererAddress,
        'caterer_city': catererCity,
        'caterer_state': catererState,
        'caterer_zip': catererZip,
        'persons_served': personsServed,
        'approved_by': approvedBy,
        'approved_by_date': approvedByDate,
        'status': status,
        'isDelete': isDelete,
        'final_comment': finalComment,
        'applicant_signature': applicantSignature,
        'applicant_signature_name': applicantSignatureName,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  // ---------- DB (temp_food_permits) ----------
  /// Same columns as before (no DB upgrade needed); every field is also
  /// kept in raw_json.
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
        'raw_json': jsonEncode(raw.isNotEmpty ? raw : toJson()),
      };

  factory TempFoodPermitModel.fromDb(Map<String, Object?> r) {
    // Full object from raw_json (all fields)
    final rawJson = r['raw_json'];
    if (rawJson is String && rawJson.isNotEmpty) {
      try {
        final d = jsonDecode(rawJson);
        if (d is Map) {
          return TempFoodPermitModel.fromJson(Map<String, dynamic>.from(d));
        }
      } catch (_) {}
    }
    // Fallback: columns only
    return TempFoodPermitModel(
      id: _int(r['id']) ?? 0,
      permitNumber: _str(r['permit_number']),
      organizationApplying: _str(r['business_name']),
      location: _str(r['business_address']),
      city: _str(r['city']),
      state: _str(r['state']),
      zip: _str(r['zip']),
      phone: _str(r['phone']),
      email: _str(r['email']),
      contactPerson: _str(r['owner_name']),
      event: _str(r['establishment_type']),
      date: _str(r['inspection_date']),
      status: _str(r['status']),
      isDelete: _int(r['isDelete']) ?? 0,
      createdAt: _str(r['created_at']),
      updatedAt: _str(r['updated_at']),
      deletedAt: _str(r['deleted_at']),
    );
  }

  // ---------- Names used by the screens / DB (kept for compatibility) ----------

  /// Vendor applying for the permit (falls back to the event name).
  String? get businessName => organizationApplying ?? event;

  /// Where the event takes place (the inspection address).
  String? get businessAddress => location;

  /// Contact person of the applicant.
  String? get ownerName => contactPerson;

  /// Event name.
  String? get establishmentType => event;

  /// Event date.
  String? get inspectionDate => date;

  bool get isActive => (status ?? '').toLowerCase() == 'active';

  /// "location, city, ST zip"
  String get fullAddress {
    final stateZip =
        [state, zip].where((e) => e != null && e.isNotEmpty).join(' ');
    final cityLine =
        [city, stateZip].where((e) => e != null && e.isNotEmpty).join(', ');
    return [location ?? '', cityLine].where((e) => e.isNotEmpty).join(', ');
  }

  /// Applicant mailing address: "address, addr_city, ST zip"
  String get applicantFullAddress {
    final stateZip = [addrState, addrZip]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    final cityLine = [addrCity, stateZip]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');
    return [address ?? '', cityLine].where((e) => e.isNotEmpty).join(', ');
  }

  /// "10:00 AM – 1:00 PM" (empty if no hours)
  String get hoursText {
    String fmt(String? t) {
      if (t == null) return '';
      final parts = t.split(':');
      final h = int.tryParse(parts.first);
      final m = parts.length > 1 ? parts[1] : '00';
      if (h == null) return t;
      final hour12 = h % 12 == 0 ? 12 : h % 12;
      return '$hour12:$m ${h < 12 ? 'AM' : 'PM'}';
    }

    final from = fmt(hoursFrom);
    final to = fmt(hoursTo);
    if (from.isEmpty && to.isEmpty) return '';
    if (from.isEmpty || to.isEmpty) return from.isEmpty ? to : from;
    return '$from – $to';
  }
}