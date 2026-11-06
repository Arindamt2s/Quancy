import 'package:flutter/foundation.dart';
import 'package:quincy/API/ApiExtension.dart';
import 'package:quincy/API/auth_repository.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Login/Model/LoginModel.dart';


class LoginViewModel extends ChangeNotifier {
  final AuthRepository _repository;
  final DBManager _db;

  LoginViewModel({AuthRepository? repository, DBManager? db})
      : _repository = repository ?? AuthRepository(),
        _db = db ?? DBManager.instance;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, List<String>> _fieldErrors = {};
  UserModel? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, List<String>> get fieldErrors => _fieldErrors;
  UserModel? get user => _user;
Future<void> saveAppMode(String mode) => _db.saveAppMode(mode);
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = {};
    notifyListeners();

    try {
      final response = await _repository.login(
        email: email.trim(),
        password: password,
      );

      await _db.saveLogin(response.user, response.accessToken);
      _user = response.user;
      return true;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      _fieldErrors = e.errors;
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again';
      debugPrint('❌ Login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
void clearFieldError(String field) {
  if (_fieldErrors.containsKey(field)) {
    _fieldErrors = Map.of(_fieldErrors)..remove(field);
    notifyListeners();
  }
}
  Future<void> loadSavedUser() async {
    _user = await _db.getLoggedInUser();
    notifyListeners();
  }

  Future<void> logout() async {
    await _db.clearSession();
    _user = null;
    notifyListeners();
  }
}