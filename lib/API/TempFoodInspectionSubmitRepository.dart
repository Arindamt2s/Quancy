import 'package:flutter/foundation.dart';
import 'package:quincy/API/TempFoodApiClient.dart';
import 'package:quincy/HTTPS/apiConstants.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodInspectionRequest.dart';


/// POST /api/temp-food/inspection response:
/// {
///   "status": true,
///   "inspectionID": 123,
///   "permit_id": 45
/// }
class TempFoodInspectionSubmitResponse {
  final bool status;
  final String? message;

  /// "inspectionID" – used by /temp-food/inspection-item and
  /// /temp-food/item-temperature.
  final int? inspectionId;

  /// "permit_id"
  final int? permitId;

  const TempFoodInspectionSubmitResponse({
    required this.status,
    this.message,
    this.inspectionId,
    this.permitId,
  });

  factory TempFoodInspectionSubmitResponse.fromJson(Map<String, dynamic> j) =>
      TempFoodInspectionSubmitResponse(
        status: TempFoodApiClient.isTrue(j['status'] ?? j['success']),
        message: j['message']?.toString(),
        inspectionId: _toInt(j['inspectionID'] ?? j['inspection_id']),
        permitId: _toInt(j['permit_id']),
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'inspectionID': inspectionId,
        'permit_id': permitId,
      };

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// POST /api/temp-food/inspection (API 1 of 3)
///
/// Body: [TempFoodInspectionRequest] (temp_food_permit_id, MM/dd/yyyy dates).
///
/// Path: lib/API/TempFoodInspectionSubmitRepository.dart
class TempFoodInspectionApiRepository {
  Future<TempFoodSubmitResult<TempFoodInspectionSubmitResponse>>
      submitInspection(
    TempFoodInspectionRequest request, {
    required String token,
  }) async {
    final res = await TempFoodApiClient.post(
      URLConstants.tempFoodInspection,
      token: token,
      body: request.toJson(),
    );
    if (!res.isSuccess) {
      return TempFoodSubmitResult.failure(res.error!,
          statusCode: res.statusCode);
    }
    final parsed = TempFoodInspectionSubmitResponse.fromJson(res.json);
    debugPrint('🏕️ temp-food/inspection → inspectionID ${parsed.inspectionId}');
    return TempFoodSubmitResult.success(parsed, statusCode: res.statusCode);
  }
}