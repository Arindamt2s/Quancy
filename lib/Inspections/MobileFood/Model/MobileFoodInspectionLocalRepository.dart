// lib/Database/MobileFoodInspectionLocalRepository.dart
//
// Removes a submitted inspection from the local database
// (so it disappears from "Incomplete inspections") and deletes its
// photo / signature files from the device.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:quincy/Database/DBManager.dart';

class MobileFoodInspectionLocalRepository {
  /// Child tables first, parent table last.
  /// Tables that don't exist on the device are skipped.
  /// TODO: make sure the temperature table name is in this list.
  static const List<String> _tables = [
    'MobileFoodInspectionAnswer',
    'MobileFoodInspectionTemperature',
    'MobileFoodTemperature',
    'MobileFoodInspectionFinal',
    'MobileFoodInspection',
  ];

  static const _photoColumns = ['photo_1', 'photo_2', 'photo_3', 'photo_4'];
  static const _signColumns = ['pic_signature', 'inspector_signature'];

  /// Deletes every row of [inspectionId] (the local "MFI-…" id)
  /// and its image files.
  Future<void> deleteInspection(String inspectionId) async {
    final db = await DBManager.instance.database;

    // Which of our tables exist in this database
    final existing = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ))
        .map((r) => r['name'].toString())
        .toSet();

    // 1. Collect file paths BEFORE the rows are gone
    final paths = <String>[];
    if (existing.contains('MobileFoodInspectionAnswer')) {
      final rows = await db.query(
        'MobileFoodInspectionAnswer',
        columns: _photoColumns,
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );
      for (final r in rows) {
        for (final c in _photoColumns) {
          final v = r[c]?.toString();
          if (v != null && v.isNotEmpty) paths.add(v);
        }
      }
    }
    if (existing.contains('MobileFoodInspectionFinal')) {
      final rows = await db.query(
        'MobileFoodInspectionFinal',
        columns: _signColumns,
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );
      for (final r in rows) {
        for (final c in _signColumns) {
          final v = r[c]?.toString();
          if (v != null && v.isNotEmpty) paths.add(v);
        }
      }
    }

    // 2. Delete the rows (all or nothing)
    await db.transaction((txn) async {
      for (final table in _tables) {
        if (!existing.contains(table)) continue;
        final n = await txn.delete(
          table,
          where: 'inspection_id = ?',
          whereArgs: [inspectionId],
        );
        debugPrint('🗑️ $table: $n row(s) deleted for $inspectionId');
      }
    });

    // 3. Delete the image files (failures here don't matter)
    await _deleteFiles(inspectionId, paths);
  }

  Future<void> _deleteFiles(String inspectionId, List<String> paths) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      for (final path in paths) {
        final full = p.isAbsolute(path) ? path : p.join(docs.path, path);
        final f = File(full);
        if (await f.exists()) await f.delete();
      }
      // Photos are stored in a folder named after the inspection id
      final folder = Directory(p.join(docs.path, inspectionId));
      if (await folder.exists()) await folder.delete(recursive: true);
    } catch (e) {
      debugPrint('⚠️ Could not delete inspection files: $e');
    }
  }
}