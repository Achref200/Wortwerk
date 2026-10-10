# Wortwerk experience audit

Audit date: 2026-10-07  
Scope: the product requirements in `docs/SPEC.md`, decisions and shipped slices in `docs/DECISIONS.md` and `README.md`, AutoClaw task history, and current Flutter/Firebase source.

## Current state

Wortwerk has a real, server-backed first learning slice. It does not yet meet the build specification for a complete A1-C2 learning product. Treat screens with local-only controls, preview copy, or no repository as prototypes; a visible button is not evidence that its workflow is implemented.

### Verified end-to-end slices

- Anonymous Firebase sign-in and account linking interfaces for Google, Apple, and email link exist. Email linking requires `AUTH_EMAIL_CONTINUE_URL` and external provider setup.
- Onboarding draft persistence, goal/time/self-assessment selection, adaptive placement questions, server evaluation, and a self-assessed fallback exist.
- One five-question A1 greetings lesson is read from a canonical JSON seed into Firestore. The app renders the published document, and `completeLesson` loads that same published level/unit/lesson before validating answers and computing XP server-side.
- The existing A1 greetings lesson now has one JSON content source seeded into `levels/A1/units/a1_greetings/lessons/a1_greetings`. The app renders that published Firestore document, and `completeLesson` reads the same document for server-side answer validation and scoring. The remote project remains unseeded until explicit authenticated provisioning.
- A ten-card A1 greetings review is persisted by `completeFlashcardReview`, with retry-safe request IDs and a basic learning interval.
- Completed lessons/reviews update server-owned streak and XP data. Weekly rest day and shields are represented in the streak calculation.
- Home now reads the server-backed streak/day summary and displays today's earned XP plus completion progress for the available lesson and ten-card review activities, including loading/error states.
- When both available Home activities are complete, the checklist now transitions to a low-pressure celebration with optional extra practice.
- Home now listens to three persisted daily missions initialized by `getDailyMissions`. Lesson, ten-card review, and qualifying Fritz completion update the mission document transactionally and award each mission's XP once; the Home card shows goal focus, progress, completion, retry, and loading states.
- A shared `AsyncResourceController<T>` now models idle/loading/data/empty/offline/failure states, retains prior data during refreshes, ignores stale request completions, and notifies listeners. The published lesson flow is wired through lesson use cases and a controller, with explicit empty/offline/error retry UIs. A connectivity data source/controller drives an app-wide offline banner and refreshes on app resume. Home's streak stream has an explicit retry action for errors. The Fritz loading illustration is now a native animated vector with reduced-motion support and a finite entrance so it does not run forever.
- Flutter static analysis, full-suite tests, Cloud Functions compilation and unit tests are recorded with their latest results in Verification performed below.

These slices have focused tests, but are much narrower than the launch curriculum and full specification.

## Screen and workflow comparison

