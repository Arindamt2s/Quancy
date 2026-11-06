// lib/Inspections/MobileFood/Submit/Model/MobileFoodTemperatureSubmitModel.dart
//
// POST /mobile-food/item-temperature
//
// Request body (JSON array):
// [
//   { "inspection_id": 66, "locations": "Walk-in cooler", "temps": "38" }
// ]
//
// Response:
// { "status": true, "message": "Location Temperature Submitted successfully!" }

import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureModel.dart';

// ---------------------------------------------------------------------------
// Request
// ---------------------------------------------------------------------------

/// One row of the Temperature Observations tab.
class MobileFoodTemperatureRequest {
  /// Server inspection id (from /mobile-food/inspection), not the local MFI-… id
  final int inspectionId;
  final String locations;
  final String temps;

  const MobileFoodTemperatureRequest({
    required this.inspectionId,
    required this.locations,
    required this.temps,
  });

  /// From a saved DB row (MobileFoodTemperatureModel).
  factory MobileFoodTemperatureRequest.fromModel(
    MobileFoodTemperatureModel m,
    int serverInspectionId,
  ) =>
      MobileFoodTemperatureRequest(
        inspectionId: serverInspectionId,
        locations: m.itemLocation.trim(),
        temps: m.temperature?.toString() ?? '',
      );

  /// True when the inspector typed a location or a temperature.
  bool get hasData => locations.isNotEmpty || temps.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'inspection_id': inspectionId,
        'locations': locations,
        'temps': temps,
      };
}

// ---------------------------------------------------------------------------
// Response
// ---------------------------------------------------------------------------

/// {"status": true, "message": "..."}  (also accepts "success": true)
class MobileFoodTemperatureSubmitResponse {
  final bool status;
  final String? message;

  MobileFoodTemperatureSubmitResponse({required this.status, this.message});

  factory MobileFoodTemperatureSubmitResponse.fromJson(
      Map<String, dynamic> json) {
    bool b(dynamic v) =>
        v == true || v == 1 || v?.toString().toLowerCase() == 'true';
    return MobileFoodTemperatureSubmitResponse(
      status: b(json['status']) || b(json['success']),
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {'status': status, 'message': message};
}