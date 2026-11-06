import 'package:http/http.dart' as http;

import 'package:quincy/API/FoodSubmitHttps.dart';
// ← adjust if your file lives elsewhere
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureSubmitModel.dart';

// =====================================================================
//  POST /food/item-temperature
//  Body : a JSON ARRAY (no wrapper key) – one object per row:
//  [
//    { "inspection_id": 66, "locations": "item", "temps": 89 }
//  ]
// =====================================================================

class FoodTemperatureSubmitRepository {
  FoodTemperatureSubmitRepository({http.Client? client})
      : _http = FoodSubmitHttp(client: client);

  final FoodSubmitHttp _http;

  /// The exact body sent to the server (also used for the payload log).
  ///
  /// Built from MobileFoodTemperatureRequest.toJson(), with the keys
  /// renamed to what the Food API expects:
  ///   inspection_id → inspection_id
  ///   item_location → locations
  ///   temperature   → temps
  static List<Map<String, dynamic>> buildBody(
      List<MobileFoodTemperatureRequest> rows) {
    dynamic pick(Map j, List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && '$v'.trim().isNotEmpty) return v;
      }
      return null;
    }

    int? asInt(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'.trim()));

    return rows.map((e) {
      final j = e.toJson();
      return <String, dynamic>{
        'inspection_id': asInt(pick(j, ['inspection_id', 'inspectionId'])),
        'locations':
            '${pick(j, ['locations', 'item_location', 'itemLocation', 'location']) ?? ''}',
        'temps': asInt(pick(j, ['temps', 'temperature', 'temp'])),
      };
    }).toList();
  }

  /// Sends all Temperature Observation rows in one call.
  /// Same call as Mobile Food:
  /// `submitTemperatures(temperatures: list, token: token)`.
  Future<FoodSubmitResult> submitTemperatures({
    required List<MobileFoodTemperatureRequest> temperatures,
    required String token,
  }) async {
    // No rows filled → nothing to send (submit still succeeds)
    if (temperatures.isEmpty) return FoodSubmitResult.success();

    return _http.postJson(
      URLConstants.foodTemperatureSubmit,
      buildBody(temperatures), // bare array: [ {...}, {...} ]
      token: token,
      timeout: const Duration(seconds: 30),
    );
  }
}