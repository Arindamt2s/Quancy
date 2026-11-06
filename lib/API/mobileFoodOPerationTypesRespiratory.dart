import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';

import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeModel.dart';

/// Operation types for the Final Submit tab.
/// GET /mobile-food/operation-types
/// → {"status": true, "operationTypes": [ {id, name, status, ...} ]}
class MobileFoodOperationTypesRepository {
  static const String baseUrl = URLConstants.baseUrl;

  Future<List<MobileFoodOperationTypeModel>> getOperationTypes({
    required String token,
  }) async {
    final url =
        Uri.parse('$baseUrl${URLConstants.mobileFoodOOperationTypesList}');

    try {
      final response = await http
          .get(
            url,
            headers: {
              ...ApiHeaders.basicHeader(),
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 45));

      final json = ApiResponseHandler.handle(response);
      return MobileFoodOperationTypeModel.listFromResponse(json);
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }
}