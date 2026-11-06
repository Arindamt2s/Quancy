

import 'package:quincy/Login/Model/LoginModel.dart';

class LoginResponse {
  final UserModel user;
  final String accessToken;

  LoginResponse({required this.user, required this.accessToken});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    if (json['user'] == null || json['access_token'] == null) {
      throw const FormatException('Missing user or access_token in response');
    }
    return LoginResponse(
      user: UserModel.fromJson(json['user']),
      accessToken: json['access_token'],
    );
  }
}