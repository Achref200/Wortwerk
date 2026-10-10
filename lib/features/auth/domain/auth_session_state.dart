import 'package:equatable/equatable.dart';

import '../../../core/error/app_failure.dart';
import 'auth_account.dart';

/// Who the app currently believes is signed in.
///
/// The session is the single owner of the active account: routers, feature
/// repositories and route keys all read it instead of asking Firebase
/// directly, so a sign-out or account switch is observed in one place.
sealed class AuthSessionState extends Equatable {
  const AuthSessionState();

  /// The active account, when there is one.
  AuthAccount? get account => switch (this) {
    AuthSessionActive(:final account) => account,
    _ => null,
  };

  /// True once the first auth snapshot has arrived. Until then the app must
  /// not redirect, because it does not yet know whether a session exists.
  bool get isResolved => this is! AuthSessionUnknown;

  bool get isSignedOut => this is AuthSessionSignedOut;

  /// A lifecycle operation (sign-out, verification, deletion) is in flight.
  bool get isPending => switch (this) {
    AuthSessionActive(:final pending) => pending,
    AuthSessionSignedOut(:final pending) => pending,
    _ => false,
  };

  /// The most recent lifecycle failure, cleared once the learner dismisses it.
  AppFailure? get failure => switch (this) {
    AuthSessionActive(:final failure) => failure,
    AuthSessionSignedOut(:final failure) => failure,
    _ => null,
  };
}

/// No auth snapshot has arrived yet (startup, or a slow provider).
final class AuthSessionUnknown extends AuthSessionState {
  const AuthSessionUnknown();

  @override
  List<Object?> get props => const <Object?>['unknown'];
}

/// An account is signed in. Guests are active accounts too.
final class AuthSessionActive extends AuthSessionState {
  const AuthSessionActive({
    required this.account,
    this.pending = false,
    this.failure,
  });

  @override
  final AuthAccount account;
  final bool pending;
  @override
  final AppFailure? failure;

  /// A stable identity for the account so listeners can tell an account switch
  /// from a same-account profile refresh such as a new verification flag.
  String get identity =>
      '${account.uid}:${account.isAnonymous}:${account.emailVerified}';

  AuthSessionActive copyWith({
    AuthAccount? account,
    bool? pending,
    AppFailure? failure,
    bool clearFailure = false,
  }) => AuthSessionActive(
    account: account ?? this.account,
    pending: pending ?? this.pending,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [account.uid, account.isAnonymous, account.email, account.emailVerified, pending, failure];
}

/// No account is signed in.
final class AuthSessionSignedOut extends AuthSessionState {
  const AuthSessionSignedOut({this.pending = false, this.failure});

  final bool pending;
  @override
  final AppFailure? failure;

  AuthSessionSignedOut copyWith({
    bool? pending,
    AppFailure? failure,
    bool clearFailure = false,
  }) => AuthSessionSignedOut(
    pending: pending ?? this.pending,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [pending, failure];
}
