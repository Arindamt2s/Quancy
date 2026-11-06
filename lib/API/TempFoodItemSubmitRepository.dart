import 'package:quincy/API/FoodItemSubmitReposiratory.dart';

import 'package:quincy/API/TempFoodApiClient.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/MobileFood/Submit/Model/MobileFoodInspectionItemsModel.dart';

/// POST /api/temp-food/inspection-item (API 2 of 3)
/// Body is built exactly like Food's /food/inspection-item.
///
/// Path: lib/API/TempFood/TempFoodItemSubmitRepository.dart
class TempFoodInspectionItemRepository {
  /// Same JSON body as the Food item submit.
  static Object buildBody(List<MobileFoodInspectionItemRequest> items) =>
      FoodInspectionItemRepository.buildBody(items);

  Future<TempFoodSubmitResult<void>> submitItems({
    required List<MobileFoodInspectionItemRequest> items,
    required String token,
  }) async {
    if (items.isEmpty) return TempFoodSubmitResult.success(null);
    final res = await TempFoodApiClient.post(
      URLConstants.tempFoodListSubmit,
      token: token,
      body: buildBody(items),
    );
    return res.isSuccess
        ? TempFoodSubmitResult.success(null, statusCode: res.statusCode)
        : TempFoodSubmitResult.failure(res.error!, statusCode: res.statusCode);
  }
}
