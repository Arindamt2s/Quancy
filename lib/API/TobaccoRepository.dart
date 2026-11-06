import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/Inspections/Tobacco/Model/TobaccoJson.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoPermitModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoSectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Schedule/Model/TobaccoInspectionScheduleModel.dart';
import 'package:quincy/Inspections/Tobacco/TobaccoDeps.dart';

/// API + local DB for the Tobacco module.
///
/// Path: lib/API/TobaccoRepository.dart
///
///   GET /tobacco/get-permit-list-by-pagination         → tobacco_permits
///   GET /tobacco/get-section-details                   → tobacco_sections / _sub_sections / _items
///   GET /tobacco/get-inspection-schedules-by-pagination → tobacco_inspection_schedules
///
/// The paged endpoints are read until a page brings nothing new, then the
/// local table is replaced in one go (so rows removed on the server also
/// disappear locally). If anything fails, the saved data stays untouched.
class TobaccoRepository {
  TobaccoRepository({http.Client? client, DBManager? db})
      : _client = client ?? http.Client(),
        _db = db ?? DBManager.instance;

  final http.Client _client;
  final DBManager _db;

  static const Duration _timeout = Duration(seconds: 60);

  /// Submit carries two signature images → a bit longer.
  static const Duration _submitTimeout = Duration(seconds: 90);

  /// Safety stop for the paging loops.
  static const int _maxPages = 500;

  // ⚠️ Paging query parameters. The schedule response returns
  // "last_schedule_id", so the next page is requested with the same key.
  // Change these names if the backend expects something else.
  static const String permitCursorParam = 'last_permit_id';
  static const String scheduleCursorParam = 'last_schedule_id';

  // ------------------------------------------------------------- Permits

  /// Downloads every permit and replaces the local table.
  Future<List<TobaccoPermitModel>> syncPermits(
      {void Function(int fetched)? onProgress}) async {
    final rows = await _fetchAllPages(
      path: URLConstants.tobaccoPermitList,
      listKeys: const ['permits', 'permit', 'data'],
      cursorParam: permitCursorParam,
      cursorKeys: const ['last_permit_id', 'last_id'],
      onProgress: onProgress,
    );
    final list = rows.map(TobaccoPermitModel.fromJson).toList();
    await _db.saveTobaccoPermits(list);
    return list;
  }

  Future<List<TobaccoPermitModel>> getSavedPermits() => _db.getTobaccoPermits();

  // ----------------------------------------------------------- Checklist

  /// Downloads the section details (sections → items → children) and
  /// replaces the local checklist tables.
  Future<TobaccoChecklistData> syncChecklist() async {
    final json = await _getJson(URLConstants.tobaccoSectionList);
    final data = TobaccoChecklistData.fromResponse(json);
    if (data.isEmpty) {
      throw const TobaccoApiException('No sections received from the server.');
    }
    await _db.saveTobaccoChecklist(data);
    return data;
  }

  Future<List<TobaccoSectionModel>> getSavedChecklist() =>
      _db.getTobaccoChecklist();

  // ----------------------------------------------------------- Schedules

  /// Downloads every schedule and replaces the local table.
  Future<List<TobaccoInspectionScheduleModel>> syncSchedules(
      {void Function(int fetched)? onProgress}) async {
    final rows = await _fetchAllPages(
      path: URLConstants.tobaccoInspectionScheduleList,
      listKeys: const ['schedules', 'schedule', 'data'],
      cursorParam: scheduleCursorParam,
      cursorKeys: const ['last_schedule_id', 'last_id'],
      onProgress: onProgress,
    );
    final list = rows.map(TobaccoInspectionScheduleModel.fromJson).toList();
    await _db.saveTobaccoInspectionSchedules(list);
    return list;
  }

  Future<List<TobaccoInspectionScheduleModel>> getSavedSchedules(
          {int? inspectorId}) =>
      _db.getTobaccoInspectionSchedules(inspectorId: inspectorId);

  // -------------------------------------------------------------- Submit

  /// POST /tobacco/inspection (Final Submit).
  /// [body] comes from TobaccoInspectionViewModel.buildSubmitBody():
  /// dates mm-dd-yyyy, times HH:mm:ss, signatures base64 PNG,
  /// "schedule_id" 0 for a normal inspection.
  /// Response: { "status": true, "inspectionID": 12, "permit_id": 81 }
  Future<TobaccoSubmitResult> submitInspection(
      Map<String, dynamic> body) async {
    final json = await _postJson(URLConstants.tobaccoInspectionSubmit, body);
    return TobaccoSubmitResult(
      inspectionId: tbInt(json['inspectionID'] ?? json['inspection_id']),
      permitId: tbInt(json['permit_id']),
      raw: json,
    );
  }

  /// POST /tobacco/inspection-details – all answers of one inspection
  /// (JSON array, built by TobaccoInspectionViewModel.buildItemsBody()).
  Future<Map<String, dynamic>> submitInspectionItems(
      List<Map<String, dynamic>> items) =>
      _postJson(URLConstants.tobaccoInspectionItemSubmit, items);

  // ------------------------------------------------------------- Helpers