| Surface / workflow | Current implementation | Required result and gap | Status |
|---|---|---|---|
| Startup and routing | Router starts at onboarding or home after profile lookup. | No splash/config gate, minimum-version, maintenance, offline route, or auth/onboarding redirect state machine. | Partial |
| Authentication | Anonymous session; Google/Apple linking; email link; email/password account creation, sign-in, and reset. Password registration links to the active guest so its UID and progress are retained. Auth success routes into the learning shell. | End-to-end provider configuration, email-link return handling, sign-out, reauthentication, verification/deletion, account migration, and complete localized auth copy remain. Signing into a different account leaves the guest profile separate; the form now explains that. | Partial |
| Onboarding | Goals, daily minutes, self-assessment, adaptive A1-B1 placement, saved draft, plan completion. | No full seven-step experience: name capture, reminder choice/pre-permission education, localization, offline handling across steps, and all resume/error cases need specification-level review. | Partial |
| Home | Live streak, today's XP, and activity progress come from server summaries. Three persisted goal-focused missions show lesson, review, and Fritz progress and award XP on server-confirmed completion. The two current practice activities have a separate low-pressure completion card. | No profile/continue-learning repository, personalized next lesson, weekly XP summary, or pull-to-refresh; missions still use a fixed activity set rather than goal-specific choices. | Partial |
| Learning path | A Firestore repository loads published levels, units, lessons, per-lesson completion, level criteria, and unlock grants. The path shows live word-retention, Fritz-conversation, and review criteria. Lesson completion checks server-owned level grants and requires previous units to be complete with at least 60% average, while placement sets the starting level/unit. | Locked-unit explanation UI, unit detail, chest, curriculum beyond the one published lesson, automatic path refresh after completion, and emulator verification remain. The repository uses one-shot reads and an explicit refresh action. | Partial |
| Lesson | Published question content is loaded from Firestore; server completion fetches the same document and validates its answer key. Loading, unavailable-content retry, local feedback, and server save retry are present. | Still only one existing five-question multiple-choice lesson. No per-answer resume/outbox, varied question types, authored/reviewed curriculum pipeline beyond this migration, standalone result route, or retry-errors flow. | Partial |
| Lesson result | A result is shown inline after the callable returns. | No full result flow with skill breakdown, learned words, confirmed XP animation, daily mission progress, offline-pending state, or progression/level-up handoff. | Partial |
| Flashcards | Ten A1 greeting cards, flip, rating buttons, server-persisted review schedule, loading/error states. | No content deck repository, due/new deck selection, audio, article color chips, swipe gestures, resume/offline outbox, flexible session length, or empty-due experience. | Partial |
| Streak and missions | Firestore streak summary, current count, active week strip, three shortcut actions, shields/rest day copy; daily mission document and Home completion state are server-backed. | Three-week activity grid, chest, at-risk/broken recovery offer, streak celebration trigger, weekly mission flow, and timezone/DST integration coverage remain. | Partial |
| Fritz assistant / tutor | Firestore chat, retry-safe messages, persisted threads, `fritzChat` callable, German-learning modes, Secret Manager adapters with timeout fallback, input limits, and usage throttles. Provider use defaults off. Six learner turns update server-owned conversation progression. German speech recognition adds a reviewable transcript before send; tutor replies have optional German speech playback. | AI remains disabled until exposed keys are revoked and replacement secrets are configured. Speech permissions and behavior need physical-device verification; output scope lacks response-policy and topic validation. Client history/search and emulator verification remain. | Implemented but gated |
| Groups | Streams curated public groups; supports level filters, consent-gated join, leave, member chat, message reports, block controls, loading/error/empty states, and full-screen composer. Server limits messages and hides after three unique reports. | No DMs/friend requests, group creation, pagination, unread/read state, moderator console/appeals, profanity or German-scope filtering; block filtering is client-side; age self-attestation policy needs release confirmation. | Partial |
| Profile | Reads the signed-in learner's Firestore display name, CEFR level, goals, daily goal, XP, and current/longest streak; validates and saves display-name edits to that learner's profile. Account email remains sourced from Firebase Auth. | Avatar customization, skill/badge progress, friends, data export, and deletion/export review remain. | Partial |
| Settings | English/German interface language is persisted to `users/{uid}.uiLang`. Daily minutes, reminder time, rest weekday, adaptive-level choice, speech-output choice, and notification category choices now load/save through a user-scoped Firestore repository/controller. Load and save failures have explicit retry/feedback states; Firestore rules validate owner updates. Push permission/device registration remains in the notification controller. | Local reminder scheduling and enforcement of notification categories are not yet connected; adaptive-plan and speech preferences still need to drive their respective workflows. Review untranslated interface copy across every route and complete accessibility/localization coverage. | Partial |
| Notifications inbox | Streams the signed-in learner's server-owned Firestore inbox; shows loading, empty, retryable failure and grouped Today/Yesterday/Earlier states. Cached items remain visible with a retry banner after stream errors. Unread items have an accessible marker and swipe-to-read; the owner-scoped callable updates `readAt`; trusted level-unlock transactions create a localized inbox event with a `/path` deep link. Push permission, authenticated registration, per-device localization, foreground presentation, safe tap routing, and opt-out are wired. | Physical delivery still needs APNs/Xcode and web push setup. Local scheduling, daily/reminder/group notification producers, unread badge count, and notification category preferences remain. | Partial |
| Level-up | Reachable celebration screen with sparkle reveal. | Not triggered by a verified server unlock; no new level/reward payload, shield/cosmetic award, tap-to-skip, or focused next-node navigation. | Visual only |
| Insights | No route or screen. | Weekly/monthly/all-time charts, skill summaries, heatmap, empty and accessible summaries are absent. | Not implemented |

## Cross-cutting requirements

