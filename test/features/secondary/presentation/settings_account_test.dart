import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/l10n/app_language.dart';
import 'package:wortwerk/core/l10n/locale_controller.dart';
import 'package:wortwerk/features/auth/auth.dart';
import 'package:wortwerk/features/notifications/application/push_notifications_controller.dart';
import 'package:wortwerk/features/settings/domain/learner_preferences.dart';
import 'package:wortwerk/features/settings/domain/learner_preferences_repository.dart';
import 'package:wortwerk/features/secondary/presentation/secondary_pages.dart';

void main() {
  group('Settings account section', () {
    testWidgets('loads and saves learning preferences for the account', (
      tester,
    ) async {
      final preferences = _FakeLearnerPreferencesRepository();
      await _pump(tester, preferences: preferences);

      expect(find.text('10 Minuten'), findsOneWidget);
      final goal = find.byType(DropdownButton<int>).first;
      await tester.tap(goal);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 Minuten').last);
      await tester.pumpAndSettle();

      expect(preferences.saveCalls, 1);
      expect(preferences.value.dailyMinutes, 15);
      expect(find.text('Auf deinem Profil gespeichert.'), findsOneWidget);
    });

    testWidgets('shows guest status and offers sign-out only', (tester) async {
      final harness = await _pump(tester);

      expect(find.text('KONTO'), findsOneWidget);
      expect(find.text('Gastsitzung'), findsOneWidget);
      expect(find.text('Abmelden'), findsOneWidget);
      // A guest has no address to confirm and nothing to delete yet.
      expect(find.text('E-Mail-Adresse bestätigen'), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text('Konto löschen'),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(harness.repository.signOutCalls, 0);
    });

    testWidgets('signs out only after the confirmation sheet', (tester) async {
      final harness = await _pump(tester, account: _FakeAuthRepository.member);

      expect(find.text('Angemeldet als learner@wortwerk.test'), findsOneWidget);
      expect(find.text('Adresse noch nicht bestätigt'), findsOneWidget);

      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      expect(find.text('Abmelden?'), findsOneWidget);
      expect(harness.repository.signOutCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Abmelden'));
      await tester.pumpAndSettle();

      expect(harness.repository.signOutCalls, 1);
      expect(harness.session.state, isA<AuthSessionSignedOut>());
    });

    testWidgets('sends a confirmation mail and confirms it with a notice', (
      tester,
    ) async {
      final harness = await _pump(tester, account: _FakeAuthRepository.member);

      await tester.tap(find.text('E-Mail-Adresse bestätigen'));
      await tester.pumpAndSettle();

      expect(harness.repository.verificationCalls, 1);
      expect(
        find.textContaining('Eine Bestätigungsmail ist unterwegs'),
        findsOneWidget,
      );
    });

    testWidgets('refreshes and shows the confirmed address badge', (
      tester,
    ) async {
      final harness = await _pump(tester, account: _FakeAuthRepository.member);

      await tester.tap(find.text('Ich habe bestätigt – aktualisieren'));
      await tester.pumpAndSettle();

      expect(find.text('Adresse bestätigt'), findsOneWidget);
      expect(harness.session.state.account?.emailVerified, isTrue);
    });

    testWidgets('deletes only after the password is confirmed', (tester) async {
      final harness = await _pump(tester, account: _FakeAuthRepository.member);

      await tester.tap(find.text('Konto löschen'));
      await tester.pumpAndSettle();
      expect(find.text('Konto löschen?'), findsOneWidget);
      expect(harness.repository.deleteCalls, 0);

      await tester.enterText(find.byType(TextField), 'geheim-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Konto löschen'));
      await tester.pumpAndSettle();

      expect(harness.repository.deleteCalls, 1);
      expect(harness.repository.lastDeletePassword, 'geheim-123');
      expect(harness.session.state, isA<AuthSessionSignedOut>());
    });

    testWidgets('shows a stale-login failure and keeps the account', (
      tester,
    ) async {
      final repository = _FakeAuthRepository(_FakeAuthRepository.member)
        ..deleteFailure = const AuthFailure(
          code: 'requires-recent-login',
          message: 'Recent login required.',
        );
      final harness = await _pump(tester, repository: repository);

      await tester.tap(find.text('Konto löschen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'falsch');
      await tester.tap(find.widgetWithText(FilledButton, 'Konto löschen'));
      await tester.pumpAndSettle();

      expect(harness.session.state, isA<AuthSessionActive>());
      expect(find.text('Angemeldet als learner@wortwerk.test'), findsOneWidget);
      expect(find.textContaining('Du hast keinen Zugriff'), findsOneWidget);
    });
  });
}

final class _Harness {
  const _Harness({required this.repository, required this.session});

  final _FakeAuthRepository repository;
  final AuthSessionBloc session;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AuthAccount? account,
  _FakeAuthRepository? repository,
  _FakeLearnerPreferencesRepository? preferences,
}) async {
  // The settings list is longer than a phone viewport; a tall surface keeps
  // every row built and hittable without scroll gymnastics.
  tester.view.physicalSize = const Size(900, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final resolved = repository ?? _FakeAuthRepository(account);
  final session = AuthSessionBloc(repository: resolved)
    ..add(const AuthSessionStarted());
  // bloc 9.2.1 close() deadlocks inside the widget-test fake zone; fire-and-
  // forget outside the awaited chain lets the real async teardown drain it.
  // ignore: discarded_futures
  addTearDown(() => unawaited(session.close()));
  addTearDown(resolved.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: SettingsPage(
        localeController: LocaleController(store: _StubLocaleStore()),
        preferencesRepository:
            preferences ?? _FakeLearnerPreferencesRepository(),
        pushNotifications: _StubPushNotifications(),
        authSession: session,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(repository: resolved, session: session);
}

final class _FakeLearnerPreferencesRepository
    implements LearnerPreferencesRepository {
  LearnerPreferences value = const LearnerPreferences();
  int saveCalls = 0;

  @override
  Future<LearnerPreferences> load() async => value;

  @override
  Future<void> save(LearnerPreferences preferences) async {
    saveCalls++;
    value = preferences;
  }
}

final class _StubLocaleStore implements LocalePreferenceStore {
  @override
  Future<AppLanguage?> load() async => null;

  @override
  Future<void> save(AppLanguage language) async {}
}

final class _StubPushNotifications extends PushNotificationsController {
  @override
  bool get enabled => false;

  @override
  bool get isWorking => false;

  @override
  PushNotificationProblem? get problem => null;

  @override
  Stream<PushNotice> get foregroundNotices => const Stream<PushNotice>.empty();

  @override
  Future<void> initialize({required void Function(String path) onOpen}) async {}

  @override
  Future<bool> enable(String language) async => false;

  @override
  Future<void> disable() async {}
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository([AuthAccount? initial]) : _account = initial ?? guest {
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
  AuthFailure? deleteFailure;
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
    _account = null;
    _snapshots.add(null);
  }

  @override
  Future<AuthAccount> reloadAccount() async {
    final account = _account;
    if (account == null) {
      throw const AuthFailure(code: 'missing-user', message: 'No account.');
    }
    // The provider is the source of truth for the verification flag.
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
