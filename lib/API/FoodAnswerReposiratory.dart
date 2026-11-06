import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodFinalSubmitModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionAnswerModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureModel.dart';

/// Local storage for a Food inspection: answers, temperatures,
/// Final Submit and the photo / signature files.
///
/// The row shapes are identical to Mobile Food, so the same models are
/// used – only the tables (Food*) and the photo folder differ.
class FoodAnswerRepository {
  final DBManager _db = DBManager.instance;

  // ---------------- Answers ----------------

  Future<Map<int, MobileFoodInspectionAnswerModel>> loadAnswers(
      String inspectionId) async {
    final rows = await _db.getFoodAnswers(inspectionId);
    return {for (final a in rows) a.itemId: a};
  }

  Future<void> saveAnswer(MobileFoodInspectionAnswerModel a) =>
      _db.saveFoodAnswers([a]);

  Future<void> saveAnswers(List<MobileFoodInspectionAnswerModel> list) =>
      _db.saveFoodAnswers(list);

  // ---------------- Temperatures ----------------

  Future<List<MobileFoodTemperatureModel>> loadTemperatures(
          String inspectionId) =>
      _db.getFoodTemperatures(inspectionId);

  Future<void> saveTemperatures(
          String inspectionId, List<MobileFoodTemperatureModel> rows) =>
      _db.saveFoodTemperatures(inspectionId, rows);

  // ---------------- Final Submit ----------------

  Future<MobileFoodFinalSubmitModel?> loadFinalSubmit(String inspectionId) =>
      _db.getFoodFinalSubmit(inspectionId);

  Future<void> saveFinalSubmit(MobileFoodFinalSubmitModel data) =>
      _db.saveFoodFinalSubmit(data);

  /// Operation types are shared with Mobile Food (synced on the Dashboard).
  Future<List<MobileFoodOperationTypeModel>> loadOperationTypes() =>
      _db.getMobileFoodOperationTypes();

  // ---------------- Files ----------------

  Future<Directory> _dirFor(String inspectionId) async {
    final dir = Directory(
        p.join(await _db.foodInspectionPhotoBaseDir(), inspectionId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies a picked photo into the inspection folder.
  /// Returns the ABSOLUTE path that is saved in the database.
  Future<String> storePhoto({
    required String inspectionId,
    required int itemId,
    required int slot,
    required String sourcePath,
  }) async {
    final dir = await _dirFor(inspectionId);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final name =
        'item_${itemId}_slot${slot}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = p.join(dir.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Saves signature PNG bytes. Returns the absolute file path.
  Future<String> storeSignature({
    required String inspectionId,
    required String who, // 'pic' | 'inspector'
    required Uint8List bytes,
  }) async {
    final dir = await _dirFor(inspectionId);
    final dest = p.join(
        dir.path, 'sign_${who}_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  /// Deletes a photo / signature file (ignored if null or missing).
  Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('⚠️ Delete file error: $e');
    }
  }
}