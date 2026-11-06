// lib/Inspections/MobileFood/Repository/MobileFoodInspectionApiRepository.dart
//
// API only – no database access here.
// The screen reads the local DB, builds the request and calls submitInspection().

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/MobileFood/Submit/Model/mobileFoodInspectionModel.dart';



/// Success / error wrapper so the UI doesn't need try/catch.
class ApiResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  ApiResult.success(this.data) : error = null;
  ApiResult.failure(this.error) : data = null;
}

class MobileFoodInspectionApiRepository {
  final http.Client _client;

  MobileFoodInspectionApiRepository({http.Client? client})
      : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 90);

  /// POST /mobile-food/inspection
  Future<ApiResult<MobileFoodInspectionResponse>> submitInspection(
    MobileFoodInspectionRequest request, {
    String? token,
  }) async {
    final uri =
        Uri.parse(URLConstants.baseUrl + URLConstants.mobileFoodInspection);

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader: 'application/json',
              if (token != null && token.isNotEmpty)
                HttpHeaders.authorizationHeader: 'Bearer $token',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      final json = _tryDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json == null) {
          return ApiResult.failure('Invalid response from server.');
        }
        final parsed = MobileFoodInspectionResponse.fromJson(json);
        if (!parsed.success) {
          return ApiResult.failure(parsed.message ?? 'Submission failed.');
        }
        return ApiResult.success(parsed);
      }

      if (response.statusCode == 401) {
        return ApiResult.failure('Session expired. Please log in again.');
      }

      return ApiResult.failure(
        json?['message']?.toString() ??
            _firstValidationError(json) ??
            'Server error (${response.statusCode}).',
      );
    } on TimeoutException {
      return ApiResult.failure('Request timed out. Please try again.');
    } on SocketException {
      return ApiResult.failure('No internet connection.');
    } catch (e) {
      return ApiResult.failure('Unexpected error: $e');
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  /// Laravel style: {"errors": {"field": ["message"]}}
  String? _firstValidationError(Map<String, dynamic>? json) {
    final errors = json?['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      return first is List && first.isNotEmpty
          ? first.first.toString()
          : first.toString();
    }
    return null;
  }
}