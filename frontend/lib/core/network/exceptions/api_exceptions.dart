sealed class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

final class UnauthorizedException extends ApiException {
  UnauthorizedException({super.message = 'Unauthorized user', super.statusCode = 401});
}

final class BadRequestException extends ApiException {
  BadRequestException({super.message = 'Bad request', super.statusCode = 400});
}

final class NotFoundException extends ApiException {
  NotFoundException({super.message = 'Resource not found', super.statusCode = 404});
}

final class ConflictException extends ApiException {
  ConflictException({super.message = 'Conflict', super.statusCode = 409});
}

final class ForbiddenException extends ApiException {
  ForbiddenException({super.message = 'Forbidden', super.statusCode = 403});
}

final class InternalServerErrorException extends ApiException {
  InternalServerErrorException({super.message = 'Internal server error', super.statusCode = 500});
}

final class ServiceUnavailableException extends ApiException {
  ServiceUnavailableException({super.message = 'Service unavailable', super.statusCode = 503});
}

final class RequestTimeoutException extends ApiException {
  RequestTimeoutException({super.message = 'Request timeout', super.statusCode = 408});
}

final class TooManyRequestsException extends ApiException {
  TooManyRequestsException({super.message = 'Too many requests', super.statusCode = 429});
}

final class UnprocessableEntityException extends ApiException {
  UnprocessableEntityException({super.message = 'Unprocessable Entity', super.statusCode = 422});
}

final class UnknownApiException extends ApiException {
  UnknownApiException({required super.message, super.statusCode});
}
