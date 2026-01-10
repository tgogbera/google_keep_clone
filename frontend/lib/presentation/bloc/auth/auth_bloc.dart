import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/token_storage.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;

  AuthBloc({required AuthRepository authRepository, required TokenStorage tokenStorage})
    : _authRepository = authRepository,
      _tokenStorage = tokenStorage,
      super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final authResponse = await _authRepository.login(event.email, event.password);

      // Store token in secure storage
      await _tokenStorage.saveToken(authResponse.token);

      emit(AuthAuthenticated(user: authResponse.user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onRegisterRequested(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final authResponse = await _authRepository.register(event.email, event.password);

      // Store token in secure storage
      await _tokenStorage.saveToken(authResponse.token);

      emit(AuthAuthenticated(user: authResponse.user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _tokenStorage.deleteToken();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final token = await _tokenStorage.getToken();

      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }

      // Verify token by fetching current user
      // The Dio interceptor will automatically add the token to the request
      final user = await _authRepository.getCurrentUser();

      emit(AuthAuthenticated(user: user));
    } catch (e) {
      // Token is invalid or expired
      await _tokenStorage.deleteToken();
      emit(const AuthUnauthenticated());
    }
  }
}
