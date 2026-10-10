import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

enum AppFailureKind {
  network,
  timeout,
  unauthenticated,
  permissionDenied,
  notFound,
  rateLimited,
  serverError,
  validation,
  conflict,
  contentMissing,
  unknown,
}

final class AppFailure implements Exception {
  const AppFailure(this.kind);

  final AppFailureKind kind;

  bool get retryable => switch (kind) {
    AppFailureKind.network ||
    AppFailureKind.timeout ||
    AppFailureKind.serverError => true,
    _ => false,
  };

  String get message => switch (kind) {
    AppFailureKind.network => 'Check your connection and try again.',
    AppFailureKind.timeout => 'That took too long. Try again.',
    AppFailureKind.unauthenticated => 'Sign in to continue.',
    AppFailureKind.permissionDenied => 'You do not have access to that.',
    AppFailureKind.notFound => 'We could not find that.',
    AppFailureKind.rateLimited => 'Please wait a moment before trying again.',
    AppFailureKind.serverError => 'Something went wrong. Try again.',
    AppFailureKind.validation => 'Check the information and try again.',
    AppFailureKind.conflict => 'That change conflicts with newer data.',
    AppFailureKind.contentMissing => 'This learning content is unavailable.',
    AppFailureKind.unknown => 'Something unexpected happened.',
  };

  String get analyticsCode => 'app_failure_${kind.name}';

  static AppFailure fromFirebaseException(FirebaseException error) {
    return AppFailure(switch (error.code) {
      'network-request-failed' || 'unavailable' => AppFailureKind.network,
      'deadline-exceeded' => AppFailureKind.timeout,
      'unauthenticated' ||
      'user-not-found' ||
      'invalid-user-token' => AppFailureKind.unauthenticated,
      'permission-denied' => AppFailureKind.permissionDenied,
      'not-found' => AppFailureKind.notFound,
      'resource-exhausted' || 'too-many-requests' => AppFailureKind.rateLimited,
      'internal' || 'unknown' => AppFailureKind.serverError,
      'invalid-argument' => AppFailureKind.validation,
      'already-exists' || 'aborted' => AppFailureKind.conflict,
      'content-missing' => AppFailureKind.contentMissing,
      _ => AppFailureKind.unknown,
    });
  }

  static AppFailure fromException(Object error) {
    if (error is FirebaseFunctionsException) {
      return AppFailure(switch (error.code) {
        'unavailable' || 'network-request-failed' => AppFailureKind.network,
        'deadline-exceeded' => AppFailureKind.timeout,
        'unauthenticated' => AppFailureKind.unauthenticated,
        'permission-denied' => AppFailureKind.permissionDenied,
        'not-found' => AppFailureKind.notFound,
        'resource-exhausted' => AppFailureKind.rateLimited,
        'invalid-argument' => AppFailureKind.validation,
        'already-exists' || 'aborted' => AppFailureKind.conflict,
        'failed-precondition' => AppFailureKind.contentMissing,
        'internal' => AppFailureKind.serverError,
        _ => AppFailureKind.unknown,
      });
    }
    if (error is FirebaseException) {
      return fromFirebaseException(error);
    }
    if (error is TimeoutException) {
      return const AppFailure(AppFailureKind.timeout);
    }
    if (error is SocketException) {
      return const AppFailure(AppFailureKind.network);
    }
    return const AppFailure(AppFailureKind.unknown);
  }

  @override
  String toString() => message;
}
