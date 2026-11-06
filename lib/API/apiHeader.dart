

import 'package:quincy/Database/DBManager.dart';



class ApiHeaders {
  // For public endpoints like login (no token)
  static Map<String, String> basicHeader() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // For all endpoints after login
  static Future<Map<String, String>> authHeader() async {
    final token = await DBManager.instance.getAccessToken();
    return {
      ...basicHeader(),
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}