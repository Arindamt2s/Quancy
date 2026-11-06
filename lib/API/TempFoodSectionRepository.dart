import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodSectionModel.dart';

/// GET /api/temp-food/sections-list
///
/// Path: lib/API/TempFood/TempFoodSectionRepository.dart
class TempFoodSectionRepository {
  static const String baseUrl = URLConstants.baseUrl;

  Future<List<TempFoodSectionModel>> getSections(
      {required String token}) async {
    final url = Uri.parse('$baseUrl${URLConstants.tempFoodSectionList}');

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

      debugPrint('🏕️ Temp Food sections ${response.statusCode}: $url');

      final json = ApiResponseHandler.handle(response);

      if (json is Map && json['status'] == false) {
        throw Exception(json['message'] ?? 'Could not load sections.');
      }

      dynamic list = json;
      if (json is Map) {
        list = json['sections'] ?? json['data'];
        if (list is Map) list = list['data'];
      }
      if (list is! List) return [];

      return list
          .whereType<Map>()
          .map((e) =>
              TempFoodSectionModel.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.id != 0)
          .toList();
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }
}