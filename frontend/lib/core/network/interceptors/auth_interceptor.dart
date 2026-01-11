import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../storage/token_storage.dart';
import '../../config/api_config.dart';

/// Interceptor that automatically adds authentication token to requests
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, {Dio? refreshDio})
    : _refreshDio = refreshDio ?? Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  final TokenStorage _tokenStorage;
  final Dio _refreshDio; // Dependency injection instead of creating inline
  final List<_RequestRetry> _pendingRequests = [];
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await _tokenStorage.getToken();

      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      options.headers['Content-Type'] = 'application/json';
      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'Failed to add auth headers: $e',
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final shouldRetry = statusCode == 401 && err.requestOptions.extra['retried'] != true;

    if (!shouldRetry) {
      handler.next(err);
      return;
    }

    try {
      if (_isRefreshing) {
        // Queue the request instead of dropping it
        _pendingRequests.add(_RequestRetry(requestOptions: err.requestOptions, handler: handler));
        return;
      }

      _isRefreshing = true;

      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _clearTokens();
        handler.next(err);
        return;
      }

      final response = await _refreshDio.post(
        '/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final newToken = response.data?['token'] as String?;
      if (newToken == null || newToken.isEmpty) {
        await _clearTokens();
        handler.next(err);
        return;
      }

      await _tokenStorage.saveToken(newToken);

      final newRefreshToken = response.data?['refresh_token'] as String?;
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _tokenStorage.saveRefreshToken(newRefreshToken);
      }

      // Retry original request
      await _retryRequest(err.requestOptions, newToken, handler);

      // Retry all pending requests
      for (final pending in _pendingRequests) {
        await _retryRequest(pending.requestOptions, newToken, pending.handler);
      }
      _pendingRequests.clear();
    } catch (e) {
      await _clearTokens();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _retryRequest(
    RequestOptions requestOptions,
    String token,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final opts = requestOptions;
      opts.headers['Authorization'] = 'Bearer $token';
      opts.extra['retried'] = true;

      final retryResponse = await _refreshDio.fetch(opts);
      handler.resolve(retryResponse);
    } catch (e) {
      handler.reject(
        DioException(requestOptions: requestOptions, error: e, type: DioExceptionType.unknown),
      );
    }
  }

  Future<void> _clearTokens() async {
    try {
      await Future.wait([_tokenStorage.deleteToken(), _tokenStorage.deleteRefreshToken()]);
    } catch (e) {
      // Log error but don't fail
      debugPrint('Error clearing tokens: $e');
    }
  }
}

/// Helper class to store pending request information
class _RequestRetry {
  final RequestOptions requestOptions;
  final ErrorInterceptorHandler handler;

  _RequestRetry({required this.requestOptions, required this.handler});
}
