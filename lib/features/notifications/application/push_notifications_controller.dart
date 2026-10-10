import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/notifications_repository.dart';

final class PushNotice {
  const PushNotice({required this.title, required this.body, this.deepLink});

  final String title;
  final String body;
  final String? deepLink;
}

enum PushNotificationProblem {
  unavailable,
  permissionDenied,
  tokenUnavailable,
  serverError,
}

abstract class PushNotificationsController extends ChangeNotifier {
  bool get enabled;

  bool get isWorking;

  PushNotificationProblem? get problem;

  Stream<PushNotice> get foregroundNotices;

  Future<void> initialize({required void Function(String path) onOpen});

  Future<bool> enable(String language);

  Future<void> disable();
}

final class FirebasePushNotificationsController
    extends PushNotificationsController {
  FirebasePushNotificationsController({
    required this._messaging,
    required this._repository,
    required this._authUidChanges,
    required this._language,
    required this.useEmulators,
    required this.webVapidKey,
  });

  final FirebaseMessaging _messaging;
  final NotificationsRepository _repository;
  final Stream<String?> _authUidChanges;
  final String Function() _language;
  final bool useEmulators;
  final String webVapidKey;
  final StreamController<PushNotice> _foreground =
      StreamController<PushNotice>.broadcast();
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  void Function(String path)? _onOpen;
  String? _lastToken;
  bool _enabled = false;
  bool _isWorking = false;
  PushNotificationProblem? _problem;

  @override
  bool get enabled => _enabled;

  @override
  bool get isWorking => _isWorking;

  @override
  PushNotificationProblem? get problem => _problem;

  @override
  Stream<PushNotice> get foregroundNotices => _foreground.stream;

  @override
  Future<void> initialize({required void Function(String path) onOpen}) async {
    _onOpen = onOpen;
    if (useEmulators || (kIsWeb && webVapidKey.isEmpty)) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (error) {
        debugPrint(
          'notification_presentation_setup_failed ${error.runtimeType}',
        );
      }
    }
    _openSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
      onError: (Object error) =>
          debugPrint('notification_open_stream_failed ${error.runtimeType}'),
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error) => debugPrint(
        'notification_foreground_stream_failed ${error.runtimeType}',
      ),
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) {
        if (_enabled) unawaited(_registerToken(token));
      },
      onError: (Object error) =>
          debugPrint('notification_token_refresh_failed ${error.runtimeType}'),
    );
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _handleOpenedMessage(initialMessage);
    } catch (error) {
      final code = error is PlatformException ? error.code : error.runtimeType;
      debugPrint('notification_initial_message_failed $code');
    }
    _authSubscription = _authUidChanges.distinct().listen(
      (uid) {
        _lastToken = null;
        if (uid == null) {
          _enabled = false;
          notifyListeners();
        } else {
          unawaited(_restoreRegistration());
        }
      },
      onError: (Object error) =>
          debugPrint('notification_auth_stream_failed ${error.runtimeType}'),
    );
  }

  @override
  Future<bool> enable(String language) async {
    if (useEmulators || (kIsWeb && webVapidKey.isEmpty)) {
      _setProblem(PushNotificationProblem.unavailable);
      return false;
    }
    _setWorking(true);
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!_isAuthorized(settings.authorizationStatus)) {
        _enabled = false;
        _problem = PushNotificationProblem.permissionDenied;
        return false;
      }
      final token = await _getToken();
      if (token == null) {
        _enabled = false;
        _problem = PushNotificationProblem.tokenUnavailable;
        return false;
      }
      await _repository.registerDevice(
        token: token,
        platform: _platformName,
        language: language,
      );
      _lastToken = token;
      _enabled = true;
      _problem = null;
      return true;
    } catch (error) {
      _enabled = false;
      _problem = PushNotificationProblem.serverError;
      debugPrint('notification_enable_failed ${error.runtimeType}');
      return false;
    } finally {
      _setWorking(false);
    }
  }

  @override
  Future<void> disable() async {
    _setWorking(true);
    try {
      await _repository.disablePush();
      _enabled = false;
      _lastToken = null;
      _problem = null;
    } catch (error) {
      _problem = PushNotificationProblem.serverError;
      debugPrint('notification_disable_failed ${error.runtimeType}');
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _restoreRegistration() async {
    try {
      _enabled = await _repository.pushEnabled();
      if (!_enabled) {
        notifyListeners();
        return;
      }
      final settings = await _messaging.getNotificationSettings();
      if (!_isAuthorized(settings.authorizationStatus)) {
        _enabled = false;
        notifyListeners();
        return;
      }
      final token = await _getToken();
      if (token != null) await _registerToken(token);
      notifyListeners();
    } catch (error) {
      debugPrint('notification_restore_failed ${error.runtimeType}');
    }
  }

  Future<String?> _getToken() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      String? apnsToken;
      for (var attempt = 0; attempt < 10 && apnsToken == null; attempt++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
      if (apnsToken == null) return null;
    }
    return _messaging.getToken(vapidKey: kIsWeb ? webVapidKey : null);
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastToken) return;
    await _repository.registerDevice(
      token: token,
      platform: _platformName,
      language: _language(),
    );
    _lastToken = token;
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final path = _safeInternalPath(message.data['deepLink']);
    if (path != null) _onOpen?.call(path);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    if (title == null || body == null) return;
    _foreground.add(
      PushNotice(
        title: title,
        body: body,
        deepLink: _safeInternalPath(message.data['deepLink']),
      ),
    );
  }

  String? _safeInternalPath(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        !uri.path.startsWith('/') ||
        uri.path.startsWith('//')) {
      return null;
    }
    return uri.toString();
  }

  bool _isAuthorized(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  String get _platformName => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ when kIsWeb => 'web',
    _ => 'web',
  };

  void _setWorking(bool value) {
    _isWorking = value;
    notifyListeners();
  }

  void _setProblem(PushNotificationProblem problem) {
    _problem = problem;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    unawaited(_openSubscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_foreground.close());
    super.dispose();
  }
}
