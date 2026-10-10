import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../app/environment.dart';

abstract final class FirebaseBootstrap {
  static Future<FirebaseApp> initialize(AppEnvironment environment) async {
    final app = await Firebase.initializeApp(
      options: environment.firebaseOptions(
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
    );

    if (environment.useEmulators) {
      final host = environment.emulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instanceFor(region: environment.functionsRegion)
          .useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    }

    if (!environment.useEmulators) {
      await FirebaseAnalytics.instanceFor(app: app)
          .setAnalyticsCollectionEnabled(true);
    }
    if (!environment.useEmulators &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !environment.useEmulators,
      );
    }

    return app;
  }
}
