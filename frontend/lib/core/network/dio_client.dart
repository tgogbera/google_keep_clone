import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'interceptors/auth_interceptor.dart';
import '../storage/token_storage.dart';

/// Custom exception used across the app
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

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
    );

    _dio = Dio(options);

    // Add auth interceptor
    _dio.interceptors.add(AuthInterceptor(_tokenStorage));

    // Add logging interceptor for debug mode
    if (!kReleaseMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
        ),
      );
    }

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
  }

  static final ApiClient _instance = ApiClient._internal();
  static final TokenStorage _tokenStorage = TokenStorage();

  late final Dio _dio;

  /// Get the underlying Dio instance (for backward compatibility)
  Dio get dio => _dio;

  /// -------------------------
  /// HTTP METHODS
  /// -------------------------

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// -------------------------
  /// ERROR HANDLING
  /// -------------------------

  ApiException _handleError(DioException error) {
    if (error.response != null) {
      // Server responded with error status
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      String message;
      if (data is Map<String, dynamic>) {
        message =
            data['error'] as String? ??
            data['message'] as String? ??
            'Request failed with status $statusCode';
      } else if (data is String) {
        message = data;
      } else {
        message = 'Request failed with status $statusCode';
      }

      return ApiException(statusCode: statusCode, message: message);
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(message: 'Connection timeout. Please check your internet connection.');
    } else if (error.type == DioExceptionType.connectionError) {
      return ApiException(message: 'Connection error. Please check your internet connection.');
    } else {
      return ApiException(message: error.message ?? 'An unexpected error occurred');
    }
  }

  /// -------------------------
  /// LOGGING
  /// -------------------------

  void _logRequest(RequestOptions options) {
    if (kDebugMode) {
      debugPrint('REQUEST[${options.method}] => ${options.uri}');
      if (options.data != null) {
        debugPrint('Request Data: ${options.data}');
      }
    }
  }

  void _logResponse(Response response) {
    if (kDebugMode) {
      debugPrint('RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}');
    }
  }

  void _logError(DioException error) {
    if (kDebugMode) {
      debugPrint('ERROR[${error.response?.statusCode}] => ${error.requestOptions.uri}');
      debugPrint('Error Message: ${error.message}');
      if (error.response?.data != null) {
        debugPrint('Error Data: ${error.response?.data}');
      }
    }
  }

  /// Clear the Dio instance (useful for testing or reconfiguration)
  void clear() {
    _dio.close(force: true);
  }
}
