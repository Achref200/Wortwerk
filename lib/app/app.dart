import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/error/app_failure.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/locale_controller.dart';
import '../core/l10n/wortwerk_strings.dart';
import '../core/network/network_status_banner.dart';
import '../core/network/network_status_controller.dart';
import '../design_system/wortwerk_theme.dart';
import '../features/auth/application/auth_session_bloc.dart';
import '../features/notifications/application/push_notifications_controller.dart';
import 'environment.dart';

final class WortwerkApp extends StatelessWidget {
  const WortwerkApp({
    required this.environment,
    required this.router,
    this.networkStatus,
    this.localeController,
    this.pushNotifications,
    this.authSession,
    super.key,
  });

  final AppEnvironment environment;
  final GoRouter router;
  final NetworkStatusController? networkStatus;

  /// The app-wide owner of the signed-in account. Provided to the widget tree
  /// so any screen can read the session without touching Firebase auth.
  final AuthSessionBloc? authSession;

  /// When provided, learner-facing copy follows this controller's language and
  /// rebuilds when it changes. Widget tests that omit it render the German
  /// source catalog, matching the authored copy.
  final LocaleController? localeController;
  final PushNotificationsController? pushNotifications;

  @override
  Widget build(BuildContext context) {
    final controller = localeController;
    if (controller == null) return _buildApp(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildApp(context),
    );
  }

  Widget _buildApp(BuildContext context) {
    final language = localeController?.language ?? AppLanguage.fallback;
    final session = authSession;
    if (session != null) {
      return BlocProvider<AuthSessionBloc>.value(
        value: session,
        child: _buildMaterialApp(context, language),
      );
    }
    return _buildMaterialApp(context, language);
  }

  Widget _buildMaterialApp(BuildContext context, AppLanguage language) {
    return MaterialApp.router(
      title: 'Wortwerk',
      debugShowCheckedModeBanner: false,
      theme: WortwerkTheme.light,
      routerConfig: router,
      builder: (context, child) {
        final app = child ?? const SizedBox.shrink();
        final localized = WortwerkLocalizations(
          strings: WortwerkStrings(language),
          child: app,
        );
        final notificationAwareApp = pushNotifications == null
            ? localized
            : ScaffoldMessenger(
                child: _ForegroundNotificationListener(
                  controller: pushNotifications!,
                  router: router,
                  child: localized,
                ),
              );
        final networkAwareApp = networkStatus == null
            ? notificationAwareApp
            : NetworkStatusBanner(
                controller: networkStatus!,
                child: notificationAwareApp,
              );
        if (!environment.showsEmulatorBanner) {
          return networkAwareApp;
        }
        return Banner(
          message: 'EMULATOR',
          location: BannerLocation.topStart,
          child: networkAwareApp,
        );
      },
    );
  }
}

final class _ForegroundNotificationListener extends StatefulWidget {
  const _ForegroundNotificationListener({
    required this.controller,
    required this.router,
    required this.child,
  });

  final PushNotificationsController controller;
  final GoRouter router;
  final Widget child;

  @override
  State<_ForegroundNotificationListener> createState() =>
      _ForegroundNotificationListenerState();
}

final class _ForegroundNotificationListenerState
    extends State<_ForegroundNotificationListener> {
  StreamSubscription<PushNotice>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _ForegroundNotificationListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _listen();
  }

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = widget.controller.foregroundNotices.listen(_showNotice);
  }

  void _showNotice(PushNotice notice) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notice.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(notice.body),
          ],
        ),
        action: notice.deepLink == null
            ? null
            : SnackBarAction(
                label: WortwerkLocalizations.of(context)(WText.open),
                onPressed: () => widget.router.go(notice.deepLink!),
              ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({
    required this.failure,
    required this.onRetry,
    this.language = AppLanguage.fallback,
    super.key,
  });

  final AppFailure failure;
  final VoidCallback onRetry;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final strings = WortwerkStrings(language);
    return MaterialApp(
      title: 'Wortwerk',
      theme: WortwerkTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings(WText.bootstrapTitle)),
                  const SizedBox(height: 12),
                  Text(_bootstrapFailureMessage(strings)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onRetry,
                    child: Text(strings(WText.retry)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _bootstrapFailureMessage(WortwerkStrings strings) =>
      switch (failure.kind) {
        AppFailureKind.network => strings(WText.bootNetwork),
        AppFailureKind.timeout => strings(WText.bootTimeout),
        AppFailureKind.unauthenticated => strings(WText.bootUnauthenticated),
        AppFailureKind.permissionDenied => strings(WText.bootPermissionDenied),
        AppFailureKind.notFound => strings(WText.bootNotFound),
        AppFailureKind.rateLimited => strings(WText.bootRateLimited),
        AppFailureKind.serverError => strings(WText.bootServer),
        AppFailureKind.validation => strings(WText.bootValidation),
        AppFailureKind.conflict => strings(WText.bootConflict),
        AppFailureKind.contentMissing => strings(WText.bootContentMissing),
        AppFailureKind.unknown => strings(WText.bootUnknown),
      };
}
