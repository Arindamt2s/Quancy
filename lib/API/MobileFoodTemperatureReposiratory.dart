// lib/API/MobileFoodTemperatureSubmitRepository.dart
//
// POST /mobile-food/item-temperature  (JSON array)
// Call it AFTER /mobile-food/inspection-item succeeded.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:quincy/API/MobileFoodInspectionSubmitRepository.dart'
    show ApiResult;
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureSubmitModel.dart';


class MobileFoodTemperatureSubmitRepository {
  final http.Client _client;

  MobileFoodTemperatureSubmitRepository({http.Client? client})
      : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 60);

  Future<ApiResult<MobileFoodTemperatureSubmitResponse>> submitTemperatures({
    required List<MobileFoodTemperatureRequest> temperatures,
    String? token,
  }) async {
    // Only rows the inspector actually filled in
    final toSend = temperatures.where((t) => t.hasData).toList();

    if (toSend.isEmpty) {
      _log('ℹ️ No temperature rows to submit.');
      return ApiResult.success(MobileFoodTemperatureSubmitResponse(
          status: true, message: 'No temperatures'));
    }

    final uri = Uri.parse(
        URLConstants.baseUrl + URLConstants.mobileFoodTemperatureSubmit);
    final body = jsonEncode(toSend.map((t) => t.toJson()).toList());

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
      if (token != null && token.isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer $token',
    };

    // ---------- REQUEST LOG ----------
    _log('================ 📤 TEMPERATURE REQUEST ================');
    _log('POST $uri');
    _log('Body:\n${const JsonEncoder.withIndent('  ').convert(jsonDecode(body))}');

    try {
      final sw = Stopwatch()..start();
      final response =
          await _client.post(uri, headers: headers, body: body).timeout(_timeout);
      sw.stop();

      // ---------- RESPONSE LOG ----------
      _log('================ 📥 TEMPERATURE RESPONSE ================');
      _log('Status: ${response.statusCode} (${sw.elapsedMilliseconds} ms)');
      _log('Body:\n${response.body}');

      final json = _tryDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json == null) {
          return ApiResult.failure('Invalid response from server.');
        }
        final parsed = MobileFoodTemperatureSubmitResponse.fromJson(json);
        if (!parsed.status) {
          return ApiResult.failure(
              parsed.message ?? 'Temperature submission failed.');
        }
        return ApiResult.success(parsed);
      }

      if (response.statusCode == 401) {
        return ApiResult.failure('Session expired. Please log in again.');
      }

      final parts = [json?['message']?.toString(), _firstValidationError(json)]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toList();
      return ApiResult.failure('(${response.statusCode}) '
          '${parts.isEmpty ? 'Server error' : parts.join(' – ')}');
    } on TimeoutException {
      _log('❌ TEMPERATURE TIMEOUT after ${_timeout.inSeconds}s');
      return ApiResult.failure('Request timed out. Please try again.');
    } on SocketException catch (e) {
      _log('❌ TEMPERATURE SOCKET ERROR: $e');
      return ApiResult.failure('No internet connection.');
    } catch (e, st) {
      _log('❌ TEMPERATURE UNEXPECTED ERROR: $e\n$st');
      return ApiResult.failure('Unexpected error: $e');
    }
  }

  // ---------------- Helpers ----------------

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  /// Laravel style: {"errors": {"0.temps": ["message"]}}
  String? _firstValidationError(Map<String, dynamic>? json) {
    final errors = json?['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final entry = errors.entries.first;
      final v = entry.value;
      final msg = v is List && v.isNotEmpty ? v.first.toString() : v.toString();
      return '${entry.key}: $msg';
    }
    return null;
  }

  void _log(String text) {
    const chunk = 800;
    for (final line in text.split('\n')) {
      for (var i = 0; i < max(line.length, 1); i += chunk) {
        // ignore: avoid_print
        print(line.isEmpty ? '' : line.substring(i, min(i + chunk, line.length)));
      }
    }
  }
}