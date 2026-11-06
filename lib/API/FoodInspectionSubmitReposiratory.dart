import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/HTTPS/apiConstants.dart';

import 'package:quincy/Inspections/MobileFood/Submit/Model/mobileFoodInspectionModel.dart';

// =====================================================================
//  POST /food/inspection
//  Body  : MobileFoodInspectionRequest.toJson()  (same as Mobile Food)
//  Reply : { "status": true, "message": "...", "data": { "inspection_id": 123 } }
// =====================================================================

/// `data` object of the response.
class FoodInspectionSubmitData {
  /// Server id of the new inspection – used by
  /// /food/inspection-item and /food/item-temperature.
  final int? inspectionId;

  const FoodInspectionSubmitData({this.inspectionId});

  factory FoodInspectionSubmitData.fromJson(Map<String, dynamic> j) {
    int? asInt(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

    // Key match ignoring case and "_": inspectionID, inspection_id,
    // inspectionId, InspectionID … all work.
    dynamic find(String key) {
      String norm(String k) => k.replaceAll('_', '').toLowerCase();
      final want = norm(key);
      for (final e in j.entries) {
        if (norm(e.key) == want) return e.value;
      }
      return null;
    }

    return FoodInspectionSubmitData(
      // API reply: {"status":true,"data":{"inspectionID":3227,"permit_id":1539}}
      inspectionId: asInt(find('inspection_id') ?? j['id']),
    );
  }
}

/// Whole response body.
/// POST /food/inspection response:
/// {
///   "status": true,
///   "inspectionID": 123,
///   "permit_id": 45
/// }
class FoodInspectionSubmitResponse {
  /// "status"
  final bool status;

  /// "message" (only sent on errors, if at all)
  final String? message;

  /// "inspectionID" – server inspection id, used by
  /// /food/inspection-item and /food/item-temperature.
  final int? inspectionId;

  /// "permit_id"
  final int? permitId;

  const FoodInspectionSubmitResponse({
    required this.status,
    this.message,
    this.inspectionId,
    this.permitId,
  });

  factory FoodInspectionSubmitResponse.fromJson(Map<String, dynamic> j) =>
      FoodInspectionSubmitResponse(
        status: j['status'] == true ||
            j['status'] == 1 ||
            j['status']?.toString().toLowerCase() == 'true' ||
            j['success'] == true,
        message: j['message']?.toString(),
        inspectionId: _toInt(j['inspectionID']),
        permitId: _toInt(j['permit_id']),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'inspectionID': inspectionId,
        'permit_id': permitId,
      };

  /// Accepts 123, "123" or 123.0.
  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// Success → [data], failure → [error] (a message to show the user).
class FoodInspectionSubmitResult {
  final FoodInspectionSubmitResponse? data;
  final String? error;
  final int? statusCode;

  const FoodInspectionSubmitResult._({this.data, this.error, this.statusCode});

  factory FoodInspectionSubmitResult.success(
          FoodInspectionSubmitResponse data,
          {int? statusCode}) =>
      FoodInspectionSubmitResult._(data: data, statusCode: statusCode);

  factory FoodInspectionSubmitResult.failure(String error,
          {int? statusCode}) =>
      FoodInspectionSubmitResult._(error: error, statusCode: statusCode);

  bool get isSuccess => error == null;
}

class FoodInspectionApiRepository {
  FoodInspectionApiRepository({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 60); // body has base64 signatures

  /// Sends the inspection (establishment, final submit, signatures).
  /// Same call as Mobile Food: `submitInspection(request, token: token)`.
  Future<FoodInspectionSubmitResult> submitInspection(
    MobileFoodInspectionRequest request, {
    required String token,
  }) async {
    final url = Uri.parse('${URLConstants.baseUrl}${URLConstants.foodInspection}');

    try {
      final res = await _client
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      debugPrint('🌐 POST $url → ${res.statusCode}');
      if (kDebugMode) debugPrint('↩️ ${_short(res.body)}');

      final body = _decode(res.body);

      if (res.statusCode == 401) {
        return FoodInspectionSubmitResult.failure(
            'Session expired. Please log in again.',
            statusCode: 401);
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return FoodInspectionSubmitResult.failure(
          _errorMessage(body) ?? 'Server error (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }

      if (body == null) {
        return FoodInspectionSubmitResult.failure(
            'Unexpected server response.',
            statusCode: res.statusCode);
      }

      final parsed = FoodInspectionSubmitResponse.fromJson(body);
      if (!parsed.status) {
        return FoodInspectionSubmitResult.failure(
          _errorMessage(body) ?? 'Submission failed.',
          statusCode: res.statusCode,
        );
      }
      return FoodInspectionSubmitResult.success(parsed,
          statusCode: res.statusCode);
    } on SocketException {
      return FoodInspectionSubmitResult.failure(
          'No internet connection. The inspection is saved – try again later.');
    } on TimeoutException {
      return FoodInspectionSubmitResult.failure(
          'The server took too long to respond. Please try again.');
    } on http.ClientException catch (e) {
      return FoodInspectionSubmitResult.failure(e.message);
    } catch (e) {
      debugPrint('❌ Food inspection submit error: $e');
      return FoodInspectionSubmitResult.failure(
          'Could not submit the inspection.');
    }
  }

  // ---------------- Helpers ----------------

  Map<String, dynamic>? _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// "message", or the first Laravel validation error ("errors": {field: [msg]}).
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

  String _short(String s) => s.length > 500 ? '${s.substring(0, 500)}…' : s;
}