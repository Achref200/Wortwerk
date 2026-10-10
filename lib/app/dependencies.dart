import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../core/haptics/haptic_service.dart';
import '../core/l10n/firestore_locale_preference_store.dart';
import '../core/l10n/locale_controller.dart';
import '../core/network/connectivity_data_source.dart';
import '../core/network/network_status_controller.dart';
import '../features/auth/auth.dart';
import '../features/community/data/firebase_community_repository.dart';
import '../features/community/domain/community_repository.dart';
import '../features/flashcards/data/callable_flashcard_repository.dart';
import '../features/flashcards/domain/flashcard_review.dart';
import '../features/fritz/data/firebase_fritz_chat_repository.dart';
import '../features/fritz/domain/fritz_message.dart';
import '../features/fritz/application/speech_practice_service.dart';
import '../features/lesson/data/callable_lesson_repository.dart';
import '../features/lesson/data/firestore_lesson_content_repository.dart';
import '../features/lesson/domain/lesson_repository.dart';
import '../features/onboarding/data/callable_placement_evaluator.dart';
import '../features/onboarding/data/firestore_onboarding_progress_repository.dart';
import '../features/onboarding/domain/onboarding_progress_repository.dart';
import '../features/onboarding/domain/placement_session.dart';
import '../features/notifications/data/firebase_notifications_repository.dart';
import '../features/notifications/domain/notifications_repository.dart';
import '../features/notifications/application/push_notifications_controller.dart';
import '../features/path/data/firestore_learning_path_repository.dart';
import '../features/path/domain/learning_path_repository.dart';
import '../features/streak/data/firestore_learning_streak_repository.dart';
import '../features/streak/domain/learning_streak_summary.dart';
import '../features/settings/data/firestore_learner_preferences_repository.dart';
import '../features/settings/domain/learner_preferences_repository.dart';
import '../features/profile/data/firestore_learner_profile_repository.dart';
import '../features/profile/domain/learner_profile_repository.dart';
import '../features/missions/data/firebase_daily_missions_repository.dart';
import '../features/missions/domain/daily_missions.dart';
import 'environment.dart';
import 'router.dart';

final GetIt dependencies = GetIt.instance;

