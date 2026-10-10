import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/error/app_failure.dart';

void main() {
  group('AppFailure', () {
    test('maps Firebase errors to stable, non-sensitive failure details', () {
      final failure = AppFailure.fromFirebaseException(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      expect(failure.kind, AppFailureKind.network);
      expect(failure.retryable, isTrue);
      expect(failure.analyticsCode, 'app_failure_network');
      expect(failure.message, contains('connection'));
    });

    test('does not include backend exception text in user copy', () {
      final failure = AppFailure.fromFirebaseException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'private document path',
        ),
      );

      expect(failure.kind, AppFailureKind.permissionDenied);
      expect(failure.retryable, isFalse);
      expect(failure.message, isNot(contains('private document path')));
    });

    test('maps callable network and content failures consistently', () {
      expect(
        AppFailure.fromException(
          FirebaseFunctionsException(code: 'unavailable', message: 'offline'),
        ).kind,
        AppFailureKind.network,
      );
      expect(
        AppFailure.fromException(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'content unavailable',
          ),
        ).kind,
        AppFailureKind.contentMissing,
      );
    });
  });
}
