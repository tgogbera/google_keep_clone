import 'package:dio/dio.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../../core/storage/token_storage.dart';
import '../../core/config/api_config.dart';

class AuthRepository {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  AuthRepository({required Dio dio, TokenStorage? tokenStorage})
    : _dio = dio,
      _tokenStorage = tokenStorage ?? TokenStorage();

  Future<AuthResponse> register(String email, String password) async {
    try {
      final response = await _dio.post('/register', data: {'email': email, 'password': password});

      final auth = AuthResponse.fromJson(response.data);

      // Save refresh token if backend returned it (fallback for non-cookie clients)
      if (auth.refreshToken != null) {
        await _tokenStorage.saveRefreshToken(auth.refreshToken!);
      }

      return auth;
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data['error'] as String? ?? 'Registration failed';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _dio.post('/login', data: {'email': email, 'password': password});

      final auth = AuthResponse.fromJson(response.data);

      // Save refresh token if backend returned it (fallback for non-cookie clients)
      if (auth.refreshToken != null) {
        await _tokenStorage.saveRefreshToken(auth.refreshToken!);
      }

      return auth;
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data['error'] as String? ?? 'Login failed';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }

  /// Exchanges a stored refresh token (or cookie) for a new access token and
  /// updates stored tokens accordingly.
  Future<void> refresh() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();

      // Use a fresh Dio instance to avoid interceptor recursion
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

      final data = refreshToken != null ? {'refresh_token': refreshToken} : {};

      final response = await refreshDio.post('/refresh', data: data);

      final newToken = response.data['token'] as String?;
      if (newToken != null) {
        await _tokenStorage.saveToken(newToken);
      }

      final newRefresh = response.data['refresh_token'] as String?;
      if (newRefresh != null) {
        await _tokenStorage.saveRefreshToken(newRefresh);
      }
    } on DioException catch (_) {
      // Bubble up to caller — they can handle clearing local state
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      // Try to inform server to revoke refresh token
      await _dio.post('/logout');
    } catch (_) {
      // ignore network errors here
    } finally {
      // Clear local tokens
      await _tokenStorage.deleteToken();
      await _tokenStorage.deleteRefreshToken();
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/me');

      // The /me endpoint returns {user_id, email}, so we'll create a minimal User
      return User(
        id: response.data['user_id'] as int,
        email: response.data['email'] as String,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data['error'] as String? ?? 'Failed to get user';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }
}
