import 'package:quincy/Inspections/Tobacco/Model/TobaccoJson.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoPermitModel.dart';

/// Establishment tab of a Tobacco inspection (one row per inspection).
///
/// Path: lib/Inspections/Tobacco/Model/TobaccoInspectionModel.dart
///
/// [scheduleId] is 0 for a normal inspection (started from the permit list)
/// and the schedule's id when started from the schedule list – it is sent
/// as "schedule_id" on submit.
class TobaccoInspectionModel {
  static const String statusIncomplete = 'incomplete';
  static const String statusCompleted = 'completed';

  final String inspectionId;
  final int userId;
  final int? permitId;
  final int scheduleId;

  /// Id from POST /tobacco/inspection (null until the first call succeeds).
  final int? serverInspectionId;
  final String businessName;
  final String? contactName;
  final String? permitNumber;
  final String? address;
  final String? telephone;
  final String? owner;
  final String? personInCharge;

  /// yyyy-MM-dd
  final String inspectionDate;

  /// HH:mm (24h)
  final String? timeIn;
  final String? timeOut;
  final String? inspector;
  final int? inspectorId;
  final String status;
  final int currentStep;
  final String? createdAt;
  final String? updatedAt;

  const TobaccoInspectionModel({
    required this.inspectionId,
    required this.userId,
    this.permitId,
    this.scheduleId = 0,
    this.serverInspectionId,
    required this.businessName,
    this.contactName,
    this.permitNumber,
    this.address,
    this.telephone,
    this.owner,
    this.personInCharge,
    required this.inspectionDate,
    this.timeIn,
    this.timeOut,
    this.inspector,
    this.inspectorId,
    this.status = statusIncomplete,
    this.currentStep = 0,
    this.createdAt,
    this.updatedAt,
  });

  static String newId() => 'TB_${DateTime.now().millisecondsSinceEpoch}';

  /// New inspection pre-filled from a permit.
  factory TobaccoInspectionModel.fromPermit({
    required int userId,
    TobaccoPermitModel? permit,
    int? permitId,
    int scheduleId = 0,
    int? inspectorId,
    String? inspectorName,
  }) {
    return TobaccoInspectionModel(
      inspectionId: newId(),
      userId: userId,
      permitId: permit?.id ?? permitId,
      scheduleId: scheduleId,
      businessName: permit?.establishmentName ?? '',
      contactName: permit?.applicantName,
      permitNumber: permit?.permitNumber,
      address: permit?.businessAddress,
      telephone: permit?.phone,
      owner: permit?.ownerName,
      // Blank on purpose: the inspector must pick date and inspector.
      inspectionDate: '',
      inspectorId: inspectorId,
      inspector: inspectorName,
    );
  }

  bool get isCompleted => status == statusCompleted;