| Requirement | Evidence and remaining work | Status |
|---|---|---|
| Design system | Theme colors/type and reusable cards exist. Tokens are not consistently centralized; component state catalog, Widgetbook, golden gallery, Rive assets, and design QA are absent. | Partial |
| Motion and touch feedback | Lesson answer feedback draws a correct or incorrect mark; a server-confirmed result gets a finite confetti burst, staged reveal, animated accuracy ring, and XP count-up. Home uses a finite flame entrance, rolling streak digits, XP count-up, and press-scale feedback. Lesson, streak, flashcard, tutor, notifications, account, and level-up full-screen routes share the 300 ms fade-through transition. Existing reduced-motion handling remains active. The learning-path current node carries a `PulseHalo` attention ring (static under reduced motion, layout-pinned so it never overflows). | Partial: continuous path motion still needs off-screen/background pausing; route/lesson choreography needs device and accessibility review; haptic service is not consistently connected. |
| Accessibility | Some live regions and semantic labels exist. A 200% text pass, 48dp audit, full screen-reader and keyboard review, RTL, and reduced-motion coverage are not demonstrated. | Partial |
| Localization | Typed English/German catalogs and a source-copy translator are exposed app-wide. Settings resolves the active language from device locale, loads/saves `users/{uid}.uiLang`, and retains German for uncatalogued lesson text. | Audit remaining interface labels and semantics screen by screen; `explainLang` behavior, RTL, French/Arabic, and full locale/accessibility coverage remain. | Partial |
| Offline behavior | A transport-status banner and reconnect check now exist, and lesson reads distinguish offline from other failures while preserving stale data. `connectivity_plus` detects network transport only, not actual internet or Firebase reachability; repository failures remain authoritative. Durable lesson outbox/resume and reconnect reconciliation across the other flows are still absent. | Partial |
| Analytics and observability | Analytics/Crashlytics dependencies are registered outside emulator mode. Required event coverage, PII audit, dashboards, and crash-free release evidence are absent. | Partial |
| Security/compliance | Firestore rules and storage rules exist. App Check, community UGC safeguards, account lifecycle, privacy export/deletion verification, and a full security review are outstanding. | Partial |
| Firestore provisioning | Active learning paths, server-owned write boundaries, content read rules, schema versioning, and planned composite indexes are recorded in `docs/FIRESTORE_SCHEMA.md`. The workspace targets the dev emulator; the linked project was not accessible, so no remote schema or content was written. | Local structure only |
| Figma verification | Figma is documented as source of truth; MCP quota is exhausted and `screenshots/` contains no captured screen set. Pixel/layout comparison has not been performed in this session. | Blocked on Figma editor/MCP access |

## Delivery plan and TODO reconciliation

The AutoClaw board currently has no active or claimable tickets. The task ledger records completed implementation slices, not the open product scope below. The delivery milestones in `docs/SPEC.md` therefore remain the authoritative backlog; a prior completed slice must not be mistaken for milestone completion.

| Milestone | Assessment |
|---|---|
| M0 Foundation | Partial: app/Firebase setup exists; emulator suite, all flavor runs, and CI evidence are not verified here. |
| M1 Design system | Partial: theme/components exist; variants, gallery, goldens, and animation kit are incomplete. |
| M2 Auth and onboarding | Partial: guest, linking methods, saved onboarding, placement exist; end-to-end platform/provider and notification setup are incomplete. |
| M3 Content and lessons | Partial: one existing A1 lesson has a Firestore reader, idempotent Admin SDK seeder, and server scoring from published content; full authored/reviewed curriculum, exercise variety, per-answer resume, and deck content remain. |
| M4 Flashcards | Partial: ten-card A1 slice works; full decks, due queue, offline support, and full SRS validation remain. |
| M5 Streak, XP, missions | Partial: streak/XP and three daily missions update in trusted transactions; weekly chest, recovery offer, goal-specific mission selection, and full date-boundary verification remain. |
| M6 Path and unlocks | Partial: published A1 core vocabulary, review retention, Fritz conversation counts, and passing review rounds feed server-owned criteria; the server creates a level grant once all three are met, advances the active CEFR level, awards 120 XP and one shield, and gates lesson completion. Earlier levels remain accessible. Later units require all prior lessons and 60% average. Path UI reads and displays level criteria and explains locked units. Full multi-level curriculum, level-up animation handoff, and emulator verification remain. |
| M7 Fritz | Partial: chat UI, server callable, provider fallback, persistence, rate limits, retry, six-turn progression, speech-to-text, and German text-to-speech exist. Provider use remains gated; response-policy/topic validation and physical-device speech verification remain. |
| M8 Community | Partial: curated group discovery, consent-gated join/leave, callable chat, reports, block, and auto-hide are verified locally. DMs/friends, moderator tooling, pagination, unread state, and full UGC safeguards remain. |
| M9 Notifications/settings/profile/insights | Partial: Firestore inbox, FCM level-unlock delivery, secure device lifecycle, and read-state workflow exist. Local scheduling and group/reminder producers, persisted settings beyond language, profile statistics and insights remain incomplete. |
| M10 Hardening | Not verified: accessibility, localization, offline matrix, security/performance, and device coverage remain. |
| M11 Beta | Not started: no release build, store package, or stability evidence. |

