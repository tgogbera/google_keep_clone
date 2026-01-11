import 'package:flutter/foundation.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/exceptions/api_exceptions.dart';
import '../models/auth_response.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Register a new user
  /// Throws [BadRequestException] if validation fails
  /// Throws [ConflictException] if email already exists
  /// Throws [ApiException] for other errors
  Future<AuthResponse> register(String email, String password) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      '/register',
      data: {'email': email, 'password': password},
    );

    return AuthResponse.fromJson(data);
  }

  /// Login with email and password
  /// Throws [UnauthorizedException] if credentials are invalid
  /// Throws [ApiException] for other errors
  Future<AuthResponse> login(String email, String password) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      '/login',
      data: {'email': email, 'password': password},
    );

    return AuthResponse.fromJson(data);
  }

  /// Get current authenticated user
  /// Throws [UnauthorizedException] if not authenticated
  /// Throws [ApiException] for other errors
  Future<User> getCurrentUser() async {
    final data = await _apiClient.get<Map<String, dynamic>>('/me');

    return User.fromJson(data);
  }

  /// Logout (notifies server to revoke tokens)
  /// Ignores network errors—server logout is best-effort
  Future<void> logout() async {
    try {
      await _apiClient.post('/logout');
    } catch (e) {
      // Best effort—server logout failures don't block local logout
      debugPrint('Logout request failed: $e');
    }
  }
}
