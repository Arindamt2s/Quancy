import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/HTTPS/apiConstants.dart';


/// Result of a Food submit call: success, or a message for the user.
class FoodSubmitResult {
  final String? error;
  final int? statusCode;

  /// Decoded response body (null if it wasn't JSON).
  final Map<String, dynamic>? body;

  const FoodSubmitResult._({this.error, this.statusCode, this.body});

  factory FoodSubmitResult.success({int? statusCode, Map<String, dynamic>? body}) =>
      FoodSubmitResult._(statusCode: statusCode, body: body);

  factory FoodSubmitResult.failure(String error, {int? statusCode}) =>
      FoodSubmitResult._(error: error, statusCode: statusCode);

  bool get isSuccess => error == null;
}

/// Shared POST for /food/inspection-item and /food/item-temperature.
class FoodSubmitHttp {
  FoodSubmitHttp({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<FoodSubmitResult> postJson(
    String path,
    Object body, {
    required String token,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final url = Uri.parse('${URLConstants.baseUrl}$path');
    try {
      final res = await _client
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      debugPrint('🌐 POST $url → ${res.statusCode}');
      if (kDebugMode) {
        final s = res.body;
        debugPrint('↩️ ${s.length > 500 ? '${s.substring(0, 500)}…' : s}');
      }

      final json = _decode(res.body);

      if (res.statusCode == 401) {
        return FoodSubmitResult.failure('Session expired. Please log in again.',
            statusCode: 401);
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return FoodSubmitResult.failure(
          _errorMessage(json) ?? 'Server error (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
      // 2xx but the API says it failed
      final status = json?['status'];
      if (status == false || status == 0) {
        return FoodSubmitResult.failure(
          _errorMessage(json) ?? 'Submission failed.',
          statusCode: res.statusCode,
        );
      }
      return FoodSubmitResult.success(statusCode: res.statusCode, body: json);
    } on SocketException {
      return FoodSubmitResult.failure(
          'No internet connection. The inspection is saved – try again later.');
    } on TimeoutException {
      return FoodSubmitResult.failure(
          'The server took too long to respond. Please try again.');
    } on http.ClientException catch (e) {
      return FoodSubmitResult.failure(e.message);
    } catch (e) {
      debugPrint('❌ POST $path error: $e');
      return FoodSubmitResult.failure('Could not reach the server.');
    }
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// "message", or the first Laravel validation error.
  String? _errorMessage(Map<String, dynamic>? body) {
    if (body == null) return null;
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      if (first != null) return first.toString();
    }
    final msg = body['message']?.toString();
    return (msg == null || msg.trim().isEmpty) ? null : msg;
  }
}