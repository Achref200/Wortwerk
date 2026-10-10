import '../../../core/error/app_failure.dart';

/// App-safe snapshot of the signed-in Firebase account.
///
/// The domain layer intentionally exposes values rather than Firebase SDK
/// objects so callers can depend on auth without depending on Firebase.
final class AuthAccount {
  const AuthAccount({
    required this.uid,
    required this.isAnonymous,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.providerIds = const <String>[],
  });

  final String uid;
  final bool isAnonymous;
  final String? email;
  final String? displayName;

  /// True once the learner confirmed the address behind an email/password or
  /// email-link credential. Always false for guest and provider-only
  /// accounts, which have no address to confirm.
  final bool emailVerified;

  final List<String> providerIds;

  /// True when the account can be opened with an email address and password,
  /// which is the only case where [AuthRepository.deleteAccount] can
  /// re-authenticate without a fresh provider round trip.
  bool get hasPasswordProvider => providerIds.contains('password');

  /// The address used to re-authenticate and to send verification mail.
  String? get contactEmail => email;
}

/// Firebase-independent description of the URL Firebase should use for
/// email-link actions. The app must provide a URL configured for its project;
/// Wortwerk does not guess or invent a production domain.
final class EmailLinkSettings {
  const EmailLinkSettings({
    required this.continueUrl,
    this.handleCodeInApp = true,
  });

  final String continueUrl;
  final bool handleCodeInApp;
}

/// An auth failure that keeps provider details for diagnostics while exposing
/// only stable, app-owned copy to learners.
final class AuthFailure implements Exception {
  const AuthFailure({required this.code, required this.message});

  final String code;
  final String message;

  /// Maps the provider code onto the app's shared failure vocabulary so the
  /// presentation layer can pick retry affordances without re-parsing strings.
  AppFailureKind get kind => switch (code) {
    'network-request-failed' ||
    'network-error' ||
    'too-many-requests' => AppFailureKind.network,
    'timeout' => AppFailureKind.timeout,
    'user-disabled' ||
    'user-not-found' ||
    'invalid-credential' ||
    'wrong-password' => AppFailureKind.unauthenticated,
    'requires-recent-login' || 'user-mismatch' => AppFailureKind.permissionDenied,
    'invalid-email' || 'weak-password' || 'missing-password' =>
        AppFailureKind.validation,
    'email-already-in-use' ||
    'credential-already-in-use' ||
    'account-exists-with-different-credential' => AppFailureKind.conflict,
    _ => AppFailureKind.unknown,
  };

  /// The shared failure value for callers that speak `AppFailure`.
  AppFailure get failure => AppFailure(kind);

  String get userMessage {
    return switch (code) {
      'credential-already-in-use' ||
      'account-exists-with-different-credential' =>
        'Diese Anmeldemethode geh\u00f6rt zu einem anderen Konto. Dein bisheriger '
            'Lernfortschritt bleibt mit deiner Gastsitzung verbunden.',
      'email-link-not-configured' =>
        'Die E-Mail-Anmeldung ist noch nicht verf\u00fcgbar. Du kannst Google oder '
            'Apple verwenden oder als Gast weiterlernen.',
      'network-request-failed' || 'network-error' || 'timeout' =>
        'Keine Verbindung. Pr\u00fcfe dein Internet und versuche es erneut.',
      'invalid-email' =>
        'Pr\u00fcfe deine E-Mail-Adresse und versuche es erneut.',
      'weak-password' =>
        'W\u00e4hle ein Passwort mit mindestens sechs Zeichen.',
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'E-Mail-Adresse oder Passwort stimmen nicht. Bitte pr\u00fcfe deine Eingabe.',
      'email-already-in-use' => 'F\u00fcr diese E-Mail gibt es bereits ein Konto. Melde dich an, um es zu \u00f6ffnen.',
      'invalid-email-link' || 'expired-action-code' || 'invalid-action-code' =>
        'Dieser Anmeldelink ist ung\u00fcltig oder abgelaufen. Bitte fordere einen '
            'neuen Link an.',
      'requires-recent-login' =>
        'Bitte melde dich erneut an, um dein Konto zu l\u00f6schen. Aus '
            'Sicherheitsgr\u00fcnden braucht diese Aktion eine frische Anmeldung.',
      'missing-password' =>
        'Gib dein Passwort ein, um diese Aktion zu best\u00e4tigen.',
      'too-many-requests' =>
        'Zu viele Versuche. Bitte warte einen Moment und versuche es erneut.',
      'user-disabled' =>
        'Dieses Konto wurde deaktiviert. Bitte wende dich an den Support.',
      'user-mismatch' =>
        'Die Angaben geh\u00f6ren zu einem anderen Konto. Bitte pr\u00fcfe sie.',
      'operation-not-allowed' || 'provider-error' =>
        'Diese Anmeldemethode ist gerade nicht verf\u00fcgbar. Bitte versuche eine '
            'andere Methode.',
      'popup-closed-by-user' || 'canceled' => 'Die Anmeldung wurde abgebrochen. Du kannst es jederzeit erneut versuchen.',
      _ => 'Die Anmeldung hat gerade nicht geklappt. Bitte versuche es erneut.',
    };
  }

  @override
  String toString() => message;
}