  TobaccoInspectionModel copyWith({
    String? businessName,
    String? contactName,
    String? permitNumber,
    String? address,
    String? telephone,
    String? owner,
    String? personInCharge,
    String? inspectionDate,
    String? timeIn,
    String? timeOut,
    String? inspector,
    int? inspectorId,
    String? status,
    int? currentStep,
    String? createdAt,
    String? updatedAt,
    int? serverInspectionId,
  }) {
    return TobaccoInspectionModel(
      inspectionId: inspectionId,
      userId: userId,
      permitId: permitId,
      scheduleId: scheduleId,
      serverInspectionId: serverInspectionId ?? this.serverInspectionId,
      businessName: businessName ?? this.businessName,
      contactName: contactName ?? this.contactName,
      permitNumber: permitNumber ?? this.permitNumber,
      address: address ?? this.address,
      telephone: telephone ?? this.telephone,
      owner: owner ?? this.owner,
      personInCharge: personInCharge ?? this.personInCharge,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      timeIn: timeIn ?? this.timeIn,
      timeOut: timeOut ?? this.timeOut,
      inspector: inspector ?? this.inspector,
      inspectorId: inspectorId ?? this.inspectorId,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'inspection_id': inspectionId,
        'user_id': userId,
        'permit_id': permitId,
        'schedule_id': scheduleId,
        'server_inspection_id': serverInspectionId,
        'business_name': businessName,
        'contact_name': contactName,
        'permit_number': permitNumber,
        'address': address,
        'telephone': telephone,
        'owner': owner,
        'person_in_charge': personInCharge,
        'inspection_date': inspectionDate,
        'time_in': timeIn,
        'time_out': timeOut,
        'inspector': inspector,
        'inspector_id': inspectorId,
        'status': status,
        'current_step': currentStep,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory TobaccoInspectionModel.fromMap(Map<String, Object?> m) =>
      TobaccoInspectionModel(
        inspectionId: m['inspection_id'].toString(),
        userId: tbInt(m['user_id']) ?? 0,
        permitId: tbInt(m['permit_id']),
        scheduleId: tbInt(m['schedule_id']) ?? 0,
        serverInspectionId: tbInt(m['server_inspection_id']),
        businessName: tbStr(m['business_name']) ?? '',
        contactName: tbStr(m['contact_name']),
        permitNumber: tbStr(m['permit_number']),
        address: tbStr(m['address']),
        telephone: tbStr(m['telephone']),
        owner: tbStr(m['owner']),
        personInCharge: tbStr(m['person_in_charge']),
        inspectionDate: tbStr(m['inspection_date']) ?? '',
        timeIn: tbStr(m['time_in']),
        timeOut: tbStr(m['time_out']),
        inspector: tbStr(m['inspector']),
        inspectorId: tbInt(m['inspector_id']),
        status: tbStr(m['status']) ?? statusIncomplete,
        currentStep: tbInt(m['current_step']) ?? 0,
        createdAt: tbStr(m['created_at']),
        updatedAt: tbStr(m['updated_at']),
      );

  /// "establishment" part of the submit body.
  Map<String, dynamic> toApi() => {
        'business_name': businessName,
        'contact_name': contactName ?? '',
        'permit_number': permitNumber ?? '',
        'address': address ?? '',
        'telephone': telephone ?? '',
        'owner': owner ?? '',
        'person_in_charge': personInCharge ?? '',
        'inspection_date': inspectionDate,
        'time_in': timeIn ?? '',
        'time_out': timeOut ?? '',
        'inspector_id': inspectorId ?? 0,
      };
}

/// One answer row. Product sub-questions (A, B, …) get their own row.
///
/// * [answer]       "yes" / "no" / "na" for button questions.
/// * [selectedIds]  checked child option ids (checkbox questions, or the
///                  reasons under a "NO" answer).
/// * [textValue]    text questions, or the "Other:" text.
class TobaccoInspectionAnswerModel {
  static const yes = 'yes';
  static const no = 'no';
  static const na = 'na';

  final String inspectionId;
  final int itemId;
  final String? answer;
  final List<int> selectedIds;
  final String? textValue;

  const TobaccoInspectionAnswerModel({
    required this.inspectionId,
    required this.itemId,
    this.answer,
    this.selectedIds = const [],
    this.textValue,
  });

  bool get isEmpty =>
      (answer ?? '').isEmpty &&
      selectedIds.isEmpty &&
      (textValue ?? '').trim().isEmpty;

  TobaccoInspectionAnswerModel copyWith({
    String? answer,
    bool clearAnswer = false,
    List<int>? selectedIds,
    String? textValue,
    bool clearText = false,
  }) {
    return TobaccoInspectionAnswerModel(
      inspectionId: inspectionId,
      itemId: itemId,
      answer: clearAnswer ? null : (answer ?? this.answer),
      selectedIds: selectedIds ?? this.selectedIds,
      textValue: clearText ? null : (textValue ?? this.textValue),
    );
  }

  Map<String, Object?> toMap() => {
        'inspection_id': inspectionId,
        'item_id': itemId,
        'answer': answer,
        'selected_ids': selectedIds.join(','),
        'text_value': textValue,
      };

  factory TobaccoInspectionAnswerModel.fromMap(Map<String, Object?> m) {
    final ids = (m['selected_ids']?.toString() ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
    return TobaccoInspectionAnswerModel(
      inspectionId: m['inspection_id'].toString(),
      itemId: tbInt(m['item_id']) ?? 0,
      answer: tbStr(m['answer']),
      selectedIds: ids,
      textValue: m['text_value']?.toString(),
    );
  }
}

/// Final Submit tab – same columns as the other modules' *Final tables.
/// Signature columns hold paths relative to
/// DBManager.tobaccoInspectionFileBaseDir().
class TobaccoFinalSubmitModel {
  final String inspectionId;
  final String? reinspectionDate;
  final String? purpose;
  final int? operationTypeId;
  final String? operationTypeName;
  final String? discussion;
  final String? otherInformation;
  final String? picSignature;
  final String? picSignDate;
  final String? picName;
  final String? inspectorSignature;
  final String? inspectorSignDate;
  final String? inspectorName;

  const TobaccoFinalSubmitModel({
    required this.inspectionId,
    this.reinspectionDate,
    this.purpose,
    this.operationTypeId,
    this.operationTypeName,
    this.discussion,
    this.otherInformation,
    this.picSignature,
    this.picSignDate,
    this.picName,
    this.inspectorSignature,
    this.inspectorSignDate,
    this.inspectorName,
  });

  TobaccoFinalSubmitModel copyWith({
    String? reinspectionDate,
    bool clearReinspectionDate = false,
    String? purpose,
    int? operationTypeId,
    String? operationTypeName,
    String? discussion,
    String? otherInformation,
    String? picSignature,
    bool clearPicSignature = false,
    String? picSignDate,
    String? picName,
    String? inspectorSignature,
    bool clearInspectorSignature = false,
    String? inspectorSignDate,
    String? inspectorName,
  }) {
    return TobaccoFinalSubmitModel(
      inspectionId: inspectionId,
      reinspectionDate: clearReinspectionDate
          ? null
          : (reinspectionDate ?? this.reinspectionDate),
      purpose: purpose ?? this.purpose,
      operationTypeId: operationTypeId ?? this.operationTypeId,
      operationTypeName: operationTypeName ?? this.operationTypeName,
      discussion: discussion ?? this.discussion,
      otherInformation: otherInformation ?? this.otherInformation,
      picSignature:
          clearPicSignature ? null : (picSignature ?? this.picSignature),
      picSignDate: picSignDate ?? this.picSignDate,
      picName: picName ?? this.picName,
      inspectorSignature: clearInspectorSignature
          ? null
          : (inspectorSignature ?? this.inspectorSignature),
      inspectorSignDate: inspectorSignDate ?? this.inspectorSignDate,
      inspectorName: inspectorName ?? this.inspectorName,
    );
  }

  Map<String, Object?> toMap() => {
        'inspection_id': inspectionId,
        'reinspection_date': reinspectionDate,
        'purpose': purpose,
        'operation_type_id': operationTypeId,
        'operation_type_name': operationTypeName,
        'discussion': discussion,
        'other_information': otherInformation,
        'pic_signature': picSignature,
        'pic_sign_date': picSignDate,
        'pic_name': picName,
        'inspector_signature': inspectorSignature,
        'inspector_sign_date': inspectorSignDate,
        'inspector_name': inspectorName,
      };

  factory TobaccoFinalSubmitModel.fromMap(Map<String, Object?> m) =>
      TobaccoFinalSubmitModel(
        inspectionId: m['inspection_id'].toString(),
        reinspectionDate: tbStr(m['reinspection_date']),
        purpose: tbStr(m['purpose']),
        operationTypeId: tbInt(m['operation_type_id']),
        operationTypeName: tbStr(m['operation_type_name']),
        discussion: m['discussion']?.toString(),
        otherInformation: m['other_information']?.toString(),
        picSignature: tbStr(m['pic_signature']),
        picSignDate: tbStr(m['pic_sign_date']),
        picName: tbStr(m['pic_name']),
        inspectorSignature: tbStr(m['inspector_signature']),
        inspectorSignDate: tbStr(m['inspector_sign_date']),
        inspectorName: tbStr(m['inspector_name']),
      );
}

/// Purpose of Inspection choices on Final Submit → "purpose_id".
/// ⚠️ Ids must match the backend's purpose ids – edit here if they differ.
const Map<int, String> kTobaccoPurposes = {
  1: 'Routine',
  2: 'Re-inspection',
  3: 'Complaint',
  4: 'Follow-up',
  5: 'Suspension of permit',
  6: 'Retailer requested',
  7: 'Other',
};

/// Names for the dropdown (same order as the ids).
final List<String> kTobaccoPurposeOptions = kTobaccoPurposes.values.toList();

/// "Routine" → 1 (0 when unknown).
int tobaccoPurposeId(String? name) {
  if (name == null) return 0;
  for (final e in kTobaccoPurposes.entries) {
    if (e.value.toLowerCase() == name.trim().toLowerCase()) return e.key;
  }
  return 0;
}

/// Operation type for the dropdown (mobile_food_operation_types table,
/// synced by the Dashboard from /mobile-food/operation-types).
class TobaccoOperationTypeOption {
  final int id;
  final String name;
  const TobaccoOperationTypeOption(this.id, this.name);

  factory TobaccoOperationTypeOption.fromDb(Map<String, Object?> r) =>
      TobaccoOperationTypeOption(
          tbInt(r['id']) ?? 0, tbStr(r['name']) ?? 'Type #${r['id']}');
}

/// Inspector for the dropdown (read straight from the inspectors table).
class TobaccoInspectorOption {
  final int id;
  final String name;
  const TobaccoInspectorOption(this.id, this.name);

  factory TobaccoInspectorOption.fromDb(Map<String, Object?> r) {
    final name = [tbStr(r['first_name']), tbStr(r['last_name'])]
        .whereType<String>()
        .join(' ');
    return TobaccoInspectorOption(
      tbInt(r['id']) ?? 0,
      name.isEmpty ? (tbStr(r['email']) ?? 'Inspector #${r['id']}') : name,
    );
  }
}
