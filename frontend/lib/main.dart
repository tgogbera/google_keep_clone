import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/dio_client.dart';
import 'core/storage/token_storage.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/note_repository.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/cubit/note/note_cubit.dart';
import 'presentation/router/app_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize core services
    final tokenStorage = TokenStorage();
    final dioClient = DioClient(tokenStorage);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TokenStorage>(create: (_) => tokenStorage),
        RepositoryProvider<DioClient>(create: (_) => dioClient),
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepository(dio: context.read<DioClient>().dio),
        ),
        RepositoryProvider<NoteRepository>(
          create: (context) => NoteRepository(dio: context.read<DioClient>().dio),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
              tokenStorage: context.read<TokenStorage>(),
            )..add(const AuthCheckRequested()),
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
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
              ),
              routerConfig: AppRouter.createRouter(context),
            );
          },
        ),
      ),
    );
  }
}
