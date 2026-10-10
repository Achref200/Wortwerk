import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/error/app_failure.dart';
import 'package:wortwerk/features/auth/auth.dart';

/// Waits until [condition] holds, so the tests do not depend on how many
/// intermediate states the bloc emits.
Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('The expected session state never arrived.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('AuthSessionBloc', () {
    test('stays unresolved until the provider reports a snapshot', () async {
      final repository = _FakeAuthRepository();
      final bloc = AuthSessionBloc(repository: repository);
      addTearDown(bloc.close);
      addTearDown(repository.dispose);

      expect(bloc.state, isA<AuthSessionUnknown>());
      expect(bloc.state.isResolved, isFalse);
      expect(bloc.currentUserId, isNull);

      bloc.add(const AuthSessionStarted());
      await _waitFor(() => bloc.state is AuthSessionActive);

      expect(bloc.state.isResolved, isTrue);
      expect(bloc.currentUserId, 'guest-1');
      expect(bloc.state.account?.isAnonymous, isTrue);
    });

    test('signs out and reports who did it to the repository', () async {
      final repository = _FakeAuthRepository();
      final bloc = AuthSessionBloc(repository: repository)..add(const AuthSessionStarted());
      addTearDown(bloc.close);
      addTearDown(repository.dispose);

      await _waitFor(() => bloc.state is AuthSessionActive);
      bloc.add(const AuthSessionSignOutRequested());
      await _waitFor(() => bloc.state is AuthSessionSignedOut);

      expect(repository.signOutCalls, 1);
      expect(bloc.currentUserId, isNull);
      expect(bloc.state.isPending, isFalse);
    });

    test('keeps the session and surfaces a shared failure when sign-out fails', () async {
      final repository = _FakeAuthRepository()
        ..signOutFailure = const AuthFailure(
          code: 'network-request-failed',
          message: 'Offline.',
        );
      final bloc = AuthSessionBloc(repository: repository)..add(const AuthSessionStarted());
      addTearDown(bloc.close);
      addTearDown(repository.dispose);

      await _waitFor(() => bloc.state is AuthSessionActive);
      bloc.add(const AuthSessionSignOutRequested());
      await _waitFor(() => bloc.state.failure != null);

      expect(bloc.state, isA<AuthSessionActive>());
      expect(bloc.state.failure?.kind, AppFailureKind.network);
      expect(bloc.state.failure?.retryable, isTrue);
      expect(bloc.state.isPending, isFalse);

      bloc.add(const AuthSessionFailureDismissed());
      await _waitFor(() => bloc.state.failure == null);
      expect(bloc.state, isA<AuthSessionActive>());
    });

    test('sends verification mail and reports it as a one-shot notice', () async {
      final repository = _FakeAuthRepository(account: _FakeAuthRepository.member);
      final bloc = AuthSessionBloc(repository: repository)..add(const AuthSessionStarted());
      addTearDown(bloc.close);
      addTearDown(repository.dispose);

      await _waitFor(() => bloc.state is AuthSessionActive);
      final notices = <AuthSessionNotice>[];
      final subscription = bloc.notices.listen(notices.add);
      addTearDown(subscription.cancel);

      bloc.add(const AuthSessionVerificationRequested());
      await _waitFor(() => repository.verificationCalls == 1);
      await _waitFor(() => notices.isNotEmpty);

      expect(notices, [AuthSessionNotice.verificationSent]);
      expect(bloc.state.isPending, isFalse);
      expect(bloc.state.failure, isNull);
    });

    test('reload refreshes provider-owned fields such as verification', () async {
      final repository = _FakeAuthRepository(account: _FakeAuthRepository.member);
      final bloc = AuthSessionBloc(repository: repository)..add(const AuthSessionStarted());
      addTearDown(bloc.close);
      addTearDown(repository.dispose);

      await _waitFor(() => bloc.state is AuthSessionActive);
      expect(bloc.state.account?.emailVerified, isFalse);

      bloc.add(const AuthSessionReloadRequested());
      await _waitFor(() => bloc.state.account?.emailVerified ?? false);

      expect(bloc.state.account?.emailVerified, isTrue);
      expect(bloc.state.isPending, isFalse);
    });

    test('deletes with the supplied password and ends the session', () async {
      final repository = _FakeAuthRepository(account: _FakeAuthRepository.member);
      final bloc = AuthSessionBloc(repository: repository)..add(const AuthSessionStarted());
      addTearDown(bloc.close);
      addTearDown(repository.dispose);

      await _waitFor(() => bloc.state is AuthSessionActive);
      bloc.add(const AuthSessionDeletionRequested(password: 'geheim-123'));
      await _waitFor(() => bloc.state is AuthSessionSignedOut);

      expect(repository.deleteCalls, 1);
      expect(repository.lastDeletePassword, 'geheim-123');
    });

    test('surfaces a stale-login failure and keeps the account', () async {
      final repository = _FakeAuthRepository(account: _FakeAuthRepository.member)
        ..deleteFailure = const AuthFailure(
          code: 'requires-recent-login',
          message: 'Recent login required.',
        );
      final bloc = AuthSessionBloc(repository: repository)..add(const AuthSessionStarted());
      addTearDown(bloc.close);
      addTearDown(repository.dispose);

      await _waitFor(() => bloc.state is AuthSessionActive);
      bloc.add(const AuthSessionDeletionRequested(password: 'geheim-123'));
      await _waitFor(() => bloc.state.failure != null);

      expect(bloc.state, isA<AuthSessionActive>());
      expect(bloc.state.failure?.kind, AppFailureKind.permissionDenied);
      expect(bloc.state.isPending, isFalse);
    });

    test('reports a degraded sign-out even when the provider stream is quiet', () async {
      // A repository whose stream never reports null still ends the session,
      // because the handler emits the signed-out state itself.
      final repository = _FakeAuthRepository()..silentSignOut = true;
      final bloc = AuthSessionBloc(repository: repository)..add(const AuthSessionStarted());
      addTearDown(bloc.close);
      addTearDown(repository.dispose);

      await _waitFor(() => bloc.state is AuthSessionActive);
      bloc.add(const AuthSessionSignOutRequested());
      await _waitFor(() => bloc.state is AuthSessionSignedOut);

      expect(bloc.state.isSignedOut, isTrue);
    });
  });
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AuthAccount? account})
    : _account = account ?? guest {
    _snapshots.add(_account);
  }

  static const guest = AuthAccount(uid: 'guest-1', isAnonymous: true);
  static const member = AuthAccount(
    uid: 'member-1',
    isAnonymous: false,
    email: 'learner@wortwerk.test',
    providerIds: <String>['password'],
  );

  final StreamController<AuthAccount?> _snapshots =
      StreamController<AuthAccount?>();
  AuthAccount? _account;
  AuthFailure? signOutFailure;
  AuthFailure? deleteFailure;
  bool silentSignOut = false;
  int signOutCalls = 0;
  int deleteCalls = 0;
  int verificationCalls = 0;
  String? lastDeletePassword;

  @override
  String? get currentUserId => _account?.uid;

  @override
  Stream<AuthAccount?> get authStateChanges => _snapshots.stream;

  @override
  Future<AuthAccount> ensureGuestSession() async => _account ?? guest;

  @override
  Future<AuthAccount> linkGoogle() async => _account ?? guest;

  @override
  Future<AuthAccount> linkApple() async => _account ?? guest;

  @override
  Future<AuthAccount> createEmailPasswordAccount({
    required String email,
    required String password,
  }) async => _account ?? guest;

  @override
  Future<AuthAccount> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => _account ?? guest;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> sendEmailLink({required String email}) async {}

  @override
  Future<AuthAccount> completeEmailLink({
    required String email,
    required String emailLink,
  }) async => _account ?? guest;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final failure = signOutFailure;
    if (failure != null) throw failure;
    _account = null;
    if (!silentSignOut) _snapshots.add(null);
  }

  @override
  Future<AuthAccount> reloadAccount() async {
    final account = _account;
    if (account == null) {
      throw const AuthFailure(code: 'missing-user', message: 'No account.');
    }
    final refreshed = AuthAccount(
      uid: account.uid,
      isAnonymous: account.isAnonymous,
      email: account.email,
      displayName: account.displayName,
      emailVerified: true,
      providerIds: account.providerIds,
    );
    _account = refreshed;
    return refreshed;
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationCalls++;
  }

  @override
  Future<void> deleteAccount({String password = ''}) async {
    deleteCalls++;
    lastDeletePassword = password;
    final failure = deleteFailure;
    if (failure != null) throw failure;
    _account = null;
    _snapshots.add(null);
  }

  Future<void> dispose() => _snapshots.close();
}
