// lib/API/InspectorRepository.dart
//
// GET /inspector → List<InspectorModel>
// Saving to the database is done by InspectorViewModel via DBManager.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:quincy/API/MobileFoodInspectionSubmitRepository.dart'
    show ApiResult;
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspector/Model/InspectorModel.dart';


class InspectorRepository {
  final http.Client _client;

  InspectorRepository({http.Client? client})
      : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 45);

  /// Calls GET /inspector. [token] is read from auth_session when null.
  Future<ApiResult<List<InspectorModel>>> fetchInspectors({
    String? token,
  }) async {
    token ??= await DBManager.instance.getAccessToken();
    final uri = _uri(URLConstants.inspectorList);

    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      if (token != null && token.isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer $token',
    };

    _log('================ 📤 INSPECTORS REQUEST ================');
    _log('GET $uri');

    try {
      final sw = Stopwatch()..start();
      final response =
          await _client.get(uri, headers: headers).timeout(_timeout);
      sw.stop();

      _log('================ 📥 INSPECTORS RESPONSE ================');
      _log('Status: ${response.statusCode} (${sw.elapsedMilliseconds} ms)');
      _log('Body:\n${response.body}');

      final json = _tryDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json == null) {
          return ApiResult.failure('Invalid response from server.');
        }
        final parsed = InspectorListResponse.fromJson(json);
        if (!parsed.status) {
          return ApiResult.failure(
              parsed.message ?? 'Could not load inspectors.');
        }
        _log('✅ ${parsed.inspectors.length} inspector(s) received');
        return ApiResult.success(parsed.inspectors);
      }

      if (response.statusCode == 401) {
        return ApiResult.failure('Session expired. Please log in again.');
      }
      final msg = json?['message']?.toString();
      return ApiResult.failure('(${response.statusCode}) '
          '${msg == null || msg.isEmpty ? 'Server error' : msg}');
    } on TimeoutException {
      _log('❌ INSPECTORS TIMEOUT after ${_timeout.inSeconds}s');
      return ApiResult.failure('Request timed out. Please try again.');
    } on SocketException catch (e) {
      _log('❌ INSPECTORS SOCKET ERROR: $e');
      return ApiResult.failure('No internet connection.');
    } catch (e, st) {
      _log('❌ INSPECTORS UNEXPECTED ERROR: $e\n$st');
      return ApiResult.failure('Unexpected error: $e');
    }
  }

  // ---------------- Helpers ----------------

  /// Joins base URL and path with exactly one "/"
  /// ("inspector" has no leading slash in URLConstants).
  Uri _uri(String path) {
    final base = URLConstants.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

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