import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/TempFood/Schedule/Model/TempFoodInspectionScheduleModel.dart';

/// GET /api/temp-food/get-inspection-shedules-by-pagination/{last_id?}/{fetched_data_count?}
///
/// First page:  .../0/200
/// Next pages:  .../{highest id of previous page}/200
///
/// Path: lib/API/TempFood/TempFoodInspectionScheduleRepository.dart
class TempFoodInspectionScheduleRepository {
  static const String baseUrl = URLConstants.baseUrl;

  static const int pageSize = 200;
  static const int _maxPages = 500; // safety stop

  /// Fetches ONE page.
  Future<TempFoodInspectionScheduleResponse> getInspectionSchedules({
    required String token,
    int lastId = 0,
    int count = pageSize,
  }) async {
    final url = Uri.parse(
        '$baseUrl${URLConstants.tempFoodInspectionSchedule}/$lastId/$count');

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

      debugPrint('🏕️ Temp Food schedules ${response.statusCode}: $url');

      final json = ApiResponseHandler.handle(response);
      return TempFoodInspectionScheduleResponse.fromJson(json);
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }

  /// Fetches every page and returns all schedules.
  Future<List<TempFoodInspectionScheduleModel>> getAllInspectionSchedules({
    required String token,
    void Function(int fetchedSoFar)? onPage,
  }) async {
    final all = <TempFoodInspectionScheduleModel>[];
    final seenIds = <int>{};
    var lastId = 0;

    for (var page = 0; page < _maxPages; page++) {
      final res = await getInspectionSchedules(token: token, lastId: lastId);
      if (!res.success) throw TempFoodScheduleFetchFailed();

      final batch = res.schedules;
      for (final s in batch) {
        if (seenIds.add(s.id)) all.add(s);
      }
      onPage?.call(all.length);
      debugPrint('🏕️ page ${page + 1}: ${batch.length} rows '
          '(lastId=$lastId, last_schedule_id=${res.lastScheduleId}, '
          'total=${all.length})');

      if (batch.length < pageSize) break; // last page

      final nextId =
          batch.map((s) => s.id).fold<int>(lastId, (a, b) => b > a ? b : a);
      if (nextId <= lastId) break; // cursor didn't advance
      lastId = nextId;
    }

    return all;
  }
}

/// Thrown when the server answers "status": false.
class TempFoodScheduleFetchFailed implements Exception {
  @override
  String toString() => 'The server could not return temporary food schedules.';
}