## Ordered completion backlog

1. **Restore a verifiable development gate:** provision free disk and Java 21/Firebase Emulator Suite, run Flutter tests, Functions tests, emulator smoke suite, and device builds; connect the repository/CI workflow and capture its result.
2. **Protect and finish the AI boundary:** revoke the three credentials pasted in the conversation. After replacement credentials are issued, configure provider secrets in Firebase Secret Manager and explicitly set `FRITZ_AI_ENABLED=true`; leave it false before that. Add response scope and level-topic validation. Verify speech permissions on Android/iOS devices, then verify callable, rules, fallback, and client states in the emulator. Never ship provider credentials in Flutter or source control.
3. **Complete one authored A1 unit:** create reviewed seed content and content repository; deliver multiple lesson types and per-answer persistence/resume; finish result/redo flow and offline completion reconciliation.
4. **Finish the daily learning loop:** make mission selection reflect learner goals, add weekly missions/chest and streak recovery, complete timezone-boundary coverage, and add Home profile/continue-learning and weekly XP data.
5. **Finish progression:** extend server-owned criteria and access grants across authored A1-C2 content; add locked-unit explanations, level-up navigation/reward confirmation, and path refresh. Verify all transaction paths in Firestore emulators.
6. **Expand the curriculum:** author and review A1 (six units), A2 (six), and B1 (four) content before presenting them as available. Keep B2-C2 honestly labeled as future until content and validation exist.
7. **Finish community:** friend requests and direct messages with recipient controls, query-safe block enforcement, paginated history, unread/read state, human moderator console and appeals, and German-learning scope safeguards. The starter group flow is callable-backed; UGC still needs operational moderation before release.
8. **Finish design and release quality:** capture Figma comparisons at 390x844, 360x800 and large text; implement EN/FR/AR and RTL; run a11y/reduced-motion/offline/timezone/security/performance scenario matrices and collect release evidence.
9. **Extend notification delivery:** the opt-in/token/FCM level-unlock slice is complete and emulator-verified. Add local scheduling and localized lesson/mission/group/reminder events, configure APNs and web push, and verify physical delivery and quiet-hour preferences on devices.

## 2026-10-09 motion kit slice

- The shared fade-through page transition is wired to full-screen learner/auth routes, with the motion kit's existing reduced-motion behavior.
- Lesson completion now celebrates only after the server confirms the save. The result stages in, draws its check, shows a short confetti burst, animates accuracy, and counts up XP.
- Home's streak card uses the custom flame, rolling streak count, XP count-up, and `PressableScale`; values remain sourced from the streak repository.
- Verification: `flutter analyze --no-pub` passed. Focused widget tests were started, but Flutter could not copy its compiled test artifact because the system drive had 57 MB free (`errno 112`). The lesson result widget tests were updated to assert the animated score/reward widgets; rerun focused tests when disk space is available.
- Follow-up remains: visually verify route/lesson transitions on a device, connect haptic feedback consistently, pause any continuous path effects when off-screen/backgrounded, and review animation timing with large text and accessibility settings.

## Verification performed for this audit

