import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum AppFlavor {
  dev,
  staging,
  production;

  static AppFlavor parse(String value) => switch (value) {
    'dev' => AppFlavor.dev,
    'staging' => AppFlavor.staging,
    'production' => AppFlavor.production,
    _ => throw ArgumentError.value(value, 'APP_FLAVOR', 'Unknown flavor'),
  };
}

final class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.useEmulators,
    required this.firebaseProjectId,
    required this.firebaseApiKey,
    required this.firebaseSenderId,
    required this.androidAppId,
    required this.iosAppId,
    required this.webAppId,
    required this.emulatorHost,
    this.storageBucket,
    this.webVapidKey = '',
  });

  factory AppEnvironment.fromEnvironment() {
    const flavorValue = String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'dev',
    );
    final flavor = AppFlavor.parse(flavorValue);
    const emulatorValue = String.fromEnvironment('USE_FIREBASE_EMULATORS');
    final useEmulators = emulatorValue.isEmpty
        ? flavor == AppFlavor.dev
        : switch (emulatorValue) {
            'true' => true,
            'false' => false,
            _ => throw ArgumentError.value(
              emulatorValue,
              'USE_FIREBASE_EMULATORS',
              'Expected "true" or "false"',
            ),
          };

    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
    const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

    if (!useEmulators) {
      final missing = <String>[
        if (projectId.isEmpty) 'FIREBASE_PROJECT_ID',
        if (apiKey.isEmpty) 'FIREBASE_API_KEY',
        if (senderId.isEmpty) 'FIREBASE_SENDER_ID',
        if (androidAppId.isEmpty) 'FIREBASE_ANDROID_APP_ID',
        if (iosAppId.isEmpty) 'FIREBASE_IOS_APP_ID',
        if (webAppId.isEmpty) 'FIREBASE_WEB_APP_ID',
        if (storageBucket.isEmpty) 'FIREBASE_STORAGE_BUCKET',
      ];
      if (missing.isNotEmpty) {
        throw StateError(
          'Cloud Firebase requires these build defines: ${missing.join(', ')}',
        );
      }
    }

    final effectiveProjectId = projectId.isEmpty
        ? 'demo-wortwerk-${flavor.name}'
        : projectId;

    return AppEnvironment(
      flavor: flavor,
      useEmulators: useEmulators,
      firebaseProjectId: effectiveProjectId,
      firebaseApiKey: apiKey.isEmpty ? 'demo-api-key' : apiKey,
      firebaseSenderId: senderId.isEmpty ? '1234567890' : senderId,
      androidAppId: androidAppId.isEmpty
          ? '1:1234567890:android:wortwerk-emulator'
          : androidAppId,
      iosAppId: iosAppId.isEmpty
          ? '1:1234567890:ios:wortwerk-emulator'
          : iosAppId,
      webAppId: webAppId.isEmpty
          ? '1:1234567890:web:wortwerk-emulator'
          : webAppId,
      emulatorHost: emulatorHost.isEmpty
          ? (defaultTargetPlatform == TargetPlatform.android
                ? '10.0.2.2'
                : '127.0.0.1')
          : emulatorHost,
      storageBucket: storageBucket.isEmpty
          ? '$effectiveProjectId.firebasestorage.app'
          : storageBucket,
      webVapidKey: webVapidKey,
    );
  }

  final AppFlavor flavor;
  final bool useEmulators;
  final String firebaseProjectId;
  final String firebaseApiKey;
  final String firebaseSenderId;
  final String androidAppId;
  final String iosAppId;
  final String webAppId;
  final String emulatorHost;
  final String? storageBucket;
  final String webVapidKey;

  bool get showsEmulatorBanner => useEmulators;
  String get functionsRegion => 'europe-west1';

  FirebaseOptions firebaseOptions({
    required TargetPlatform platform,
    required bool isWeb,
  }) {
    final appId = isWeb
        ? webAppId
        : switch (platform) {
            TargetPlatform.android => androidAppId,
            TargetPlatform.iOS || TargetPlatform.macOS => iosAppId,
            _ => throw UnsupportedError(
              'Firebase is configured for Android, iOS, macOS and web only.',
            ),
          };

    return FirebaseOptions(
      apiKey: firebaseApiKey,
      appId: appId,
      messagingSenderId: firebaseSenderId,
      projectId: firebaseProjectId,
      storageBucket: storageBucket,
    );
  }

  static AppEnvironment emulator({
    String host = '127.0.0.1',
    AppFlavor flavor = AppFlavor.dev,
  }) {
    return AppEnvironment(
      flavor: flavor,
      useEmulators: true,
      firebaseProjectId: 'demo-wortwerk-${flavor.name}',
      firebaseApiKey: 'demo-api-key',
      firebaseSenderId: '1234567890',
      androidAppId: '1:1234567890:android:wortwerk-emulator',
      iosAppId: '1:1234567890:ios:wortwerk-emulator',
      webAppId: '1:1234567890:web:wortwerk-emulator',
      emulatorHost: host,
    );
  }
}