  /// Reads pages until one is empty or brings no new ids.
  /// Rows are de-duplicated by "id" (last copy wins).
  Future<List<Map<String, dynamic>>> _fetchAllPages({
    required String path,
    required List<String> listKeys,
    required String cursorParam,
    required List<String> cursorKeys,
    void Function(int fetched)? onProgress,
  }) async {
    final byId = <int, Map<String, dynamic>>{};
    var cursor = 0;

    for (var page = 0; page < _maxPages; page++) {
      final json = await _getJson(
        path,
        query: cursor > 0 ? {cursorParam: '$cursor'} : null,
      );

      final list = _firstList(json, listKeys);
      if (list.isEmpty) break;

      var added = 0;
      var maxId = cursor;
      for (final e in list) {
        final id = tbInt(e['id']);
        if (id == null) continue;
        if (!byId.containsKey(id)) added++;
        byId[id] = e;
        if (id > maxId) maxId = id;
      }
      onProgress?.call(byId.length);

      // Cursor from the response, else the biggest id we got.
      int? next;
      for (final k in cursorKeys) {
        next = tbInt(json[k]);
        if (next != null) break;
      }
      next ??= maxId;

      // Server ignored the cursor (returned everything) or nothing new.
      if (added == 0 || next <= cursor) break;
      cursor = next;
    }
    return byId.values.toList();
  }

  List<Map<String, dynamic>> _firstList(
      Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      // {"data": {"data": [...]}} (Laravel paginator)
      if (v is Map && v['data'] is List) {
        return (v['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>> _getJson(String path,
      {Map<String, String>? query}) async {
    final token = await _db.getAccessToken();
    final base = Uri.parse('${URLConstants.baseUrl}$path');
    final uri = (query == null || query.isEmpty)
        ? base
        : base.replace(queryParameters: {...base.queryParameters, ...query});

    debugPrint('🌐 GET $uri');
    http.Response res;
    try {
      res = await _client.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      }).timeout(_timeout);
    } on SocketException {
      throw const TobaccoApiException('No internet connection.');
    } on TimeoutException {
      throw const TobaccoApiException('The server took too long to respond.');
    } on http.ClientException catch (e) {
      throw TobaccoApiException('Network error: ${e.message}');
    }

    return _handle(res);
  }

  /// [body] is a JSON object (Map) or array (List).
  Future<Map<String, dynamic>> _postJson(String path, Object body) async {
    final token = await _db.getAccessToken();
    final uri = Uri.parse('${URLConstants.baseUrl}$path');
    final encoded = jsonEncode(body);
    // Log without the (long) base64 signatures.
    final logged = body is Map<String, dynamic>
        ? {
            for (final e in body.entries)
              e.key: e.key.endsWith('_sign') && '${e.value}'.length > 40
                  ? '<base64 ${'${e.value}'.length} chars>'
                  : e.value,
          }
        : body;
    debugPrint('🌐 POST $uri ${jsonEncode(logged)}');

    http.Response res;
    try {
      res = await _client
          .post(uri,
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                if (token != null && token.isNotEmpty)
                  'Authorization': 'Bearer $token',
              },
              body: encoded)
          .timeout(_submitTimeout);
    } on SocketException {
      throw const TobaccoApiException(
          'No internet connection. The inspection is saved on this device – '
          'submit again when you are online.');
    } on TimeoutException {
      throw const TobaccoApiException(
          'The server took too long to respond. Please try again.');
    } on http.ClientException catch (e) {
      throw TobaccoApiException('Network error: ${e.message}');
    }
    debugPrint('📥 ${res.statusCode} ${res.body.length > 500 ? res.body.substring(0, 500) : res.body}');
    return _handle(res);
  }

  /// Status codes, JSON parsing, "status": false and Laravel 422 errors.
  Map<String, dynamic> _handle(http.Response res) {
    Map<String, dynamic>? json;
    try {
      final d = jsonDecode(res.body);
      if (d is Map) json = Map<String, dynamic>.from(d);
    } catch (_) {}

    if (res.statusCode == 401) {
      throw const TobaccoApiException('Session expired. Please log in again.',
          statusCode: 401);
    }
    if (res.statusCode == 422 && json != null) {
      // {"message": "...", "errors": {"field": ["msg"]}}
      final errors = json['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        final msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
        throw TobaccoApiException(msg, statusCode: 422);
      }
      throw TobaccoApiException(
          tbStr(json['message']) ?? 'Some fields are not valid.',
          statusCode: 422);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TobaccoApiException(
          tbStr(json?['message']) ?? 'Server error (${res.statusCode}).',
          statusCode: res.statusCode);
    }
    if (json == null) {
      throw const TobaccoApiException('Unexpected response from the server.');
    }
    if (json['status'] == false) {
      throw TobaccoApiException(
          tbStr(json['message']) ?? 'Request failed on the server.');
    }
    return json;
  }

}

/// Answer of POST /tobacco/inspection.
class TobaccoSubmitResult {
  final int? inspectionId;
  final int? permitId;
  final Map<String, dynamic> raw;
  const TobaccoSubmitResult(
      {this.inspectionId, this.permitId, this.raw = const {}});
}

class TobaccoApiException implements Exception {
  final String message;
  final int? statusCode;
  const TobaccoApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
