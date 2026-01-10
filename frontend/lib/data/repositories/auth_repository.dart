import 'package:dio/dio.dart';
import '../models/auth_response.dart';
import '../models/user.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository({required Dio dio}) : _dio = dio;

  Future<AuthResponse> register(String email, String password) async {
    try {
      final response = await _dio.post('/register', data: {'email': email, 'password': password});

      return AuthResponse.fromJson(response.data);
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

      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage = e.response?.data['error'] as String? ?? 'Login failed';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
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
