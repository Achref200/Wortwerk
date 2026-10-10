import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class AppBlocObserver extends BlocObserver {
  const AppBlocObserver({this.captureInCrashlytics = true});

  final bool captureInCrashlytics;

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      debugPrint(
        'bloc_transition ${bloc.runtimeType} '
        '${transition.currentState.runtimeType}->'
        '${transition.nextState.runtimeType}',
      );
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (kDebugMode) {
      debugPrint('bloc_error ${bloc.runtimeType} ${error.runtimeType}');
    }
    if (captureInCrashlytics &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          Exception('Bloc error: ${error.runtimeType}'),
          stackTrace,
          reason: 'bloc_error:${bloc.runtimeType}',
          fatal: false,
        ),
      );
    }
  }
}
