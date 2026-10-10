// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/auth/domain/auth_account.dart';
import '../../../../lib/features/auth/domain/auth_repository.dart';
import '../../../../lib/features/auth/presentation/auth_account_page.dart';

void main() {
  group('AuthAccountPage', () {
    testWidgets('continues with the account returned by guest auth', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      AuthAccount? continuedAccount;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthAccountPage(
            repository: repository,
            onContinueAsGuest: (account) => continuedAccount = account,
          ),
        ),
      );

      await tester.ensureVisible(find.text('Weiter als Gast'));
      await tester.tap(find.text('Weiter als Gast'));
      await tester.pumpAndSettle();

      expect(repository.ensureGuestCalls, 1);
      expect(continuedAccount?.uid, 'guest-123');
      expect(continuedAccount?.isAnonymous, isTrue);
      expect(
        find.text('Deine Gastsitzung ist auf diesem Gerät bereit.'),
        findsOneWidget,
      );
    });

    testWidgets('shows German account actions and accessible form labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: AuthAccountPage(repository: _FakeAuthRepository())),
      );

      expect(find.text('Dein Lernen – überall dabei.'), findsOneWidget);
      expect(find.text('Mit Google fortfahren'), findsOneWidget);
      expect(find.text('Mit Apple fortfahren'), findsOneWidget);
      expect(find.text('Konto mit Passwort erstellen'), findsOneWidget);
      expect(find.text('E-Mail-Adresse'), findsOneWidget);
      expect(find.text('Stattdessen E-Mail-Link senden'), findsOneWidget);
      expect(find.text('Weiter als Gast'), findsOneWidget);
      expect(find.bySemanticsLabel('Mit Google fortfahren'), findsWidgets);
      expect(find.bySemanticsLabel('Mit Apple fortfahren'), findsWidgets);
      expect(find.bySemanticsLabel('E-Mail-Adresse'), findsWidgets);
      expect(find.bySemanticsLabel('Lernbuch-Symbol'), findsWidgets);
    });

    testWidgets('creates a password account and preserves guest progress', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      AuthAccount? linkedAccount;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthAccountPage(
            repository: repository,
            onAccountLinked: (account) => linkedAccount = account,
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const ValueKey('account-email')));
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        'learner@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'secure-pass-123',
      );
      await tester.ensureVisible(find.text('Konto erstellen'));
      await tester.tap(find.text('Konto erstellen'));
      await tester.pumpAndSettle();

      expect(repository.createAccountCalls, 1);
      expect(linkedAccount?.uid, 'guest-123');
      expect(linkedAccount?.isAnonymous, isFalse);
      expect(
        find.text(
          'Dein Konto ist erstellt. Dein Lernfortschritt ist verknüpft.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows safe auth failures without claiming the account linked',
      (tester) async {
        final repository = _FakeAuthRepository()
          ..googleFailure = const AuthFailure(
            code: 'provider-error',
            message: 'The exact provider failure from the service.',
          );
        var linkCallbackInvoked = false;
        await tester.pumpWidget(
          MaterialApp(
            home: AuthAccountPage(
              repository: repository,
              onAccountLinked: (_) => linkCallbackInvoked = true,
            ),
          ),
        );

        await tester.tap(find.text('Mit Google fortfahren'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Diese Anmeldemethode ist gerade nicht'),
          findsOneWidget,
        );
        expect(
          find.text('The exact provider failure from the service.'),
          findsNothing,
        );
        expect(
          find.text('Dein Konto ist mit dieser Sitzung verknüpft.'),
          findsNothing,
        );
        expect(linkCallbackInvoked, isFalse);
      },
    );

    testWidgets(
      'makes credential-already-in-use clear and keeps guest option',
      (tester) async {
        final repository = _FakeAuthRepository()
          ..appleFailure = const AuthFailure(
            code: 'credential-already-in-use',
            message: 'Credential already in use.',
          );
        await tester.pumpWidget(
          MaterialApp(home: AuthAccountPage(repository: repository)),
        );

        await tester.tap(find.text('Mit Apple fortfahren'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Lernfortschritt bleibt mit deiner Gastsitzung verbunden.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Lernfortschritt bleibt mit deiner Gastsitzung verbunden.',
          ),
          findsOneWidget,
        );
        expect(find.text('Weiter als Gast'), findsOneWidget);
      },
    );
  });
}

class _FakeAuthRepository implements AuthRepository {
  final AuthAccount guest = const AuthAccount(
    uid: 'guest-123',
    isAnonymous: true,
  );
  int ensureGuestCalls = 0;
  int createAccountCalls = 0;
  int signInCalls = 0;
  int passwordResetCalls = 0;

  @override
  String? get currentUserId => guest.uid;
  AuthFailure? googleFailure;
  AuthFailure? appleFailure;

  @override
  Stream<AuthAccount?> get authStateChanges => Stream.value(guest);

  @override
  Future<AuthAccount> ensureGuestSession() async {
    ensureGuestCalls++;
    return guest;
  }

  @override
  Future<AuthAccount> linkGoogle() async {
    final failure = googleFailure;
    if (failure != null) throw failure;
    return const AuthAccount(
      uid: 'guest-123',
      isAnonymous: false,
      providerIds: ['google.com'],
    );
  }

  @override
  Future<AuthAccount> linkApple() async {
    final failure = appleFailure;
    if (failure != null) throw failure;
    return const AuthAccount(
      uid: 'guest-123',
      isAnonymous: false,
      providerIds: ['apple.com'],
    );
  }

  @override
  Future<AuthAccount> createEmailPasswordAccount({
    required String email,
    required String password,
  }) async {
    createAccountCalls++;
    return const AuthAccount(
      uid: 'guest-123',
      isAnonymous: false,
      email: 'learner@example.com',
      providerIds: ['password'],
    );
  }

  @override
  Future<AuthAccount> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return const AuthAccount(
      uid: 'account-456',
      isAnonymous: false,
      email: 'learner@example.com',
      providerIds: ['password'],
    );
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetCalls++;
  }

  @override
  Future<void> sendEmailLink({required String email}) async {}

  @override
  Future<AuthAccount> completeEmailLink({
    required String email,
    required String emailLink,
  }) async => const AuthAccount(uid: 'guest-123', isAnonymous: false);

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthAccount> reloadAccount() async => guest;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> deleteAccount({String password = ''}) async {}
}
