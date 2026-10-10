import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wortwerk/app/app.dart';
import 'package:wortwerk/app/environment.dart';
import 'package:wortwerk/app/router.dart';
import 'package:wortwerk/core/error/app_failure.dart';
import 'package:wortwerk/core/haptics/haptic_service.dart';
import 'package:wortwerk/core/l10n/app_language.dart';
import 'package:wortwerk/core/l10n/locale_controller.dart';
import 'package:wortwerk/features/auth/auth.dart';
import 'package:wortwerk/features/community/domain/community_repository.dart';
import 'package:wortwerk/features/flashcards/domain/flashcard_review.dart';
import 'package:wortwerk/features/fritz/domain/fritz_message.dart';
import 'package:wortwerk/features/fritz/application/speech_practice_service.dart';
import 'package:wortwerk/features/lesson/domain/greetings_lesson.dart';
import 'package:wortwerk/features/lesson/domain/lesson_repository.dart';
import 'package:wortwerk/features/missions/domain/daily_missions.dart';
import 'package:wortwerk/features/onboarding/domain/local_placement_evaluator.dart';
import 'package:wortwerk/features/onboarding/domain/onboarding_progress_repository.dart';
import 'package:wortwerk/features/onboarding/domain/placement_session.dart';
import 'package:wortwerk/features/notifications/domain/inbox_notification.dart';
import 'package:wortwerk/features/notifications/domain/notifications_repository.dart';
import 'package:wortwerk/features/notifications/application/push_notifications_controller.dart';
import 'package:wortwerk/features/path/domain/learning_path.dart';
import 'package:wortwerk/features/path/domain/learning_path_repository.dart';
import 'package:wortwerk/features/streak/domain/learning_streak_summary.dart';
import 'package:wortwerk/features/settings/domain/learner_preferences.dart';
import 'package:wortwerk/features/settings/domain/learner_preferences_repository.dart';
import 'package:wortwerk/features/profile/domain/learner_profile.dart';
import 'package:wortwerk/features/profile/domain/learner_profile_repository.dart';

import 'fixtures/a1_greetings_lesson.dart';

