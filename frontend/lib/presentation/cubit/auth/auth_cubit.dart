import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/exceptions/api_exceptions.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/data/models/user.dart';
import 'package:frontend/data/repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;

  AuthCubit({required AuthRepository authRepository, required TokenStorage tokenStorage})
    : _authRepository = authRepository,
      _tokenStorage = tokenStorage,
      super(const AuthInitial());

  /// Check if user is already authenticated on app startup
  Future<void> checkAuthStatus() async {
    emit(const AuthLoading());
    try {
      final token = await _tokenStorage.getToken();

      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }

      final user = await _authRepository.getCurrentUser();
      emit(AuthAuthenticated(user: user));
    } on UnauthorizedException catch (_) {
      await _clearAuthData();
      emit(const AuthUnauthenticated());
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: _formatErrorMessage(e)));
    }
  }

  /// Handle login
  Future<void> login(String email, String password) async {
    emit(const AuthLoading());
    try {
      final authResponse = await _authRepository.login(email, password);
      await _saveAuthTokens(authResponse);
      emit(AuthAuthenticated(user: authResponse.user));
    } on UnauthorizedException {
      emit(const AuthError(message: 'Invalid email or password'));
    } on RequestTimeoutException {
      emit(const AuthError(message: 'Network timeout. Please check your connection.'));
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: _formatErrorMessage(e)));
    }
  }

  /// Handle registration
  Future<void> register(String email, String password) async {
    emit(const AuthLoading());
    try {
      final authResponse = await _authRepository.register(email, password);
      await _saveAuthTokens(authResponse);
      emit(AuthAuthenticated(user: authResponse.user));
    } on ConflictException {
      emit(const AuthError(message: 'Email already registered'));
    } on BadRequestException {
      emit(const AuthError(message: 'Invalid email or password format'));
    } on RequestTimeoutException {
      emit(const AuthError(message: 'Network timeout. Please check your connection.'));
    } on ApiException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: _formatErrorMessage(e)));
    }
  }

  /// Handle logout
  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (e) {
      _logError('Server logout failed: $e');
    } finally {
      await _clearAuthData();
      emit(const AuthUnauthenticated());
    }
  }

  /// Save tokens from auth response
  Future<void> _saveAuthTokens(dynamic authResponse) async {
    await _tokenStorage.saveToken(authResponse.token);
    if (authResponse.refreshToken != null) {
      await _tokenStorage.saveRefreshToken(authResponse.refreshToken);
    }
  }

  /// Clear all auth data on logout or auth failure
  Future<void> _clearAuthData() async {
    await Future.wait([_tokenStorage.deleteToken(), _tokenStorage.deleteRefreshToken()]);
  }

  /// Format error messages for display
  String _formatErrorMessage(dynamic error) {
    if (error is ApiException) return error.message;
    if (error is Exception) {
      final message = error.toString();
      if (message.startsWith('Exception: ')) {
        return message.substring(10);
      }
      return message;
    }
    return 'An unexpected error occurred';
  }

  void _logError(String message) {
    debugPrint('❌ AuthCubit: $message');
  }
}