- `flutter analyze --no-pub`: passed.
- `npm run build` in `functions/`: passed.
- `npm run test:unit` in `functions/`: 23 passed.
- The focused flashcard widget suite passed (3 tests) after its fake haptics dependency was corrected; the first two focused Home tests passed before adding the all-done state test.
- `flutter test --no-pub --concurrency=1 --reporter expanded`: 46 passed. The first run caught outdated lesson test routing after the Firestore content repository was wired; the fakes were updated and the full suite then passed.
- Firebase emulator/device smoke and Figma visual comparisons: not completed. The emulator command was attempted, but this machine has Java 17 and Firebase CLI 15.32.1 exits before startup because its emulator workflow now requires Java 21. The remote Firebase project also remains inaccessible from this workspace.
- Current change focused checks: `flutter analyze --no-pub` passed; `test/app_failure_test.dart`, `test/features/lesson/presentation/lesson_page_test.dart`, `test/features/home/presentation/home_page_test.dart`, `test/features/auth/presentation/auth_account_page_test.dart`, `test/core/network/network_status_controller_test.dart`, and `test/core/state/async_resource_test.dart` all passed (22 tests total). An initial focused run exposed a stale lesson value captured outside its notifier subscription; that was fixed before the passing rerun. The full suite has not been rerun after these changes because a Flutter compile attempt exhausted C: drive space; clearing generated build output recovered space for the focused checks.
- Latest path slice: `flutter analyze --no-pub` passed, and `test/widget_test.dart` passed (15 tests). This suite verifies that only repository-provided path content is rendered, that an offline repository failure offers retry and transitions to a real empty state, and that a published lesson node opens with its data-driven coordinates. Firestore-emulator behavior for the new repository remains unverified because the local emulator still requires Java 21.
- Latest Fritz server slice: `npm run test:unit` in `functions/` passed (33 tests), including six-turn qualification, explicit provider-default-off behavior, and request fingerprint distinctions. `flutter analyze --no-pub` and the 16-test widget suite passed, including the new-thread route. Provider calls were not made; emulator integration and actual Secret Manager setup remain unverified.
- Latest progression slice: `npm run test:unit` in `functions/` passed (38 tests), including retention, three-criterion readiness, and previous-unit completion/60% rules. `flutter analyze --no-pub` passed, and the 17-test widget suite passed, including live criterion display and locked-unit explanation. Firestore transaction integration still needs emulator verification; the published level must be reseeded so its core vocabulary IDs are present.
- Latest daily-missions slice: Functions build and unit tests pass (46 tests), including exactly-once mission XP. Focused Home widget tests pass (5 tests), covering loading, server-backed mission progress, streak and mission retry recovery, and completion. The full Flutter suite passes (136 tests), and `flutter analyze --no-pub` reports no issues. Home route tests now use a tall test viewport so mission content does not make old visibility assertions depend on scrolling. The longer viewport exposed a narrow onboarding welcome row; its text now wraps within the available width. Firestore emulator transaction verification remains outstanding (this workspace currently has Java 17 and Firebase CLI is not on PATH).

### State-layer adoption still required

The new async state contract is currently adopted by the published lesson-content read. Home streak uses its existing stream builder, and onboarding/auth/flashcards/tutor/path/profile/settings/notifications continue to own their feature-specific form, stream, or preview states. Each live repository-backed flow still needs a screen-by-screen loading/empty/offline/failure/retry review, with durable write queues and cache policy where the learning action must survive disconnection. Do not count the shared primitives as proof that every route now handles every state.

### 2026-10-07 follow-up

- Added password registration, sign-in, and password reset to the auth
  repository/page. Registration links to an anonymous Firebase account to keep
  the same UID. Signing into a different account does not merge guest data;
  the account form warns about this.
- User-scoped streak, path, onboarding, and Fritz repositories resolve the
  active Firebase UID for new operations. Home, path, streak, and tutor route
  widgets are keyed by UID so they rebuild on navigation after account
  switching. An already-open stream can still be bound to the prior UID, and a
  complete session/auth state owner is outstanding.
- `flutter analyze --no-pub` passes. A full `flutter test` attempt could not
  start: the C: drive had 0 bytes free while Flutter copied the compiled test
  kernel. No tests ran in that attempt. No files were deleted to recover space.
- The three AI keys pasted in the request are exposed. Revoke them and use
  replacement secrets stored only in Firebase Secret Manager. Fritz remains
  disabled until replacement secrets are configured.
- Added a live German/English interface language selector backed by
  `users/{uid}.uiLang`, with device-language initialization and user-scoped
  preference reads/writes. UI source strings in the typed and existing copy
  catalogs are translated; uncatalogued learning material stays German. Full
  screen-by-screen copy review and RTL support remain open.
- Localization verification: `flutter analyze --no-pub` reports no issues;
  the full Flutter suite passed (72 tests), including the settings
  language-switch route and source-copy translator checks.
