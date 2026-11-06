import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';

import 'package:quincy/Inspections/MobileFood/Model/MobileFoodSectionModel.dart';

/// Sections, section parts and items for the Mobile Food inspection form.
class MobileFoodChecklistRepository {
  static const String baseUrl = URLConstants.baseUrl;

  Future<MobileFoodSectionResponse> getSections({required String token}) async {
    final json = await _get(URLConstants.mobileFoodSectionList, token);
    return MobileFoodSectionResponse.fromJson(json);
  }

  Future<MobileFoodSectionPartResponse> getSectionParts({
    required String token,
  }) async {
    final json = await _get(URLConstants.mobileFoodSectionPartsList, token);
    return MobileFoodSectionPartResponse.fromJson(json);
  }

  Future<MobileFoodItemResponse> getItems({required String token}) async {
    final json = await _get(URLConstants.mobileFoodItemList, token);
    return MobileFoodItemResponse.fromJson(json);
  }

  // ---------------- Shared GET ----------------

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final url = Uri.parse('$baseUrl$path');

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

      return ApiResponseHandler.handle(response);
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }
}