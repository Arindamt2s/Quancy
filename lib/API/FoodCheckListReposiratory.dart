import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/Food/Model/FoodSectionModel.dart';

/// Result wrapper: data on success, error message otherwise.
class FoodApiResult<T> {
  final T? data;
  final String? error;
  final bool isOffline;

  const FoodApiResult.success(this.data)
      : error = null,
        isOffline = false;
  const FoodApiResult.failure(this.error, {this.isOffline = false})
      : data = null;

  bool get isSuccess => error == null;
}

/// Food checklist APIs:
///   GET /food/sections-list       → { status, sections: [...] }
///   GET /food/section-parts-list  → { status, sectionParts: [...] }
///   GET /food/items-list          → { status, items: [...] }
class FoodChecklistApiRepository {
  FoodChecklistApiRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 30);

  Future<FoodApiResult<List<FoodSectionModel>>> fetchSections(
          {String? token}) =>
      _getList(URLConstants.getFoodSectionList, 'sections',
          FoodSectionModel.fromJson, token);

  Future<FoodApiResult<List<FoodSectionPartModel>>> fetchSectionParts(
          {String? token}) =>
      _getList(URLConstants.getFoodSectionPartsList, 'sectionParts',
          FoodSectionPartModel.fromJson, token);

  Future<FoodApiResult<List<FoodItemModel>>> fetchItems({String? token}) =>
      _getList(URLConstants.getFoodItemList, 'items', FoodItemModel.fromJson,
          token);

  /// GET [path], read the array under [key] and map every entry.
  Future<FoodApiResult<List<T>>> _getList<T>(
    String path,
    String key,
    T Function(Map<String, dynamic>) fromJson,
    String? token,
  ) async {
    token ??= await DBManager.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      return const FoodApiResult.failure('Session expired. Please log in again.');
    }

    final url = Uri.parse('${URLConstants.baseUrl}$path');
    try {
      final res = await _client.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(_timeout);

      debugPrint('🌐 GET $url → ${res.statusCode}');

      if (res.statusCode == 401) {
        return const FoodApiResult.failure(
            'Session expired. Please log in again.');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return FoodApiResult.failure('Server error (${res.statusCode}).');
      }

      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) {
        return const FoodApiResult.failure('Unexpected server response.');
      }
      if (body['status'] == false) {
        return FoodApiResult.failure(
            body['message']?.toString() ?? 'Request failed.');
      }

      final raw = body[key];
      if (raw is! List) return const FoodApiResult.success([]);

      final list = raw
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return FoodApiResult.success(list);
    } on SocketException {
      return const FoodApiResult.failure('No internet connection.',
          isOffline: true);
    } on TimeoutException {
      return const FoodApiResult.failure('Request timed out.', isOffline: true);
    } on http.ClientException catch (e) {
      return FoodApiResult.failure(e.message, isOffline: true);
    } catch (e) {
      debugPrint('❌ $path parse error: $e');
      return const FoodApiResult.failure('Could not read the server response.');
    }
  }
}