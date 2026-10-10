import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'app/dependencies.dart';
import 'app/environment.dart';
import 'core/error/app_failure.dart';
import 'core/l10n/locale_controller.dart';
import 'core/network/network_status_controller.dart';
import 'core/observers/app_bloc_observer.dart';
import 'features/auth/application/auth_session_bloc.dart';
import 'features/auth/domain/auth_account.dart';
import 'features/notifications/application/push_notifications_controller.dart';
import 'firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.fromEnvironment();
  Bloc.observer = AppBlocObserver(
    captureInCrashlytics: !environment.useEmulators,
  );

  try {
    final firebaseApp = await FirebaseBootstrap.initialize(environment);
    await configureDependencies(
      environment: environment,
      firebaseApp: firebaseApp,
    );
    runApp(
      WortwerkApp(
        environment: environment,
        router: GetIt.instance<GoRouter>(),
        networkStatus: GetIt.instance<NetworkStatusController>(),
        localeController: GetIt.instance<LocaleController>(),
        pushNotifications: GetIt.instance<PushNotificationsController>(),
        authSession: GetIt.instance<AuthSessionBloc>(),
      ),
    );
  } on FirebaseException catch (error) {
    debugPrint('firebase_bootstrap_error ${error.code}');
    runApp(
      BootstrapFailureApp(
        failure: AppFailure.fromFirebaseException(error),
        onRetry: main,
      ),
    );
  } on AuthFailure catch (error) {
    debugPrint('auth_bootstrap_error ${error.code}');
    runApp(
      BootstrapFailureApp(
        failure: AppFailure.fromFirebaseException(
          FirebaseException(plugin: 'firebase_auth', code: error.code),
        ),
        onRetry: main,
      ),
    );
  }
}
