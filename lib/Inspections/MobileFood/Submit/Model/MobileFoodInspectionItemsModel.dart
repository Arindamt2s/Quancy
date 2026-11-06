import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionAnswerModel.dart';

// ---------------------------------------------------------------------------
// Request
// ---------------------------------------------------------------------------

/// One row of POST /mobile-food/inspection-item
///
/// Photos are sent as COMPRESSED BASE64 STRINGS in the text fields
/// image / image1 / image2 / image3 (no file uploads).
/// The local database still keeps the original file paths.
class MobileFoodInspectionItemRequest {
  final int inspectionId;
  final int itemId;

  /// The code when selected ("OUT", "IN", "NO", "NA", "COS", "R"), else ""
  final String out;
  final String inValue; // `in` is a Dart keyword
  final String no;
  final String na;
  final String cos;
  final String r;

  final String comment;

  /// Base64 strings for image, image1, image2, image3 ('' = empty slot)
  final List<String> images;

  static const imageKeys = ['image', 'image1', 'image2', 'image3'];

  const MobileFoodInspectionItemRequest({
    required this.inspectionId,
    required this.itemId,
    required this.out,
    required this.inValue,
    required this.no,
    required this.na,
    required this.cos,
    required this.r,
    required this.comment,
    required this.images,
  });

  /// [imagesBase64] must be in slot order (slot 0 → image, 1 → image1 …).
  /// Use '' for an empty slot.
  factory MobileFoodInspectionItemRequest.fromAnswer(
    MobileFoodInspectionAnswerModel a,
    int serverInspectionId, {
    List<String> imagesBase64 = const [],
  }) {
    String flag(bool on, String code) => on ? code : '';
    final isOut = a.result == 'OUT';

    return MobileFoodInspectionItemRequest(
      inspectionId: serverInspectionId,
      itemId: a.itemId,
      out: flag(isOut, 'OUT'),
      inValue: flag(a.result == 'IN', 'IN'),
      no: flag(a.result == 'NO', 'NO'),
      na: flag(a.result == 'NA', 'NA'),
      cos: flag(isOut && a.cos, 'COS'), // COS / R only with OUT
      r: flag(isOut && a.repeat, 'R'),
      comment: a.comment.trim(),
      images: [
        for (var i = 0; i < imageKeys.length; i++)
          i < imagesBase64.length ? imagesBase64[i] : '',
      ],
    );
  }

  /// True when the inspector selected a result, typed a comment or added a photo.
  bool get hasData =>
      out.isNotEmpty ||
      inValue.isNotEmpty ||
      no.isNotEmpty ||
      na.isNotEmpty ||
      comment.isNotEmpty ||
      images.any((b) => b.isNotEmpty);

  /// All fields for row [index] (text + base64 images):
  ///   arrayKey ''      → 0[out], 0[in], 0[image] …
  ///   arrayKey 'items' → items[0][out], items[0][image] …
  ///
  /// [includeEmptyImages] = false leaves out empty image slots.
  Map<String, String> toFields(
    int index, {
    String arrayKey = '',
    bool includeEmptyImages = false,
  }) {
    String k(String name) =>
        arrayKey.isEmpty ? '$index[$name]' : '$arrayKey[$index][$name]';

    return {
      k('inspection_id'): inspectionId.toString(),
      k('item_id'): itemId.toString(),
      k('out'): out,
      k('in'): inValue,
      k('no'): no,
      k('na'): na,
      k('cos'): cos,
      k('r'): r,
      k('comment'): comment,
      for (var i = 0; i < imageKeys.length; i++)
        if (includeEmptyImages || images[i].isNotEmpty)
          k(imageKeys[i]): images[i],
    };
  }

  /// Same row as JSON (if the API accepts a JSON body instead of form fields).
  Map<String, dynamic> toJson() => {
        'inspection_id': inspectionId,
        'item_id': itemId,
        'out': out,
        'in': inValue,
        'no': no,
        'na': na,
        'cos': cos,
        'r': r,
        'comment': comment,
        for (var i = 0; i < imageKeys.length; i++) imageKeys[i]: images[i],
      };
}

// ---------------------------------------------------------------------------
// Response
// ---------------------------------------------------------------------------

/// {"success": true, "message": "string"}  (also accepts "status": true)
class MobileFoodItemSubmitResponse {
  final bool success;
  final String? message;

  MobileFoodItemSubmitResponse({required this.success, this.message});

  factory MobileFoodItemSubmitResponse.fromJson(Map<String, dynamic> json) {
    bool b(dynamic v) =>
        v == true || v == 1 || v?.toString().toLowerCase() == 'true';
    return MobileFoodItemSubmitResponse(
      success: b(json['success']) || b(json['status']),
      message: json['message']?.toString(),
    );
  }
}