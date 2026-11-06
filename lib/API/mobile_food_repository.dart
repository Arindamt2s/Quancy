import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodPermitModel.dart';


class MobileFoodPermitRepository {
  static const String baseUrl = URLConstants.baseUrl;

  Future<MobileFoodPermitResponse> getPermitList({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl${URLConstants.mobileFoodPermits}');

    try {
      final response = await http
          .get(
            url,
            headers: {
              ...ApiHeaders.basicHeader(),
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final json = ApiResponseHandler.handle(response);
      return MobileFoodPermitResponse.fromJson(json);
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }
}