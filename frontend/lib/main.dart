import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/presentation/cubit/auth/auth_cubit.dart';
import 'core/network/api_client.dart';
import 'core/observers/app_bloc_observer.dart';
import 'core/storage/token_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/note_repository.dart';
import 'presentation/cubit/note/note_cubit.dart';
import 'core/router/app_router.dart';

void main() {
  // Register global BLoC observer for debugging and logging
  Bloc.observer = AppBlocObserver();

  runZonedGuarded(() => runApp(const MyApp()), (error, stackTrace) {
    debugPrint('Error: $error');
    debugPrint('StackTrace: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize core services
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TokenStorage>(create: (_) => tokenStorage),
        RepositoryProvider<ApiClient>(create: (_) => apiClient),
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepository(apiClient: context.read<ApiClient>()),
        ),
        RepositoryProvider<NoteRepository>(
          create: (context) => NoteRepository(apiClient: context.read<ApiClient>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (context) => AuthCubit(
              authRepository: context.read<AuthRepository>(),
              tokenStorage: context.read<TokenStorage>(),
            )..checkAuthStatus(),
          ),
          BlocProvider<NoteCubit>(
            create: (context) => NoteCubit(noteRepository: context.read<NoteRepository>()),
          ),
        ],
        child: Builder(
          builder: (context) {
            return MaterialApp.router(
              title: 'Google Keep Clone',
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(useMaterial3: true),
              routerConfig: AppRouter.createRouter(context),
            );
          },
        ),
      ),
    );
  }
}
