# Wortwerk React Native transformation status

## Implemented in this pass

- Added profile destinations for name editing, learning settings, the notification inbox, streak history, and account security. Profile preference writes use the existing owner-scoped Firestore rules.
- Added account linking from an anonymous learner to email/password, email verification, and password-reset requests. The client does not expose account deletion because the backend does not yet have an atomic user-data deletion workflow.
- Added inbox loading and read-state updates through the existing `markNotificationRead` callable. Settings distinguish saved notification preferences from actual device delivery; push can be switched off through the existing callable, but the new client does not claim device registration or reminder scheduling.
- Added joined-group conversations with server-validated message submission, the latest 50 visible messages, report and block actions, and leave confirmation. Firestore messages are read only for members; hidden messages are excluded by a query that matches the existing security rule and composite index.
- Added a reusable Fritz vector character with idle, happy, thinking, confused, speaking, listening, encouraging, and celebrating expressions. It has original layered SVG geometry, a cap and red-and-gold band, blink/breath motion and emotion-specific reactions. Existing Reanimated screen transitions, staggered reveals, spring presses, progress animation, haptics and reduced-motion behavior remain in use.
- Added Expo Router's SDK 57-compatible `fade_from_bottom` screen transition. The app keeps its current dependency set; this pass adds no native animation or 3D package.
- Added a versioned curriculum manifest, source-schema validation, duplicate/reference/answer checks, dry-run mode, 450-document batched idempotent writes, and a repeated emulator-tested publish path. Seed writes do not touch learner progress and remote writes still require both an explicit project ID and matching confirmation.
- Added lesson objectives, duration, XP metadata, vocabulary/grammar tags, exercise instructions, and CEFR difficulty to the existing A1 greetings lesson without changing the legacy server-scored choice-answer contract.

## Verified content and backend targets

The manifest currently validates **1 published A1 lesson with 10 multiple-choice exercises**. The learning-path seed publishes one A1 unit and lesson. The app still has its earlier fixed ten greeting flashcards; these are not yet a manifest-backed scalable vocabulary deck. There is no published A2–C2 curriculum. The 6-level / 120-lesson / 1,200-exercise target remains planned.

The publisher targets the Firebase emulator by default in the documented local workflow. This pass published the source to `demo-wortwerk-dev` on the Firestore emulator. It wrote level/unit/manifest/lesson content only; no production Firebase project was addressed and no learner progress was changed.

Run the curriculum checks and emulator seed from the repository root:

```powershell
npm --prefix functions run seed:content -- --dry-run
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
npm --prefix functions run seed:content -- --project demo-wortwerk-dev
npm --prefix functions run test:unit
```

The source schema is checked in `functions/scripts/content-validation.cjs`; the current authored lesson is `content/a1_greetings.json`, and its source list/version are in `content/manifest.json`.

## Fritz rendering and motion choice

Fritz is a vector character rendered with `react-native-svg` and animated with the already-installed Reanimated package. The eight named states change the face and reaction as well as the surrounding copy/layout; this is more useful for the current Expo Go-compatible app than introducing a native 3D runtime without a model or rig. **It is not a 3D character.** No licensed 3D model, Rive file, Lottie character, or source artwork was present in the repository. The visual inspiration supplied in chat was not a reusable mascot asset. A later asset pass can replace the vector drawing behind the same `Fritz` mood API with a properly licensed Rive/3D renderer.

Reanimated/UI animations call `useReducedMotion`; layout entrance patterns are omitted when the OS asks for reduced motion, and tap/lesson feedback remains accessible without gesture-only answers. No 60 FPS measurement or real-device battery/performance study has been performed in this workspace.

## Concrete remaining work

- Expand the curriculum with independently reviewed, pedagogically sequenced content. The validator and publisher are ready for versioned sources, but no level beyond the single short greetings lesson is ready to publish.
- Build a reusable exercise model and trusted scorer for ordering, typed fill-in, matching, reading/listening and pronunciation. The existing client/backend answer contract is multiple-choice only; extra exercise shapes must remain backward compatible with Flutter.
- Integrate the existing adaptive placement callable into resumable onboarding; the current UI still uses a self-selected level and does not complete the six-question assessment.
- Migrate greeting flashcards to published deck/card content, add native card audio, and provide an explainable scheduling/history UI. Current review uses the existing fixed ten cards and backend SRS state.
- Add multiple Fritz threads and working explain/translate/practice modes, microphone dictation, and speech preferences. The current single persisted main thread has real generated replies disabled in the local emulator (`FRITZ_AI_ENABLED=false`); no fake AI response is shown.
- Finish auth recovery for an existing account on a second device, Google/Apple provider configuration, and a server-owned account-deletion workflow. Current UI can link the active guest account and send password reset/verification email; linking must happen before losing access to the original guest account.
- Add notification device registration, category-aware delivery and scheduled reminders. The existing Functions deliver supported level-unlock pushes when a real device token and credentials are configured; this client pass only implements the inbox and honest preference controls.
- Add community pagination, moderation review workflow and blocked-user query filtering across devices. This view intentionally loads only the latest 50 messages; direct messages, friend requests and group creation are still absent.
- Exercise new profile/community screens on physical Android/iOS devices and capture interaction/performance measurements. Only the supported web bundle and emulator backend tests were run here.

## Verification record

The recorded checks for this pass are: curriculum dry run validated 1 lesson / 10 exercises; Functions unit suite passed 51/51, including five new curriculum validation tests; Firebase emulator smoke passed the authenticated placement, progress, community moderation and notification lifecycle flows against the ten-question source; Expo JavaScript exports completed for web, Android and iOS. These exports do not compile a signed APK/IPA or replace a real-device run. Final React Native lint and typecheck passed; no production writes or real push sends are part of this verification.
