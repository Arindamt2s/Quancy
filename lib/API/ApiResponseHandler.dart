import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quincy/API/ApiExtension.dart';


class ApiResponseHandler {
  static Map<String, dynamic> handle(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      }
    } catch (_) {
      // Non-JSON body (e.g. HTML error page)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw InvalidResponseException();
      }
    }

    final String? message = body['message']?.toString() ?? body['error']?.toString();

    switch (response.statusCode) {
      case 200:
      case 201:
        return body;
      case 204:
        return {};
      case 400:
        throw BadRequestException(message ?? 'Bad request');
      case 401:
        throw UnauthorizedException(message ?? 'Invalid email or password');
      case 403:
        throw ForbiddenException(message ?? 'Access denied');
      case 404:
        throw NotFoundException(message ?? 'Not found');
      case 422:
        throw ValidationException(
          _firstValidationError(body) ?? message ?? 'Validation failed',
          _parseErrors(body),
        );
      case 429:
        throw TooManyRequestsException();
      case 500:
      case 502:
      case 503:
      case 504:
        throw ServerException(message ?? 'Server error. Please try again later', response.statusCode);
      default:
        throw ApiException(
          message ?? 'Unexpected error (${response.statusCode})',
          response.statusCode,
        );
    }
  }

  // Laravel format: {"message": "...", "errors": {"email": ["..."]}}
  static Map<String, List<String>> _parseErrors(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is! Map) return {};
    return errors.map((key, value) => MapEntry(
          key.toString(),
          value is List ? value.map((e) => e.toString()).toList() : [value.toString()],
        ));
  }

  static String? _firstValidationError(Map<String, dynamic> body) {
    final errors = _parseErrors(body);
    if (errors.isEmpty) return null;
    final first = errors.values.first;
    return first.isNotEmpty ? first.first : null;
  }
}