- Notification inbox follow-up: all three dedicated inbox tests and the full
  Flutter suite pass; Functions build and unit tests pass (42). With the installed
  Java 21 runtime, the Auth, Functions and Storage emulators were started
  alongside the already-running Firestore emulator. The emulator smoke test
  completed a real review transaction that unlocked A2 and verified its
  notification document, passed owner mark-read, and rejected direct client
  read-state writes. Its first run caught and corrected an outdated expected
  XP total after daily mission rewards were added.

- Push delivery follow-up: the Flutter app now has explicit permission opt-in,
  authenticated per-device token registration, token-refresh updates, foreground
  notices, and safe in-app deep-link handling. A server trigger sends localized
  level-unlock notifications and removes invalid tokens; push opt-out removes
  all of the user's stored device registrations. Android notification channel
  and permission plus the iOS remote-notification background mode are in source.
  `flutter analyze --no-pub` passed, the Flutter suite passed (73 tests), the
  Functions build/unit suite passed (44 tests), and the Auth/Functions/Firestore
  emulator smoke suite passed including register/disable token lifecycle.
  FCM delivery to physical devices remains unverified: APNs credentials and
  Xcode push capability, a web VAPID key/service worker, and a deployed
  Firebase project's messaging configuration are external setup. Scheduled
  reminders and group-message push events are still backlog work.
  After reloading the updated rules into the running demo emulator, the smoke
  suite also confirmed an authenticated client receives 403 for device-token
  reads.
- Community group starter follow-up: groups now come from Firestore, and
  callable-only join/leave/send/report/block flows enforce age/rules
  attestation, plain-text limits, idempotency, rate limits, and three-reporter
  auto-hide. The app has consent-gated discovery, filters, loading/error/empty
  states, a full-height chat route, and a keyboard send action. The full Flutter
  suite passed (76 tests), `flutter analyze --no-pub` passed, Functions build
  and unit tests passed (46 tests), and the Auth/Functions/Firestore emulator
  smoke test passed for consent, chat, reporting, blocking, leaving, and denied
  direct client writes. `docs/moderation.md` records operator steps and release
  gaps. Friends/DMs, moderator tooling, pagination, unread/read state, German
  scope/profanity controls, and server-enforced block filtering remain open.
- Fritz voice follow-up: short German speech recognition uses the platform
  speech service, places a reviewable transcript in the tutor composer, and
  reports denied, unavailable, and failed states. Tutor replies have an
  optional German text-to-speech action. `speech_to_text` and `flutter_tts`
  dependencies and Android/iOS permission descriptions are configured. The
  full Flutter suite passed (76 tests) and `flutter analyze --no-pub` passed.
  `flutter build web` succeeds in JavaScript mode; its WebAssembly compatibility
  dry run reports casts inside `flutter_tts` 4.2.5, so Wasm is not verified.
  Physical-device permissions and speech-engine behavior remain unverified;
  `flutter doctor -v` reports that the Android SDK/platforms are absent. AI
  provider calls remain gated pending key rotation.

### 2026-10-08 motion slice and test-infra fix

- Slice B (visible motion): the learning-path current node now wears a
  `PulseHalo` attention ring (streak-orange, 1.6 s loop, scale 1→1.06 with a
  fading 58 px halo). The halo is layout-pinned with a `SizedBox.square` so the
  extra paint size never overflows the path row, and it renders statically
  under reduced motion. Six widget tests that pump the path were converted
  from `pumpAndSettle` to bounded pumps because the halo loops forever.
- Test-infra fix: bloc 9.2.1 `Bloc.close()` deadlocks inside `testWidgets`
  fake-async teardown (Cubit is fine; idle blocs hang; `runAsync` rescues a
  bare bloc but not blocs whose controllers were created in the fake zone).
  Widget-test harnesses now tear down `AuthSessionBloc` with
  `addTearDown(() => unawaited(bloc.close()))`. Decision recorded in
  `docs/DECISIONS.md`.
- Verification: `flutter analyze --no-pub` reports no issues; the full Flutter
  suite passed (128 tests). Notifications audit vs SPEC ch.10 rechecked:
  inbox page (grouping, unread dot, swipe-read, deep links, cached+retry),
  push controller (permission, token lifecycle, foreground notices, safe
  routing, opt-out), and the onboarding pre-prompt after the plan screen are
  in place. Remaining ch.10 gaps: per-type Settings switches are static, no
  local scheduling/producers beyond level-unlock, no unread badge count, and
  the denied-permission row lacks an OS-settings deep link (external setup:
  APNs, web VAPID).
