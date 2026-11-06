class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class BadRequestException extends ApiException {
  BadRequestException([String msg = 'Bad request']) : super(msg, 400);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String msg = 'Invalid email or password']) : super(msg, 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException([String msg = 'Access denied']) : super(msg, 403);
}

class NotFoundException extends ApiException {
  NotFoundException([String msg = 'Resource not found']) : super(msg, 404);
}

class ValidationException extends ApiException {
  final Map<String, List<String>> errors;
  ValidationException(String msg, this.errors) : super(msg, 422);
}

class TooManyRequestsException extends ApiException {
  TooManyRequestsException([String msg = 'Too many attempts. Please try again later'])
      : super(msg, 429);
}

class ServerException extends ApiException {
  ServerException([String msg = 'Server error. Please try again later', int? code])
      : super(msg, code ?? 500);
}

class NoInternetException extends ApiException {
  NoInternetException() : super('No internet connection');
}

class TimeoutApiException extends ApiException {
  TimeoutApiException() : super('Request timed out. Please try again');
}

class InvalidResponseException extends ApiException {
  InvalidResponseException() : super('Invalid response from server');
}