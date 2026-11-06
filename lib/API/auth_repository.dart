import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Login/Model/LoginResponseModel.dart';

class AuthRepository {
  static const String baseUrl = URLConstants.baseUrl;

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl${URLConstants.login}');

    try {
      final response = await http
          .post(
            url,
            headers: ApiHeaders.basicHeader(),
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      final json = ApiResponseHandler.handle(response);
      return LoginResponse.fromJson(json);
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }
}