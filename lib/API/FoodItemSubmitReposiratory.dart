import 'package:http/http.dart' as http;
import 'package:quincy/API/FoodSubmitHttps.dart';
import 'package:quincy/HTTPS/apiConstants.dart';

import 'package:quincy/Inspections/MobileFood/Submit/Model/MobileFoodInspectionItemsModel.dart';



// =====================================================================
//  POST /food/inspection-item
//  Body : a JSON ARRAY (no wrapper key) – one object per answered item:
//  [
//    {
//      "inspection_id": 3227, "item_id": 1,
//      "out": "OUT", "in": "IN", "no": "NO", "na": "NA",
//      "cos": "COS", "r": "R",
//      "comment": "...",
//      "image": "<base64>", "image1": "<base64>",
//      "image2": "<base64>", "image3": "<base64>"
//    }
//  ]
//  Each object = MobileFoodInspectionItemRequest.toJson() (same as Mobile Food).
// =====================================================================

class FoodInspectionItemRepository {
  FoodInspectionItemRepository({http.Client? client})
      : _http = FoodSubmitHttp(client: client);

  final FoodSubmitHttp _http;

  /// The exact body sent to the server (also used for the payload log).
  static List<Map<String, dynamic>> buildBody(
          List<MobileFoodInspectionItemRequest> items) =>
      items.map((e) => Map<String, dynamic>.from(e.toJson())).toList();

  /// Sends all answered checklist items in one call.
  /// Same call as Mobile Food: `submitItems(items: list, token: token)`.
  Future<FoodSubmitResult> submitItems({
    required List<MobileFoodInspectionItemRequest> items,
    required String token,
  }) async {
    // Nothing answered → nothing to send
    if (items.isEmpty) return FoodSubmitResult.success();

    return _http.postJson(
      URLConstants.foodItemListSubmit,
      buildBody(items), // bare array: [ {...}, {...} ]
      token: token,
      // Photos are base64 → allow more time for big inspections
      timeout: const Duration(seconds: 120),
    );
  }
}