Future<void> configureDependencies({
  required AppEnvironment environment,
  required FirebaseApp firebaseApp,
}) async {
  if (dependencies.isRegistered<AppEnvironment>()) {
    throw StateError('Wortwerk dependencies have already been configured.');
  }

  final functions = FirebaseFunctions.instanceFor(
    app: firebaseApp,
    region: environment.functionsRegion,
  );
  final lessonRepository = CallableLessonRepository(functions);
  final flashcardRepository = CallableFlashcardRepository(functions);
  final auth = FirebaseAuth.instanceFor(app: firebaseApp);
  final firestore = FirebaseFirestore.instanceFor(app: firebaseApp);
  final lessonContentRepository = FirestoreLessonContentRepository(firestore);
  const emailLinkContinueUrl = String.fromEnvironment(
    'AUTH_EMAIL_CONTINUE_URL',
  );
  final authRepository = FirebaseAuthAccountRepository(
    auth: auth,
    emailLinkSettings: emailLinkContinueUrl.isEmpty
        ? null
        : EmailLinkSettings(continueUrl: emailLinkContinueUrl),
  );
  await authRepository.ensureGuestSession();
  final guest = auth.currentUser;
  if (guest == null) {
    throw StateError('Guest sign-in completed without an authenticated user.');
  }
  String currentUid() => auth.currentUser?.uid ?? guest.uid;
  final deviceLanguage = LocaleController.deviceLanguage();
  final localeController = LocaleController(
    store: FirestoreLocalePreferenceStore(
      firestore: firestore,
      uid: guest.uid,
      uidProvider: currentUid,
    ),
    initialLanguage: deviceLanguage,
  );
  await localeController.load();
  final fritzChatRepository = FirebaseFritzChatRepository(
    firestore: firestore,
    functions: functions,
    uid: guest.uid,
    uidProvider: currentUid,
  );
  final speechPracticeService = DeviceSpeechPracticeService();
  final onboardingProgressRepository = FirestoreOnboardingProgressRepository(
    firestore: firestore,
    uid: guest.uid,
    uidProvider: currentUid,
    initialUiLang: deviceLanguage.code,
  );
  final hasCompletedOnboarding = await onboardingProgressRepository
      .ensureGuestProfile();
  final placementEvaluator = CallablePlacementEvaluator(functions);
  final learningStreakRepository = FirestoreLearningStreakRepository(
    firestore: firestore,
    uid: guest.uid,
    uidProvider: currentUid,
  );
  final dailyMissionsRepository = FirebaseDailyMissionsRepository(
    firestore,
    functions,
    currentUid,
  );
  final learningPathRepository = FirestoreLearningPathRepository(
    firestore: firestore,
    uid: guest.uid,
    uidProvider: currentUid,
  );
  LearnerPreferencesRepository learnerPreferencesRepository() =>
      FirestoreLearnerPreferencesRepository(
        firestore: firestore,
        uid: currentUid(),
      );
  LearnerProfileRepository learnerProfileRepository() =>
      FirestoreLearnerProfileRepository(
        firestore: firestore,
        uid: currentUid(),
      );
  final notificationsRepository = FirebaseNotificationsRepository(
    firestore: firestore,
    functions: functions,
    uid: guest.uid,
    uidProvider: currentUid,
  );
  final communityRepository = FirebaseCommunityRepository(
    firestore: firestore,
    functions: functions,
    auth: auth,
  );
  final pushNotifications = FirebasePushNotificationsController(
    messaging: FirebaseMessaging.instance,
    repository: notificationsRepository,
    authUidChanges: auth.userChanges().map((user) => user?.uid),
    language: () => localeController.language.code,
    useEmulators: environment.useEmulators,
    webVapidKey: environment.webVapidKey,
  );
  final hapticService = PlatformHapticService();
  final networkStatus = NetworkStatusController(ConnectivityPlusDataSource());
  // The session owner observes the provider stream for the whole app life; it
  // is created before the router so redirects can read it synchronously.
  final authSession = AuthSessionBloc(repository: authRepository)
    ..add(const AuthSessionStarted());
  final router = createAppRouter(
    placementEvaluator: placementEvaluator,
    authRepository: authRepository,
    lessonRepository: lessonRepository,
    lessonContentRepository: lessonContentRepository,
    flashcardRepository: flashcardRepository,
    fritzChatRepository: fritzChatRepository,
    speechPracticeService: speechPracticeService,
    hapticService: hapticService,
    learningStreakRepository: learningStreakRepository,
    dailyMissionsRepository: dailyMissionsRepository,
    learningPathRepository: learningPathRepository,
    onboardingProgressRepository: onboardingProgressRepository,
    notificationsRepository: notificationsRepository,
    communityRepository: communityRepository,
    pushNotifications: pushNotifications,
    localeController: localeController,
    learnerPreferencesRepositoryFactory: learnerPreferencesRepository,
    learnerProfileRepositoryFactory: learnerProfileRepository,
    authSession: authSession,
    initialLocation: hasCompletedOnboarding ? '/home' : '/onboarding',
  );
  await pushNotifications.initialize(onOpen: router.go);

  dependencies
    ..registerSingleton<AppEnvironment>(environment)
    ..registerSingleton<FirebaseApp>(firebaseApp)
    ..registerSingleton<FirebaseAuth>(auth)
    ..registerSingleton<AuthRepository>(authRepository)
    ..registerSingleton<AuthSessionBloc>(authSession)
    ..registerSingleton<FirebaseCrashlytics>(FirebaseCrashlytics.instance)
    ..registerSingleton<FirebaseFirestore>(firestore)
    ..registerSingleton<FirebaseFunctions>(functions)
    ..registerSingleton<LocaleController>(localeController)
    ..registerSingleton<LessonRepository>(lessonRepository)
    ..registerSingleton<FlashcardRepository>(flashcardRepository)
    ..registerSingleton<FritzChatRepository>(fritzChatRepository)
    ..registerSingleton<SpeechPracticeService>(speechPracticeService)
    ..registerSingleton<HapticService>(hapticService)
    ..registerSingleton<NetworkStatusController>(networkStatus)
    ..registerSingleton<LearningStreakRepository>(learningStreakRepository)
    ..registerSingleton<DailyMissionsRepository>(dailyMissionsRepository)
    ..registerSingleton<LearningPathRepository>(learningPathRepository)
    ..registerSingleton<NotificationsRepository>(notificationsRepository)
    ..registerSingleton<CommunityRepository>(communityRepository)
    ..registerSingleton<PushNotificationsController>(pushNotifications)
    ..registerSingleton<FirebaseStorage>(
      FirebaseStorage.instanceFor(app: firebaseApp),
    )
    ..registerSingleton<PlacementEvaluator>(placementEvaluator)
    ..registerSingleton<OnboardingProgressRepository>(
      onboardingProgressRepository,
    )
    ..registerSingleton<FirebaseRemoteConfig>(FirebaseRemoteConfig.instance)
    ..registerSingleton<GoRouter>(router);

  if (!environment.useEmulators) {
    dependencies.registerSingleton<FirebaseAnalytics>(
      FirebaseAnalytics.instanceFor(app: firebaseApp),
    );
  }
}
