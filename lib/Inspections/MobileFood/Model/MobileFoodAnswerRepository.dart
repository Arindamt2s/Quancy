import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

// TODO: fix this import if DBManager lives somewhere else in your project.
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionAnswerModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodFinalSubmitModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeModel.dart';

/// Saves / loads checklist answers and keeps item photos as files
/// on the device. The DB only stores each photo's file path
/// (relative to the photo folder, so paths survive iOS app updates
/// where the app container path changes).
class MobileFoodAnswerRepository {
  final DBManager _db;

  MobileFoodAnswerRepository([DBManager? db]) : _db = db ?? DBManager.instance;

  // ---------- Load / save ----------

  /// itemId → answer, with photo paths resolved to absolute paths.
  Future<Map<int, MobileFoodInspectionAnswerModel>> loadAnswers(
      String inspectionId) async {
    final base = await _db.inspectionPhotoBaseDir();
    final list = await _db.getMobileFoodAnswers(inspectionId);
    return {
      for (final a in list)
        a.itemId: a.copyWithPhotos(
          a.photos.map((x) => x == null ? null : _toAbsolute(base, x)).toList(),
        ),
    };
  }

  Future<void> saveAnswer(MobileFoodInspectionAnswerModel answer) async {
    final base = await _db.inspectionPhotoBaseDir();
    await _db.saveMobileFoodAnswer(_withRelativePhotos(base, answer));
  }

  Future<void> saveAnswers(List<MobileFoodInspectionAnswerModel> list) async {
    if (list.isEmpty) return;
    final base = await _db.inspectionPhotoBaseDir();
    await _db.saveMobileFoodAnswers(
      list.map((a) => _withRelativePhotos(base, a)).toList(),
    );
  }

  // ---------- Temperature Observations ----------

  Future<List<MobileFoodTemperatureModel>> loadTemperatures(
          String inspectionId) =>
      _db.getMobileFoodTemperatures(inspectionId);

  /// Replaces all saved temperature rows of the inspection.
  Future<void> saveTemperatures(
          String inspectionId, List<MobileFoodTemperatureModel> rows) =>
      _db.saveMobileFoodTemperatures(inspectionId, rows);

  // ---------- Final Submit ----------

  /// Operation Type dropdown (saved by the Dashboard sync).
  Future<List<MobileFoodOperationTypeModel>> loadOperationTypes() =>
      _db.getMobileFoodOperationTypes();

  /// Saved Final Submit data, with signature paths made absolute.
  Future<MobileFoodFinalSubmitModel?> loadFinalSubmit(
      String inspectionId) async {
    final data = await _db.getMobileFoodFinalSubmit(inspectionId);
    if (data == null) return null;
    final base = await _db.inspectionPhotoBaseDir();
    return data.withSignatures(
      pic: data.picSignature == null
          ? null
          : _toAbsolute(base, data.picSignature!),
      inspector: data.inspectorSignature == null
          ? null
          : _toAbsolute(base, data.inspectorSignature!),
    );
  }

  Future<void> saveFinalSubmit(MobileFoodFinalSubmitModel data) async {
    final base = await _db.inspectionPhotoBaseDir();
    await _db.saveMobileFoodFinalSubmit(data.withSignatures(
      pic: data.picSignature == null
          ? null
          : _toRelative(base, data.picSignature!),
      inspector: data.inspectorSignature == null
          ? null
          : _toRelative(base, data.inspectorSignature!),
    ));
  }

  /// Writes a signature PNG to <photos>/<inspectionId>/ and returns
  /// its absolute path. [who] is 'pic' or 'inspector'.
  Future<String> storeSignature({
    required String inspectionId,
    required String who,
    required Uint8List bytes,
  }) async {
    final base = await _db.inspectionPhotoBaseDir();
    final dir = Directory(p.join(base, inspectionId));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path,
        'signature_${who}_${DateTime.now().millisecondsSinceEpoch}.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // ---------- Photo files ----------

  /// Copies a picked image (camera/gallery temp file) into
  /// <photos>/<inspectionId>/ and returns the new absolute path.
  Future<String> storePhoto({
    required String inspectionId,
    required int itemId,
    required int slot,
    required String sourcePath,
  }) async {
    final base = await _db.inspectionPhotoBaseDir();
    final dir = Directory(p.join(base, inspectionId));
    if (!await dir.exists()) await dir.create(recursive: true);

    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final name =
        'item${itemId}_slot${slot + 1}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final saved = await File(sourcePath).copy(p.join(dir.path, name));
    return saved.path;
  }

  Future<void> deletePhoto(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('⚠️ Delete photo error: $e');
    }
  }

  // ---------- Helpers ----------

  MobileFoodInspectionAnswerModel _withRelativePhotos(
          String base, MobileFoodInspectionAnswerModel a) =>
      a.copyWithPhotos(
        a.photos.map((x) => x == null ? null : _toRelative(base, x)).toList(),
      );

  String _toRelative(String base, String path) =>
      p.isWithin(base, path) ? p.relative(path, from: base) : path;

  String _toAbsolute(String base, String path) =>
      p.isAbsolute(path) ? path : p.join(base, path);
}