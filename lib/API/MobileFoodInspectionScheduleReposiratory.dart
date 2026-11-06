import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/ApiResponseHandler.dart';
import 'package:quincy/API/apiHeader.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/MobileFood/Schedule/Model/MobileFoodInspectionscheduleModel.dart';

/// GET /api/mobile-food/get-inspection-shedules/{last_id?}/{fetched_data_count?}
///
/// First page:  .../0/200
/// Next pages:  .../{last id of previous page}/200
class MobileFoodInspectionScheduleRepository {
  static const String baseUrl = URLConstants.baseUrl;

  /// Records requested per call.
  static const int pageSize = 200;

  /// Safety stop so a backend bug can never loop forever (200 × 500 = 100k).
  static const int _maxPages = 500;

  /// Fetches ONE page.
  /// [lastId] = id of the last schedule already received (0 for the first page).
  Future<MobileFoodInspectionScheduleResponse> getInspectionSchedules({
    required String token,
    int lastId = 0,
    int count = pageSize,
  }) async {
    // URLConstants.mobileFoodInspectionSchedule must be
    // '/api/mobile-food/get-inspection-shedules' (note the API spelling "shedules")
    // with no trailing slash.
    final url = Uri.parse(
        '$baseUrl${URLConstants.mobileFoodInspectionSchedule}/$lastId/$count');

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

      debugPrint('📅 Schedules ${response.statusCode}: $url');

      final json = ApiResponseHandler.handle(response);
      return MobileFoodInspectionScheduleResponse.fromJson(json);
    } on SocketException {
      throw NoInternetException();
    } on TimeoutException {
      throw TimeoutApiException();
    } on FormatException {
      throw InvalidResponseException();
    }
  }

  /// Fetches every page (200 at a time) and returns all schedules.
  ///
  /// Stops when a page comes back with fewer than [pageSize] rows, is empty,
  /// or the cursor does not move forward.
  /// [onPage] reports the running total (useful for a sync progress label).
  Future<List<MobileFoodInspectionScheduleModel>> getAllInspectionSchedules({
    required String token,
    void Function(int fetchedSoFar)? onPage,
  }) async {
    final all = <MobileFoodInspectionScheduleModel>[];
    final seenIds = <int>{};
    var lastId = 0;

    for (var page = 0; page < _maxPages; page++) {
      final res = await getInspectionSchedules(token: token, lastId: lastId);

      if (!res.success) {
        // First page failing = real failure; a later page failing would leave
        // a partial list, so treat it as a failure too.
        throw ScheduleFetchFailed();
      }

      final batch = res.schedules;
      for (final s in batch) {
        if (seenIds.add(s.id)) all.add(s);
      }
      onPage?.call(all.length);
      debugPrint('📅 page ${page + 1}: ${batch.length} rows '
          '(lastId=$lastId, last_schedule_id=${res.lastScheduleId}, '
          'total=${all.length})');

      if (batch.length < pageSize) break; // last page

      // Cursor = highest id in this page (does not rely on the list order).
      final nextId =
          batch.map((s) => s.id).fold<int>(lastId, (a, b) => b > a ? b : a);
      if (nextId <= lastId) break; // cursor didn't advance – avoid a loop
      lastId = nextId;
    }

    return all;
  }
}

/// Thrown when the server answers "status": false.
class ScheduleFetchFailed implements Exception {
  @override
  String toString() => 'The server could not return schedules.';
}