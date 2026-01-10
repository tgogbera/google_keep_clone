import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final FlutterSecureStorage _secureStorage;
  static const String _tokenKey = 'auth_token';

  AuthBloc({
    required AuthRepository authRepository,
    FlutterSecureStorage? secureStorage,
  })  : _authRepository = authRepository,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final authResponse = await _authRepository.login(
        event.email,
        event.password,
      );
      
      await _secureStorage.write(
        key: _tokenKey,
        value: authResponse.token,
      );

      emit(AuthAuthenticated(
        user: authResponse.user,
        token: authResponse.token,
      ));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final authResponse = await _authRepository.register(
        event.email,
        event.password,
      );
      
      await _secureStorage.write(
        key: _tokenKey,
        value: authResponse.token,
      );

      emit(AuthAuthenticated(
        user: authResponse.user,
        token: authResponse.token,
      ));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _secureStorage.delete(key: _tokenKey);
    emit(const AuthUnauthenticated());
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      
      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }

      // Verify token by fetching current user
      final user = await _authRepository.getCurrentUser(token);
      
      emit(AuthAuthenticated(
        user: user,
        token: token,
      ));
    } catch (e) {
      // Token is invalid or expired
      await _secureStorage.delete(key: _tokenKey);
      emit(const AuthUnauthenticated());
    }
  }
}
