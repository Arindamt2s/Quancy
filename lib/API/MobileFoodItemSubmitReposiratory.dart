// lib/API/MobileFoodInspectionItemRepository.dart
//
// POST /mobile-food/inspection-item  (multipart/form-data, TEXT FIELDS ONLY)
// Call it AFTER /mobile-food/inspection succeeded – it needs that inspectionID.
//
// Each item is sent as:
//   inspection_id, item_id,
//   out / in / no / na / cos / r  → "OUT" / "IN" / "NO" / "NA" / "COS" / "R"
//                                    when selected, "" otherwise
//   comment,
//   image, image1, image2, image3 → compressed base64 strings
//
// Photos are compressed + base64 encoded in the screen
// (FoodMobileDetailsScreen._itemPhotosBase64) before they reach this class.
// The local database keeps the original file paths.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:quincy/API/MobileFoodInspectionSubmitRepository.dart'
    show ApiResult;
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/MobileFood/Submit/Model/MobileFoodInspectionItemsModel.dart';

class MobileFoodInspectionItemRepository {
  final http.Client _client;

  MobileFoodInspectionItemRepository({http.Client? client})
      : _client = client ?? http.Client();

  /// How the array is named in the form fields:
  ///   ''      → 0[item_id], 0[image], 1[item_id] …   (top-level array)
  ///   'items' → items[0][item_id], items[0][image] …
  /// TODO: confirm with the backend which one it reads.
  static const String arrayKey = '';

  /// Send image keys even when the slot is empty ("" value).
  /// TODO: set true if the backend requires every image key.
  static const bool includeEmptyImages = false;

  /// Items per request – keeps each upload small when there are many photos.
  static const int batchSize = 10;

  static const Duration _timeout = Duration(minutes: 3);

  /// Sends the items. Build them with
  /// `MobileFoodInspectionItemRequest.fromAnswer(answer, serverInspectionId,
  ///   imagesBase64: [...])`.
  Future<ApiResult<MobileFoodItemSubmitResponse>> submitItems({
    required List<MobileFoodInspectionItemRequest> items,
    String? token,
  }) async {
    // Only items the inspector actually touched
    final toSend = items.where((i) => i.hasData).toList();

    if (toSend.isEmpty) {
      _log('ℹ️ No checklist items to submit.');
      return ApiResult.success(
          MobileFoodItemSubmitResponse(success: true, message: 'No items'));
    }

    MobileFoodItemSubmitResponse? last;
    for (var start = 0; start < toSend.length; start += batchSize) {
      final end = min(start + batchSize, toSend.length);
      final r = await _sendBatch(
        toSend.sublist(start, end),
        token,
        label: 'items ${start + 1}-$end of ${toSend.length}',
      );
      if (!r.isSuccess) {
        return ApiResult.failure(
            'Items ${start + 1}-$end of ${toSend.length}: ${r.error}');
      }
      last = r.data;
    }
    return ApiResult.success(last!);
  }

  Future<ApiResult<MobileFoodItemSubmitResponse>> _sendBatch(
    List<MobileFoodInspectionItemRequest> batch,
    String? token, {
    required String label,
  }) async {
    final uri = Uri.parse(
        URLConstants.baseUrl + URLConstants.mobileFooditemListSubmit);
    final req = http.MultipartRequest('POST', uri);

    req.headers[HttpHeaders.acceptHeader] = 'application/json';
    if (token != null && token.isNotEmpty) {
      req.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    // Text fields only: inspection_id, item_id, out, in, no, na, cos, r,
    // comment, image, image1, image2, image3 (base64). No files.
    for (var i = 0; i < batch.length; i++) {
      req.fields.addAll(batch[i].toFields(
        i,
        arrayKey: arrayKey,
        includeEmptyImages: includeEmptyImages,
      ));
    }

    // ---------- REQUEST LOG ----------
    final totalBytes =
        req.fields.values.fold<int>(0, (s, v) => s + v.length);
    _log('================ 📤 ITEMS REQUEST ($label) ================');
    _log('POST $uri');
    _log('Fields:\n${const JsonEncoder.withIndent('  ').convert(_logFields(req.fields))}');
    _log('Total upload: ${(totalBytes / 1024).toStringAsFixed(1)} KB');

    try {
      final sw = Stopwatch()..start();
      final streamed = await _client.send(req).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      sw.stop();

      // ---------- RESPONSE LOG ----------
      _log('================ 📥 ITEMS RESPONSE ($label) ================');
      _log('Status: ${response.statusCode} (${sw.elapsedMilliseconds} ms)');
      _log('Body:\n${response.body}');

      final json = _tryDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json == null) {
          return ApiResult.failure('Invalid response from server.');
        }
        final parsed = MobileFoodItemSubmitResponse.fromJson(json);
        if (!parsed.success) {
          return ApiResult.failure(parsed.message ?? 'Item submission failed.');
        }
        return ApiResult.success(parsed);
      }

      if (response.statusCode == 401) {
        return ApiResult.failure('Session expired. Please log in again.');
      }
      if (response.statusCode == 413) {
        return ApiResult.failure('Upload too large (413). Reduce batchSize.');
      }

      final parts = [json?['message']?.toString(), _firstValidationError(json)]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toList();
      return ApiResult.failure('(${response.statusCode}) '
          '${parts.isEmpty ? 'Server error' : parts.join(' – ')}');
    } on TimeoutException {
      _log('❌ ITEMS TIMEOUT after ${_timeout.inSeconds}s');
      return ApiResult.failure('Upload timed out. Please try again.');
    } on SocketException catch (e) {
      _log('❌ ITEMS SOCKET ERROR: $e');
      return ApiResult.failure('No internet connection.');
    } catch (e, st) {
      _log('❌ ITEMS UNEXPECTED ERROR: $e\n$st');
      return ApiResult.failure('Unexpected error: $e');
    }
  }

  // ---------------- Helpers ----------------

  /// Fields for the console: base64 images shown as their size, not the
  /// full string (a single photo would flood the log).
  Map<String, String> _logFields(Map<String, String> fields) {
    final imageKey = RegExp(r'\[image\d?\]$');
    return {
      for (final e in fields.entries)
        e.key: imageKey.hasMatch(e.key) && e.value.isNotEmpty
            ? '<base64 ${(e.value.length / 1024).toStringAsFixed(1)} KB, '
                '${e.value.substring(0, min(20, e.value.length))}…>'
            : e.value,
    };
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  /// Laravel style: {"errors": {"0.item_id": ["message"]}}
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

  /// Prints long text in pieces so the console doesn't cut it.
  void _log(String text) {
    const chunk = 800;
    for (final line in text.split('\n')) {
      if (line.isEmpty) {
        // ignore: avoid_print
        print('');
        continue;
      }
      for (var i = 0; i < line.length; i += chunk) {
        // ignore: avoid_print
        print(line.substring(i, min(i + chunk, line.length)));
      }
    }
  }
}