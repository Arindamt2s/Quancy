import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/Food/Model/FoodPermitModel.dart';

class FoodPermitRepository {
  static const String baseUrl = URLConstants.baseUrl;

  Future<FoodPermitResponse> getPermitList({
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl${URLConstants.getFoodPermitList}');

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

      debugPrint('🍽️ Food permits ${response.statusCode}: $url');

      final json = ApiResponseHandler.handle(response);
      debugPrint('🍽️ Food permits keys: ${json.keys.toList()}');
      return FoodPermitResponse.fromJson(json);
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }
}