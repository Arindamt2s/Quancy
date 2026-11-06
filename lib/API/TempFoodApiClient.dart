import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';

/// Shared GET / POST helper for the Temporary Food repositories
/// (same headers, timeout and error mapping as the Food repositories).
///
/// Path: lib/API/TempFood/TempFoodApiClient.dart
class TempFoodApiClient {
  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> _headers(String token, {bool json = false}) => {
        ...ApiHeaders.basicHeader(),
        if (json) 'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// GET [path] (relative to baseUrl). Throws NoInternetException,
  /// TimeoutApiException or InvalidResponseException like the other repos.
  static Future<Map<String, dynamic>> get(String path,
      {required String token}) async {
    final url = Uri.parse('${URLConstants.baseUrl}$path');
    try {
      final res =
          await http.get(url, headers: _headers(token)).timeout(timeout);
      debugPrint('🏕️ GET ${res.statusCode}: $url');
      final json = ApiResponseHandler.handle(res);
      if (json is Map) return Map<String, dynamic>.from(json);
      return {'data': json};
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }

  /// POST a JSON body. Never throws – the result says what happened.
  static Future<TempFoodPostResult> post(
    String path, {
    required String token,
    required Object body,
  }) async {
    final url = Uri.parse('${URLConstants.baseUrl}$path');
    try {
      final res = await http
          .post(url,
              headers: _headers(token, json: true), body: jsonEncode(body))
          .timeout(timeout);
      debugPrint('🏕️ POST ${res.statusCode}: $url');

      var json = <String, dynamic>{};
      try {
        final d = jsonDecode(res.body);
        if (d is Map) json = Map<String, dynamic>.from(d);
      } catch (_) {
        debugPrint('⚠️ Non-JSON response: ${res.body}');
      }

      final ok2xx = res.statusCode >= 200 && res.statusCode < 300;
      final flag = json.containsKey('status')
          ? isTrue(json['status'])
          : json.containsKey('success')
              ? isTrue(json['success'])
              : ok2xx;
      if (ok2xx && flag) {
        return TempFoodPostResult(json: json, statusCode: res.statusCode);
      }
      return TempFoodPostResult(
        json: json,
        statusCode: res.statusCode,
        error: messageOf(json) ?? 'Server error (${res.statusCode}).',
      );
    } on SocketException {
      return const TempFoodPostResult(error: 'No internet connection.');
    } on TimeoutException {
      return const TempFoodPostResult(
          error: 'The server took too long to respond.');
    } catch (e) {
      debugPrint('❌ POST $url error: $e');
      return TempFoodPostResult(error: 'Request failed: $e');
    }
  }

  static bool isTrue(dynamic v) =>
      v == true || v == 1 || v?.toString().toLowerCase() == 'true';

  /// "message", or the first validation error.
  static String? messageOf(Map<String, dynamic> json) {
    final m = json['message']?.toString();
    if (m != null && m.trim().isNotEmpty) return m;
    final errors = json['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      return first is List && first.isNotEmpty
          ? first.first.toString()
          : first.toString();
    }
    return null;
  }

  /// Finds the list in a response: tries [keys] (and a paginated
  /// {"data": {"data": [...]}}), then any list value.
  static List<Map<String, dynamic>> listOf(
    Map<String, dynamic> json, [
    List<String> keys = const [],
  ]) {
    List<Map<String, dynamic>> asMaps(List l) => l
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    for (final k in [...keys, 'data', 'list', 'result']) {
      var v = json[k];
      if (v is Map && v['data'] is List) v = v['data'];
      if (v is List) return asMaps(v);
    }
    for (final v in json.values) {
      if (v is List) return asMaps(v);
    }
    return [];
  }

  /// Throws when the body says "status": false.
  static void ensureOk(Map<String, dynamic> json, String what) {
    if (json.containsKey('status') && !isTrue(json['status'])) {
      throw TempFoodApiException(
          messageOf(json) ?? 'The server could not return $what.');
    }
  }
}

class TempFoodPostResult {
  final Map<String, dynamic> json;
  final int? statusCode;
  final String? error;

  const TempFoodPostResult({this.json = const {}, this.statusCode, this.error});

  bool get isSuccess => error == null;
}

class TempFoodApiException implements Exception {
  final String message;
  TempFoodApiException(this.message);

  @override
  String toString() => message;
}

/// Result returned to the inspection screen by the submit repositories.
class TempFoodSubmitResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;

  const TempFoodSubmitResult._({this.data, this.error, this.statusCode});

  factory TempFoodSubmitResult.success(T? data, {int? statusCode}) =>
      TempFoodSubmitResult._(data: data, statusCode: statusCode);

  factory TempFoodSubmitResult.failure(String error, {int? statusCode}) =>
      TempFoodSubmitResult._(error: error, statusCode: statusCode);

  bool get isSuccess => error == null;
}
