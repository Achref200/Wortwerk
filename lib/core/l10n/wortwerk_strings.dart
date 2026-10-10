import 'package:flutter/widgets.dart';

import '../localization/wortwerk_localizations.dart' as legacy;
import 'app_language.dart';

/// Every user-facing string the app renders through the catalog.
///
/// Keys are grouped by surface. Adding a key requires a value in both language
/// catalogs; `test/core/l10n/wortwerk_strings_test.dart` fails when one is
/// missing, which is the test-time guarantee the ARB workflow would otherwise
/// give. German is the source language and must stay verbatim for authored
/// copy; English is a faithful translation for the developer and for learners
/// who prefer English chrome.
enum WText {
  // Shell and navigation.
  navStart,
  navPath,
  navGroups,
  navProfile,
  askFritz,

  // Shared actions and states.
  retry,
  loading,
  open,

  // Shared failure component.
  failureTitle,
  failureNetwork,
  failureTimeout,
  failureContentMissing,
  failureNotFound,
  failurePermissionDenied,
  failureUnauthenticated,
  failureRateLimited,
  failureValidation,
  failureConflict,
  failureServer,

  // Bootstrap failure screen.
  bootstrapTitle,
  bootNetwork,
  bootTimeout,
  bootUnauthenticated,
  bootPermissionDenied,
  bootNotFound,
  bootRateLimited,
  bootServer,
  bootValidation,
  bootConflict,
  bootContentMissing,
  bootUnknown,

  // Route not found.
  routeNotFound,
  backToStart,

  // Authentication.
  authHeroHeadline,
  authHeroBody,
  authContinueGoogle,
  authContinueApple,
  authCreateTitle,
  authSignInTitle,
  authSignInBody,
  authCreateBody,
  authEmailLabel,
  authPasswordLabel,
  authPasswordHelper,
  authShowPassword,
  authHidePassword,
  authCreateButton,
  authEmailLinkButton,
  authForgotPassword,
  authSwitchToCreate,
  authSwitchToSignIn,
  authContinueAsGuest,
  authGuestNote,
  authBookIcon,
  authBusySemantics,
  authGuestReady,
  authLinked,
  authEmailRequired,
  authEmailInvalid,
  authEmailLinkInvalid,
  authPasswordTooShort,
  authSignedIn,
  authAccountCreated,
  authErrorGeneric,
  authFailureCredentialInUse,
  authFailureEmailLinkNotConfigured,
  authFailureNetwork,
  authFailureInvalidEmail,
  authFailureWeakPassword,
  authFailureBadCredentials,
  authFailureEmailInUse,
  authFailureInvalidLink,
  authFailureProviderUnavailable,
  authFailureCancelled,
  authFailureRecentLogin,
  authFailureRateLimited,
  authFailureDisabled,
  authEmailLinkSentTemplate,
  authResetSent,

  // Home.
  homeGreeting,
  homeQuestion,
  notifications,
  homeNextStep,
  homeYourPath,
  homePracticeWords,
  homePracticeWordsBody,
  homeSpeak,
  homeSpeakBody,
  homeRestNote,
  homeRestBody,
  homeProgressUnavailable,
  homeProgressLoading,
  homeGoalsDone,
  homeGoalsDoneBody,
  homeExtraPractice,
  homeSmallGoals,
  homeTaskLesson,
  homeTaskWords,
  homeTaskDone,
  homeTaskSemanticsDone,
  homeTaskSemanticsOpen,
  homeTaskProgressTemplate,
  lessonCardTag,
  lessonCardTitle,
  lessonCardBody,
  startLesson,

  // Community.
  communityTitle,
  communitySubtitle,
  communityEmptyTitle,
  communityEmptyBody,
  communityDiscover,
  communityPreparing,
  communityEyebrow,
  communityRules,
  communityFilterAll,
  communityFilterLevel,
  communityFilterFriends,
  communityFilterJoined,
  communityJoin,
  communityOpen,
  communityNoGroups,
  communityNoMessages,
  communityJoinConsentTitle,
  communityJoinConsentBody,
  communityAgeAttest,
  communityAcceptRules,
  communityMemberCountTemplate,
  communityMessageHint,
  communitySend,
  communityLeave,
  communityReport,
  communityBlock,
  communityReportSent,
  communitySendError,
  communityLoadError,
  communityJoinFailed,
  communityJoined,
  communityNotMember,
  communityYou,
  communityBack,
  communityReasonHarassment,
  communityReasonSpam,
  communityReasonUnsafe,
  communityReasonOther,

  // Fritz speaking practice.
  fritzMicStart,
  fritzMicStop,
  fritzMicListening,
  fritzMicUnavailable,
  fritzMicPermission,
  fritzMicError,
  fritzSpeakReply,
  fritzVoicePrivacy,
  fritzSpeechError,

  // Profile.
  profileTitle,
  settings,
  profileCardTitle,
  profileCardBody,
  profileLinkAccount,
  profileViewPlan,
  profileSectionPath,
  profileLinkLevels,
  profileLinkStreak,
  profileLinkNotifications,

  // Settings.
  settingsLearning,
  settingsDailyGoal,
  settingsReminder,
  settingsRestDay,
  settingsAdaptLevel,
  settingsAdaptLevelBody,
  settingsSpeech,
  settingsSpeechBody,
  settingsNotificationsHeader,
  settingsLearningReminder,
  settingsGroupMessages,
  settingsWeeklyReport,
  settingsPreviewNote,
  settingsLanguageHeader,
  settingsLanguageTitle,
  settingsLanguageBody,
  settingsTenMinutes,
  settingsTime,

  // Account (settings).
  accountHeader,
  accountGuestStatus,
  accountGuestStatusBody,
  accountSignedInStatusTemplate,
  accountUnverifiedBadge,
  accountVerifiedBadge,
  accountVerifyAction,
  accountVerifyBody,
  accountVerificationSent,
  accountRefreshAction,
  accountSignOutAction,
  accountSignOutConfirmTitle,
  accountSignOutConfirmBody,
  accountDeleteAction,
  accountDeleteBody,
  accountDeleteConfirmTitle,
  accountDeleteConfirmBody,
  accountDeletePasswordLabel,
  accountDeleteWarning,
  accountCancel,
  accountWorking,

  // Notifications inbox.
  notifTitle,
  notifSubtitle,
  notifEmpty,
  notifEmptyBody,
  notifToday,
  notifYesterday,
  notifEarlier,
  notifLevelUnlockedTitle,
  notifLevelUnlockedBodyTemplate,
  notifReminderTitle,
  notifReminderBody,
  notifGroupMessageTitle,
  notifGroupMessageBody,
  notifGenericTitle,
  notifGenericBody,
  notifMarkReadError,
  notifLoadError,
  notifUnread,
  pushPromptTitle,
  pushPromptBody,
  pushEnable,
  pushDisable,
  pushUnavailable,
  pushPermissionDenied,
  pushTokenUnavailable,
  pushServerError,

