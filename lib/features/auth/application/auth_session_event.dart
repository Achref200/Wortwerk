import 'package:equatable/equatable.dart';

import '../domain/auth_account.dart';

/// One-shot effects the session owner reports to the UI.
///
/// These are deliberately not state: a "verification mail is on its way"
/// confirmation must be shown once and must not be replayed when the route
/// rebuilds for an unrelated reason.
enum AuthSessionNotice { verificationSent }

/// Events accepted by [AuthSessionBloc].
sealed class AuthSessionEvent extends Equatable {
  const AuthSessionEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Starts observing the provider's session stream.
///
/// Kept as an explicit lifecycle event even though the bloc subscribes in its
/// constructor: callers still say what they mean, and tests can await it.
final class AuthSessionStarted extends AuthSessionEvent {
  const AuthSessionStarted();
}

/// Reports one snapshot from the provider's session stream.
///
/// A `null` account means signed out. Handlers for this event complete
/// immediately — a long-lived handler would keep the event queue busy and
/// deadlock [Bloc.close].
final class AuthSessionSnapshot extends AuthSessionEvent {
  const AuthSessionSnapshot(this.account);

  final AuthAccount? account;

  @override
  List<Object?> get props => <Object?>[account];
}

/// Re-reads the active account from the provider.
final class AuthSessionReloadRequested extends AuthSessionEvent {
  const AuthSessionReloadRequested();

  @override
  List<Object?> get props => const <Object?>['reload'];
}

/// Ends the session.
final class AuthSessionSignOutRequested extends AuthSessionEvent {
  const AuthSessionSignOutRequested();

  @override
  List<Object?> get props => const <Object?>['sign-out'];
}

/// Sends the provider's address-confirmation mail.
final class AuthSessionVerificationRequested extends AuthSessionEvent {
  const AuthSessionVerificationRequested();

  @override
  List<Object?> get props => const <Object?>['verify'];
}

/// Deletes the account. [password] is required for password accounts because
/// deletion needs a recent login.
final class AuthSessionDeletionRequested extends AuthSessionEvent {
  const AuthSessionDeletionRequested({this.password = ''});

  final String password;

  @override
  List<Object?> get props => ['delete'];
}

/// Clears the last lifecycle failure so the UI stops showing it.
final class AuthSessionFailureDismissed extends AuthSessionEvent {
  const AuthSessionFailureDismissed();

  @override
  List<Object?> get props => const <Object?>['dismiss'];
}
