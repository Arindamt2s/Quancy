import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';


import 'package:quincy/Inspections/MobileFood/Model/MobileFoodFinalSubmitModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionAnswerModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionModel.dart';
import 'package:quincy/Inspections/Food/Model/FoodPermitModel.dart';
import 'package:quincy/Inspections/Food/Model/FoodInspectionModel.dart';
import 'package:quincy/Inspections/Food/Model/FoodSectionModel.dart';
import 'package:quincy/Inspections/Food/Schedule/Model/FoodInspectionScheduleModel.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodInspectionModel.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodPermitModel.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodSectionModel.dart';
import 'package:quincy/Inspections/TempFood/Schedule/Model/TempFoodInspectionScheduleModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoInspectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoPermitModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoSectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Schedule/Model/TobaccoInspectionScheduleModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodPermitModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodSectionModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureModel.dart';
import 'package:quincy/Inspections/MobileFood/Schedule/Model/MobileFoodInspectionscheduleModel.dart';
import 'package:quincy/Inspector/Model/InspectorModel.dart';
import 'package:quincy/Login/Model/LoginModel.dart';
import 'package:sqflite/sqflite.dart';

class DBManager {
  DBManager._internal();
  static final DBManager instance = DBManager._internal();

  static const String _dbName = 'quincy_auth.db';

  // v2: app_mode, v3: mobile_food_permits, v4: MobileFoodInspection,
  // v5: mobile food sections / section parts / items,
  // v6: MobileFoodInspectionAnswer (checklist answers + photo paths),
  // v7: MobileFoodTemperature (temperature observation rows),
  // v8: mobile_food_operation_types,
  // v9: MobileFoodInspectionFinal (Final Submit tab + signatures),
  // v10: inspectors (GET /inspector),
  // v11: mobile_food_inspection_schedules (GET /mobile-food/get-inspection-shedules)
  // v12: mobile_food_inspection_schedules.previous_inspection_id
  // v13: food_permits (GET /food/get-permit-list)
  // v14: Food checklist (food_sections / food_section_parts / food_items)
  //      + FoodInspection, FoodInspectionAnswer, FoodTemperature,
  //        FoodInspectionFinal
  // v15: food_inspection_schedules (GET /food/get-inspection-shedules)
  // v16: FoodInspection.inspector_id (selected inspector's id)
  // v17: Temporary Food – temp_food_permits, temp_food_sections /
  //      _section_parts / _items, TempFoodInspection (+ inspector_id),
  //      TempFoodInspectionAnswer, TempFoodTemperature,
  //      TempFoodInspectionFinal, temp_food_inspection_schedules
  // v18: Tobacco – tobacco_permits, tobacco_sections / _sub_sections /
  //      _items, TobaccoInspection (+ schedule_id), TobaccoInspectionAnswer,
  //      TobaccoInspectionFinal, tobacco_inspection_schedules
  // v19: TobaccoInspectionFinal.operation_type_id / operation_type_name
  // v20: TobaccoInspection.server_inspection_id (id from /tobacco/inspection)
  static const int _dbVersion = 20;

  static const String tableUser = 'users';
  static const String tableAuth = 'auth_session';
  static const String tableMobileFoodPermit = 'mobile_food_permits';
  static const String tableMobileFoodInspection = 'MobileFoodInspection';
  static const String tableMobileFoodSection = 'mobile_food_sections';
  static const String tableMobileFoodSectionPart = 'mobile_food_section_parts';
  static const String tableMobileFoodItem = 'mobile_food_items';
  static const String tableMobileFoodAnswer = 'MobileFoodInspectionAnswer';
  static const String tableMobileFoodTemperature = 'MobileFoodTemperature';
  static const String tableMobileFoodOperationType =
      'mobile_food_operation_types';
  static const String tableMobileFoodFinal = 'MobileFoodInspectionFinal';
  static const String tableInspector = 'inspectors';
  static const String tableMobileFoodSchedule =
      'mobile_food_inspection_schedules';
  static const String tableFoodPermit = 'food_permits';

  // ---- Food inspection ----
  static const String tableFoodSection = 'food_sections';
  static const String tableFoodSectionPart = 'food_section_parts';
  static const String tableFoodItem = 'food_items';
  static const String tableFoodInspection = 'FoodInspection';
  static const String tableFoodAnswer = 'FoodInspectionAnswer';
  static const String tableFoodTemperature = 'FoodTemperature';
  static const String tableFoodFinal = 'FoodInspectionFinal';
  static const String tableFoodInspectionSchedules =
      'food_inspection_schedules';

  // ---- Temporary Food inspection ----
  static const String tableTempFoodPermit = 'temp_food_permits';
  static const String tableTempFoodSection = 'temp_food_sections';
  static const String tableTempFoodSectionPart = 'temp_food_section_parts';
  static const String tableTempFoodItem = 'temp_food_items';
  static const String tableTempFoodInspection = 'TempFoodInspection';
  static const String tableTempFoodAnswer = 'TempFoodInspectionAnswer';
  static const String tableTempFoodTemperature = 'TempFoodTemperature';
  static const String tableTempFoodFinal = 'TempFoodInspectionFinal';
  // ---- Tobacco inspection ----
  static const String tableTobaccoPermit = 'tobacco_permits';
  static const String tableTobaccoSection = 'tobacco_sections';
  static const String tableTobaccoSubSection = 'tobacco_sub_sections';
  static const String tableTobaccoItem = 'tobacco_items';
  static const String tableTobaccoInspection = 'TobaccoInspection';
  static const String tableTobaccoAnswer = 'TobaccoInspectionAnswer';
  static const String tableTobaccoFinal = 'TobaccoInspectionFinal';
  static const String tableTobaccoInspectionSchedules =
      'tobacco_inspection_schedules';

  static const String tableTempFoodInspectionSchedules =
      'temp_food_inspection_schedules';

  /// Only active, not-deleted rows
  static const String _activeWhere =
      "LOWER(IFNULL(status, 'active')) = 'active' AND IFNULL(deleted_at, '') = ''";

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<String> getDatabasePath() async {
    final path = join(await getDatabasesPath(), _dbName);
    debugPrint('📂 DB path: $path');
    return path;
  }

  /// Folder where inspection item photos are stored as files.
  /// Each inspection gets its own sub-folder: <base>/<inspection_id>/
  Future<String> inspectionPhotoBaseDir() async =>
      join(await getDatabasesPath(), 'inspection_photos');

  /// Same as [inspectionPhotoBaseDir] for Food inspections.
  Future<String> foodInspectionPhotoBaseDir() async =>
      join(await getDatabasesPath(), 'food_inspection_photos');

  /// Same as [inspectionPhotoBaseDir] for Temporary Food inspections.
  Future<String> tempFoodInspectionPhotoBaseDir() async =>
      join(await getDatabasesPath(), 'temp_food_inspection_photos');

  /// Tobacco inspection files (signatures): <base>/<inspection_id>/
  Future<String> tobaccoInspectionFileBaseDir() async =>
      join(await getDatabasesPath(), 'tobacco_inspection_files');

