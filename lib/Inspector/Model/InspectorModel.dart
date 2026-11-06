// lib/Inspections/Inspector/Model/InspectorModel.dart
//
// GET /inspector
// {
//   "status": true,
//   "inspectors": [
//     { "id": 1, "first_name": "...", "last_name": "...", "nick_name": "...",
//       "email": "...", "phone": "...", "email_verified_at": "...",
//       "role_id": 2, "status": 1, "profile_photo": "...",
//       "deleted_at": null, "created_at": "...", "updated_at": "..." }
//   ]
// }

class InspectorModel {
  final int id;
  final String firstName;
  final String lastName;
  final String nickName;
  final String email;
  final String phone;
  final String? emailVerifiedAt;
  final int? roleId;
  final int? status;
  final String profilePhoto;
  final String? deletedAt;
  final String? createdAt;
  final String? updatedAt;

  const InspectorModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.nickName = '',
    this.email = '',
    this.phone = '',
    this.emailVerifiedAt,
    this.roleId,
    this.status,
    this.profilePhoto = '',
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// "First Last" (falls back to nick name, then email)
  String get fullName {
    final n = '$firstName $lastName'.trim();
    if (n.isNotEmpty) return n;
    if (nickName.isNotEmpty) return nickName;
    return email;
  }

  bool get isDeleted => deletedAt != null && deletedAt!.isNotEmpty;

  // ---------------- JSON (API) ----------------

  factory InspectorModel.fromJson(Map<String, dynamic> j) => InspectorModel(
        id: _int(j['id']) ?? 0,
        firstName: _str(j['first_name']),
        lastName: _str(j['last_name']),
        nickName: _str(j['nick_name']),
        email: _str(j['email']),
        phone: _str(j['phone']),
        emailVerifiedAt: _strOrNull(j['email_verified_at']),
        roleId: _int(j['role_id']),
        status: _int(j['status']),
        profilePhoto: _str(j['profile_photo']),
        deletedAt: _strOrNull(j['deleted_at']),
        createdAt: _strOrNull(j['created_at']),
        updatedAt: _strOrNull(j['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'nick_name': nickName,
        'email': email,
        'phone': phone,
        'email_verified_at': emailVerifiedAt,
        'role_id': roleId,
        'status': status,
        'profile_photo': profilePhoto,
        'deleted_at': deletedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  // ---------------- Database (inspectors table) ----------------

  /// Same column names as the API, so the row is just the JSON.
  Map<String, Object?> toDb() => toJson();

  factory InspectorModel.fromDb(Map<String, Object?> r) =>
      InspectorModel.fromJson(Map<String, dynamic>.from(r));

  // ---------------- Helpers ----------------

  static int? _int(dynamic v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  static String _str(dynamic v) => v?.toString().trim() ?? '';

  static String? _strOrNull(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  }
}

/// Whole response of GET /inspector
class InspectorListResponse {
  final bool status;
  final String? message;
  final List<InspectorModel> inspectors;

  InspectorListResponse({
    required this.status,
    required this.inspectors,
    this.message,
  });

  factory InspectorListResponse.fromJson(Map<String, dynamic> json) {
    bool b(dynamic v) =>
        v == true || v == 1 || v?.toString().toLowerCase() == 'true';
    final list = json['inspectors'];
    return InspectorListResponse(
      status: b(json['status']) || b(json['success']),
      message: json['message']?.toString(),
      inspectors: list is List
          ? list
              .whereType<Map>()
              .map((e) => InspectorModel.fromJson(Map<String, dynamic>.from(e)))
              .where((i) => i.id != 0)
              .toList()
          : const [],
    );
  }
}