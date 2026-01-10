import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Global BLoC observer for logging and debugging
/// Observes all BLoC events, state changes, and errors
///
/// This observer monitors:
/// - BLoC/Cubit creation and closure
/// - Events added to Bloc instances
/// - State changes in Bloc and Cubit instances
/// - Transitions in Bloc instances (event -> state)
/// - Errors that occur during event processing
class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (kDebugMode) {
      debugPrint('🟢 onCreate -- ${bloc.runtimeType}');
    }
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (kDebugMode) {
      debugPrint('📥 onEvent -- ${bloc.runtimeType}, $event');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      debugPrint('🔄 onChange -- ${bloc.runtimeType}');
      debugPrint('   ${change.currentState.runtimeType} -> ${change.nextState.runtimeType}');

      // Only print full state details if states are different
      if (change.currentState != change.nextState) {
        debugPrint('   Previous: ${change.currentState}');
        debugPrint('   Current: ${change.nextState}');
      }
    }
  }

  @override
  void onTransition(Bloc<dynamic, dynamic> bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      debugPrint('➡️  onTransition -- ${bloc.runtimeType}');
      debugPrint('   Event: ${transition.event.runtimeType}');
      debugPrint(
        '   ${transition.currentState.runtimeType} -> ${transition.nextState.runtimeType}',
      );
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('❌ onError -- ${bloc.runtimeType}');
      debugPrint('   Error: $error');
      debugPrint('   StackTrace: $stackTrace');
    }
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (kDebugMode) {
      debugPrint('🔴 onClose -- ${bloc.runtimeType}');
    }
  }
}
