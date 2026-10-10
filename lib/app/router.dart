import 'dart:async';

import 'package:wortwerk/core/l10n/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/haptics/haptic_service.dart';
import '../core/animations/motion.dart';
import '../core/animations/page_transitions.dart';
import '../core/l10n/locale_controller.dart';
import '../features/auth/auth.dart';
import '../features/community/domain/community_repository.dart';
import '../features/community/presentation/community_page.dart';
import '../features/flashcards/domain/flashcard_review.dart';
import '../features/flashcards/presentation/flashcards_page.dart';
import '../features/fritz/domain/fritz_message.dart';
import '../features/fritz/application/speech_practice_service.dart';
import '../features/lesson/domain/lesson_repository.dart';
import '../features/lesson/presentation/lesson_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/onboarding/domain/placement_session.dart';
import '../features/onboarding/domain/onboarding_progress_repository.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/notifications/domain/notifications_repository.dart';
import '../features/notifications/application/push_notifications_controller.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/path/presentation/learning_path_page.dart';
import '../features/path/domain/learning_path_repository.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/domain/learner_profile_repository.dart';
import '../features/settings/domain/learner_preferences_repository.dart';
import '../features/secondary/presentation/secondary_pages.dart';
import '../features/streak/domain/learning_streak_summary.dart';
import '../features/missions/domain/daily_missions.dart';
import 'primary_shell.dart';

