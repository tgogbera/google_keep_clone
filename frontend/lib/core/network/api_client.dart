import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/network/exceptions/api_exceptions.dart';
import '../config/api_config.dart';
import 'interceptors/auth_interceptor.dart';
import '../storage/token_storage.dart';

/// Singleton API client for making HTTP requests
/// Handles authentication, error handling, and logging
class ApiClient {
  factory ApiClient() => _instance;

  ApiClient._internal() {
    final baseUrl = ApiConfig.baseUrl;
    assert(baseUrl.isNotEmpty, 'API base URL must be set');

    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null, // Handle all status codes
    );

    _dio = Dio(options);
    _setupInterceptors();
  }

  static final ApiClient _instance = ApiClient._internal();
  static final TokenStorage _tokenStorage = TokenStorage();

  late final Dio _dio;

  /// Get the underlying Dio instance (for backward compatibility)
  Dio get dio => _dio;

  void _setupInterceptors() {
    // Add auth interceptor first (runs before others)
    _dio.interceptors.add(AuthInterceptor(_tokenStorage));

    // Add request/response logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logRequest(options);
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logResponse(response);
          handler.next(response);
        },
        onError: (error, handler) {
          _logError(error);
          handler.next(error);
        },
      ),
    );

    // Add debug logging interceptor last (least intrusive)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }

  /// -------------------------
  /// HTTP METHODS
  /// -------------------------

  /// Generic request method to reduce code duplication
  Future<T> _request<T>(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final optionsWithTimeout = (options ?? Options()).copyWith(
        method: method,
        // sendTimeout is only meaningful when there's a request body to send (e.g., POST/PUT/PATCH)
        // Avoid setting it on requests without a body (like GET) to prevent web adapter warnings.
        sendTimeout: data != null ? const Duration(seconds: 30) : null,
      );

      final response = await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: optionsWithTimeout,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) => _request<T>(
    'GET',
    path,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
    onReceiveProgress: onReceiveProgress,
  );

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => _request<T>(
    'POST',
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => _request<T>(
    'PUT',
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  /// PATCH request
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => _request<T>(
    'PATCH',
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => _request<T>(
    'DELETE',
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
    cancelToken: cancelToken,
  );

  /// -------------------------
  /// ERROR HANDLING
  /// -------------------------

  ApiException _handleError(DioException error) {
    // Handle timeout errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return RequestTimeoutException(
        message: 'Connection timeout. Please check your internet connection.',
      );
    }

    // Handle connection errors
    if (error.type == DioExceptionType.connectionError) {
      return UnknownApiException(
        message: 'Connection error. Please check your internet connection.',
      );
    }

    // Handle server response errors
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      final message = _extractErrorMessage(data, statusCode);

      // Map status codes to specific exception types
      return switch (statusCode) {
        400 => BadRequestException(message: message),
        401 => UnauthorizedException(message: message),
        403 => ForbiddenException(message: message),
        404 => NotFoundException(message: message),
        408 => RequestTimeoutException(message: message),
        409 => ConflictException(message: message),
        422 => UnprocessableEntityException(message: message),
        429 => TooManyRequestsException(message: message),
        500 => InternalServerErrorException(message: message),
        503 => ServiceUnavailableException(message: message),
        _ => UnknownApiException(statusCode: statusCode, message: message),
      };
    }

    // Handle other errors
    return UnknownApiException(message: error.message ?? 'An unexpected error occurred');
  }

  /// Extract error message from various response formats
  String _extractErrorMessage(dynamic data, int? statusCode) {
    if (data is Map<String, dynamic>) {
      return data['error'] as String? ??
          data['message'] as String? ??
          data['msg'] as String? ?? // Common alternative
          'Request failed with status $statusCode';
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
    return 'Request failed with status $statusCode';
  }

  /// -------------------------
  /// LOGGING
  /// -------------------------

  void _logRequest(RequestOptions options) {
    if (kDebugMode) {
      debugPrint('📤 REQUEST[${options.method}] => ${options.uri}');
      if (options.data != null) {
        debugPrint('   Body: ${_truncateLog(options.data.toString())}');
      }
      if (options.queryParameters.isNotEmpty) {
        debugPrint('   Params: ${options.queryParameters}');
      }
    }
  }

  void _logResponse(Response response) {
    if (kDebugMode) {
      final emoji = response.statusCode! < 400 ? '📥' : '⚠️ ';
      debugPrint('$emoji RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}');
    }
  }

  void _logError(DioException error) {
    if (kDebugMode) {
      debugPrint('❌ ERROR[${error.response?.statusCode}] => ${error.requestOptions.uri}');
      debugPrint('   Message: ${error.message}');
      if (error.response?.data != null) {
        debugPrint('   Data: ${_truncateLog(error.response?.data.toString() ?? '')}');
      }
    }
  }

  /// Truncate long log messages for readability
  String _truncateLog(String log, {int maxLength = 500}) {
    if (log.length <= maxLength) return log;
    return '${log.substring(0, maxLength)}...';
  }

  /// Clear the Dio instance (useful for testing or reconfiguration)
  void clear() {
    _dio.close(force: true);
  }
}
