import 'auth_account.dart';

/// Auth operations needed by the app, independent of a particular SDK.
abstract interface class AuthRepository {
  String? get currentUserId;

  Stream<AuthAccount?> get authStateChanges;

  /// Returns the current account, creating an anonymous one only when needed.
  Future<AuthAccount> ensureGuestSession();

  /// Links a provider to the current account, creating a guest first if needed.
  Future<AuthAccount> linkGoogle();
  Future<AuthAccount> linkApple();

  /// Creates an email/password account, linking a guest account when possible.
  Future<AuthAccount> createEmailPasswordAccount({
    required String email,
    required String password,
  });

  /// Signs into an existing email/password account.
  Future<AuthAccount> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Sends a Firebase password reset email.
  Future<void> sendPasswordResetEmail({required String email});

  /// Ends the current session. The app is guest-first, so the next bootstrap
  /// starts a fresh guest session rather than leaving the learner stuck on a
  /// dead route.
  Future<void> signOut();

  /// Re-reads the provider's copy of the account, refreshing fields only the
  /// provider can change such as `emailVerified` after the learner follows the
  /// verification link.
  Future<AuthAccount> reloadAccount();

  /// Sends a provider verification email when the account has an address and
  /// has not confirmed it yet. No-op for guests and provider accounts.
  Future<void> sendEmailVerification();

  /// Deletes the account and its provider-side identity.
  ///
  /// Destructive actions must have a recent login, so a password account is
  /// re-authenticated with [password] first. Provider-only accounts are
  /// re-authenticated with their provider instead; a provider that refuses a
  /// silent re-authentication surfaces `requires-recent-login`.
  Future<void> deleteAccount({String password = ''});

  /// Sends an email sign-in link using app-supplied Firebase action settings.
  Future<void> sendEmailLink({required String email});

  /// Finishes an email link, linking it to an existing guest where possible.
  Future<AuthAccount> completeEmailLink({
    required String email,
    required String emailLink,
  });
}