GoRouter createAppRouter({
  required PlacementEvaluator placementEvaluator,
  required AuthRepository authRepository,
  required LessonRepository lessonRepository,
  required LessonContentRepository lessonContentRepository,
  required FlashcardRepository flashcardRepository,
  required FritzChatRepository fritzChatRepository,
  required SpeechPracticeService speechPracticeService,
  required HapticService hapticService,
  required LearningStreakRepository learningStreakRepository,
  required DailyMissionsRepository dailyMissionsRepository,
  required LearningPathRepository learningPathRepository,
  required OnboardingProgressRepository onboardingProgressRepository,
  required NotificationsRepository notificationsRepository,
  required CommunityRepository communityRepository,
  required PushNotificationsController pushNotifications,
  required LocaleController localeController,
  required LearnerPreferencesRepository Function()
  learnerPreferencesRepositoryFactory,
  required LearnerProfileRepository Function() learnerProfileRepositoryFactory,
  required AuthSessionBloc authSession,
  String initialLocation = '/onboarding',
}) => GoRouter(
  initialLocation: initialLocation,
  // A sign-out or account switch re-evaluates redirects immediately instead of
  // waiting for the next navigation.
  refreshListenable: _AuthSessionRefresh(authSession),
  redirect: (context, state) {
    final session = authSession.state;
    // Before the first snapshot the app cannot know whether a session exists,
    // so it must not move the learner away from the route it is opening.
    if (!session.isResolved) return null;
    if (session.isSignedOut && state.matchedLocation != '/account') {
      return '/account';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (context, state) => initialLocation),
    GoRoute(
      path: '/account',
      name: 'account',
      pageBuilder: (context, state) => _fadePage(
        state,
        AuthAccountPage(
          repository: authRepository,
          onContinueAsGuest: (_) => context.go('/home'),
          onAccountLinked: (_) => context.go('/home'),
        ),
      ),
    ),
    GoRoute(
      path: '/lesson/:lessonId',
      name: 'lesson',
      pageBuilder: (context, state) {
        final lessonId = state.pathParameters['lessonId'];
        final legacyGreetingLesson = lessonId == 'a1_greetings';
        final levelId =
            state.uri.queryParameters['level'] ??
            (legacyGreetingLesson ? 'A1' : null);
        final unitId =
            state.uri.queryParameters['unit'] ??
            (legacyGreetingLesson ? 'a1_greetings' : null);
        if (levelId == null || unitId == null || lessonId == null) {
          return _fadePage(state, const RouteNotFoundPage());
        }
        return _fadePage(
          state,
          LessonPage(
            repository: lessonRepository,
            contentRepository: lessonContentRepository,
            levelId: levelId,
            unitId: unitId,
            lessonId: lessonId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => OnboardingPage(
        placementEvaluator: placementEvaluator,
        progressRepository: onboardingProgressRepository,
        pushNotifications: pushNotifications,
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          WortwerkPrimaryShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => HomePage(
                key: ValueKey('home:${authRepository.currentUserId}'),
                streakRepository: learningStreakRepository,
                missionsRepository: dailyMissionsRepository,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/path',
              name: 'path',
              builder: (context, state) => LearningPathPage(
                key: ValueKey('path:${authRepository.currentUserId}'),
                repository: learningPathRepository,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/groups',
              name: 'groups',
              builder: (context, state) =>
                  CommunityPage(repository: communityRepository),
              routes: [
                GoRoute(
                  path: ':groupId',
                  name: 'community-group',
                  builder: (context, state) => CommunityGroupPage(
                    repository: communityRepository,
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => ProfilePage(
                key: ValueKey('profile:${authRepository.currentUserId}'),
                authSession: authSession,
                repository: learnerProfileRepositoryFactory(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/streak',
      name: 'streak',
      pageBuilder: (context, state) => _fadePage(
        state,
        StreakPage(
          key: ValueKey('streak:${authRepository.currentUserId}'),
          repository: learningStreakRepository,
        ),
      ),
    ),
    GoRoute(
      path: '/flashcards',
      name: 'flashcards',
      pageBuilder: (context, state) => _fadePage(
        state,
        FlashcardsPage(
          repository: flashcardRepository,
          hapticService: hapticService,
        ),
      ),
    ),
    GoRoute(
      path: '/tutor',
      name: 'tutor',
      pageBuilder: (context, state) => _fadePage(
        state,
        FritzTutorPage(
          key: ValueKey(
            '${authRepository.currentUserId}:${state.uri.queryParameters['thread'] ?? 'main'}',
          ),
          repository: fritzChatRepository,
          speechPracticeService: speechPracticeService,
          preferencesRepository: learnerPreferencesRepositoryFactory(),
          initialPrompt: state.uri.queryParameters['prompt'] ?? '',
          initialMode: state.uri.queryParameters['mode'] ?? 'chat',
          threadId: state.uri.queryParameters['thread'] ?? 'main',
        ),
      ),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => SettingsPage(
        key: ValueKey('settings:${authRepository.currentUserId}'),
        localeController: localeController,
        preferencesRepository: learnerPreferencesRepositoryFactory(),
        pushNotifications: pushNotifications,
        authSession: authSession,
      ),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      pageBuilder: (context, state) => _fadePage(
        state,
        NotificationsPage(
          key: ValueKey('notifications:${authRepository.currentUserId}'),
          repository: notificationsRepository,
        ),
      ),
    ),
    GoRoute(
      path: '/level-up',
      name: 'level-up',
      pageBuilder: (context, state) => _fadePage(state, const LevelUpPage()),
    ),
  ],
  errorBuilder: (context, state) => const RouteNotFoundPage(),
);

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: MotionDurations.transition,
      reverseTransitionDuration: MotionDurations.transition,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
    );

/// Bridges the session bloc's state stream to `GoRouter.refreshListenable`.
///
/// `GoRouter` needs a [Listenable], and a Bloc exposes a `Stream`; this keeps
/// the adapter private so no page has to know about the router's plumbing.
final class _AuthSessionRefresh extends ChangeNotifier {
  _AuthSessionRefresh(AuthSessionBloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthSessionState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final class RouteNotFoundPage extends StatelessWidget {
  const RouteNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LocalizedText('Diese Seite gibt es noch nicht.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => GoRouter.of(context).go('/home'),
                child: const LocalizedText('Zurück zum Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
