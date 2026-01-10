import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../screens/login/login_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/home/home_screen.dart';
import 'auth_refresh_stream.dart';

class AppRouter {
  static String? _redirect(BuildContext context, GoRouterState state) {
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;
    final isLoginRoute = state.matchedLocation == '/login';
    final isRegisterRoute = state.matchedLocation == '/register';

    // If authenticated and trying to access login/register, redirect to home
    if (authState is AuthAuthenticated && (isLoginRoute || isRegisterRoute)) {
      return '/home';
    }

    // If not authenticated and trying to access protected routes, redirect to login
    if (authState is! AuthAuthenticated && !isLoginRoute && !isRegisterRoute) {
      return '/login';
    }

    return null; // No redirect needed
  }

  static GoRouter createRouter(BuildContext context) {
    final authRefreshStream = AuthRefreshStream(context);
    
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: authRefreshStream,
      redirect: _redirect,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );
  }
}
