import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/auth_account.dart';
import '../domain/auth_repository.dart';

/// Firebase-backed implementation of [AuthRepository].
///
/// On web, provider linking uses a popup. Native platforms use Firebase
/// Auth's provider flow. No provider operation signs the current user out.
final class FirebaseAuthAccountRepository implements AuthRepository {
  FirebaseAuthAccountRepository({FirebaseAuth? auth, this.emailLinkSettings})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final EmailLinkSettings? emailLinkSettings;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<AuthAccount?> get authStateChanges =>
      _auth.authStateChanges().map(_snapshot);

  @override
  Future<AuthAccount> ensureGuestSession() async {
    final current = _auth.currentUser;
    if (current != null) return _toAccount(current);
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          code: 'missing-user',
          message: 'Firebase did not return an account for the guest session.',
        );
      }
      return _toAccount(user);
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<AuthAccount> linkGoogle() => _linkProvider(GoogleAuthProvider());

  @override
  Future<AuthAccount> linkApple() => _linkProvider(AppleAuthProvider());

  @override
  Future<AuthAccount> createEmailPasswordAccount({
    required String email,
    required String password,
  }) async {
    try {
      final current = _auth.currentUser;
      final result = current?.isAnonymous == true
          ? await current!.linkWithCredential(
              EmailAuthProvider.credential(
                email: email.trim(),
                password: password,
              ),
            )
          : await _auth.createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
      final user = result.user;
      if (user == null) {
        throw const AuthFailure(
          code: 'missing-user',
          message: 'Firebase did not return an account after registration.',
        );
      }
      return _toAccount(user);
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<AuthAccount> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) {
        throw const AuthFailure(
          code: 'missing-user',
          message: 'Firebase did not return an account after sign-in.',
        );
      }
      return _toAccount(user);
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<AuthAccount> reloadAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        code: 'missing-user',
        message: 'There is no signed-in account to refresh.',
      );
    }
    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
    // `reload` mutates the cached user; re-read it so the snapshot reflects the
    // provider's current values.
    return _toAccount(_auth.currentUser ?? user);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        code: 'missing-user',
        message: 'Sign in before requesting an address confirmation.',
      );
    }
    if (user.email == null || user.email!.isEmpty || user.emailVerified) {
      // Nothing to confirm: guests and provider accounts carry no address of
      // their own. Treated as success so the caller does not show an error.
      return;
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> deleteAccount({String password = ''}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        code: 'missing-user',
        message: 'There is no signed-in account to delete.',
      );
    }
    try {
      await _reauthenticate(user, password);
      await user.delete();
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  /// Refreshes the session right before a destructive call.
  ///
  /// Password accounts prove ownership with the supplied password; accounts
  /// created through a provider re-use that provider, which is the only
  /// credential Firebase will accept for them.
  Future<void> _reauthenticate(User user, String password) async {
    final providerIds = user.providerData
        .map((info) => info.providerId)
        .toList(growable: false);

    if (providerIds.contains('password')) {
      final email = user.email;
      if (password.isEmpty || email == null || email.isEmpty) {
        throw const AuthFailure(
          code: 'missing-password',
          message: 'A password is required to confirm this account change.',
        );
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return;
    }

    if (providerIds.contains('google.com')) {
      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await user.reauthenticateWithPopup(provider);
      } else {
        await user.reauthenticateWithProvider(provider);
      }
      return;
    }

    if (providerIds.contains('apple.com')) {
      final provider = AppleAuthProvider();
      if (kIsWeb) {
        await user.reauthenticateWithPopup(provider);
      } else {
        await user.reauthenticateWithProvider(provider);
      }
      return;
    }

    // Guest and email-link accounts have no reusable credential. Let Firebase
    // decide, so the caller sees its `requires-recent-login` code rather than a
    // guessed one.
  }

  Future<AuthAccount> _linkProvider(AuthProvider provider) async {
    try {
      final user = await _ensureCurrentUser();
      final originalUid = user.uid;
      final linked = kIsWeb
          ? await user.linkWithPopup(provider)
          : await user.linkWithProvider(provider);
      final linkedUser = linked.user;
      if (linkedUser == null) {
        throw const AuthFailure(
          code: 'missing-user',
          message: 'The provider did not return an account.',
        );
      }
      if (linkedUser.uid != originalUid) {
        throw const AuthFailure(
          code: 'uid-changed-during-link',
          message:
              'The account could not be linked to this guest session. '
              'Your guest progress has not been moved.',
        );
      }
      return _toAccount(linkedUser);
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> sendEmailLink({required String email}) async {
    final settings = emailLinkSettings;
    if (settings == null || settings.continueUrl.trim().isEmpty) {
      throw const AuthFailure(
        code: 'email-link-not-configured',
        message:
            'Email-link sign-in is unavailable until the app supplies '
            'its Firebase-approved continue URL.',
      );
    }

    try {
      await _ensureCurrentUser();
      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: settings.continueUrl,
          handleCodeInApp: settings.handleCodeInApp,
        ),
      );
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<AuthAccount> completeEmailLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      if (!_auth.isSignInWithEmailLink(emailLink)) {
        throw const AuthFailure(
          code: 'invalid-email-link',
          message: 'This link is not a valid Firebase email sign-in link.',
        );
      }

      final current = _auth.currentUser;
      if (current != null) {
        final originalUid = current.uid;
        final credential = EmailAuthProvider.credentialWithLink(
          email: email,
          emailLink: emailLink,
        );
        final linked = await current.linkWithCredential(credential);
        final linkedUser = linked.user;
        if (linkedUser == null || linkedUser.uid != originalUid) {
          throw const AuthFailure(
            code: 'uid-changed-during-link',
            message:
                'The email could not be linked to this guest session. '
                'Your guest progress has not been moved.',
          );
        }
        return _toAccount(linkedUser);
      }

      final signedIn = await _auth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );
      final user = signedIn.user;
      if (user == null) {
        throw const AuthFailure(
          code: 'missing-user',
          message: 'Firebase did not return an account for this email link.',
        );
      }
      return _toAccount(user);
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  Future<User> _ensureCurrentUser() async {
    final current = _auth.currentUser;
    if (current != null) return current;

    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          code: 'missing-user',
          message: 'Firebase did not return an account for the guest session.',
        );
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw _toFailure(error);
    }
  }

  AuthFailure _toFailure(FirebaseAuthException error) => AuthFailure(
    code: error.code,
    message: error.message?.isNotEmpty == true
        ? error.message!
        : 'Authentication failed (${error.code}).',
  );

  AuthAccount? _snapshot(User? user) => user == null ? null : _toAccount(user);

  AuthAccount _toAccount(User user) => AuthAccount(
    uid: user.uid,
    isAnonymous: user.isAnonymous,
    email: user.email,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
    providerIds: List<String>.unmodifiable(
      user.providerData.map((info) => info.providerId),
    ),
  );
}
