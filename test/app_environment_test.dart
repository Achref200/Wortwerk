import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/app/environment.dart';

void main() {
  group('AppEnvironment emulator configuration', () {
    test('provides demo project options for supported mobile platforms', () {
      final environment = AppEnvironment.emulator();

      final android = environment.firebaseOptions(
        platform: TargetPlatform.android,
        isWeb: false,
      );
      final ios = environment.firebaseOptions(
        platform: TargetPlatform.iOS,
        isWeb: false,
      );

      expect(environment.firebaseProjectId, 'demo-wortwerk-dev');
      expect(android.appId, environment.androidAppId);
      expect(ios.appId, environment.iosAppId);
    });

    test('uses the web Firebase app id for web builds', () {
      final environment = AppEnvironment.emulator();

      expect(
        environment
            .firebaseOptions(platform: TargetPlatform.android, isWeb: true)
            .appId,
        environment.webAppId,
      );
    });

    test('rejects unsupported Firebase platforms', () {
      final environment = AppEnvironment.emulator();

      expect(
        () => environment.firebaseOptions(
          platform: TargetPlatform.windows,
          isWeb: false,
        ),
        throwsUnsupportedError,
      );
    });
  });
}