  // Level up.
  levelUpTitle,
  levelUpSubtitle,
  levelUpContinue,
  levelUpBadge,
  levelUpHeadline,
  levelUpBody,

  // Streak.
  streakTitle,
  streakSubtitle,
  streakLoading,
  streakError,
  streakNoProfile,
  streakDaySingular,
  streakDayPlural,
  streakZeroBody,
  streakActiveBody,
  streakThisWeek,
  streakMissionsTitle,
  streakMissionLesson,
  streakMissionLessonBody,
  streakMissionWord,
  streakMissionWordBody,
  streakMissionSentence,
  streakMissionSentenceBody,
  streakRestNote,
  streakToday,
  streakActiveDay,
  streakRestDay,
  streakNoDay,
  streakTodaySemantics,
  streakRestEyebrowTemplate,
  streakWeekSummaryTemplate,
  streakXpTodayTemplate,
  streakDaysInRowTemplate,
}

const _en = <WText, String>{
  WText.navStart: 'Home',
  WText.navPath: 'Path',
  WText.navGroups: 'Groups',
  WText.navProfile: 'Profile',
  WText.askFritz: 'Ask Fritz',

  WText.retry: 'Try again',
  WText.loading: 'Loading',
  WText.open: 'Open',

  WText.failureTitle: "That didn't work just now.",
  WText.failureNetwork: 'Check your connection and try again.',
  WText.failureTimeout: 'The request took too long.',
  WText.failureContentMissing: "This learning content isn't available.",
  WText.failureNotFound: "The requested data wasn't found.",
  WText.failurePermissionDenied: "You don't have access to this data.",
  WText.failureUnauthenticated: 'Please sign in again.',
  WText.failureRateLimited: 'Wait a moment and try again.',
  WText.failureValidation: "The data couldn't be validated.",
  WText.failureConflict: 'The data has changed. Load it again.',
  WText.failureServer: 'The service is unavailable right now. Try again.',

  WText.bootstrapTitle: "Wortwerk couldn't start.",
  WText.bootNetwork: 'No connection. Check your internet and try again.',
  WText.bootTimeout: 'The connection is taking too long. Try again.',
  WText.bootUnauthenticated: "Your session couldn't be verified.",
  WText.bootPermissionDenied:
      "Wortwerk can't access the data it needs right now.",
  WText.bootNotFound: "Required app data wasn't found.",
  WText.bootRateLimited: 'Please wait a moment and try again.',
  WText.bootServer: 'The service is unavailable right now. Try again.',
  WText.bootValidation: 'The app configuration is invalid. Please try again.',
  WText.bootConflict: 'Your data has changed. Please reload the app.',
  WText.bootContentMissing: "Learning content isn't available right now.",
  WText.bootUnknown: 'Please check your connection and try again.',

  WText.routeNotFound: "This page doesn't exist yet.",
  WText.backToStart: 'Back to start',

  WText.authHeroHeadline: 'Your learning — with you everywhere.',
  WText.authHeroBody:
      'Start as a guest and link your account whenever you like. That keeps '
      'your progress tied to the same session.',
  WText.authContinueGoogle: 'Continue with Google',
  WText.authContinueApple: 'Continue with Apple',
  WText.authCreateTitle: 'Create a password account',
  WText.authSignInTitle: 'Sign in',
  WText.authSignInBody:
      "Sign in with your existing Wortwerk account. This session's guest "
      "progress isn't moved into an existing account automatically.",
  WText.authCreateBody: 'Your account keeps your progress safe across devices.',
  WText.authEmailLabel: 'Email address',
  WText.authPasswordLabel: 'Password',
  WText.authPasswordHelper: 'At least six characters',
  WText.authShowPassword: 'Show password',
  WText.authHidePassword: 'Hide password',
  WText.authCreateButton: 'Create account',
  WText.authEmailLinkButton: 'Send an email link instead',
  WText.authForgotPassword: 'Forgot your password?',
  WText.authSwitchToCreate: 'No account yet? Create one',
  WText.authSwitchToSignIn: 'Already have an account? Sign in',
  WText.authContinueAsGuest: 'Continue as guest',
  WText.authGuestNote:
      'Your progress stays on this device until you link an account.',
  WText.authBookIcon: 'Learning book icon',
  WText.authBusySemantics: 'Your session is being linked securely',
  WText.authGuestReady: 'Your guest session is ready on this device.',
  WText.authLinked: 'Your account is linked to this session.',
  WText.authEmailRequired: 'Enter your email address first.',
  WText.authEmailInvalid: 'Enter a valid email address.',
  WText.authEmailLinkInvalid:
      'Enter a valid email address to get a sign-in link.',
  WText.authPasswordTooShort: 'Your password needs at least six characters.',
  WText.authSignedIn: 'You are signed in.',
  WText.authAccountCreated: 'Your account is created. Your progress is linked.',
  WText.authErrorGeneric: "Sign-in didn't work just now. Please try again.",
  WText.authFailureCredentialInUse:
      'This sign-in method belongs to another account. Your existing progress '
      'stays with your guest session.',
  WText.authFailureEmailLinkNotConfigured:
      "Email sign-in isn't available yet. You can use Google or Apple, or keep "
      'learning as a guest.',
  WText.authFailureNetwork: 'No connection. Check your internet and try again.',
  WText.authFailureInvalidEmail: 'Check your email address and try again.',
  WText.authFailureWeakPassword:
      'Choose a password with at least six characters.',
  WText.authFailureBadCredentials:
      'Email or password is incorrect. Please check your entry.',
  WText.authFailureEmailInUse:
      'An account already exists for this email. Sign in to open it.',
  WText.authFailureInvalidLink:
      'This sign-in link is invalid or expired. Please request a new one.',
  WText.authFailureProviderUnavailable:
      'This sign-in method is unavailable right now. Please try another.',
  WText.authFailureCancelled:
      'Sign-in was cancelled. You can try again at any time.',
  WText.authFailureRecentLogin:
      'Please sign in again to confirm this change. For your safety it needs a '
      'fresh sign-in.',
  WText.authFailureRateLimited:
      'Too many attempts. Please wait a moment and try again.',
  WText.authFailureDisabled:
      'This account has been disabled. Please contact support.',
  WText.authEmailLinkSentTemplate:
      'We sent a link to {email}. Open it on this device to link your guest '
      'session.',
  WText.authResetSent:
      'If an account exists for this address, a password reset email is on its '
      'way.',

  WText.homeGreeting: 'Good to see you',
  WText.homeQuestion: 'A small step?',
  WText.notifications: 'Notifications',
  WText.homeNextStep: 'Your next step',
  WText.homeYourPath: 'Your path',
  WText.homePracticeWords: 'Practise words',
  WText.homePracticeWordsBody: 'With flashcards',
  WText.homeSpeak: 'Speaking',
  WText.homeSpeakBody: 'With Fritz',
  WText.homeRestNote: 'Breaks are part of it.',
  WText.homeRestBody:
      'One rest day a week is allowed. Your learning path is waiting for you.',
  WText.homeProgressUnavailable:
      "Your daily progress isn't available right now.",
  WText.homeProgressLoading: 'Your daily progress is loading',
  WText.homeGoalsDone: 'Your goals are done.',
  WText.homeGoalsDoneBody:
      'A good moment for a break — or an optional extra round.',
  WText.homeExtraPractice: 'Continue practising (optional)',
  WText.homeSmallGoals: 'Small goals for today',
  WText.homeTaskLesson: 'Finish a lesson',
  WText.homeTaskWords: 'Review 10 words',
  WText.homeTaskDone: 'Done',
  WText.homeTaskSemanticsDone: ', completed',
  WText.homeTaskSemanticsOpen: ', open',
  WText.homeTaskProgressTemplate: 'Progress: {percent} percent',
  WText.lessonCardTag: 'A1 · UNIT 1',
  WText.lessonCardTitle: 'Greetings',
  WText.lessonCardBody: 'Saying hello and introducing yourself',
  WText.startLesson: 'Start lesson',

  WText.communityTitle: 'Learn together',
  WText.communitySubtitle: 'Find a group that fits your learning path.',
  WText.communityEmptyTitle: 'Your spot is still open.',
  WText.communityEmptyBody: 'Groups and messages appear here once you join.',
  WText.communityDiscover: 'Discover groups',
  WText.communityPreparing: 'Groups are being prepared right now.',
  WText.communityEyebrow: 'Together',
  WText.communityRules:
      'Practise kindly, respectfully and at your own pace. You stay in control '
      'of messages and groups.',
  WText.communityFilterAll: 'All',
  WText.communityFilterLevel: 'My level',
  WText.communityFilterFriends: 'Friends',
  WText.communityFilterJoined: 'Joined',
  WText.communityJoin: 'Join group',
  WText.communityOpen: 'Open group',
  WText.communityNoGroups: 'No groups match this view yet.',
  WText.communityNoMessages: 'A quiet room. Say hello when you are ready.',
  WText.communityJoinConsentTitle: 'A kind space for German practice',
  WText.communityJoinConsentBody: 'Groups are public to signed-in learners. Be respectful, keep personal details private, and report anything that feels unsafe.',
  WText.communityAgeAttest: 'I confirm that I am at least 16 years old.',
  WText.communityAcceptRules: 'I agree to the community rules.',
  WText.communityMemberCountTemplate: '{count} learners',
  WText.communityMessageHint: 'Write something in German…',
  WText.communitySend: 'Send',
  WText.communityLeave: 'Leave group',
  WText.communityReport: 'Report message',
  WText.communityBlock: 'Block learner',
  WText.communityReportSent: 'Thanks. The report was sent to the moderators.',
  WText.communitySendError: 'Your message could not be sent. You can retry it.',
  WText.communityLoadError: 'Groups could not be loaded. Try again.',
  WText.communityJoinFailed: 'You could not join this group. Please retry.',
  WText.communityJoined: 'You joined the group. Make yourself at home.',
  WText.communityNotMember: 'Join this group before opening its conversation.',
  WText.communityYou: 'You',
  WText.communityBack: 'Back to groups',
  WText.communityReasonHarassment: 'Harassment',
  WText.communityReasonSpam: 'Spam',
  WText.communityReasonUnsafe: 'Unsafe content',
  WText.communityReasonOther: 'Something else',
  WText.fritzMicStart: 'Dictate in German',
  WText.fritzMicStop: 'Stop dictation',
  WText.fritzMicListening: 'Listening in German… speak a short phrase.',
  WText.fritzMicUnavailable:
      'German speech recognition is unavailable on this device.',
  WText.fritzMicPermission:
      'Allow microphone and speech recognition to dictate.',
  WText.fritzMicError:
      'Speech recognition stopped. Try again or type your sentence.',
  WText.fritzSpeakReply: 'Listen to this German reply',
  WText.fritzVoicePrivacy: 'Your system recognizer creates the transcript. Fritz receives it only after you send it.',
  WText.fritzSpeechError:
      'Voice playback is unavailable. You can still read the reply.',

  WText.profileTitle: 'Your profile',
  WText.settings: 'Settings',
  WText.profileCardTitle: 'Your journey starts here.',
  WText.profileCardBody: 'Sign in to keep your progress safe across devices.',
  WText.profileLinkAccount: 'Link account',
  WText.profileViewPlan: 'View learning plan',
  WText.profileSectionPath: 'Your learning path',
  WText.profileLinkLevels: 'Levels and units',
  WText.profileLinkStreak: 'Learning rhythm',
  WText.profileLinkNotifications: 'Notifications',

  WText.settingsLearning: 'LEARNING',
  WText.settingsDailyGoal: 'Daily goal',
  WText.settingsReminder: 'Reminder',
  WText.settingsRestDay: 'Rest day per week',
  WText.settingsAdaptLevel: 'Adapt level',
  WText.settingsAdaptLevelBody: 'Your plan follows your progress.',
  WText.settingsSpeech: 'Speech output',
  WText.settingsSpeechBody: 'Listen to words out loud.',
  WText.settingsNotificationsHeader: 'NOTIFICATIONS',
  WText.settingsLearningReminder: 'Learning reminder',
  WText.settingsGroupMessages: 'Group messages',
  WText.settingsWeeklyReport: 'Weekly report',
  WText.settingsPreviewNote:
      'Changes apply to this preview. Settings are saved with your profile '
      "once you're signed in.",
  WText.settingsLanguageHeader: 'LANGUAGE',
  WText.settingsLanguageTitle: 'App language',
  WText.settingsLanguageBody:
      'Choose the language for menus and hints. Learning content stays in '
      'German.',
  WText.settingsTenMinutes: '10 minutes',
  WText.settingsTime: '18:00',

  WText.accountHeader: 'ACCOUNT',
  WText.accountGuestStatus: 'Guest session',
  WText.accountGuestStatusBody:
      'Your progress lives on this device until you link an account. Linking '
      'keeps the same session, so nothing is lost.',
  WText.accountSignedInStatusTemplate: 'Signed in as {email}',
  WText.accountUnverifiedBadge: 'Address not confirmed yet',
  WText.accountVerifiedBadge: 'Address confirmed',
  WText.accountVerifyAction: 'Confirm email address',
  WText.accountVerifyBody:
      'We send one link. Open it, then refresh this screen.',
  WText.accountVerificationSent:
      'A confirmation link is on its way. Open it and come back here.',
  WText.accountRefreshAction: 'I confirmed it — refresh',
  WText.accountSignOutAction: 'Sign out',
  WText.accountSignOutConfirmTitle: 'Sign out?',
  WText.accountSignOutConfirmBody:
      'You can carry on as a guest at any time, or sign back in later.',
  WText.accountDeleteAction: 'Delete account',
  WText.accountDeleteBody:
      'Removes your account and its identity on this device.',
  WText.accountDeleteConfirmTitle: 'Delete account?',
  WText.accountDeleteConfirmBody:
      'This cannot be undone. Your learning progress for this account is '
      'removed.',
  WText.accountDeletePasswordLabel: 'Password',
  WText.accountDeleteWarning:
      'Deleting needs a recent sign-in. Enter your password to confirm.',
  WText.accountCancel: 'Cancel',
  WText.accountWorking: 'Working…',

  WText.notifTitle: 'Updates',
  WText.notifSubtitle: "You're up to date.",
  WText.notifEmpty: 'No updates yet.',
  WText.notifEmptyBody: 'Your learning moments and news appear here.',
  WText.notifToday: 'Today',
  WText.notifYesterday: 'Yesterday',
  WText.notifEarlier: 'Earlier',
  WText.notifLevelUnlockedTitle: 'A new level is open',
  WText.notifLevelUnlockedBodyTemplate:
      'You unlocked {level}. Take a look at your next path.',
  WText.notifReminderTitle: 'A small step is waiting',
  WText.notifReminderBody: 'Your learning plan is ready when you are.',
  WText.notifGroupMessageTitle: 'A group message is waiting',
  WText.notifGroupMessageBody: 'Open your group to read the new message.',
  WText.notifGenericTitle: 'A Wortwerk update',
  WText.notifGenericBody: 'Open Wortwerk to see what is new.',
  WText.notifMarkReadError: 'This update could not be marked as read.',
  WText.notifLoadError: 'Your updates could not be loaded right now.',
  WText.notifUnread: 'Unread',
  WText.pushPromptTitle: 'A gentle reminder, when you want one',
  WText.pushPromptBody: 'Get a quiet nudge for your learning plan. You can switch reminders off any time.',
  WText.pushEnable: 'Enable reminders',
  WText.pushDisable: 'Turn reminders off',
  WText.pushUnavailable: 'Push reminders are unavailable in this preview.',
  WText.pushPermissionDenied:
      'Allow notifications in your device settings to turn reminders on.',
  WText.pushTokenUnavailable:
      'This device is not ready for push reminders yet.',
  WText.pushServerError:
      'Your reminder preference could not be saved. Please try again.',

  WText.levelUpTitle: 'A new chapter',
  WText.levelUpSubtitle: 'A step you can be proud of.',
  WText.levelUpContinue: 'Keep learning',
  WText.levelUpBadge: 'A NEW CHAPTER',
  WText.levelUpHeadline: 'Onward at your own pace.',
  WText.levelUpBody: 'Your next goal is waiting for you.',

  WText.streakTitle: 'Your learning rhythm',
  WText.streakSubtitle: 'Keep going, without pressure.',
  WText.streakLoading: 'Your learning rhythm is loading',
  WText.streakError: "Your learning rhythm couldn't be loaded just now.",
  WText.streakNoProfile: "Your learning profile isn't available right now.",
  WText.streakDaySingular: 'day in a row',
  WText.streakDayPlural: 'days in a row',
  WText.streakZeroBody:
      'Your first learning day starts with a short session. One rest day is '
      'planned each week.',
  WText.streakActiveBody: 'Good to see you back. Your rhythm stays your own.',
  WText.streakThisWeek: 'This week',
  WText.streakMissionsTitle: 'A small step for today',
  WText.streakMissionLesson: 'Start a lesson',
  WText.streakMissionLessonBody: '5 short questions · A1',
  WText.streakMissionWord: 'Review a word',
  WText.streakMissionWordBody: 'Flashcards',
  WText.streakMissionSentence: 'Practise a sentence with Fritz',
  WText.streakMissionSentenceBody: 'Conversation preview',
  WText.streakRestNote:
      "One rest day a week doesn't break your rhythm. A missed day is no "
      'reason to feel bad.',
  WText.streakToday: 'Today',
  WText.streakActiveDay: 'Learning day',
  WText.streakRestDay: 'Rest day',
  WText.streakNoDay: 'no learning day',
  WText.streakTodaySemantics: ', today',
  WText.streakRestEyebrowTemplate: 'YOUR REST DAY · {weekday}',
  WText.streakWeekSummaryTemplate:
      '{active} of 7 active days · longest rhythm: {longest} · shields: '
      '{shields}',
  WText.streakXpTodayTemplate: '+{xp} XP today · breaks are okay.',
  WText.streakDaysInRowTemplate: '{count} days in a row',
};

