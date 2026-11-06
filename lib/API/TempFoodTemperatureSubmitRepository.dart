import 'package:quincy/API/FoodTemperatureSubmirReposiratory.dart';

import 'package:quincy/API/TempFoodApiClient.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureSubmitModel.dart';

/// POST /api/temp-food/item-temperature (API 3 of 3)
/// Body is built exactly like Food's /food/item-temperature.
///
/// Path: lib/API/TempFood/TempFoodTemperatureSubmitRepository.dart
class TempFoodTemperatureSubmitRepository {
  /// Same JSON body as the Food temperature submit.
  static Object buildBody(List<MobileFoodTemperatureRequest> rows) =>
      FoodTemperatureSubmitRepository.buildBody(rows);

  Future<TempFoodSubmitResult<void>> submitTemperatures({
    required List<MobileFoodTemperatureRequest> temperatures,
    required String token,
  }) async {
    // Nothing entered → nothing to send.
    if (temperatures.isEmpty) return TempFoodSubmitResult.success(null);
    final res = await TempFoodApiClient.post(
      URLConstants.tempFoodTemperatureSubmit,
      token: token,
      body: buildBody(temperatures),
    );
    return res.isSuccess
        ? TempFoodSubmitResult.success(null, statusCode: res.statusCode)
        : TempFoodSubmitResult.failure(res.error!, statusCode: res.statusCode);
  }
}