void _useTallHomeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('foreground push notices can open their in-app destination', (
    tester,
  ) async {
    final push = _MemoryPushNotificationsController();
    final router = _createTestRouter(initialLocation: '/home');
    addTearDown(router.dispose);
    addTearDown(push.dispose);
    await tester.pumpWidget(
      WortwerkApp(
        environment: AppEnvironment.emulator(),
        router: router,
        pushNotifications: push,
      ),
    );
    await tester.pumpAndSettle();

    push.publish(
      const PushNotice(
        title: 'A new level is open',
        body: 'You unlocked A2.',
        deepLink: '/path',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('A new level is open'), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    // Bounded pumps: the path's current-node halo loops forever (SPEC 5.4).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(router.routeInformationProvider.value.uri.path, '/path');
  });

  testWidgets('bootstrap authentication failure shows a safe retry state', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.pumpWidget(
      BootstrapFailureApp(
        failure: AppFailure.fromFirebaseException(
          FirebaseException(
            plugin: 'firebase_auth',
            code: 'network-request-failed',
            message: 'http://127.0.0.1:9099/private-detail',
          ),
        ),
        onRetry: () => retryCount++,
      ),
    );

    expect(
      find.text('Wortwerk konnte nicht gestartet werden.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Keine Verbindung. Prüfe dein Internet und versuche es erneut.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('127.0.0.1:9099'), findsNothing);

    await tester.tap(find.text('Erneut versuchen'));
    expect(retryCount, 1);
  });

  testWidgets('learning path renders only published repository content', (
    tester,
  ) async {
    final router = _createTestRouter(initialLocation: '/path');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Bounded pumps: the current-node halo loops forever (SPEC 5.4).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Greetings starter'), findsNWidgets(2));
    expect(find.text('Weitere Lektionen folgen'), findsNothing);
    expect(find.text('Unterwegs'), findsNothing);
    expect(find.text('B1 preview'), findsNothing);
    expect(find.text('BIS A2'), findsOneWidget);
    expect(find.text('2/10 Wörter · 20 %'), findsOneWidget);
    expect(find.text('1/3 Gespräche'), findsOneWidget);
    expect(find.text('1 Runde mit mindestens 70 %'), findsOneWidget);
  });

  testWidgets('learning path exposes offline retry and honest empty state', (
    tester,
  ) async {
    final repository = _FailingPathRepository();
    final router = _createTestRouter(
      initialLocation: '/path',
      learningPathRepository: repository,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dein Lernweg ist gerade offline.'), findsOneWidget);
    expect(find.text('backend path details'), findsNothing);
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();

    expect(find.text('Dein Lernweg wird vorbereitet.'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('new users land in the guided onboarding flow', (
    WidgetTester tester,
  ) async {
    final router = _createTestRouter(
      placementEvaluator: const LocalPlacementEvaluator(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Wortwerk');
    expect(find.text('Hallo! Ich bin Fritz.'), findsOneWidget);
    expect(find.byType(Banner), findsOneWidget);
    expect(find.text("Los geht's"), findsOneWidget);
  });

  testWidgets('unknown routes have a route recovery action', (
    WidgetTester tester,
  ) async {
    _useTallHomeViewport(tester);
    final router = _createTestRouter(
      placementEvaluator: const LocalPlacementEvaluator(),
    );
    addTearDown(router.dispose);
    router.go('/missing');
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Diese Seite gibt es noch nicht.'), findsOneWidget);
    await tester.tap(find.text('Zurück zum Start'));
    await tester.pumpAndSettle();
    expect(find.text('Dein nächster Schritt'), findsOneWidget);
  });

  testWidgets('settings stay readable at 200% text scale', (
    WidgetTester tester,
  ) async {
    // SPEC 13: text scales to 200% without clipping. Keep the phone viewport
    // and verify every rendered string is neither truncated nor clipped.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = _createTestRouter(initialLocation: '/settings');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(RichText), findsWidgets);
    final clipped = <String>[];
    final paragraphs = find
        .byType(RichText)
        .evaluate()
        .map((element) => element.renderObject)
        .whereType<RenderParagraph>()
        .toList();
    // At 200% scale only the first viewport of the lazy settings list is
    // materialized; a healthy floor is enough for the clip checks below.
    expect(paragraphs.length, greaterThan(5));
    for (final paragraph in paragraphs) {
      if (paragraph.text.toPlainText().trim().isEmpty) continue;
      if (paragraph.didExceedMaxLines) {
        clipped.add(paragraph.text.toPlainText());
      }
      final box = paragraph.semanticBounds;
      if (box.right > paragraph.size.width + 0.5 ||
          box.bottom > paragraph.size.height + 0.5) {
        clipped.add(paragraph.text.toPlainText());
      }
    }
    expect(clipped, isEmpty);
  });

  testWidgets('cloud mode does not show the emulator banner', (
    WidgetTester tester,
  ) async {
    final router = _createTestRouter(
      placementEvaluator: const LocalPlacementEvaluator(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(
        environment: const AppEnvironment(
          flavor: AppFlavor.staging,
          useEmulators: false,
          firebaseProjectId: 'test-project',
          firebaseApiKey: 'test-api-key',
          firebaseSenderId: '1234567890',
          androidAppId: 'android-app',
          iosAppId: 'ios-app',
          webAppId: 'web-app',
          emulatorHost: '127.0.0.1',
        ),
        router: router,
      ),
    );

    expect(find.text('EMULATOR'), findsNothing);
  });

  testWidgets('onboarding choices shape the plan before opening the app', (
    WidgetTester tester,
  ) async {
    _useTallHomeViewport(tester);
    final router = _createTestRouter(
      placementEvaluator: const LocalPlacementEvaluator(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Los geht's"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 Min'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grundlagen'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('15 Minuten am Tag'), findsOneWidget);
    expect(find.text('A2 · Reisen'), findsOneWidget);

    await tester.tap(find.text('Loslernen'));
    await tester.pumpAndSettle();
    expect(find.text('Weiter als Gast'), findsOneWidget);
    await tester.ensureVisible(find.text('Weiter als Gast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter als Gast'));
    await tester.pumpAndSettle();
    expect(find.text('Dein nächster Schritt'), findsOneWidget);
  });

  testWidgets('settings switches and persists English app copy', (
    WidgetTester tester,
  ) async {
    final store = _MemoryLocalePreferenceStore();
    final localeController = LocaleController(store: store);
    final router = _createTestRouter(
      initialLocation: '/settings',
      localeController: localeController,
    );
    addTearDown(router.dispose);
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      WortwerkApp(
        environment: AppEnvironment.emulator(),
        router: router,
        localeController: localeController,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(localeController.language, AppLanguage.en);
    expect(store.language, AppLanguage.en);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Daily goal'), findsOneWidget);
  });

  testWidgets('home opens the server-backed A1 lesson', (
    WidgetTester tester,
  ) async {
    _useTallHomeViewport(tester);
    final router = _createTestRouter(initialLocation: '/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Lektion beginnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lektion beginnen'));
    await tester.pumpAndSettle();

    expect(find.text('Frage 1 von 5'), findsOneWidget);
  });

  testWidgets('learning path shows the current published lesson', (
    WidgetTester tester,
  ) async {
    final router = _createTestRouter(initialLocation: '/path');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    // Bounded pumps: the current-node halo loops forever (SPEC 5.4), so a
    // pumpAndSettle here would never settle. Two clocks jumps flush the load
    // future and the entrance/journey animations.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Dein Lernweg'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('path-node-A1-Greetings starter')),
      findsOneWidget,
    );
    expect(find.text('Unterwegs'), findsNothing);
  });
  testWidgets('available learning-path node opens its lesson', (
    WidgetTester tester,
  ) async {
    final router = _createTestRouter(initialLocation: '/path');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    // Bounded pumps: the current-node halo loops forever (SPEC 5.4).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 4));

    final firstLesson = find.byKey(
      const ValueKey('path-node-A1-Greetings starter'),
    );
    await tester.ensureVisible(firstLesson);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(firstLesson);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Frage 1 von 5'), findsOneWidget);
  });

  testWidgets('locked path node explains the prior-unit requirement', (
    tester,
  ) async {
    final repository = _MemoryLearningPathRepository(unitAvailable: false);
    final router = _createTestRouter(
      initialLocation: '/path',
      learningPathRepository: repository,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(
      find.byKey(const ValueKey('path-node-A1-Greetings starter')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('Beende zuerst die vorherige Einheit mit mindestens 60 %.'),
      findsOneWidget,
    );
    expect(find.text('Frage 1 von 5'), findsNothing);
  });

  testWidgets('onboarding draft restores after the app is recreated', (
    WidgetTester tester,
  ) async {
    final progressRepository = _MemoryOnboardingProgressRepository();
    final firstRouter = _createTestRouter(
      onboardingProgressRepository: progressRepository,
    );
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: firstRouter),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Los geht's"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 Min'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Wo stehst du gerade?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    firstRouter.dispose();

    final secondRouter = _createTestRouter(
      onboardingProgressRepository: progressRepository,
    );
    addTearDown(secondRouter.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: secondRouter),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wo stehst du gerade?'), findsOneWidget);
    await tester.tap(find.text('Grundlagen'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('15 Minuten am Tag'), findsOneWidget);
  });

  testWidgets('Fritz sheet opens its persisted chat screen', (
    WidgetTester tester,
  ) async {
    _useTallHomeViewport(tester);
    final fritzRepository = _MemoryFritzChatRepository();
    final speech = _MemorySpeechPracticeService();
    final router = _createTestRouter(
      placementEvaluator: const LocalPlacementEvaluator(),
      fritzChatRepository: fritzRepository,
      speechPracticeService: speech,
    );
    addTearDown(router.dispose);
    router.go('/home');
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dein nächster Schritt'), findsOneWidget);
    expect(find.byTooltip('Fritz fragen'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNWidgets(2));

    await tester.tap(find.byTooltip('Fritz fragen'));
    await tester.pumpAndSettle();
    expect(find.text('Wobei kann ich helfen?'), findsOneWidget);
    await tester.tap(find.text('Erklären'));
    await tester.pumpAndSettle();

    expect(find.text('Fritz übt mit dir'), findsOneWidget);
    expect(find.text('Womit möchtest du anfangen?'), findsOneWidget);
    expect(
      find.textContaining('Fritz ist ein KI-Lernassistent.'),
      findsOneWidget,
    );
    expect(fritzRepository.watchedThreadIds, hasLength(1));
    await tester.tap(find.text('Neues Gespräch'));
    await tester.pumpAndSettle();
    expect(fritzRepository.watchedThreadIds, hasLength(2));
    expect(
      fritzRepository.watchedThreadIds.last,
      isNot(fritzRepository.watchedThreadIds.first),
    );
  });

  testWidgets('German tutor dictation inserts a transcript before sending', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fritzRepository = _MemoryFritzChatRepository();
    final router = _createTestRouter(
      initialLocation: '/tutor',
      fritzChatRepository: fritzRepository,
      speechPracticeService: _MemorySpeechPracticeService(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Guten Morgen',
    );
    await tester.tap(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(fritzRepository.sentTexts, contains('Guten Morgen'));
  });

  testWidgets('German tutor replies can be played aloud', (
    WidgetTester tester,
  ) async {
    final fritzRepository = _MemoryFritzChatRepository()
      ..initialMessages.add(
        FritzMessage(
          id: 'reply',
          requestId: 'request-1',
          role: FritzMessageRole.tutor,
          text: 'Hallo! Wie geht es dir?',
          createdAt: DateTime.utc(2026, 10, 7),
        ),
      );
    final speech = _MemorySpeechPracticeService();
    final router = _createTestRouter(
      initialLocation: '/tutor',
      fritzChatRepository: fritzRepository,
      speechPracticeService: speech,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();
    expect(speech.spokenTexts, contains('Hallo! Wie geht es dir?'));
  });

  testWidgets('primary tabs open the matching content', (
    WidgetTester tester,
  ) async {
    final router = _createTestRouter(
      placementEvaluator: const LocalPlacementEvaluator(),
    );
    addTearDown(router.dispose);
    router.go('/home');
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Weg'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Dein Lernweg'), findsOneWidget);

    await tester.tap(find.text('Gruppen'));
    await tester.pumpAndSettle();
    expect(find.text('Gemeinsam lernen'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Dein Profil'), findsOneWidget);
    expect(find.text('Test learner'), findsOneWidget);
    expect(find.text('Level A1'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('XP insgesamt'), findsOneWidget);
  });

  testWidgets('profile name edits save through the profile repository', (
    tester,
  ) async {
    final profile = _MemoryLearnerProfileRepository();
    final router = _createTestRouter(
      initialLocation: '/home',
      profileRepository: profile,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Namen bearbeiten'));
    await tester.tap(find.text('Namen bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lena');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(profile.profile.displayName, 'Lena');
  });

  testWidgets('community joining requires consent and opens a group chat', (
    tester,
  ) async {
    final community = _MemoryCommunityRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _createTestRouter(
      initialLocation: '/groups',
      communityRepository: community,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Alltag'), findsOneWidget);
    await tester.tap(find.text('Gruppe beitreten'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ich bestätige, dass ich mindestens 16 Jahre alt bin.'),
      findsOneWidget,
    );
    final consentBoxes = find.byType(CheckboxListTile);
    await tester.tap(consentBoxes.at(0));
    await tester.pump();
    await tester.ensureVisible(consentBoxes.at(1));
    await tester.pumpAndSettle();
    await tester.tap(consentBoxes.at(1));
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(consentBoxes.at(0)).value, isTrue);
    expect(tester.widget<CheckboxListTile>(consentBoxes.at(1)).value, isTrue);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Gruppe beitreten'),
      ),
    );
    await tester.pumpAndSettle();
    expect(community.joined, contains('a1_alltag'));
    await tester.tap(find.text('Gruppe öffnen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ein ruhiger Raum. Sag Hallo, wenn du magst.'),
      findsOneWidget,
    );
    expect(find.text('Profil'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Hallo zusammen!');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(community.sentBodies, contains('Hallo zusammen!'));
  });

  testWidgets('placement test adapts eight questions and identifies B1', (
    WidgetTester tester,
  ) async {
    final router = _createTestRouter(
      placementEvaluator: const LocalPlacementEvaluator(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Los geht's"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teste mich, Fritz'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Frage 1 von 8'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);

    const answers = [
      ('Hallo', 'Frage 2 von 8', 'A1'),
      ('Bitte', 'Frage 3 von 8', 'A2'),
      ('der nächste', 'Frage 4 von 8', 'A2'),
      ('mit dem', 'Frage 5 von 8', 'B1'),
      ('weil', 'Frage 6 von 8', 'B1'),
      ('Könnten Sie mir bitte helfen?', 'Frage 7 von 8', 'B1'),
      ('die', 'Frage 8 von 8', 'B1'),
      ('Someone is repairing the road.', 'Dein Plan steht.', ''),
    ];
    for (final (answer, expectedProgress, expectedLevel) in answers) {
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text(expectedProgress), findsOneWidget);
      if (expectedLevel.isNotEmpty) {
        expect(find.text(expectedLevel), findsOneWidget);
      }
    }

    expect(find.text('B1 · Alltag und Gespräche'), findsOneWidget);
    expect(find.textContaining('100% der Antworten richtig'), findsOneWidget);
  });

  testWidgets('failed placement scoring offers retry or self-assessment', (
    WidgetTester tester,
  ) async {
    final router = _createTestRouter(
      placementEvaluator: const _UnavailablePlacementEvaluator(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Los geht's"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teste mich, Fritz'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    const incorrectAnswers = [
      'Danke',
      'Guten Abend',
      'heißt',
      'Ich wohne gut.',
      'Die',
      'Wie heißt du?',
      'lernst',
      'Nur beim Essen',
    ];
    for (var index = 0; index < incorrectAnswers.length; index++) {
      expect(find.text('Frage ${index + 1} von 8'), findsOneWidget);
      await tester.tap(find.text(incorrectAnswers[index]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
    }

    expect(
      find.textContaining(
        'Fritz konnte die Einstufung gerade nicht bestätigen.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Mein Niveau selbst auswählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gespräche führen'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('B1 · Alltag und Gespräche'), findsOneWidget);
  });

  testWidgets('signing out returns the learner to the account page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryAuthRepository(_MemoryAuthRepository.member);
    final router = _createTestRouter(
      initialLocation: '/settings',
      authRepository: repository,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WortwerkApp(environment: AppEnvironment.emulator(), router: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Angemeldet als learner@wortwerk.test'), findsOneWidget);

    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Abmelden'));
    await tester.pumpAndSettle();

    expect(repository.signOutCalls, 1);
    // The session owner drives the redirect: a signed-out learner lands on the
    // account page instead of a dead settings screen.
    expect(find.text('Weiter als Gast'), findsOneWidget);
  });
}

GoRouter _createTestRouter({
  PlacementEvaluator placementEvaluator = const LocalPlacementEvaluator(),
  OnboardingProgressRepository? onboardingProgressRepository,
  LessonRepository? lessonRepository,
  LearningPathRepository? learningPathRepository,
  FritzChatRepository? fritzChatRepository,
  SpeechPracticeService? speechPracticeService,
  CommunityRepository? communityRepository,
  LocaleController? localeController,
  AuthRepository? authRepository,
  LearnerProfileRepository? profileRepository,
  String initialLocation = '/onboarding',
}) {
  final repository = authRepository ?? _MemoryAuthRepository();
  final authSession = AuthSessionBloc(repository: repository)
    ..add(const AuthSessionStarted());
  // bloc 9.2.1 close() deadlocks inside the widget-test fake zone; fire-and-
  // forget outside the awaited chain lets the real async teardown drain it.
  // ignore: discarded_futures
  addTearDown(() => unawaited(authSession.close()));
  return _createRouterWith(
    placementEvaluator: placementEvaluator,
    onboardingProgressRepository: onboardingProgressRepository,
    lessonRepository: lessonRepository,
    learningPathRepository: learningPathRepository,
    fritzChatRepository: fritzChatRepository,
    speechPracticeService: speechPracticeService,
    communityRepository: communityRepository,
    localeController: localeController,
    profileRepository: profileRepository,
    authRepository: repository,
    authSession: authSession,
    initialLocation: initialLocation,
  );
}

GoRouter _createRouterWith({
  required PlacementEvaluator placementEvaluator,
  required AuthRepository authRepository,
  required AuthSessionBloc authSession,
  OnboardingProgressRepository? onboardingProgressRepository,
  LessonRepository? lessonRepository,
  LearningPathRepository? learningPathRepository,
  FritzChatRepository? fritzChatRepository,
  SpeechPracticeService? speechPracticeService,
  CommunityRepository? communityRepository,
  LocaleController? localeController,
  LearnerProfileRepository? profileRepository,
  String initialLocation = '/onboarding',
}) => createAppRouter(
  placementEvaluator: placementEvaluator,
  authRepository: authRepository,
  authSession: authSession,
  lessonRepository: lessonRepository ?? _MemoryLessonRepository(),
  lessonContentRepository: _MemoryLessonContentRepository(),
  flashcardRepository: _MemoryFlashcardRepository(),
  fritzChatRepository: fritzChatRepository ?? _MemoryFritzChatRepository(),
  speechPracticeService:
      speechPracticeService ?? _MemorySpeechPracticeService(),
  hapticService: _MemoryHapticService(),
  learningStreakRepository: _MemoryLearningStreakRepository(),
  dailyMissionsRepository: _MemoryDailyMissionsRepository(),
  learningPathRepository:
      learningPathRepository ?? _MemoryLearningPathRepository(),
  onboardingProgressRepository:
      onboardingProgressRepository ?? _MemoryOnboardingProgressRepository(),
  notificationsRepository: _MemoryNotificationsRepository(),
  learnerPreferencesRepositoryFactory: _MemoryLearnerPreferencesRepository.new,
  learnerProfileRepositoryFactory: () =>
      profileRepository ?? _MemoryLearnerProfileRepository(),
  communityRepository: communityRepository ?? _MemoryCommunityRepository(),
  pushNotifications: _MemoryPushNotificationsController(),
  localeController:
      localeController ??
      LocaleController(store: _MemoryLocalePreferenceStore()),
  initialLocation: initialLocation,
);

final class _MemoryLearnerPreferencesRepository
    implements LearnerPreferencesRepository {
  @override
  Future<LearnerPreferences> load() async =>
      const LearnerPreferences(speechOutput: true);

  @override
  Future<void> save(LearnerPreferences preferences) async {}
}

final class _MemoryLearnerProfileRepository
    implements LearnerProfileRepository {
  LearnerProfile profile = const LearnerProfile(
    displayName: 'Test learner',
    level: 'A1',
    dailyMinutes: 10,
    xpTotal: 0,
    currentStreak: 0,
    longestStreak: 0,
    goals: [],
  );

  @override
  Stream<LearnerProfile?> watchProfile() => Stream.value(profile);

  @override
  Future<void> updateDisplayName(String displayName) async {
    profile = LearnerProfile(
      displayName: displayName,
      level: profile.level,
      dailyMinutes: profile.dailyMinutes,
      xpTotal: profile.xpTotal,
      currentStreak: profile.currentStreak,
      longestStreak: profile.longestStreak,
      goals: profile.goals,
    );
  }
}

final class _MemoryLocalePreferenceStore implements LocalePreferenceStore {
  AppLanguage? language;

  @override
  Future<AppLanguage?> load() async => language;

  @override
  Future<void> save(AppLanguage language) async {
    this.language = language;
  }
}

final class _MemoryNotificationsRepository implements NotificationsRepository {
  @override
  Stream<List<InboxNotification>> watchInbox() => Stream.value(const []);

  @override
  Future<void> markRead(String notificationId) async {}

  @override
  Future<bool> pushEnabled() async => false;

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    required String language,
  }) async {}

  @override
  Future<void> disablePush() async {}
}

final class _MemoryPushNotificationsController
    extends PushNotificationsController {
  final StreamController<PushNotice> _notices =
      StreamController<PushNotice>.broadcast();

  @override
  bool get enabled => false;

  @override
  bool get isWorking => false;

  @override
  PushNotificationProblem? get problem => null;

  @override
  Stream<PushNotice> get foregroundNotices => _notices.stream;

  void publish(PushNotice notice) => _notices.add(notice);

  @override
  Future<void> initialize({required void Function(String path) onOpen}) async {}

  @override
  Future<bool> enable(String language) async => false;

  @override
  Future<void> disable() async {}

  @override
  void dispose() {
    _notices.close();
    super.dispose();
  }
}

final class _MemoryCommunityRepository implements CommunityRepository {
  final Set<String> joined = {};
  final List<String> sentBodies = [];

  static const _group = LearningGroup(
    id: 'a1_alltag',
    name: 'A1 · Alltag',
    topic: 'Begrüßungen und erste Gespräche',
    level: 'A1',
    memberCount: 4,
  );

  @override
  String get currentUid => 'memory-uid';

  @override
  Stream<List<LearningGroup>> watchGroups() => Stream.value([_group]);

  @override
  Stream<Set<String>> watchJoinedGroupIds() => Stream.value(Set.of(joined));

  @override
  Stream<LearningGroup?> watchGroup(String groupId) =>
      Stream.value(groupId == _group.id ? _group : null);

  @override
  Stream<bool> watchMembership(String groupId) =>
      Stream.value(joined.contains(groupId));

  @override
  Stream<Set<String>> watchBlockedUids() => Stream.value(const {});

  @override
  Stream<List<CommunityMessage>> watchMessages(String groupId) =>
      Stream.value(const []);

  @override
  Future<void> joinGroup(String groupId) async {
    joined.add(groupId);
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    joined.remove(groupId);
  }

  @override
  Future<String> sendMessage({
    required String groupId,
    required String clientRequestId,
    required String body,
  }) async {
    sentBodies.add(body);
    return clientRequestId;
  }

  @override
  Future<void> reportMessage({
    required String groupId,
    required String messageId,
    required String reason,
  }) async {}

  @override
  Future<void> blockMember(String otherUid) async {}
}

final class _MemoryLearningPathRepository implements LearningPathRepository {
  _MemoryLearningPathRepository({this.unitAvailable = true});

  final bool unitAvailable;

  @override
  Future<LearningPath> getLearningPath() async => LearningPath(
    startingLevelId: 'A1',
    progressByLevel: {
      'A1': LearningLevelProgress(
        coreVocabularyCount: 10,
        retainedWords: 2,
        fritzConversations: 1,
      ),
    },
    levels: [
      LearningPathLevel(
        id: 'A1',
        title: 'A1',
        order: 1,
        units: [
          LearningPathUnit(
            id: 'a1_greetings',
            title: 'Greeting unit',
            order: 1,
            available: unitAvailable,
            lessons: [
              LearningPathLesson(
                id: 'a1_greetings',
                title: 'Greetings starter',
                order: 1,
                completed: false,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

final class _FailingPathRepository implements LearningPathRepository {
  int calls = 0;

  @override
  Future<LearningPath> getLearningPath() async {
    calls++;
    if (calls == 1) throw const SocketException('backend path details');
    return const LearningPath(levels: []);
  }
}

final class _MemoryLearningStreakRepository
    implements LearningStreakRepository {
  @override
  Stream<LearningStreakSummary> watchSummary() => Stream.value(
    LearningStreakSummary(
      current: 0,
      longest: 0,
      shields: 2,
      restWeekday: 0,
      activeDayIds: const {},
      profileExists: true,
    ),
  );
}

final class _MemoryDailyMissionsRepository implements DailyMissionsRepository {
  @override
  Stream<DailyMissions> watchToday() => Stream.value(
    const DailyMissions(
      date: '2026-10-09',
      focusGoal: 'Reisen',
      earnedXp: 0,
      tasks: [
        DailyMission(
          kind: DailyMissionKind.lesson,
          title: 'Eine Lektion abschließen',
          progress: 0,
          target: 1,
          xp: 20,
          completed: false,
        ),
        DailyMission(
          kind: DailyMissionKind.review,
          title: '10 Wörter wiederholen',
          progress: 0,
          target: 1,
          xp: 20,
          completed: false,
        ),
        DailyMission(
          kind: DailyMissionKind.fritz,
          title: 'Mit Fritz sprechen',
          progress: 0,
          target: 1,
          xp: 30,
          completed: false,
        ),
      ],
    ),
  );
}

final class _MemoryFlashcardRepository implements FlashcardRepository {
  @override
  Future<FlashcardReviewResult> completeReview({
    required List<FlashcardReviewAnswer> answers,
    required String clientRequestId,
  }) async => FlashcardReviewResult(
    reviewedCount: answers.length,
    rememberedCount: answers.where((answer) => answer.remembered).length,
    xpAwarded: 10,
  );
}

final class _MemoryHapticService implements HapticService {
  @override
  Future<void> emit(HapticEvent event) async {}
}

final class _MemoryFritzChatRepository implements FritzChatRepository {
  final watchedThreadIds = <String>[];
  final sentTexts = <String>[];
  final initialMessages = <FritzMessage>[];

  @override
  Stream<List<FritzMessage>> watchMessages({required String threadId}) {
    watchedThreadIds.add(threadId);
    return Stream.value(List.unmodifiable(initialMessages));
  }

  @override
  Future<void> sendMessage({
    required String text,
    required String mode,
    required String threadId,
    required String clientRequestId,
  }) async {
    sentTexts.add(text);
  }
}

final class _MemorySpeechPracticeService implements SpeechPracticeService {
  final spokenTexts = <String>[];
  @override
  Future<bool> startListening({
    required ValueChanged<String> onText,
    required ValueChanged<SpeechCaptureState> onState,
  }) async {
    onState(SpeechCaptureState.listening);
    onText('Guten Morgen');
    return true;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> speakGerman(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> dispose() async {}
}

final class _MemoryLessonRepository implements LessonRepository {
  @override
  Future<LessonCompletionResult> completeLesson({
    required String levelId,
    required String unitId,
    required String lessonId,
    required List<LessonAnswer> answers,
    required String clientRequestId,
  }) async => const LessonCompletionResult(accuracy: 1, xpAwarded: 10);
}

final class _MemoryLessonContentRepository implements LessonContentRepository {
  @override
  Future<LearningLesson> getLesson({
    required String levelId,
    required String unitId,
    required String lessonId,
  }) async {
    if (levelId != a1GreetingsLesson.levelId ||
        unitId != a1GreetingsLesson.unitId ||
        lessonId != a1GreetingsLesson.id) {
      throw const FormatException('No lesson configured for this test.');
    }
    return a1GreetingsLesson;
  }
}

final class _MemoryAuthRepository implements AuthRepository {
  _MemoryAuthRepository([AuthAccount? initial]) : _account = initial ?? guest {
    _snapshots.add(_account);
  }

  static const guest = AuthAccount(uid: 'test-guest', isAnonymous: true);

  /// A linkable password account, so the account-lifecycle tests exercise the
  /// non-guest branch (verification, password-confirmed deletion).
  static const member = AuthAccount(
    uid: 'test-member',
    isAnonymous: false,
    email: 'learner@wortwerk.test',
    providerIds: <String>['password'],
  );

  final StreamController<AuthAccount?> _snapshots =
      StreamController<AuthAccount?>();
  AuthAccount? _account;
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
    final refreshed = AuthAccount(
      uid: account.uid,
      isAnonymous: account.isAnonymous,
      email: account.email,
      displayName: account.displayName,
      emailVerified: true,
      providerIds: account.providerIds,
    );
    _account = refreshed;
    _snapshots.add(refreshed);
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
    _account = null;
    _snapshots.add(null);
  }

  Future<void> dispose() => _snapshots.close();
}

final class _MemoryOnboardingProgressRepository
    implements OnboardingProgressRepository {
  OnboardingDraft? draft;
  bool onboardingCompleted = false;

  @override
  Future<bool> ensureGuestProfile() async => onboardingCompleted;

  @override
  Future<OnboardingDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(OnboardingDraft value) async {
    draft = value;
  }

  @override
  Future<void> completeOnboarding({
    required OnboardingDraft draft,
    required LearningLevel level,
    required PlacementResult? placement,
  }) async {
    this.draft = draft;
    onboardingCompleted = true;
  }
}

final class _UnavailablePlacementEvaluator implements PlacementEvaluator {
  const _UnavailablePlacementEvaluator();

  @override
  Future<PlacementResult> evaluate({
    required LearningLevel startingLevel,
    required List<PlacementAnswer> answers,
  }) async {
    throw FirebaseFunctionsException(
      code: 'unavailable',
      message: 'The emulator is not running.',
    );
  }
}
