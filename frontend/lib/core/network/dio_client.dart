import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../interceptors/auth_interceptor.dart';
import '../storage/token_storage.dart';

/// Factory for creating Dio instances with authentication interceptor
class DioClient {
  final TokenStorage _tokenStorage;
  Dio? _dio;

  DioClient(this._tokenStorage);

  /// Get or create Dio instance with auth interceptor
  Dio get dio {
    _dio ??= Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    )..interceptors.add(AuthInterceptor(_tokenStorage));

    return _dio!;
  }

  /// Clear the Dio instance (useful for testing or reconfiguration)
  void clear() {
    _dio = null;
  }
}