  Future<Database> _initDatabase() async {
    final path = await getDatabasePath();
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableUser (
        id INTEGER PRIMARY KEY,
        first_name TEXT,
        last_name TEXT,
        email TEXT,
        email_verified_at TEXT,
        role_id INTEGER,
        status INTEGER,
        profile_photo TEXT,
        deleted_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableAuth (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER NOT NULL,
        access_token TEXT NOT NULL,
        logged_in_at TEXT NOT NULL,
        app_mode TEXT
      )
    ''');

    await _createMobileFoodPermitTable(db);
    await _createMobileFoodInspectionTable(db);
    await _createMobileFoodChecklistTables(db);
    await _createMobileFoodAnswerTable(db);
    await _createMobileFoodTemperatureTable(db);
    await _createMobileFoodOperationTypeTable(db);
    await _createMobileFoodFinalTable(db);
    await _createInspectorTable(db);
    await _createMobileFoodScheduleTable(db);
    await _createFoodPermitTable(db);
    await _createFoodInspectionTables(db);
    await _createFoodScheduleTable(db);
    await _createTempFoodTables(db);
    await _createTobaccoTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableAuth ADD COLUMN app_mode TEXT');
    }
    if (oldVersion < 3) {
      await _createMobileFoodPermitTable(db);
    }
    if (oldVersion < 4) {
      await _createMobileFoodInspectionTable(db);
    }
    if (oldVersion < 5) {
      await _createMobileFoodChecklistTables(db);
    }
    if (oldVersion < 6) {
      await _createMobileFoodAnswerTable(db);
    }
    if (oldVersion < 7) {
      await _createMobileFoodTemperatureTable(db);
    }
    if (oldVersion < 8) {
      await _createMobileFoodOperationTypeTable(db);
    }
    if (oldVersion < 9) {
      await _createMobileFoodFinalTable(db);
    }
    if (oldVersion < 10) {
      await _createInspectorTable(db);
    }
    if (oldVersion < 11) {
      // New table already includes previous_inspection_id.
      await _createMobileFoodScheduleTable(db);
    } else if (oldVersion < 12) {
      // v11 table existed without the column → add it.
      await db.execute('ALTER TABLE $tableMobileFoodSchedule '
          'ADD COLUMN previous_inspection_id INTEGER');
    }
    if (oldVersion < 13) {
      await _createFoodPermitTable(db);
    }
    if (oldVersion < 14) {
      await _createFoodInspectionTables(db);
    }
    if (oldVersion < 15) {
      await _createFoodScheduleTable(db);
    }
    if (oldVersion < 16) {
      await _addColumnIfMissing(
          db, tableFoodInspection, 'inspector_id', 'INTEGER');
    }
    if (oldVersion < 17) {
      await _createTempFoodTables(db);
    }
    if (oldVersion < 18) {
      await _createTobaccoTables(db);
    }
    if (oldVersion < 19) {
      await _addColumnIfMissing(
          db, tableTobaccoFinal, 'operation_type_id', 'INTEGER');
      await _addColumnIfMissing(
          db, tableTobaccoFinal, 'operation_type_name', 'TEXT');
    }
    // After v18 so the table exists when upgrading from an older version.
    if (oldVersion < 20) {
      await _addColumnIfMissing(
          db, tableTobaccoInspection, 'server_inspection_id', 'INTEGER');
    }
  }

  /// ALTER TABLE … ADD COLUMN only when the column is not there yet
  /// (tables created by a newer CREATE already have it).
  Future<void> _addColumnIfMissing(
      DatabaseExecutor db, String table, String column, String type) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    if (cols.any((c) => c['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  /// Food: checklist (sections → parts → items) + inspection tables.
  /// Same columns as the Mobile Food tables.
  Future<void> _createFoodInspectionTables(DatabaseExecutor db) async {
    // ---- Checklist from the API ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodSection (
        id INTEGER PRIMARY KEY,
        name TEXT,
        points TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodSectionPart (
        id INTEGER PRIMARY KEY,
        food_section_id INTEGER NOT NULL,
        name TEXT,
        status TEXT,
        display_order TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_food_part_section
      ON $tableFoodSectionPart (food_section_id)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodItem (
        id INTEGER PRIMARY KEY,
        serial_number INTEGER,
        food_section_part_id INTEGER NOT NULL,
        name TEXT,
        point TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_food_item_part
      ON $tableFoodItem (food_section_part_id)
    ''');

    // ---- Establishment tab ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodInspection (
        inspection_id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        permit_id INTEGER,
        business_name TEXT NOT NULL,
        applicant_name TEXT,
        permit_number TEXT,
        address TEXT,
        telephone TEXT,
        owner TEXT,
        person_in_charge TEXT,
        inspection_date TEXT NOT NULL,
        time_in TEXT NOT NULL,
        time_out TEXT NOT NULL,
        inspector TEXT,
        inspector_id INTEGER,
        status TEXT NOT NULL DEFAULT 'incomplete',
        current_step INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fi_user_status
      ON $tableFoodInspection (user_id, status)
    ''');

    // ---- Inspection Form answers (photo_1..4 = file paths) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodAnswer (
        inspection_id TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        result TEXT,
        cos INTEGER NOT NULL DEFAULT 0,
        repeat_violation INTEGER NOT NULL DEFAULT 0,
        comment TEXT,
        photo_1 TEXT,
        photo_2 TEXT,
        photo_3 TEXT,
        photo_4 TEXT,
        updated_at TEXT,
        PRIMARY KEY (inspection_id, item_id)
      )
    ''');

