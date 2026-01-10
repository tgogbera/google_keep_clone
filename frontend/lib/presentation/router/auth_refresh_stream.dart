import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';

/// A ChangeNotifier that listens to AuthBloc state changes
/// and notifies GoRouter to refresh its redirect logic
class AuthRefreshStream extends ChangeNotifier {
  AuthRefreshStream(BuildContext context) {
    _subscription = context.read<AuthBloc>().stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
