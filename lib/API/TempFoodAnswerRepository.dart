import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodFinalSubmitModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionAnswerModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureModel.dart';

/// Local (SQLite + files) storage for one Temporary Food inspection:
/// checklist answers, photos, temperatures, Final Submit and signatures.
/// Same row models as Mobile Food / Food (same table shape).
///
/// Path: lib/API/TempFood/TempFoodAnswerRepository.dart
class TempFoodAnswerRepository {
  TempFoodAnswerRepository({DBManager? db}) : _db = db ?? DBManager.instance;

  final DBManager _db;

  // ---------- Answers ----------

  /// itemId → saved answer
  Future<Map<int, MobileFoodInspectionAnswerModel>> loadAnswers(
      String inspectionId) async {
    final list = await _db.getTempFoodAnswers(inspectionId);
    return {for (final a in list) a.itemId: a};
  }

  Future<void> saveAnswer(MobileFoodInspectionAnswerModel answer) =>
      _db.saveTempFoodAnswers([answer]);

  Future<void> saveAnswers(List<MobileFoodInspectionAnswerModel> answers) =>
      _db.saveTempFoodAnswers(answers);

  // ---------- Temperatures ----------

  Future<List<MobileFoodTemperatureModel>> loadTemperatures(
          String inspectionId) =>
      _db.getTempFoodTemperatures(inspectionId);

  Future<void> saveTemperatures(
          String inspectionId, List<MobileFoodTemperatureModel> rows) =>
      _db.saveTempFoodTemperatures(inspectionId, rows);

  // ---------- Final Submit ----------

  /// Operation types are shared (synced on the Dashboard).
  Future<List<MobileFoodOperationTypeModel>> loadOperationTypes() =>
      _db.getMobileFoodOperationTypes();

  Future<MobileFoodFinalSubmitModel?> loadFinalSubmit(String inspectionId) =>
      _db.getTempFoodFinalSubmit(inspectionId);

  Future<void> saveFinalSubmit(MobileFoodFinalSubmitModel data) =>
      _db.saveTempFoodFinalSubmit(data);

  // ---------- Files (DB stores the absolute paths) ----------

  Future<Directory> _dirFor(String inspectionId) async {
    final dir = Directory(
        p.join(await _db.tempFoodInspectionPhotoBaseDir(), inspectionId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies a picked photo into the inspection folder, returns its path.
  Future<String> storePhoto({
    required String inspectionId,
    required int itemId,
    required int slot,
    required String sourcePath,
  }) async {
    final dir = await _dirFor(inspectionId);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(dir.path,
        'item_${itemId}_${slot}_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(sourcePath).copy(target);
    return target;
  }

  /// Writes a signature PNG, returns its path. [who] = 'pic' / 'inspector'.
  Future<String> storeSignature({
    required String inspectionId,
    required String who,
    required Uint8List bytes,
  }) async {
    final dir = await _dirFor(inspectionId);
    final target = p.join(
        dir.path, 'sign_${who}_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }

  /// Deletes a photo / signature file (ignores null / missing).
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
