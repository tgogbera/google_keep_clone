import 'package:dio/dio.dart';
import '../../storage/token_storage.dart';

/// Interceptor that automatically adds authentication token to requests
class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;

  AuthInterceptor(this._tokenStorage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get token from storage
    final token = await _tokenStorage.getToken();

    // Add Authorization header if token exists
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Ensure Content-Type is set
    options.headers['Content-Type'] = 'application/json';

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 Unauthorized - token might be invalid/expired
    if (err.response?.statusCode == 401) {
      // Token will be cleared by auth bloc when it detects the error
      // This interceptor just passes through the error
    }
    handler.next(err);
  }
}