const _de = <WText, String>{
  WText.navStart: 'Start',
  WText.navPath: 'Weg',
  WText.navGroups: 'Gruppen',
  WText.navProfile: 'Profil',
  WText.askFritz: 'Fritz fragen',

  WText.retry: 'Erneut versuchen',
  WText.loading: 'Wird geladen',
  WText.open: 'Öffnen',

  WText.failureTitle: 'Das hat gerade nicht geklappt.',
  WText.failureNetwork: 'Prüfe deine Verbindung und versuche es erneut.',
  WText.failureTimeout: 'Die Anfrage hat zu lange gedauert.',
  WText.failureContentMissing: 'Dieser Lerninhalt ist nicht verfügbar.',
  WText.failureNotFound: 'Die angefragten Daten wurden nicht gefunden.',
  WText.failurePermissionDenied: 'Du hast keinen Zugriff auf diese Daten.',
  WText.failureUnauthenticated: 'Bitte melde dich erneut an.',
  WText.failureRateLimited: 'Warte kurz und versuche es dann erneut.',
  WText.failureValidation: 'Die Daten konnten nicht geprüft werden.',
  WText.failureConflict: 'Die Daten haben sich geändert. Lade sie neu.',
  WText.failureServer:
      'Der Dienst ist gerade nicht erreichbar. Versuche es erneut.',

  WText.bootstrapTitle: 'Wortwerk konnte nicht gestartet werden.',
  WText.bootNetwork:
      'Keine Verbindung. Prüfe dein Internet und versuche es erneut.',
  WText.bootTimeout: 'Die Verbindung dauert zu lange. Versuche es erneut.',
  WText.bootUnauthenticated: 'Deine Sitzung konnte nicht bestätigt werden.',
  WText.bootPermissionDenied:
      'Wortwerk kann gerade nicht auf benötigte Daten zugreifen.',
  WText.bootNotFound: 'Benötigte App-Daten wurden nicht gefunden.',
  WText.bootRateLimited: 'Bitte warte kurz und versuche es dann erneut.',
  WText.bootServer:
      'Der Dienst ist gerade nicht erreichbar. Versuche es erneut.',
  WText.bootValidation:
      'Die App-Konfiguration ist ungültig. Bitte versuche es erneut.',
  WText.bootConflict:
      'Deine Daten haben sich geändert. Bitte lade die App erneut.',
  WText.bootContentMissing: 'Lerninhalte sind gerade nicht verfügbar.',
  WText.bootUnknown: 'Bitte prüfe deine Verbindung und versuche es erneut.',

  WText.routeNotFound: 'Diese Seite gibt es noch nicht.',
  WText.backToStart: 'Zurück zum Start',

  WText.authHeroHeadline: 'Dein Lernen – überall dabei.',
  WText.authHeroBody:
      'Starte als Gast und verknüpfe dein Konto, wann immer du möchtest. So '
      'bleibt dein Lernfortschritt mit derselben Sitzung verbunden.',
  WText.authContinueGoogle: 'Mit Google fortfahren',
  WText.authContinueApple: 'Mit Apple fortfahren',
  WText.authCreateTitle: 'Konto mit Passwort erstellen',
  WText.authSignInTitle: 'Anmelden',
  WText.authSignInBody:
      'Melde dich mit deinem bestehenden Wortwerk-Konto an. Der Gastfortschritt '
      'dieser Sitzung wird nicht automatisch in ein bestehendes Konto '
      'übertragen.',
  WText.authCreateBody:
      'Dein Konto sichert deinen Lernfortschritt auf mehreren Geräten.',
  WText.authEmailLabel: 'E-Mail-Adresse',
  WText.authPasswordLabel: 'Passwort',
  WText.authPasswordHelper: 'Mindestens sechs Zeichen',
  WText.authShowPassword: 'Passwort anzeigen',
  WText.authHidePassword: 'Passwort verbergen',
  WText.authCreateButton: 'Konto erstellen',
  WText.authEmailLinkButton: 'Stattdessen E-Mail-Link senden',
  WText.authForgotPassword: 'Passwort vergessen?',
  WText.authSwitchToCreate: 'Noch kein Konto? Jetzt erstellen',
  WText.authSwitchToSignIn: 'Schon ein Konto? Anmelden',
  WText.authContinueAsGuest: 'Weiter als Gast',
  WText.authGuestNote:
      'Dein Lernfortschritt bleibt auf diesem Gerät, bis du ein Konto '
      'verknüpfst.',
  WText.authBookIcon: 'Lernbuch-Symbol',
  WText.authBusySemantics: 'Deine Sitzung wird sicher verknüpft',
  WText.authGuestReady: 'Deine Gastsitzung ist auf diesem Gerät bereit.',
  WText.authLinked: 'Dein Konto ist mit dieser Sitzung verknüpft.',
  WText.authEmailRequired: 'Gib zuerst deine E-Mail-Adresse ein.',
  WText.authEmailInvalid: 'Gib eine gültige E-Mail-Adresse ein.',
  WText.authEmailLinkInvalid:
      'Gib eine gültige E-Mail-Adresse ein, um einen Anmeldelink zu erhalten.',
  WText.authPasswordTooShort: 'Dein Passwort braucht mindestens sechs Zeichen.',
  WText.authSignedIn: 'Du bist angemeldet.',
  WText.authAccountCreated:
      'Dein Konto ist erstellt. Dein Lernfortschritt ist verknüpft.',
  WText.authErrorGeneric:
      'Die Anmeldung hat gerade nicht geklappt. Bitte versuche es erneut.',
  WText.authFailureCredentialInUse:
      'Diese Anmeldemethode gehört zu einem anderen Konto. Dein bisheriger '
      'Lernfortschritt bleibt mit deiner Gastsitzung verbunden.',
  WText.authFailureEmailLinkNotConfigured:
      'Die E-Mail-Anmeldung ist noch nicht verfügbar. Du kannst Google oder '
      'Apple verwenden oder als Gast weiterlernen.',
  WText.authFailureNetwork:
      'Keine Verbindung. Prüfe dein Internet und versuche es erneut.',
  WText.authFailureInvalidEmail:
      'Prüfe deine E-Mail-Adresse und versuche es erneut.',
  WText.authFailureWeakPassword:
      'Wähle ein Passwort mit mindestens sechs Zeichen.',
  WText.authFailureBadCredentials:
      'E-Mail-Adresse oder Passwort stimmen nicht. Bitte prüfe deine Eingabe.',
  WText.authFailureEmailInUse:
      'Für diese E-Mail gibt es bereits ein Konto. Melde dich an, um es zu '
      'öffnen.',
  WText.authFailureInvalidLink:
      'Dieser Anmeldelink ist ungültig oder abgelaufen. Bitte fordere einen '
      'neuen Link an.',
  WText.authFailureProviderUnavailable:
      'Diese Anmeldemethode ist gerade nicht verfügbar. Bitte versuche eine '
      'andere Methode.',
  WText.authFailureCancelled:
      'Die Anmeldung wurde abgebrochen. Du kannst es jederzeit erneut '
      'versuchen.',
  WText.authFailureRecentLogin:
      'Bitte melde dich erneut an, um diese Änderung zu bestätigen. Aus '
      'Sicherheitsgründen braucht sie eine frische Anmeldung.',
  WText.authFailureRateLimited:
      'Zu viele Versuche. Bitte warte einen Moment und versuche es erneut.',
  WText.authFailureDisabled:
      'Dieses Konto wurde deaktiviert. Bitte wende dich an den Support.',
  WText.authEmailLinkSentTemplate:
      'Wir haben einen Link an {email} gesendet. Öffne ihn auf diesem Gerät, '
      'um deine Gastsitzung zu verknüpfen.',
  WText.authResetSent:
      'Falls ein Konto zu dieser Adresse gehört, ist eine E-Mail zum '
      'Zurücksetzen des Passworts unterwegs.',

  WText.homeGreeting: 'Schön, dass du da bist',
  WText.homeQuestion: 'Ein kleiner Schritt?',
  WText.notifications: 'Benachrichtigungen',
  WText.homeNextStep: 'Dein nächster Schritt',
  WText.homeYourPath: 'Dein Weg',
  WText.homePracticeWords: 'Wörter üben',
  WText.homePracticeWordsBody: 'Mit Karteikarten',
  WText.homeSpeak: 'Sprechen',
  WText.homeSpeakBody: 'Mit Fritz',
  WText.homeRestNote: 'Pausen gehören dazu.',
  WText.homeRestBody:
      'Ein Ruhetag pro Woche ist erlaubt. Dein Lernweg wartet auf dich.',
  WText.homeProgressUnavailable:
      'Dein Tagesfortschritt ist gerade nicht verfügbar.',
  WText.homeProgressLoading: 'Dein Tagesfortschritt wird geladen',
  WText.homeGoalsDone: 'Deine Ziele sind geschafft.',
  WText.homeGoalsDoneBody:
      'Ein guter Moment für eine Pause — oder eine freiwillige Zusatzrunde.',
  WText.homeExtraPractice: 'Freiwillig weiterüben',
  WText.homeSmallGoals: 'Kleine Ziele für heute',
  WText.homeTaskLesson: 'Eine Lektion abschließen',
  WText.homeTaskWords: '10 Wörter wiederholen',
  WText.homeTaskDone: 'Erledigt',
  WText.homeTaskSemanticsDone: ', abgeschlossen',
  WText.homeTaskSemanticsOpen: ', offen',
  WText.homeTaskProgressTemplate: 'Fortschritt: {percent} Prozent',
  WText.lessonCardTag: 'A1 · EINHEIT 1',
  WText.lessonCardTitle: 'Begrüßungen',
  WText.lessonCardBody: 'Hallo sagen und sich vorstellen',
  WText.startLesson: 'Lektion beginnen',

  WText.communityTitle: 'Gemeinsam lernen',
  WText.communitySubtitle: 'Finde eine Gruppe, die zu deinem Lernweg passt.',
  WText.communityEmptyTitle: 'Dein Platz ist noch frei.',
  WText.communityEmptyBody:
      'Gruppen und Nachrichten erscheinen hier, sobald du beitrittst.',
  WText.communityDiscover: 'Gruppen entdecken',
  WText.communityPreparing: 'Gruppen werden gerade vorbereitet.',
  WText.communityEyebrow: 'Miteinander',
  WText.communityRules:
      'Übe freundlich, respektvoll und in deinem Tempo. Nachrichten und Gruppen '
      'werden von dir kontrolliert.',
  WText.communityFilterAll: 'Alle',
  WText.communityFilterLevel: 'Mein Niveau',
  WText.communityFilterFriends: 'Freunde',
  WText.communityFilterJoined: 'Dabei',
  WText.communityJoin: 'Gruppe beitreten',
  WText.communityOpen: 'Gruppe öffnen',
  WText.communityNoGroups: 'Für diese Ansicht gibt es noch keine Gruppen.',
  WText.communityNoMessages: 'Ein ruhiger Raum. Sag Hallo, wenn du magst.',
  WText.communityJoinConsentTitle: 'Ein freundlicher Ort zum Deutschüben',
  WText.communityJoinConsentBody: 'Gruppen sind für angemeldete Lernende sichtbar. Bleib respektvoll, teile keine persönlichen Daten und melde unsichere Inhalte.',
  WText.communityAgeAttest:
      'Ich bestätige, dass ich mindestens 16 Jahre alt bin.',
  WText.communityAcceptRules: 'Ich stimme den Gruppenregeln zu.',
  WText.communityMemberCountTemplate: '{count} Lernende',
  WText.communityMessageHint: 'Schreib etwas auf Deutsch…',
  WText.communitySend: 'Senden',
  WText.communityLeave: 'Gruppe verlassen',
  WText.communityReport: 'Nachricht melden',
  WText.communityBlock: 'Person blockieren',
  WText.communityReportSent:
      'Danke. Deine Meldung wurde an die Moderation gesendet.',
  WText.communitySendError: 'Deine Nachricht konnte nicht gesendet werden. Du kannst es erneut versuchen.',
  WText.communityLoadError:
      'Gruppen konnten nicht geladen werden. Bitte erneut versuchen.',
  WText.communityJoinFailed:
      'Du konntest der Gruppe nicht beitreten. Bitte versuche es erneut.',
  WText.communityJoined: 'Du bist dabei. Mach es dir in der Gruppe gemütlich.',
  WText.communityNotMember: 'Tritt der Gruppe bei, um das Gespräch zu öffnen.',
  WText.communityYou: 'Du',
  WText.communityBack: 'Zurück zu den Gruppen',
  WText.communityReasonHarassment: 'Belästigung',
  WText.communityReasonSpam: 'Spam',
  WText.communityReasonUnsafe: 'Unsicherer Inhalt',
  WText.communityReasonOther: 'Anderer Grund',
  WText.fritzMicStart: 'Auf Deutsch diktieren',
  WText.fritzMicStop: 'Diktat beenden',
  WText.fritzMicListening:
      'Fritz hört auf Deutsch zu … sprich einen kurzen Satz.',
  WText.fritzMicUnavailable:
      'Spracherkennung für Deutsch ist auf diesem Gerät nicht verfügbar.',
  WText.fritzMicPermission:
      'Erlaube Mikrofon und Spracherkennung für das Diktat.',
  WText.fritzMicError: 'Die Spracherkennung wurde beendet. Versuche es erneut oder tippe deinen Satz.',
  WText.fritzSpeakReply: 'Diese deutsche Antwort anhören',
  WText.fritzVoicePrivacy: 'Dein System erkennt die Sprache. Fritz erhält den Text erst, wenn du ihn sendest.',
  WText.fritzSpeechError: 'Die Sprachausgabe ist nicht verfügbar. Du kannst die Antwort weiterhin lesen.',

  WText.profileTitle: 'Dein Profil',
  WText.settings: 'Einstellungen',
  WText.profileCardTitle: 'Deine Reise beginnt hier.',
  WText.profileCardBody:
      'Melde dich an, um deinen Lernfortschritt geräteübergreifend zu sichern.',
  WText.profileLinkAccount: 'Konto verknüpfen',
  WText.profileViewPlan: 'Lernplan ansehen',
  WText.profileSectionPath: 'Dein Lernweg',
  WText.profileLinkLevels: 'Level und Einheiten',
  WText.profileLinkStreak: 'Lernrhythmus',
  WText.profileLinkNotifications: 'Benachrichtigungen',

  WText.settingsLearning: 'LERNEN',
  WText.settingsDailyGoal: 'Tagesziel',
  WText.settingsReminder: 'Erinnerung',
  WText.settingsRestDay: 'Ruhetag pro Woche',
  WText.settingsAdaptLevel: 'Niveau anpassen',
  WText.settingsAdaptLevelBody: 'Lernplan folgt deinem Fortschritt.',
  WText.settingsSpeech: 'Sprachausgabe',
  WText.settingsSpeechBody: 'Wörter laut anhören.',
  WText.settingsNotificationsHeader: 'BENACHRICHTIGUNGEN',
  WText.settingsLearningReminder: 'Lernerinnerung',
  WText.settingsGroupMessages: 'Gruppennachrichten',
  WText.settingsWeeklyReport: 'Wochenbericht',
  WText.settingsPreviewNote:
      'Änderungen gelten in dieser Vorschau. Einstellungen werden mit deinem '
      'Profil gespeichert, sobald du angemeldet bist.',
  WText.settingsLanguageHeader: 'SPRACHE',
  WText.settingsLanguageTitle: 'App-Sprache',
  WText.settingsLanguageBody:
      'Wähle die Sprache für Menüs und Hinweise. Lerninhalte bleiben auf '
      'Deutsch.',
  WText.settingsTenMinutes: '10 Minuten',
  WText.settingsTime: '18:00',

  WText.accountHeader: 'KONTO',
  WText.accountGuestStatus: 'Gastsitzung',
  WText.accountGuestStatusBody:
      'Dein Lernfortschritt bleibt auf diesem Gerät, bis du ein Konto '
      'verknüpfst. Beim Verknüpfen bleibt dieselbe Sitzung erhalten.',
  WText.accountSignedInStatusTemplate: 'Angemeldet als {email}',
  WText.accountUnverifiedBadge: 'Adresse noch nicht bestätigt',
  WText.accountVerifiedBadge: 'Adresse bestätigt',
  WText.accountVerifyAction: 'E-Mail-Adresse bestätigen',
  WText.accountVerifyBody:
      'Wir senden einen Link. Öffne ihn und aktualisiere danach diese Seite.',
  WText.accountVerificationSent:
      'Eine Bestätigungsmail ist unterwegs. Öffne den Link und komm hierher '
      'zurück.',
  WText.accountRefreshAction: 'Ich habe bestätigt – aktualisieren',
  WText.accountSignOutAction: 'Abmelden',
  WText.accountSignOutConfirmTitle: 'Abmelden?',
  WText.accountSignOutConfirmBody:
      'Du kannst jederzeit als Gast weitermachen oder dich später wieder '
      'anmelden.',
  WText.accountDeleteAction: 'Konto löschen',
  WText.accountDeleteBody:
      'Entfernt dein Konto und dessen Identität auf diesem Gerät.',
  WText.accountDeleteConfirmTitle: 'Konto löschen?',
  WText.accountDeleteConfirmBody:
      'Das kann nicht rückgängig gemacht werden. Der Lernfortschritt dieses '
      'Kontos wird entfernt.',
  WText.accountDeletePasswordLabel: 'Passwort',
  WText.accountDeleteWarning:
      'Zum Löschen ist eine frische Anmeldung nötig. Gib dein Passwort ein, um '
      'zu bestätigen.',
  WText.accountCancel: 'Abbrechen',
  WText.accountWorking: 'Wird ausgeführt…',

  WText.notifTitle: 'Hinweise',
  WText.notifSubtitle: 'Du bist auf dem Laufenden.',
  WText.notifEmpty: 'Noch keine Hinweise.',
  WText.notifEmptyBody: 'Deine Lernmomente und Neuigkeiten erscheinen hier.',
  WText.notifToday: 'Heute',
  WText.notifYesterday: 'Gestern',
  WText.notifEarlier: 'Älter',
  WText.notifLevelUnlockedTitle: 'Ein neues Niveau ist offen',
  WText.notifLevelUnlockedBodyTemplate:
      'Du hast {level} freigeschaltet. Sieh dir deinen nächsten Lernweg an.',
  WText.notifReminderTitle: 'Ein kleiner Schritt wartet',
  WText.notifReminderBody: 'Dein Lernplan ist bereit, wenn du es bist.',
  WText.notifGroupMessageTitle: 'Eine Gruppennachricht wartet',
  WText.notifGroupMessageBody:
      'Öffne deine Gruppe, um die neue Nachricht zu lesen.',
  WText.notifGenericTitle: 'Eine Neuigkeit von Wortwerk',
  WText.notifGenericBody: 'Öffne Wortwerk und entdecke, was neu ist.',
  WText.notifMarkReadError: 'Dieser Hinweis konnte nicht gelesen werden.',
  WText.notifLoadError: 'Deine Hinweise konnten gerade nicht geladen werden.',
  WText.notifUnread: 'Ungelesen',
  WText.pushPromptTitle: 'Eine sanfte Erinnerung, wenn du möchtest',
  WText.pushPromptBody: 'Erhalte einen kleinen Hinweis zu deinem Lernplan. Du kannst Erinnerungen jederzeit ausschalten.',
  WText.pushEnable: 'Erinnerungen aktivieren',
  WText.pushDisable: 'Erinnerungen ausschalten',
  WText.pushUnavailable:
      'Push-Erinnerungen sind in dieser Vorschau nicht verfügbar.',
  WText.pushPermissionDenied: 'Erlaube Mitteilungen in deinen Geräteeinstellungen, um Erinnerungen zu aktivieren.',
  WText.pushTokenUnavailable:
      'Dieses Gerät ist noch nicht für Push-Erinnerungen bereit.',
  WText.pushServerError: 'Deine Erinnerungseinstellung konnte nicht gespeichert werden. Bitte versuche es erneut.',

  WText.levelUpTitle: 'Ein neuer Abschnitt',
  WText.levelUpSubtitle: 'Ein Schritt, auf den du stolz sein kannst.',
  WText.levelUpContinue: 'Weiterlernen',
  WText.levelUpBadge: 'EIN NEUER ABSCHNITT',
  WText.levelUpHeadline: 'Weiter in deinem Tempo.',
  WText.levelUpBody: 'Dein nächstes Lernziel wartet auf dich.',

  WText.streakTitle: 'Dein Lernrhythmus',
  WText.streakSubtitle: 'Dranbleiben, ohne Druck.',
  WText.streakLoading: 'Dein Lernrhythmus wird geladen',
  WText.streakError: 'Dein Lernrhythmus konnte gerade nicht geladen werden.',
  WText.streakNoProfile: 'Dein Lernprofil ist gerade nicht verfügbar.',
  WText.streakDaySingular: 'Lerntag in Folge',
  WText.streakDayPlural: 'Lerntage in Folge',
  WText.streakZeroBody:
      'Dein erster Lerntag beginnt mit einer kurzen Einheit. Ein Ruhetag ist '
      'jede Woche eingeplant.',
  WText.streakActiveBody:
      'Schön, dass du wieder da bist. Dein Rhythmus bleibt dein eigener.',
  WText.streakThisWeek: 'Diese Woche',
  WText.streakMissionsTitle: 'Ein kleiner Schritt für heute',
  WText.streakMissionLesson: 'Eine Lektion beginnen',
  WText.streakMissionLessonBody: '5 kurze Fragen · A1',
  WText.streakMissionWord: 'Ein Wort wiederholen',
  WText.streakMissionWordBody: 'Karteikarten',
  WText.streakMissionSentence: 'Einen Satz mit Fritz üben',
  WText.streakMissionSentenceBody: 'Gesprächsvorschau',
  WText.streakRestNote:
      'Ein Ruhetag pro Woche unterbricht deinen Lernrhythmus nicht. Ein '
      'verpasster Tag ist kein Grund, dich schlecht zu fühlen.',
  WText.streakToday: 'Heute',
  WText.streakActiveDay: 'Lerntag',
  WText.streakRestDay: 'Ruhetag',
  WText.streakNoDay: 'kein Lerntag',
  WText.streakTodaySemantics: ', heute',
  WText.streakRestEyebrowTemplate: 'DEIN RUHETAG · {weekday}',
  WText.streakWeekSummaryTemplate:
      '{active} von 7 aktiven Tagen · längster Rhythmus: {longest} · '
      'Schutztage: {shields}',
  WText.streakXpTodayTemplate: '+{xp} XP heute · Pausen sind okay.',
  WText.streakDaysInRowTemplate: '{count} Lerntage in Folge',
};

