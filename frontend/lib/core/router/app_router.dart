import 'package:flutter/material.dart';
import 'package:frontend/presentation/cubit/auth/auth_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/register/register_screen.dart';
import '../../presentation/screens/home/home_screen.dart';

class AppRouter {
  static String? _redirect(BuildContext context, GoRouterState state) {
    final authBloc = context.read<AuthCubit>();
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
    return GoRouter(
      initialLocation: '/login',
      redirect: _redirect,
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      ],
    );
  }
}
