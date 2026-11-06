class UserModel {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? emailVerifiedAt;
  final int? roleId;
  final int? status;
  final String? profilePhoto;
  final String? deletedAt;
  final String? createdAt;
  final String? updatedAt;

  UserModel({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.emailVerifiedAt,
    this.roleId,
    this.status,
    this.profilePhoto,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      emailVerifiedAt: json['email_verified_at'],
      roleId: _toInt(json['role_id']),
      status: _toInt(json['status']),
      profilePhoto: json['profile_photo'],
      deletedAt: json['deleted_at'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'email_verified_at': emailVerifiedAt,
        'role_id': roleId,
        'status': status,
        'profile_photo': profilePhoto,
        'deleted_at': deletedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  static int? _toInt(dynamic v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));
}