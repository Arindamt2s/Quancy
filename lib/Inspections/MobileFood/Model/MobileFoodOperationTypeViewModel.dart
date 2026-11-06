import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// TODO: fix these two imports if the files live somewhere else in your project.
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/HTTPS/apiConstants.dart';

import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeModel.dart';

/// Downloads operation types from the API, saves them in
/// `mobile_food_operation_types`, and reads them back for the UI.
class MobileFoodOperationTypeViewModel extends ChangeNotifier {
  final DBManager _db;

  MobileFoodOperationTypeViewModel([DBManager? db])
      : _db = db ?? DBManager.instance;

  List<MobileFoodOperationTypeModel> _operationTypes = [];
  List<MobileFoodOperationTypeModel> get operationTypes => _operationTypes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// GET /mobile-food/operation-types → save to DB → load from DB.
  /// Returns true when the server list was saved. If the call fails
  /// (e.g. offline) the previously saved list is still loaded.
  Future<bool> syncOperationTypes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    var synced = false;
    try {
      final token = await _db.getAccessToken();
      final uri = Uri.parse(
          '${URLConstants.baseUrl}${URLConstants.mobileFoodOOperationTypesList}');

      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic> || body['status'] != true) {
        throw Exception('Unexpected response');
      }

      final list = MobileFoodOperationTypeModel.listFromResponse(body);
      await _db.saveMobileFoodOperationTypes(list);
      debugPrint('✅ Operation types saved: ${list.length}');
      synced = true;
    } catch (e) {
      _error = 'Could not download operation types.';
      debugPrint('❌ Operation types sync error: $e');
    }

    await loadFromDb(notify: false);
    _isLoading = false;
    notifyListeners();
    return synced;
  }

  /// Reads the saved (active) operation types from the DB.
  Future<List<MobileFoodOperationTypeModel>> loadFromDb(
      {bool notify = true}) async {
    try {
      _operationTypes = await _db.getMobileFoodOperationTypes();
    } catch (e) {
      debugPrint('❌ Load operation types error: $e');
      _operationTypes = [];
    }
    if (notify) notifyListeners();
    return _operationTypes;
  }
}