/// German weekday names ordered Sunday-first, matching `DateTime.weekday % 7`.
const weekdaysLongDe = <String>[
  'Sonntag',
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
];

const weekdaysLongEn = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// Short weekday labels ordered Monday-first, matching the week strip.
const weekdaysShortDe = <String>['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const weekdaysShortEn = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Typed access to the localized copy catalog.
final class WortwerkStrings {
  const WortwerkStrings(this.language);

  final AppLanguage language;

  Map<WText, String> get _catalog => language == AppLanguage.en ? _en : _de;

  /// Returns the string for [key] in the active language.
  String call(WText key) {
    final value = _catalog[key];
    if (value != null) return value;
    // A missing translation must never crash the UI; fall back to the source
    // language and keep the key visible for whoever adds the entry.
    return _de[key] ?? key.name;
  }

  /// Translates a German source phrase when it is known UI copy. Unknown
  /// phrases are left intact so authored lesson content remains German.
  String fromSource(String source) {
    if (language == AppLanguage.de) return source;
    for (final entry in _de.entries) {
      if (entry.value == source) return _en[entry.key] ?? source;
    }
    return legacy.WortwerkLocalizations(const Locale('en')).text(source);
  }

  List<String> get weekdaysLong =>
      language == AppLanguage.en ? weekdaysLongEn : weekdaysLongDe;

  List<String> get weekdaysShort =>
      language == AppLanguage.en ? weekdaysShortEn : weekdaysShortDe;

  String restDayEyebrow(String weekday) =>
      _template(WText.streakRestEyebrowTemplate, {'weekday': weekday});

  String weekSummary({
    required int active,
    required int longest,
    required int shields,
  }) => _template(WText.streakWeekSummaryTemplate, {
    'active': '$active',
    'longest': '$longest',
    'shields': '$shields',
  });

  String xpToday(int xp) =>
      _template(WText.streakXpTodayTemplate, {'xp': '$xp'});

  String daysInRow(int count) {
    if (count == 1) {
      return language == AppLanguage.en
          ? '1 day in a row'
          : '1 Lerntag in Folge';
    }
    return _template(WText.streakDaysInRowTemplate, {'count': '$count'});
  }

  String taskProgress(int percent) =>
      _template(WText.homeTaskProgressTemplate, {'percent': '$percent'});

  String emailLinkSent(String email) =>
      _template(WText.authEmailLinkSentTemplate, {'email': email});

  String levelUnlockedBody(String level) =>
      _template(WText.notifLevelUnlockedBodyTemplate, {'level': level});

  String signedInAs(String email) =>
      _template(WText.accountSignedInStatusTemplate, {'email': email});

  String communityMemberCount(int count) =>
      _template(WText.communityMemberCountTemplate, {'count': '$count'});

  /// Maps a stable auth failure code onto learner-facing copy.
  String authFailure(String code) => switch (code) {
    'credential-already-in-use' || 'account-exists-with-different-credential' =>
      this(WText.authFailureCredentialInUse),
    'email-link-not-configured' => this(
      WText.authFailureEmailLinkNotConfigured,
    ),
    'network-request-failed' ||
    'network-error' ||
    'timeout' => this(WText.authFailureNetwork),
    'invalid-email' => this(WText.authFailureInvalidEmail),
    'weak-password' ||
    'missing-password' => this(WText.authFailureWeakPassword),
    'requires-recent-login' || 'user-mismatch' => this(
      WText.authFailureRecentLogin,
    ),
    'too-many-requests' => this(WText.authFailureRateLimited),
    'user-disabled' => this(WText.authFailureDisabled),
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => this(WText.authFailureBadCredentials),
    'email-already-in-use' => this(WText.authFailureEmailInUse),
    'invalid-email-link' ||
    'expired-action-code' ||
    'invalid-action-code' => this(WText.authFailureInvalidLink),
    'operation-not-allowed' ||
    'provider-error' => this(WText.authFailureProviderUnavailable),
    'popup-closed-by-user' || 'canceled' => this(WText.authFailureCancelled),
    _ => this(WText.authErrorGeneric),
  };

  String _template(WText key, Map<String, String> values) {
    var result = this(key);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}

/// Exposes the active [WortwerkStrings] to the widget tree.
///
/// When no scope is present (for example a widget test that pumps a page
/// directly) the German source catalog is used, so pages keep rendering their
/// authored copy.
final class WortwerkLocalizations extends InheritedWidget {
  const WortwerkLocalizations({
    required this.strings,
    required super.child,
    super.key,
  });

  final WortwerkStrings strings;

  static WortwerkStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WortwerkLocalizations>()
          ?.strings ??
      const WortwerkStrings(AppLanguage.fallback);

  static WortwerkStrings? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WortwerkLocalizations>()
      ?.strings;

  @override
  bool updateShouldNotify(WortwerkLocalizations oldWidget) =>
      oldWidget.strings.language != strings.language;
}

extension WortwerkLocalizationContext on BuildContext {
  /// Shorthand for the active catalog: `context.l10n(WText.navHome)`.
  WortwerkStrings get l10n => WortwerkLocalizations.of(this);
}