    // ---- Temperature Observations ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodTemperature (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        item_location TEXT,
        temperature INTEGER,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ft_inspection
      ON $tableFoodTemperature (inspection_id)
    ''');

    // ---- Final Submit (signature columns = file paths) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodFinal (
        inspection_id TEXT PRIMARY KEY,
        reinspection_date TEXT,
        purpose TEXT,
        operation_type_id INTEGER,
        operation_type_name TEXT,
        discussion TEXT,
        other_information TEXT,
        pic_signature TEXT,
        pic_sign_date TEXT,
        pic_name TEXT,
        inspector_signature TEXT,
        inspector_sign_date TEXT,
        inspector_name TEXT,
        updated_at TEXT
      )
    ''');
  }

  /// Temporary Food: permits, checklist, inspection tables and schedules.
  /// Same columns as the Food tables.
  Future<void> _createTempFoodTables(DatabaseExecutor db) async {
    // ---- Permits (GET /temp-food/get-permit-list) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodPermit (
        id INTEGER PRIMARY KEY,
        permit_number TEXT,
        business_name TEXT,
        business_address TEXT,
        city TEXT,
        state TEXT,
        zip TEXT,
        phone TEXT,
        email TEXT,
        owner_name TEXT,
        establishment_type TEXT,
        inspection_date TEXT,
        status INTEGER,
        isDelete INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        raw_json TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tfp_name
      ON $tableTempFoodPermit (business_name)
    ''');

    // ---- Checklist (sections / section parts / items) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodSection (
        id INTEGER PRIMARY KEY,
        name TEXT,
        points TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodSectionPart (
        id INTEGER PRIMARY KEY,
        food_section_id INTEGER NOT NULL,
        name TEXT,
        status TEXT,
        display_order TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tf_part_section
      ON $tableTempFoodSectionPart (food_section_id)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodItem (
        id INTEGER PRIMARY KEY,
        serial_number INTEGER,
        food_section_part_id INTEGER NOT NULL,
        name TEXT,
        point TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tf_item_part
      ON $tableTempFoodItem (food_section_part_id)
    ''');

    // ---- Establishment tab ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodInspection (
        inspection_id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        permit_id INTEGER,
        business_name TEXT NOT NULL,
        applicant_name TEXT,
        permit_number TEXT,
        address TEXT,
        telephone TEXT,
        owner TEXT,
        person_in_charge TEXT,
        inspection_date TEXT NOT NULL,
        time_in TEXT NOT NULL,
        time_out TEXT NOT NULL,
        inspector TEXT,
        inspector_id INTEGER,
        status TEXT NOT NULL DEFAULT 'incomplete',
        current_step INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tfi_user_status
      ON $tableTempFoodInspection (user_id, status)
    ''');

    // ---- Inspection Form answers (photo_1..4 = file paths) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodAnswer (
        inspection_id TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        result TEXT,
        cos INTEGER NOT NULL DEFAULT 0,
        repeat_violation INTEGER NOT NULL DEFAULT 0,
        comment TEXT,
        photo_1 TEXT,
        photo_2 TEXT,
        photo_3 TEXT,
        photo_4 TEXT,
        updated_at TEXT,
        PRIMARY KEY (inspection_id, item_id)
      )
    ''');

    // ---- Temperature Observations ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodTemperature (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        item_location TEXT,
        temperature INTEGER,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tft_inspection
      ON $tableTempFoodTemperature (inspection_id)
    ''');

    // ---- Final Submit (signature columns = file paths) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodFinal (
        inspection_id TEXT PRIMARY KEY,
        reinspection_date TEXT,
        purpose TEXT,
        operation_type_id INTEGER,
        operation_type_name TEXT,
        discussion TEXT,
        other_information TEXT,
        pic_signature TEXT,
        pic_sign_date TEXT,
        pic_name TEXT,
        inspector_signature TEXT,
        inspector_sign_date TEXT,
        inspector_name TEXT,
        updated_at TEXT
      )
    ''');

    // ---- Schedules (GET /temp-food/get-inspection-shedules-by-pagination) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTempFoodInspectionSchedules (
        id INTEGER PRIMARY KEY,
        temp_food_permit_id INTEGER,
        previous_inspection_id INTEGER,
        inspector_id INTEGER,
        job_code TEXT,
        schedule_date TEXT,
        inspection_status INTEGER,
        status INTEGER,
        inspector_first_name TEXT,
        inspector_last_name TEXT,
        inspector_nick_name TEXT,
        inspector_email TEXT,
        inspector_phone TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tfs_date
      ON $tableTempFoodInspectionSchedules (schedule_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tfs_inspector
      ON $tableTempFoodInspectionSchedules (inspector_id)
    ''');
  }

  /// Tobacco: permits, checklist, inspection tables and schedules.
  Future<void> _createTobaccoTables(DatabaseExecutor db) async {
    // ---- Permits (GET /tobacco/get-permit-list-by-pagination) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTobaccoPermit (
        id INTEGER PRIMARY KEY,
        date TEXT,
        permit_number TEXT,
        establishment_name TEXT,
        business_address TEXT,
        city TEXT,
        state TEXT,
        zip TEXT,
        phone TEXT,
        permit_email TEXT,
        applicant_name TEXT,
        owner_name TEXT,
        inspection_date TEXT,
        status TEXT,
        isDelete INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        raw_json TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tbp_name
      ON $tableTobaccoPermit (establishment_name)
    ''');

    // ---- Checklist (GET /tobacco/get-section-details) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTobaccoSection (
        id INTEGER PRIMARY KEY,
        name TEXT,
        status INTEGER,
        sort_order INTEGER,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTobaccoSubSection (
        id INTEGER PRIMARY KEY,
        section_id INTEGER,
        name TEXT,
        status INTEGER,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTobaccoItem (
        id INTEGER PRIMARY KEY,
        section_id INTEGER NOT NULL,
        sub_section_id INTEGER,
        item_label TEXT,
        parent_id INTEGER,
        name TEXT,
        answer_type TEXT,
        status INTEGER,
        sort_order INTEGER,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tbi_section
      ON $tableTobaccoItem (section_id)
    ''');

    // ---- Establishment tab ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTobaccoInspection (
        inspection_id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        permit_id INTEGER,
        schedule_id INTEGER NOT NULL DEFAULT 0,
        server_inspection_id INTEGER,
        business_name TEXT NOT NULL,
        contact_name TEXT,
        permit_number TEXT,
        address TEXT,
        telephone TEXT,
        owner TEXT,
        person_in_charge TEXT,
        inspection_date TEXT NOT NULL,
        time_in TEXT,
        time_out TEXT,
        inspector TEXT,
        inspector_id INTEGER,
        status TEXT NOT NULL DEFAULT 'incomplete',
        current_step INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tbins_user_status
      ON $tableTobaccoInspection (user_id, status)
    ''');

    // ---- Inspection Form answers ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTobaccoAnswer (
        inspection_id TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        answer TEXT,
        selected_ids TEXT,
        text_value TEXT,
        updated_at TEXT,
        PRIMARY KEY (inspection_id, item_id)
      )
    ''');

    // ---- Final Submit (signature columns = relative file paths) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTobaccoFinal (
        inspection_id TEXT PRIMARY KEY,
        reinspection_date TEXT,
        purpose TEXT,
        operation_type_id INTEGER,
        operation_type_name TEXT,
        discussion TEXT,
        other_information TEXT,
        pic_signature TEXT,
        pic_sign_date TEXT,
        pic_name TEXT,
        inspector_signature TEXT,
        inspector_sign_date TEXT,
        inspector_name TEXT,
        updated_at TEXT
      )
    ''');

    // ---- Schedules (GET /tobacco/get-inspection-schedules-by-pagination) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTobaccoInspectionSchedules (
        id INTEGER PRIMARY KEY,
        tobacco_permit_id INTEGER,
        previous_inspection_id INTEGER,
        inspector_id INTEGER,
        job_code TEXT,
        schedule_date TEXT,
        inspection_status INTEGER,
        status INTEGER,
        inspector_first_name TEXT,
        inspector_last_name TEXT,
        inspector_nick_name TEXT,
        inspector_email TEXT,
        inspector_phone TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tbs_date
      ON $tableTobaccoInspectionSchedules (schedule_date)
    ''');
  }

  /// Food permits from GET /food/get-permit-list.
  /// Main fields as columns (for search / sort) + the full API object in
  /// raw_json, so no field is lost.
  Future<void> _createFoodPermitTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodPermit (
        id INTEGER PRIMARY KEY,
        permit_number TEXT,
        business_name TEXT,
        business_address TEXT,
        city TEXT,
        state TEXT,
        zip TEXT,
        phone TEXT,
        email TEXT,
        owner_name TEXT,
        establishment_type TEXT,
        inspection_date TEXT,
        status INTEGER,
        isDelete INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        raw_json TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fp_name
      ON $tableFoodPermit (business_name)
    ''');
  }

  /// Food inspection schedules from GET /food/get-inspection-shedules.
  /// The nested "inspector" object is flattened into inspector_* columns.
  Future<void> _createFoodScheduleTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoodInspectionSchedules (
        id INTEGER PRIMARY KEY,
        food_permit_id INTEGER,
        previous_inspection_id INTEGER,
        inspector_id INTEGER,
        job_code TEXT,
        schedule_date TEXT,
        inspection_status INTEGER,
        status INTEGER,
        inspector_first_name TEXT,
        inspector_last_name TEXT,
        inspector_nick_name TEXT,
        inspector_email TEXT,
        inspector_phone TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fs_date
      ON $tableFoodInspectionSchedules (schedule_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fs_inspector
      ON $tableFoodInspectionSchedules (inspector_id)
    ''');
  }

  /// Inspection schedules from GET /mobile-food/get-inspection-shedules.
  /// The nested "inspector" object is flattened into inspector_* columns.
  Future<void> _createMobileFoodScheduleTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodSchedule (
        id INTEGER PRIMARY KEY,
        mobile_food_permit_id INTEGER,
        previous_inspection_id INTEGER,
        inspector_id INTEGER,
        job_code TEXT,
        schedule_date TEXT,
        inspection_status INTEGER,
        status INTEGER,
        inspector_first_name TEXT,
        inspector_last_name TEXT,
        inspector_nick_name TEXT,
        inspector_email TEXT,
        inspector_phone TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mfs_date
      ON $tableMobileFoodSchedule (schedule_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mfs_inspector
      ON $tableMobileFoodSchedule (inspector_id)
    ''');
  }

  /// Inspectors from GET /inspector (same column names as the API).
  Future<void> _createInspectorTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableInspector (
        id INTEGER PRIMARY KEY,
        first_name TEXT,
        last_name TEXT,
        nick_name TEXT,
        email TEXT,
        phone TEXT,
        email_verified_at TEXT,
        role_id INTEGER,
        status INTEGER,
        profile_photo TEXT,
        deleted_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  /// Final Submit tab: one row per inspection.
  /// Signatures are PNG files; the columns hold their paths.
  Future<void> _createMobileFoodFinalTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodFinal (
        inspection_id TEXT PRIMARY KEY,
        reinspection_date TEXT,
        purpose TEXT,
        operation_type_id INTEGER,
        operation_type_name TEXT,
        discussion TEXT,
        other_information TEXT,
        pic_signature TEXT,
        pic_sign_date TEXT,
        pic_name TEXT,
        inspector_signature TEXT,
        inspector_sign_date TEXT,
        inspector_name TEXT,
        updated_at TEXT
      )
    ''');
  }

  /// Operation types from /mobile-food/operation-types
  Future<void> _createMobileFoodOperationTypeTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodOperationType (
        id INTEGER PRIMARY KEY,
        name TEXT,
        status INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  /// Temperature Observations rows, one row per Item/Location.
  Future<void> _createMobileFoodTemperatureTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodTemperature (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        item_location TEXT,
        temperature INTEGER,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mft_inspection
      ON $tableMobileFoodTemperature (inspection_id)
    ''');
  }

  Future<void> _createMobileFoodChecklistTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodSection (
        id INTEGER PRIMARY KEY,
        name TEXT,
        points TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodSectionPart (
        id INTEGER PRIMARY KEY,
        food_section_id INTEGER NOT NULL,
        name TEXT,
        status TEXT,
        display_order TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mf_part_section
      ON $tableMobileFoodSectionPart (food_section_id)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodItem (
        id INTEGER PRIMARY KEY,
        serial_number INTEGER,
        food_section_part_id INTEGER NOT NULL,
        name TEXT,
        point TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mf_item_part
      ON $tableMobileFoodItem (food_section_part_id)
    ''');
  }

  /// One row per (inspection, checklist item).
  /// photo_1..photo_4 hold file paths (relative to [inspectionPhotoBaseDir]).
  Future<void> _createMobileFoodAnswerTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodAnswer (
        inspection_id TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        result TEXT,
        cos INTEGER NOT NULL DEFAULT 0,
        repeat_violation INTEGER NOT NULL DEFAULT 0,
        comment TEXT,
        photo_1 TEXT,
        photo_2 TEXT,
        photo_3 TEXT,
        photo_4 TEXT,
        updated_at TEXT,
        PRIMARY KEY (inspection_id, item_id)
      )
    ''');
  }

  Future<void> _createMobileFoodPermitTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodPermit (
        id INTEGER PRIMARY KEY,
        date TEXT,
        permit_number TEXT,
        business_name TEXT,
        business_address TEXT,
        city TEXT,
        state TEXT,
        zip TEXT,
        phone TEXT,
        email TEXT,
        applicant_name TEXT,
        applicant_address TEXT,
        applicant_city TEXT,
        applicant_state TEXT,
        applicant_zip TEXT,
        applicant_phone TEXT,
        applicant_email TEXT,
        applicant_signature TEXT,
        applicant_signature_name TEXT,
        individual_signature TEXT,
        individual_signature_name TEXT,
        received_date TEXT,
        inspection_date TEXT,
        approved_by TEXT,
        permit_issued TEXT,
        isDelete INTEGER DEFAULT 0,
        status INTEGER DEFAULT 0,
        total_fees TEXT,
        payment_type TEXT,
        receipt_number TEXT,
        final_comment TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
  }

  Future<void> _createMobileFoodInspectionTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMobileFoodInspection (
        inspection_id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        permit_id INTEGER,
        business_name TEXT NOT NULL,
        applicant_name TEXT,
        permit_number TEXT,
        address TEXT,
        telephone TEXT,
        owner TEXT,
        person_in_charge TEXT,
        inspection_date TEXT NOT NULL,
        time_in TEXT NOT NULL,
        time_out TEXT NOT NULL,
        inspector TEXT,
        status TEXT NOT NULL DEFAULT 'incomplete',
        current_step INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mfi_user_status
      ON $tableMobileFoodInspection (user_id, status)
    ''');
  }

  // ---------- Save login ----------
  Future<void> saveLogin(UserModel user, String accessToken) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableUser);
      await txn.delete(tableAuth);

      await txn.insert(
        tableUser,
        user.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        tableAuth,
        {
          'id': 1,
          'user_id': user.id,
          'access_token': accessToken,
          'logged_in_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ---------- App mode (ai / normal) ----------
  Future<void> saveAppMode(String mode) async {
    final db = await database;
    await db.update(
      tableAuth,
      {'app_mode': mode},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<String?> getAppMode() async {
    final db = await database;
    final result = await db.query(tableAuth, columns: ['app_mode'], limit: 1);
    return result.isNotEmpty ? result.first['app_mode'] as String? : null;
  }

  // ---------- Read ----------
  Future<String?> getAccessToken() async {
    final db = await database;
    final result =
        await db.query(tableAuth, columns: ['access_token'], limit: 1);
    return result.isNotEmpty ? result.first['access_token'] as String? : null;
  }

  Future<int?> getLoggedInUserId() async {
    final db = await database;
    final result = await db.query(tableAuth, columns: ['user_id'], limit: 1);
    return result.isNotEmpty ? result.first['user_id'] as int? : null;
  }

  Future<UserModel?> getLoggedInUser() async {
    final db = await database;
    final session = await db.query(tableAuth, limit: 1);
    if (session.isEmpty) return null;

    final userId = session.first['user_id'];
    final result = await db.query(
      tableUser,
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return result.isNotEmpty ? UserModel.fromJson(result.first) : null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ---------- Mobile Food Permits ----------

  /// Replaces the local table with the latest list from the server
  /// (so permits deleted on the server also disappear locally).
  Future<void> saveMobileFoodPermits(
      List<MobileFoodPermitModel> permits) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableMobileFoodPermit);
      final batch = txn.batch();
      for (final p in permits) {
        batch.insert(
          tableMobileFoodPermit,
          p.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Insert or update a single permit (e.g. after editing one).
  Future<void> upsertMobileFoodPermit(MobileFoodPermitModel permit) async {
    final db = await database;
    await db.insert(
      tableMobileFoodPermit,
      permit.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MobileFoodPermitModel>> getMobileFoodPermits() async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodPermit,
      where: 'isDelete = ?',
      whereArgs: [0],
      orderBy: 'id DESC',
    );
    return rows.map(MobileFoodPermitModel.fromJson).toList();
  }

  Future<MobileFoodPermitModel?> getMobileFoodPermitById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodPermit,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? MobileFoodPermitModel.fromJson(rows.first) : null;
  }

  Future<void> clearMobileFoodPermits() async {
    final db = await database;
    await db.delete(tableMobileFoodPermit);
  }

  // ---------- Mobile Food Checklist (sections / parts / items) ----------

  /// Replaces all rows of [table] with [rows] in one transaction.
  Future<void> _replaceAll(
      String table, List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(table);
      final batch = txn.batch();
      for (final r in rows) {
        batch.insert(table, r, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveMobileFoodSections(List<MobileFoodSectionModel> list) =>
      _replaceAll(tableMobileFoodSection, list.map((e) => e.toJson()).toList());

  Future<void> saveMobileFoodSectionParts(
          List<MobileFoodSectionPartModel> list) =>
      _replaceAll(
          tableMobileFoodSectionPart, list.map((e) => e.toJson()).toList());

  Future<void> saveMobileFoodItems(List<MobileFoodItemModel> list) =>
      _replaceAll(tableMobileFoodItem, list.map((e) => e.toJson()).toList());

  Future<List<MobileFoodSectionModel>> getMobileFoodSections() async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodSection,
      where: _activeWhere,
      orderBy: 'id ASC',
    );
    return rows.map(MobileFoodSectionModel.fromJson).toList();
  }

  /// All parts, or only those of [sectionId].
  /// Sorted by display_order (empty last), then id.
  Future<List<MobileFoodSectionPartModel>> getMobileFoodSectionParts(
      {int? sectionId}) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodSectionPart,
      where: sectionId == null
          ? _activeWhere
          : '$_activeWhere AND food_section_id = ?',
      whereArgs: sectionId == null ? null : [sectionId],
      orderBy: "CASE WHEN IFNULL(display_order, '') = '' THEN 999999 "
          'ELSE CAST(display_order AS INTEGER) END ASC, id ASC',
    );
    return rows.map(MobileFoodSectionPartModel.fromJson).toList();
  }

  /// All items, or only those of [partId]. Sorted by serial number.
  Future<List<MobileFoodItemModel>> getMobileFoodItems({int? partId}) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodItem,
      where: partId == null
          ? _activeWhere
          : '$_activeWhere AND food_section_part_id = ?',
      whereArgs: partId == null ? null : [partId],
      orderBy: 'serial_number ASC, id ASC',
    );
    return rows.map(MobileFoodItemModel.fromJson).toList();
  }

  /// Sections → Section Parts → Items in ONE query.
  ///   sections.id            = section_parts.food_section_id
  ///   section_parts.id       = items.food_section_part_id
  /// Only active rows; ordered section → part display order → serial number.
  Future<List<ChecklistSectionNode>> getMobileFoodChecklistTree() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        s.id            AS s_id,
        s.name          AS s_name,
        s.points        AS s_points,
        s.status        AS s_status,
        p.id            AS p_id,
        p.food_section_id AS p_section_id,
        p.name          AS p_name,
        p.status        AS p_status,
        p.display_order AS p_display_order,
        i.id            AS i_id,
        i.serial_number AS i_serial,
        i.food_section_part_id AS i_part_id,
        i.name          AS i_name,
        i.point         AS i_point,
        i.status        AS i_status
      FROM $tableMobileFoodSection s
      INNER JOIN $tableMobileFoodSectionPart p ON p.food_section_id = s.id
      INNER JOIN $tableMobileFoodItem i        ON i.food_section_part_id = p.id
      WHERE LOWER(IFNULL(s.status, 'active')) = 'active' AND IFNULL(s.deleted_at, '') = ''
        AND LOWER(IFNULL(p.status, 'active')) = 'active' AND IFNULL(p.deleted_at, '') = ''
        AND LOWER(IFNULL(i.status, 'active')) = 'active' AND IFNULL(i.deleted_at, '') = ''
      ORDER BY
        s.id ASC,
        CASE WHEN IFNULL(p.display_order, '') = '' THEN 999999
             ELSE CAST(p.display_order AS INTEGER) END ASC,
        p.id ASC,
        i.serial_number ASC,
        i.id ASC
    ''');

    final sections = <int, ChecklistSectionNode>{};
    final parts = <int, ChecklistPartNode>{};

    for (final r in rows) {
      final sId = r['s_id'] as int;
      final pId = r['p_id'] as int;

      final sectionNode = sections.putIfAbsent(
        sId,
        () => ChecklistSectionNode(
          MobileFoodSectionModel.fromJson({
            'id': sId,
            'name': r['s_name'],
            'points': r['s_points'],
            'status': r['s_status'],
          }),
          [],
        ),
      );

      final partNode = parts.putIfAbsent(pId, () {
        final node = ChecklistPartNode(
          MobileFoodSectionPartModel.fromJson({
            'id': pId,
            'food_section_id': r['p_section_id'],
            'name': r['p_name'],
            'status': r['p_status'],
            'display_order': r['p_display_order'],
          }),
          [],
        );
        sectionNode.parts.add(node);
        return node;
      });

      partNode.items.add(MobileFoodItemModel.fromJson({
        'id': r['i_id'],
        'serial_number': r['i_serial'],
        'food_section_part_id': r['i_part_id'],
        'name': r['i_name'],
        'point': r['i_point'],
        'status': r['i_status'],
      }));
    }

    return sections.values.toList();
  }

  // ---------- Mobile Food Operation Types ----------

  /// Replaces the local list with the latest one from the server.
  Future<void> saveMobileFoodOperationTypes(
          List<MobileFoodOperationTypeModel> list) =>
      _replaceAll(
          tableMobileFoodOperationType, list.map((e) => e.toJson()).toList());

  /// Active operation types (status = 1), ordered by id.
  Future<List<MobileFoodOperationTypeModel>> getMobileFoodOperationTypes(
      {bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodOperationType,
      where: activeOnly ? 'IFNULL(status, 1) = 1' : null,
      orderBy: 'id ASC',
    );
    return rows.map(MobileFoodOperationTypeModel.fromJson).toList();
  }

  // ---------- Inspectors ----------

  /// Replaces the local list with the latest one from GET /inspector
  /// (inspectors removed on the server also disappear locally).
  Future<void> saveInspectors(List<InspectorModel> list) =>
      _replaceAll(tableInspector, list.map((e) => e.toDb()).toList());

  /// Inspectors sorted by name.
  /// [activeOnly] skips deleted ones and status 0.
  Future<List<InspectorModel>> getInspectors({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      tableInspector,
      where: activeOnly
          ? "IFNULL(deleted_at, '') = '' AND IFNULL(status, 1) != 0"
          : null,
      orderBy: 'first_name COLLATE NOCASE, last_name COLLATE NOCASE',
    );
    return rows.map(InspectorModel.fromDb).toList();
  }

  Future<InspectorModel?> getInspectorById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableInspector,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? InspectorModel.fromDb(rows.first) : null;
  }

  // ---------- Mobile Food Inspection Schedules ----------

  /// Replaces the local list with the latest one from the server
  /// (schedules removed on the server also disappear locally).
  Future<void> saveMobileFoodInspectionSchedules(
          List<MobileFoodInspectionScheduleModel> list) =>
      _replaceAll(tableMobileFoodSchedule, list.map((e) => e.toDb()).toList());

  static const String _scheduleSelect = '''
    SELECT
      s.*,
      p.business_name    AS permit_business_name,
      p.permit_number    AS permit_permit_number,
      p.business_address AS permit_business_address
    FROM $tableMobileFoodSchedule s
    LEFT JOIN $tableMobileFoodPermit p ON p.id = s.mobile_food_permit_id
  ''';

  /// Schedules joined with their permit (business name / number / address),
  /// ordered by schedule date. [activeOnly] skips deleted rows and status 0.
  /// [inspectorId] limits to one inspector's schedules.
  Future<List<MobileFoodInspectionScheduleModel>>
      getMobileFoodInspectionSchedules({
    int? inspectorId,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (activeOnly) {
      where.add("IFNULL(s.deleted_at, '') = '' AND IFNULL(s.status, 1) != 0");
    }
    if (inspectorId != null) {
      where.add('s.inspector_id = ?');
      args.add(inspectorId);
    }
    final rows = await db.rawQuery('''
      $_scheduleSelect
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY
        CASE WHEN IFNULL(s.schedule_date, '') = '' THEN 1 ELSE 0 END ASC,
        s.schedule_date ASC,
        s.id ASC
    ''', args);
    return rows.map(MobileFoodInspectionScheduleModel.fromDb).toList();
  }

  Future<MobileFoodInspectionScheduleModel?>
      getMobileFoodInspectionScheduleById(int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_scheduleSelect WHERE s.id = ? LIMIT 1',
      [id],
    );
    return rows.isNotEmpty
        ? MobileFoodInspectionScheduleModel.fromDb(rows.first)
        : null;
  }

  // ---------- Food Permits ----------

  /// Replaces the local list with the latest one from the server
  /// (permits removed on the server also disappear locally).
  Future<void> saveFoodPermits(List<FoodPermitModel> list) =>
      _replaceAll(tableFoodPermit, list.map((e) => e.toDb()).toList());

  /// Not-deleted food permits, sorted by business name.
  Future<List<FoodPermitModel>> getFoodPermits() async {
    final db = await database;
    final rows = await db.query(
      tableFoodPermit,
      where: "IFNULL(isDelete, 0) = 0 AND IFNULL(deleted_at, '') = ''",
      orderBy: 'business_name COLLATE NOCASE ASC, id DESC',
    );
    return rows.map(FoodPermitModel.fromDb).toList();
  }

  Future<FoodPermitModel?> getFoodPermitById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableFoodPermit,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? FoodPermitModel.fromDb(rows.first) : null;
  }

  // ---------- Food Inspection Schedules ----------

  /// Replaces the local list with the latest full sync
  /// (schedules removed on the server also disappear locally).
  Future<void> saveFoodInspectionSchedules(
          List<FoodInspectionScheduleModel> list) =>
      _replaceAll(
          tableFoodInspectionSchedules, list.map((e) => e.toDb()).toList());

  static const String _foodScheduleSelect = '''
    SELECT
      s.*,
      p.business_name    AS permit_business_name,
      p.permit_number    AS permit_permit_number,
      p.business_address AS permit_business_address
    FROM $tableFoodInspectionSchedules s
    LEFT JOIN $tableFoodPermit p ON p.id = s.food_permit_id
  ''';

  /// Food schedules joined with their food permit (business name / number /
  /// address), ordered by schedule date. [activeOnly] skips deleted rows and
  /// status 0. [inspectorId] limits to one inspector's schedules.
  Future<List<FoodInspectionScheduleModel>> getFoodInspectionSchedules({
    int? inspectorId,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (activeOnly) {
      where.add("IFNULL(s.deleted_at, '') = '' AND IFNULL(s.status, 1) != 0");
    }
    if (inspectorId != null) {
      where.add('s.inspector_id = ?');
      args.add(inspectorId);
    }
    final rows = await db.rawQuery('''
      $_foodScheduleSelect
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY
        CASE WHEN IFNULL(s.schedule_date, '') = '' THEN 1 ELSE 0 END ASC,
        s.schedule_date ASC,
        s.id ASC
    ''', args);
    return rows.map(FoodInspectionScheduleModel.fromDb).toList();
  }

  Future<FoodInspectionScheduleModel?> getFoodInspectionScheduleById(
      int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_foodScheduleSelect WHERE s.id = ? LIMIT 1',
      [id],
    );
    return rows.isNotEmpty
        ? FoodInspectionScheduleModel.fromDb(rows.first)
        : null;
  }

  Future<int> countRows(String table) async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ---------- Mobile Food Inspection Answers ----------

  /// Inserts / updates one item answer. An empty answer
  /// (nothing selected, no comment, no photos) deletes the row.
  Future<void> saveMobileFoodAnswer(
      MobileFoodInspectionAnswerModel answer) async {
    final db = await database;
    await _writeAnswer(db, answer, DateTime.now().toIso8601String());
  }

  /// Saves many answers in one transaction.
  Future<void> saveMobileFoodAnswers(
      List<MobileFoodInspectionAnswerModel> answers) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final a in answers) {
        await _writeAnswer(txn, a, now);
      }
    });
  }

  Future<void> _writeAnswer(DatabaseExecutor db,
      MobileFoodInspectionAnswerModel a, String now) async {
    if (a.isEmpty) {
      await db.delete(
        tableMobileFoodAnswer,
        where: 'inspection_id = ? AND item_id = ?',
        whereArgs: [a.inspectionId, a.itemId],
      );
      return;
    }
    await db.insert(
      tableMobileFoodAnswer,
      {...a.toMap(), 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MobileFoodInspectionAnswerModel>> getMobileFoodAnswers(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodAnswer,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
    return rows.map(MobileFoodInspectionAnswerModel.fromMap).toList();
  }

  // ---------- Mobile Food Temperature Observations ----------

  /// Replaces all temperature rows of [inspectionId] with [rows]
  /// (empty rows are skipped).
  Future<void> saveMobileFoodTemperatures(
      String inspectionId, List<MobileFoodTemperatureModel> rows) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        tableMobileFoodTemperature,
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );
      final batch = txn.batch();
      for (final r in rows.where((r) => !r.isEmpty)) {
        final map = r.toMap()
          ..remove('id')
          ..['updated_at'] = now;
        batch.insert(tableMobileFoodTemperature, map);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<MobileFoodTemperatureModel>> getMobileFoodTemperatures(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodTemperature,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(MobileFoodTemperatureModel.fromMap).toList();
  }

  // ---------- Mobile Food Final Submit ----------

  Future<void> saveMobileFoodFinalSubmit(
      MobileFoodFinalSubmitModel data) async {
    final db = await database;
    await db.insert(
      tableMobileFoodFinal,
      {...data.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MobileFoodFinalSubmitModel?> getMobileFoodFinalSubmit(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodFinal,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      limit: 1,
    );
    return rows.isNotEmpty
        ? MobileFoodFinalSubmitModel.fromMap(rows.first)
        : null;
  }

  // ---------- Mobile Food Inspections ----------

  /// Inserts a new inspection or updates the existing one with the same id.
  /// Keeps the original created_at on update.
  Future<void> saveMobileFoodInspection(
      MobileFoodInspectionModel inspection) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      tableMobileFoodInspection,
      columns: ['created_at'],
      where: 'inspection_id = ?',
      whereArgs: [inspection.inspectionId],
      limit: 1,
    );

    final createdAt = existing.isNotEmpty
        ? (existing.first['created_at'] as String? ?? now)
        : now;

    await db.insert(
      tableMobileFoodInspection,
      inspection.copyWith(createdAt: createdAt, updatedAt: now).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMobileFoodInspectionStep(
      String inspectionId, int step) async {
    final db = await database;
    await db.update(
      tableMobileFoodInspection,
      {
        'current_step': step,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<MobileFoodInspectionModel?> getMobileFoodInspectionById(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodInspection,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      limit: 1,
    );
    return rows.isNotEmpty
        ? MobileFoodInspectionModel.fromMap(rows.first)
        : null;
  }

  /// Incomplete inspections of one user, newest first.
  Future<List<MobileFoodInspectionModel>> getIncompleteMobileFoodInspections(
      int userId) async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodInspection,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, MobileFoodInspectionModel.statusIncomplete],
      orderBy: 'updated_at DESC',
    );
    return rows.map(MobileFoodInspectionModel.fromMap).toList();
  }

  /// Deletes the inspection, its answers, temperatures and photo files.
  Future<void> deleteMobileFoodInspection(String inspectionId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        tableMobileFoodAnswer,
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );
      await txn.delete(
        tableMobileFoodTemperature,
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );
      await txn.delete(
        tableMobileFoodFinal,
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );
      await txn.delete(
        tableMobileFoodInspection,
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );
    });

    try {
      final dir = Directory(join(await inspectionPhotoBaseDir(), inspectionId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('⚠️ Delete inspection photos error: $e');
    }
  }

  // =====================================================================
  // ---------- Food: checklist (sections / parts / items) ----------
  // =====================================================================

  Future<void> saveFoodSections(List<FoodSectionModel> list) =>
      _replaceAll(tableFoodSection, list.map((e) => e.toJson()).toList());

  Future<void> saveFoodSectionParts(List<FoodSectionPartModel> list) =>
      _replaceAll(tableFoodSectionPart, list.map((e) => e.toJson()).toList());

  Future<void> saveFoodItems(List<FoodItemModel> list) =>
      _replaceAll(tableFoodItem, list.map((e) => e.toJson()).toList());

  Future<List<FoodSectionModel>> getFoodSections() async {
    final db = await database;
    final rows = await db.query(tableFoodSection,
        where: _activeWhere, orderBy: 'id ASC');
    return rows.map(FoodSectionModel.fromJson).toList();
  }

  Future<List<FoodSectionPartModel>> getFoodSectionParts(
      {int? sectionId}) async {
    final db = await database;
    final rows = await db.query(
      tableFoodSectionPart,
      where: sectionId == null
          ? _activeWhere
          : '$_activeWhere AND food_section_id = ?',
      whereArgs: sectionId == null ? null : [sectionId],
      orderBy: "CASE WHEN IFNULL(display_order, '') = '' THEN 999999 "
          'ELSE CAST(display_order AS INTEGER) END ASC, id ASC',
    );
    return rows.map(FoodSectionPartModel.fromJson).toList();
  }

  Future<List<FoodItemModel>> getFoodItems({int? partId}) async {
    final db = await database;
    final rows = await db.query(
      tableFoodItem,
      where: partId == null
          ? _activeWhere
          : '$_activeWhere AND food_section_part_id = ?',
      whereArgs: partId == null ? null : [partId],
      orderBy: 'serial_number ASC, id ASC',
    );
    return rows.map(FoodItemModel.fromJson).toList();
  }

  /// Sections → Parts → Items in ONE JOIN query (active rows only).
  Future<List<FoodChecklistSectionNode>> getFoodChecklistTree() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        s.id AS s_id, s.name AS s_name, s.points AS s_points, s.status AS s_status,
        p.id AS p_id, p.food_section_id AS p_section_id, p.name AS p_name,
        p.status AS p_status, p.display_order AS p_display_order,
        i.id AS i_id, i.serial_number AS i_serial,
        i.food_section_part_id AS i_part_id, i.name AS i_name,
        i.point AS i_point, i.status AS i_status
      FROM $tableFoodSection s
      INNER JOIN $tableFoodSectionPart p ON p.food_section_id = s.id
      INNER JOIN $tableFoodItem i        ON i.food_section_part_id = p.id
      WHERE LOWER(IFNULL(s.status, 'active')) = 'active' AND IFNULL(s.deleted_at, '') = ''
        AND LOWER(IFNULL(p.status, 'active')) = 'active' AND IFNULL(p.deleted_at, '') = ''
        AND LOWER(IFNULL(i.status, 'active')) = 'active' AND IFNULL(i.deleted_at, '') = ''
      ORDER BY
        s.id ASC,
        CASE WHEN IFNULL(p.display_order, '') = '' THEN 999999
             ELSE CAST(p.display_order AS INTEGER) END ASC,
        p.id ASC,
        i.serial_number ASC,
        i.id ASC
    ''');

    final sections = <int, FoodChecklistSectionNode>{};
    final parts = <int, FoodChecklistPartNode>{};

    for (final r in rows) {
      final sId = r['s_id'] as int;
      final pId = r['p_id'] as int;

      final sectionNode = sections.putIfAbsent(
        sId,
        () => FoodChecklistSectionNode(
          FoodSectionModel.fromJson({
            'id': sId,
            'name': r['s_name'],
            'points': r['s_points'],
            'status': r['s_status'],
          }),
          [],
        ),
      );

      final partNode = parts.putIfAbsent(pId, () {
        final node = FoodChecklistPartNode(
          FoodSectionPartModel.fromJson({
            'id': pId,
            'food_section_id': r['p_section_id'],
            'name': r['p_name'],
            'status': r['p_status'],
            'display_order': r['p_display_order'],
          }),
          [],
        );
        sectionNode.parts.add(node);
        return node;
      });

      partNode.items.add(FoodItemModel.fromJson({
        'id': r['i_id'],
        'serial_number': r['i_serial'],
        'food_section_part_id': r['i_part_id'],
        'name': r['i_name'],
        'point': r['i_point'],
        'status': r['i_status'],
      }));
    }
    return sections.values.toList();
  }

  // ---------- Food: inspections (Establishment tab) ----------

  /// Keeps the original created_at and the saved inspector_id on update
  /// (the model's toMap() has no inspector_id, and REPLACE would clear it).
  Future<void> saveFoodInspection(FoodInspectionModel inspection) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      tableFoodInspection,
      columns: ['created_at', 'inspector_id'],
      where: 'inspection_id = ?',
      whereArgs: [inspection.inspectionId],
      limit: 1,
    );
    final createdAt = existing.isNotEmpty
        ? (existing.first['created_at'] as String? ?? now)
        : now;
    final inspectorId =
        existing.isNotEmpty ? existing.first['inspector_id'] : null;
    await db.insert(
      tableFoodInspection,
      {
        ...inspection.copyWith(createdAt: createdAt, updatedAt: now).toMap(),
        if (inspectorId != null) 'inspector_id': inspectorId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Saves the selected inspector's id on the Food inspection row.
  Future<void> setFoodInspectionInspectorId(
      String inspectionId, int? inspectorId) async {
    final db = await database;
    await db.update(
      tableFoodInspection,
      {'inspector_id': inspectorId},
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  /// The inspector id saved for a Food inspection (null if none).
  Future<int?> getFoodInspectionInspectorId(String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableFoodInspection,
      columns: ['inspector_id'],
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['inspector_id'];
    return v is int ? v : int.tryParse('${v ?? ''}');
  }

  Future<void> updateFoodInspectionStep(String inspectionId, int step) async {
    final db = await database;
    await db.update(
      tableFoodInspection,
      {'current_step': step, 'updated_at': DateTime.now().toIso8601String()},
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<FoodInspectionModel?> getFoodInspectionById(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableFoodInspection,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      limit: 1,
    );
    return rows.isNotEmpty ? FoodInspectionModel.fromMap(rows.first) : null;
  }

  Future<List<FoodInspectionModel>> getIncompleteFoodInspections(
      int userId) async {
    final db = await database;
    final rows = await db.query(
      tableFoodInspection,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, FoodInspectionModel.statusIncomplete],
      orderBy: 'updated_at DESC',
    );
    return rows.map(FoodInspectionModel.fromMap).toList();
  }

  /// inspection_id → number of answered checklist items (result set).
  Future<Map<String, int>> getFoodAnsweredCounts(int userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.inspection_id AS id, COUNT(*) AS c
      FROM $tableFoodAnswer a
      INNER JOIN $tableFoodInspection i ON i.inspection_id = a.inspection_id
      WHERE i.user_id = ? AND IFNULL(a.result, '') != ''
      GROUP BY a.inspection_id
    ''', [userId]);
    return {
      for (final r in rows) r['id'].toString(): (r['c'] as num?)?.toInt() ?? 0,
    };
  }

  // ---------- Food: answers ----------
  // Same row shape as MobileFoodInspectionAnswer → same model is reused.

  Future<void> saveFoodAnswers(
      List<MobileFoodInspectionAnswerModel> answers) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final a in answers) {
        if (a.isEmpty) {
          await txn.delete(
            tableFoodAnswer,
            where: 'inspection_id = ? AND item_id = ?',
            whereArgs: [a.inspectionId, a.itemId],
          );
        } else {
          await txn.insert(
            tableFoodAnswer,
            {...a.toMap(), 'updated_at': now},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<List<MobileFoodInspectionAnswerModel>> getFoodAnswers(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(tableFoodAnswer,
        where: 'inspection_id = ?', whereArgs: [inspectionId]);
    return rows.map(MobileFoodInspectionAnswerModel.fromMap).toList();
  }

  // ---------- Food: temperature observations ----------

  Future<void> saveFoodTemperatures(
      String inspectionId, List<MobileFoodTemperatureModel> rows) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(tableFoodTemperature,
          where: 'inspection_id = ?', whereArgs: [inspectionId]);
      final batch = txn.batch();
      for (final r in rows.where((r) => !r.isEmpty)) {
        final map = r.toMap()
          ..remove('id')
          ..['updated_at'] = now;
        batch.insert(tableFoodTemperature, map);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<MobileFoodTemperatureModel>> getFoodTemperatures(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableFoodTemperature,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(MobileFoodTemperatureModel.fromMap).toList();
  }

  // ---------- Food: final submit ----------

  Future<void> saveFoodFinalSubmit(MobileFoodFinalSubmitModel data) async {
    final db = await database;
    await db.insert(
      tableFoodFinal,
      {...data.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MobileFoodFinalSubmitModel?> getFoodFinalSubmit(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(tableFoodFinal,
        where: 'inspection_id = ?', whereArgs: [inspectionId], limit: 1);
    return rows.isNotEmpty
        ? MobileFoodFinalSubmitModel.fromMap(rows.first)
        : null;
  }

  /// Deletes a Food inspection, its answers, temperatures, final row
  /// and its photo / signature files.
  Future<void> deleteFoodInspection(String inspectionId) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in [
        tableFoodAnswer,
        tableFoodTemperature,
        tableFoodFinal,
        tableFoodInspection,
      ]) {
        await txn.delete(t,
            where: 'inspection_id = ?', whereArgs: [inspectionId]);
      }
    });
    try {
      final dir =
          Directory(join(await foodInspectionPhotoBaseDir(), inspectionId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('⚠️ Delete food inspection photos error: $e');
    }
  }

  // =====================================================================
  // ---------- Temporary Food ----------
  // =====================================================================

  // ---------- Temp Food: permits ----------

  /// Replaces the local list with the latest one from the server.
  Future<void> saveTempFoodPermits(List<TempFoodPermitModel> list) =>
      _replaceAll(tableTempFoodPermit, list.map((e) => e.toDb()).toList());

  /// Not-deleted temp food permits, sorted by business name.
  Future<List<TempFoodPermitModel>> getTempFoodPermits() async {
    final db = await database;
    final rows = await db.query(
      tableTempFoodPermit,
      where: "IFNULL(isDelete, 0) = 0 AND IFNULL(deleted_at, '') = ''",
      orderBy: 'business_name COLLATE NOCASE ASC, id DESC',
    );
    return rows.map(TempFoodPermitModel.fromDb).toList();
  }

  Future<TempFoodPermitModel?> getTempFoodPermitById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableTempFoodPermit,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? TempFoodPermitModel.fromDb(rows.first) : null;
  }

  // ---------- Temp Food: checklist ----------

  Future<void> saveTempFoodSections(List<TempFoodSectionModel> list) =>
      _replaceAll(tableTempFoodSection, list.map((e) => e.toJson()).toList());

  Future<void> saveTempFoodSectionParts(List<TempFoodSectionPartModel> list) =>
      _replaceAll(
          tableTempFoodSectionPart, list.map((e) => e.toJson()).toList());

  Future<void> saveTempFoodItems(List<TempFoodItemModel> list) =>
      _replaceAll(tableTempFoodItem, list.map((e) => e.toJson()).toList());

  /// Sections → Parts → Items in ONE JOIN query (active rows only).
  Future<List<TempFoodChecklistSectionNode>> getTempFoodChecklistTree() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        s.id AS s_id, s.name AS s_name, s.points AS s_points, s.status AS s_status,
        p.id AS p_id, p.food_section_id AS p_section_id, p.name AS p_name,
        p.status AS p_status, p.display_order AS p_display_order,
        i.id AS i_id, i.serial_number AS i_serial,
        i.food_section_part_id AS i_part_id, i.name AS i_name,
        i.point AS i_point, i.status AS i_status
      FROM $tableTempFoodSection s
      INNER JOIN $tableTempFoodSectionPart p ON p.food_section_id = s.id
      INNER JOIN $tableTempFoodItem i        ON i.food_section_part_id = p.id
      WHERE LOWER(IFNULL(s.status, 'active')) = 'active' AND IFNULL(s.deleted_at, '') = ''
        AND LOWER(IFNULL(p.status, 'active')) = 'active' AND IFNULL(p.deleted_at, '') = ''
        AND LOWER(IFNULL(i.status, 'active')) = 'active' AND IFNULL(i.deleted_at, '') = ''
      ORDER BY
        s.id ASC,
        CASE WHEN IFNULL(p.display_order, '') = '' THEN 999999
             ELSE CAST(p.display_order AS INTEGER) END ASC,
        p.id ASC,
        i.serial_number ASC,
        i.id ASC
    ''');

    final sections = <int, TempFoodChecklistSectionNode>{};
    final parts = <int, TempFoodChecklistPartNode>{};

    for (final r in rows) {
      final sId = r['s_id'] as int;
      final pId = r['p_id'] as int;

      final sectionNode = sections.putIfAbsent(
        sId,
        () => TempFoodChecklistSectionNode(
          TempFoodSectionModel.fromJson({
            'id': sId,
            'name': r['s_name'],
            'points': r['s_points'],
            'status': r['s_status'],
          }),
          [],
        ),
      );

      final partNode = parts.putIfAbsent(pId, () {
        final node = TempFoodChecklistPartNode(
          TempFoodSectionPartModel.fromJson({
            'id': pId,
            'food_section_id': r['p_section_id'],
            'name': r['p_name'],
            'status': r['p_status'],
            'display_order': r['p_display_order'],
          }),
          [],
        );
        sectionNode.parts.add(node);
        return node;
      });

      partNode.items.add(TempFoodItemModel.fromJson({
        'id': r['i_id'],
        'serial_number': r['i_serial'],
        'food_section_part_id': r['i_part_id'],
        'name': r['i_name'],
        'point': r['i_point'],
        'status': r['i_status'],
      }));
    }
    return sections.values.toList();
  }

  // ---------- Temp Food: inspections (Establishment tab) ----------

  /// Keeps the original created_at and the saved inspector_id on update.
  Future<void> saveTempFoodInspection(TempFoodInspectionModel inspection) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      tableTempFoodInspection,
      columns: ['created_at', 'inspector_id'],
      where: 'inspection_id = ?',
      whereArgs: [inspection.inspectionId],
      limit: 1,
    );
    final createdAt = existing.isNotEmpty
        ? (existing.first['created_at'] as String? ?? now)
        : now;
    final inspectorId =
        existing.isNotEmpty ? existing.first['inspector_id'] : null;
    await db.insert(
      tableTempFoodInspection,
      {
        ...inspection.copyWith(createdAt: createdAt, updatedAt: now).toMap(),
        if (inspectorId != null) 'inspector_id': inspectorId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setTempFoodInspectionInspectorId(
      String inspectionId, int? inspectorId) async {
    final db = await database;
    await db.update(
      tableTempFoodInspection,
      {'inspector_id': inspectorId},
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<int?> getTempFoodInspectionInspectorId(String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableTempFoodInspection,
      columns: ['inspector_id'],
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['inspector_id'];
    return v is int ? v : int.tryParse('${v ?? ''}');
  }

  Future<void> updateTempFoodInspectionStep(
      String inspectionId, int step) async {
    final db = await database;
    await db.update(
      tableTempFoodInspection,
      {'current_step': step, 'updated_at': DateTime.now().toIso8601String()},
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<TempFoodInspectionModel?> getTempFoodInspectionById(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableTempFoodInspection,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      limit: 1,
    );
    return rows.isNotEmpty ? TempFoodInspectionModel.fromMap(rows.first) : null;
  }

  Future<List<TempFoodInspectionModel>> getIncompleteTempFoodInspections(
      int userId) async {
    final db = await database;
    final rows = await db.query(
      tableTempFoodInspection,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, TempFoodInspectionModel.statusIncomplete],
      orderBy: 'updated_at DESC',
    );
    return rows.map(TempFoodInspectionModel.fromMap).toList();
  }

  /// inspection_id → number of answered checklist items.
  Future<Map<String, int>> getTempFoodAnsweredCounts(int userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.inspection_id AS id, COUNT(*) AS c
      FROM $tableTempFoodAnswer a
      INNER JOIN $tableTempFoodInspection i ON i.inspection_id = a.inspection_id
      WHERE i.user_id = ? AND IFNULL(a.result, '') != ''
      GROUP BY a.inspection_id
    ''', [userId]);
    return {
      for (final r in rows) r['id'].toString(): (r['c'] as num?)?.toInt() ?? 0,
    };
  }

  // ---------- Temp Food: answers ----------

  Future<void> saveTempFoodAnswers(
      List<MobileFoodInspectionAnswerModel> answers) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final a in answers) {
        if (a.isEmpty) {
          await txn.delete(
            tableTempFoodAnswer,
            where: 'inspection_id = ? AND item_id = ?',
            whereArgs: [a.inspectionId, a.itemId],
          );
        } else {
          await txn.insert(
            tableTempFoodAnswer,
            {...a.toMap(), 'updated_at': now},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<List<MobileFoodInspectionAnswerModel>> getTempFoodAnswers(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(tableTempFoodAnswer,
        where: 'inspection_id = ?', whereArgs: [inspectionId]);
    return rows.map(MobileFoodInspectionAnswerModel.fromMap).toList();
  }

  // ---------- Temp Food: temperature observations ----------

  Future<void> saveTempFoodTemperatures(
      String inspectionId, List<MobileFoodTemperatureModel> rows) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(tableTempFoodTemperature,
          where: 'inspection_id = ?', whereArgs: [inspectionId]);
      final batch = txn.batch();
      for (final r in rows.where((r) => !r.isEmpty)) {
        final map = r.toMap()
          ..remove('id')
          ..['updated_at'] = now;
        batch.insert(tableTempFoodTemperature, map);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<MobileFoodTemperatureModel>> getTempFoodTemperatures(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(
      tableTempFoodTemperature,
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(MobileFoodTemperatureModel.fromMap).toList();
  }

  // ---------- Temp Food: final submit ----------

  Future<void> saveTempFoodFinalSubmit(MobileFoodFinalSubmitModel data) async {
    final db = await database;
    await db.insert(
      tableTempFoodFinal,
      {...data.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MobileFoodFinalSubmitModel?> getTempFoodFinalSubmit(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(tableTempFoodFinal,
        where: 'inspection_id = ?', whereArgs: [inspectionId], limit: 1);
    return rows.isNotEmpty
        ? MobileFoodFinalSubmitModel.fromMap(rows.first)
        : null;
  }

  /// Deletes a Temp Food inspection, its answers, temperatures, final row
  /// and its photo / signature files.
  Future<void> deleteTempFoodInspection(String inspectionId) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in [
        tableTempFoodAnswer,
        tableTempFoodTemperature,
        tableTempFoodFinal,
        tableTempFoodInspection,
      ]) {
        await txn.delete(t,
            where: 'inspection_id = ?', whereArgs: [inspectionId]);
      }
    });
    try {
      final dir =
          Directory(join(await tempFoodInspectionPhotoBaseDir(), inspectionId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('⚠️ Delete temp food inspection photos error: $e');
    }
  }

  // ---------- Temp Food: schedules ----------

  Future<void> saveTempFoodInspectionSchedules(
          List<TempFoodInspectionScheduleModel> list) =>
      _replaceAll(tableTempFoodInspectionSchedules,
          list.map((e) => e.toDb()).toList());

  static const String _tempFoodScheduleSelect = '''
    SELECT
      s.*,
      p.business_name    AS permit_business_name,
      p.permit_number    AS permit_permit_number,
      p.business_address AS permit_business_address
    FROM $tableTempFoodInspectionSchedules s
    LEFT JOIN $tableTempFoodPermit p ON p.id = s.temp_food_permit_id
  ''';

  /// Temp Food schedules joined with their permit, ordered by date.
  Future<List<TempFoodInspectionScheduleModel>> getTempFoodInspectionSchedules({
    int? inspectorId,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (activeOnly) {
      where.add("IFNULL(s.deleted_at, '') = '' AND IFNULL(s.status, 1) != 0");
    }
    if (inspectorId != null) {
      where.add('s.inspector_id = ?');
      args.add(inspectorId);
    }
    final rows = await db.rawQuery('''
      $_tempFoodScheduleSelect
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY
        CASE WHEN IFNULL(s.schedule_date, '') = '' THEN 1 ELSE 0 END ASC,
        s.schedule_date ASC,
        s.id ASC
    ''', args);
    return rows.map(TempFoodInspectionScheduleModel.fromDb).toList();
  }

  Future<TempFoodInspectionScheduleModel?> getTempFoodInspectionScheduleById(
      int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_tempFoodScheduleSelect WHERE s.id = ? LIMIT 1',
      [id],
    );
    return rows.isNotEmpty
        ? TempFoodInspectionScheduleModel.fromDb(rows.first)
        : null;
  }

  // =====================================================================
  // ---------- Tobacco ----------
  // =====================================================================

  // ---------- Tobacco: permits ----------

  /// Replaces the local list with the latest one from the server.
  Future<void> saveTobaccoPermits(List<TobaccoPermitModel> list) =>
      _replaceAll(tableTobaccoPermit, list.map((e) => e.toDb()).toList());

  /// Not-deleted tobacco permits, sorted by establishment name.
  Future<List<TobaccoPermitModel>> getTobaccoPermits() async {
    final db = await database;
    final rows = await db.query(
      tableTobaccoPermit,
      where: "IFNULL(isDelete, 0) = 0 AND IFNULL(deleted_at, '') = ''",
      orderBy: 'establishment_name COLLATE NOCASE ASC, id DESC',
    );
    return rows.map(TobaccoPermitModel.fromDb).toList();
  }

  Future<TobaccoPermitModel?> getTobaccoPermitById(int id) async {
    final db = await database;
    final rows = await db.query(tableTobaccoPermit,
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty ? TobaccoPermitModel.fromDb(rows.first) : null;
  }

  // ---------- Tobacco: checklist ----------

  /// Replaces sections, sub-sections and items in ONE transaction.
  Future<void> saveTobaccoChecklist(TobaccoChecklistData data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableTobaccoSection);
      await txn.delete(tableTobaccoSubSection);
      await txn.delete(tableTobaccoItem);
      final batch = txn.batch();
      for (final s in data.sections) {
        batch.insert(tableTobaccoSection, s.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final s in data.subSections) {
        batch.insert(tableTobaccoSubSection, s.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final i in data.items) {
        batch.insert(tableTobaccoItem, i.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Sections → items → children (ALL rows; hide status 0 in the UI).
  Future<List<TobaccoSectionModel>> getTobaccoChecklist() async {
    final db = await database;
    final s = await db.query(tableTobaccoSection, orderBy: 'sort_order, id');
    final ss = await db.query(tableTobaccoSubSection, orderBy: 'id');
    final i = await db.query(tableTobaccoItem, orderBy: 'sort_order, id');
    return TobaccoChecklistData.buildTree(
      s.map(TobaccoSectionModel.fromDb).toList(),
      ss.map(TobaccoSubSectionModel.fromDb).toList(),
      i.map(TobaccoItemModel.fromDb).toList(),
    );
  }

  // ---------- Tobacco: operation types (Final Submit dropdown) ----------

  Future<List<TobaccoOperationTypeOption>> getTobaccoOperationTypeOptions()
      async {
    final db = await database;
    final rows = await db.query(
      tableMobileFoodOperationType,
      columns: ['id', 'name'],
      where: 'IFNULL(status, 1) = 1',
      orderBy: 'id ASC',
    );
    return rows.map(TobaccoOperationTypeOption.fromDb).toList();
  }

  // ---------- Tobacco: inspectors (dropdown) ----------

  Future<List<TobaccoInspectorOption>> getTobaccoInspectorOptions() async {
    final db = await database;
    final rows = await db.query(
      tableInspector,
      columns: ['id', 'first_name', 'last_name', 'email'],
      where: "IFNULL(deleted_at, '') = '' AND IFNULL(status, 1) != 0",
      orderBy: 'first_name COLLATE NOCASE, last_name COLLATE NOCASE',
    );
    return rows.map(TobaccoInspectorOption.fromDb).toList();
  }

  // ---------- Tobacco: inspections (Establishment tab) ----------

  /// Inserts or updates; keeps the original created_at.
  Future<void> saveTobaccoInspection(TobaccoInspectionModel inspection) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      tableTobaccoInspection,
      columns: ['created_at'],
      where: 'inspection_id = ?',
      whereArgs: [inspection.inspectionId],
      limit: 1,
    );
    final createdAt = existing.isNotEmpty
        ? (existing.first['created_at'] as String? ?? now)
        : now;
    await db.insert(
      tableTobaccoInspection,
      inspection.copyWith(createdAt: createdAt, updatedAt: now).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTobaccoInspectionStep(
      String inspectionId, int step) async {
    final db = await database;
    await db.update(
      tableTobaccoInspection,
      {'current_step': step, 'updated_at': DateTime.now().toIso8601String()},
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  /// Id returned by POST /tobacco/inspection (so a failed answers call
  /// can be retried without creating the inspection twice).
  Future<void> setTobaccoServerInspectionId(
      String inspectionId, int? serverId) async {
    final db = await database;
    await db.update(
      tableTobaccoInspection,
      {
        'server_inspection_id': serverId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<void> setTobaccoInspectionStatus(
      String inspectionId, String status) async {
    final db = await database;
    await db.update(
      tableTobaccoInspection,
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<TobaccoInspectionModel?> getTobaccoInspectionById(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(tableTobaccoInspection,
        where: 'inspection_id = ?', whereArgs: [inspectionId], limit: 1);
    return rows.isNotEmpty ? TobaccoInspectionModel.fromMap(rows.first) : null;
  }

  /// The latest incomplete inspection of [userId] for this permit + schedule
  /// (so re-opening the same permit / schedule resumes instead of duplicating).
  Future<TobaccoInspectionModel?> findIncompleteTobaccoInspection({
    required int userId,
    required int? permitId,
    required int scheduleId,
  }) async {
    if (permitId == null) return null;
    final db = await database;
    final rows = await db.query(
      tableTobaccoInspection,
      where: 'user_id = ? AND permit_id = ? AND schedule_id = ? AND status = ?',
      whereArgs: [
        userId,
        permitId,
        scheduleId,
        TobaccoInspectionModel.statusIncomplete,
      ],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isNotEmpty ? TobaccoInspectionModel.fromMap(rows.first) : null;
  }

  Future<List<TobaccoInspectionModel>> getIncompleteTobaccoInspections(
      int userId) async {
    final db = await database;
    final rows = await db.query(
      tableTobaccoInspection,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, TobaccoInspectionModel.statusIncomplete],
      orderBy: 'updated_at DESC',
    );
    return rows.map(TobaccoInspectionModel.fromMap).toList();
  }

  /// inspection_id → number of answered rows (Tobacco incomplete list).
  Future<Map<String, int>> getTobaccoAnsweredCounts(int userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.inspection_id AS id, COUNT(*) AS c
      FROM $tableTobaccoAnswer a
      INNER JOIN $tableTobaccoInspection i ON i.inspection_id = a.inspection_id
      WHERE i.user_id = ?
      GROUP BY a.inspection_id
    ''', [userId]);
    return {
      for (final r in rows) r['id'].toString(): (r['c'] as num?)?.toInt() ?? 0,
    };
  }

  // ---------- Tobacco: answers ----------

  /// Empty answers delete their row.
  Future<void> saveTobaccoAnswers(
      List<TobaccoInspectionAnswerModel> answers) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final a in answers) {
        if (a.isEmpty) {
          await txn.delete(
            tableTobaccoAnswer,
            where: 'inspection_id = ? AND item_id = ?',
            whereArgs: [a.inspectionId, a.itemId],
          );
        } else {
          await txn.insert(
            tableTobaccoAnswer,
            {...a.toMap(), 'updated_at': now},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<List<TobaccoInspectionAnswerModel>> getTobaccoAnswers(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(tableTobaccoAnswer,
        where: 'inspection_id = ?', whereArgs: [inspectionId]);
    return rows.map(TobaccoInspectionAnswerModel.fromMap).toList();
  }

  // ---------- Tobacco: final submit ----------

  Future<void> saveTobaccoFinalSubmit(TobaccoFinalSubmitModel data) async {
    final db = await database;
    await db.insert(
      tableTobaccoFinal,
      {...data.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<TobaccoFinalSubmitModel?> getTobaccoFinalSubmit(
      String inspectionId) async {
    final db = await database;
    final rows = await db.query(tableTobaccoFinal,
        where: 'inspection_id = ?', whereArgs: [inspectionId], limit: 1);
    return rows.isNotEmpty ? TobaccoFinalSubmitModel.fromMap(rows.first) : null;
  }

  /// Deletes a Tobacco inspection, its answers, final row and files.
  Future<void> deleteTobaccoInspection(String inspectionId) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in [
        tableTobaccoAnswer,
        tableTobaccoFinal,
        tableTobaccoInspection,
      ]) {
        await txn.delete(t,
            where: 'inspection_id = ?', whereArgs: [inspectionId]);
      }
    });
    try {
      final dir =
          Directory(join(await tobaccoInspectionFileBaseDir(), inspectionId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('⚠️ Delete tobacco inspection files error: $e');
    }
  }

  // ---------- Tobacco: schedules ----------

  Future<void> saveTobaccoInspectionSchedules(
          List<TobaccoInspectionScheduleModel> list) =>
      _replaceAll(tableTobaccoInspectionSchedules,
          list.map((e) => e.toDb()).toList());

  static const String _tobaccoScheduleSelect = '''
    SELECT
      s.*,
      p.establishment_name AS permit_business_name,
      p.permit_number      AS permit_permit_number,
      p.business_address   AS permit_business_address,
      p.city               AS permit_city
    FROM $tableTobaccoInspectionSchedules s
    LEFT JOIN $tableTobaccoPermit p ON p.id = s.tobacco_permit_id
  ''';

  /// Tobacco schedules joined with their permit, ordered by date.
  Future<List<TobaccoInspectionScheduleModel>> getTobaccoInspectionSchedules({
    int? inspectorId,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (activeOnly) {
      where.add("IFNULL(s.deleted_at, '') = '' AND IFNULL(s.status, 1) != 0");
    }
    if (inspectorId != null) {
      where.add('s.inspector_id = ?');
      args.add(inspectorId);
    }
    final rows = await db.rawQuery('''
      $_tobaccoScheduleSelect
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY
        CASE WHEN IFNULL(s.schedule_date, '') = '' THEN 1 ELSE 0 END ASC,
        s.schedule_date ASC,
        s.id ASC
    ''', args);
    return rows.map(TobaccoInspectionScheduleModel.fromDb).toList();
  }

  Future<TobaccoInspectionScheduleModel?> getTobaccoInspectionScheduleById(
      int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_tobaccoScheduleSelect WHERE s.id = ? LIMIT 1',
      [id],
    );
    return rows.isNotEmpty
        ? TobaccoInspectionScheduleModel.fromDb(rows.first)
        : null;
  }

  // ---------- Logout ----------
  /// Inspections are NOT cleared, so a user's incomplete inspections
  /// are still there after they log in again (they're filtered by user_id).
  /// Schedules are cleared because they belong to the logged-in account.
  Future<void> clearSession() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableAuth);
      await txn.delete(tableUser);
      await txn.delete(tableMobileFoodPermit);
      await txn.delete(tableMobileFoodSchedule);
      await txn.delete(tableFoodPermit);
      await txn.delete(tableFoodInspectionSchedules);
      await txn.delete(tableTempFoodPermit);
      await txn.delete(tableTempFoodInspectionSchedules);
      await txn.delete(tableTobaccoPermit);
      await txn.delete(tableTobaccoInspectionSchedules);
    });
  }
}
