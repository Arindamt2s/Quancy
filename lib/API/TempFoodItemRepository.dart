import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodSectionModel.dart';

/// GET /api/temp-food/items-list
///
/// Path: lib/API/TempFoodItemRepository.dart
class TempFoodItemRepository {
  static const String baseUrl = URLConstants.baseUrl;

  Future<List<TempFoodItemModel>> getItems({required String token}) async {
    final url = Uri.parse('$baseUrl${URLConstants.getTempFoodItemList}');

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

      debugPrint('🏕️ Temp Food items ${response.statusCode}: $url');

      final json = ApiResponseHandler.handle(response);

      // "status": false → error message from the server
      if (json is Map && json['status'] == false) {
        throw Exception(json['message'] ?? 'Could not load inspection items.');
      }

      // Supports: [..], {"data": [..]}, {"items": [..]},
      // {"data": {"data": [..]}} (paginated)
      dynamic list = json;
      if (json is Map) {
        list = json['items'] ?? json['data'];
        if (list is Map) list = list['data'];
      }
      if (list is! List) return [];

      return list
          .whereType<Map>()
          .map((e) => TempFoodItemModel.fromJson(Map<String, dynamic>.from(e)))
          .where((i) => i.id != 0)
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