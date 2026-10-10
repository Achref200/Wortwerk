# Wortwerk

Wortwerk is a Flutter German-learning app. Its build specification and design
handoff are saved in this repository:

- [Build specification](docs/SPEC.md)
- [Design decisions](docs/DECISIONS.md)
- [Firestore schema and provisioning status](docs/FIRESTORE_SCHEMA.md)
- [Design tokens](design/tokens.json)
- [Screen reference markup](design/screens.html) (reference only)
- [Figma source](https://www.figma.com/design/SYs96tnLm9umKj22YerkDk/Wortwerk-%E2%80%94-German-learning-app?node-id=9-3)

The Figma screenshots are the visual source of truth. The current Figma MCP
Starter-plan quota is exhausted; do not treat local reference markup as a
replacement for checking the Figma frames. Use the Figma Desktop development
plugin workflow while MCP access is unavailable.

The current Flutter UI follows the supplied agent pack: it includes a guided
onboarding flow, the four primary learning tabs, reusable design tokens,
Fritz's avatar, and the Fritz assistant sheet. The navigation capsule and Fritz
button use a translucent blurred surface at the owner's request; learning
content stays flat with outlined cards and solid pastel fills. Figma MCP edits
are separate and have not been made from this workspace.
The Bricolage Grotesque, DM Sans, and Caveat font assets are bundled locally
with their SIL Open Font Licenses under `assets/fonts/licenses/`.

New learners can choose a self-assessed starting level or complete Fritz's
adaptive A1–B1 placement quiz. The quiz adjusts difficulty after two
consecutive correct or incorrect answers, then sends the answer IDs to the
`evaluatePlacement` Cloud Function for authoritative scoring. If the callable
cannot be reached, onboarding offers retry or an explicit self-assessed
starting level instead. Check the scorer with
`npm run test:unit --prefix functions`.
Development starts with Firebase anonymous authentication, saves onboarding
drafts and the chosen level to the learner's own Firestore profile, and returns
completed learners to Home on relaunch. Learners can keep their guest UID and
progress when linking Google or Apple. Email-link sign-in requires a
Firebase-approved return URL supplied as `AUTH_EMAIL_CONTINUE_URL`. The first
playable A1 greetings lesson sends answer IDs to the authenticated
`completeLesson` callable; XP and progress are computed and saved by the
server. Weekly streak and active-day summaries are read from Firestore, with
loading, empty, and retry states instead of fabricated activity. Completing a
lesson or a saved flashcard review advances the server-owned streak; the
default weekly rest day and streak shields are applied by the Functions
transaction.

The current review session contains ten A1 greeting cards. Card ratings and
spaced-repetition schedules are saved by `completeFlashcardReview`; a new
session awards 10 XP, remembered cards grow their interval up to 30 days, and
missed cards return to a 10-minute learning step. Request IDs make retries
idempotent. The winding path currently links to the playable A1 greetings
lesson; later lessons and levels remain unavailable until their curriculum and
server-verified unlock requirements are implemented.

Fritz conversations are sent only to the authenticated `fritzChat` Cloud
Function. Replies and user messages are stored under the learner-owned
`users/{uid}/aiThreads/{threadId}/messages` path; per-user daily and per-minute
limits and idempotency records are server-owned. Provider credentials are
Firebase Secret Manager secrets and are never included in the Flutter app,
Firestore conversation data, or application logs. The function tries the
providers in `FRITZ_PROVIDER_ORDER` (default `nvidia,gemini,openai`) and moves
to the next configured provider after a timeout or provider failure. Fallback
is best-effort, not an uptime guarantee. Provider calls are disabled by default
with `FRITZ_AI_ENABLED=false`; the callable rejects requests before reading any
provider key until an operator explicitly changes it to `true`.

**Credential rotation is required before enabling Fritz.** API keys posted in
chat or elsewhere outside the provider's secret manager must be revoked, not
reused. After creating fresh keys directly with each provider, set them through
an authenticated Firebase CLI session; each command prompts for the secret
value in the local terminal. Never put secret values in `.env`, Dart defines,
Firestore, source control, issue trackers, or chat:

```powershell
firebase functions:secrets:set NVIDIA_NIM_API_KEY --project wortwerk-35912
firebase functions:secrets:set GEMINI_API_KEY --project wortwerk-35912
firebase functions:secrets:set OPENAI_API_KEY --project wortwerk-35912
```

After rotating and configuring the replacement secrets, set
`FRITZ_AI_ENABLED=true` in the project-specific Functions environment file.
Keep it `false` until the replacement values are confirmed in Secret Manager.
Deploy the Functions only after all desired secrets have been configured:

```powershell
firebase deploy --only functions:fritzChat --project wortwerk-35912
```

The preferred provider order is non-secret configuration. Set
`FRITZ_PROVIDER_ORDER` in the project-specific Functions environment file, for
example `.env.wortwerk-35912`, using a comma-separated permutation of
`nvidia,gemini,openai`. Do not put API keys in this file. If no provider secret
is configured, Fritz returns an explicit unavailable/configuration state and
does not fabricate an answer.

## Toolchain

Use Flutter `3.47.2` as pinned in `.fvmrc`, Dart 3, Java 21 and Node 22.
Flutter dependencies use Firebase SDKs and Bloc/Cubit. Android has `dev`,
`staging`, and `production` Gradle flavors.

## Local development

Enable Windows Developer Mode (or another platform's symlink support) before
running `flutter pub get` when using Flutter plugins.

Start the Firebase Authentication, Firestore, Functions and Storage emulators:

```powershell
npx firebase-tools emulators:start --project demo-wortwerk-dev
```

Before starting the emulators for the first time:

```powershell
npm ci --prefix functions
npm --prefix functions run build
```

The lesson player reads published questions from Firestore; scoring reads the
same lesson document on the server. Seed the existing A1 greetings content into
the local emulator before opening the lesson:

```powershell
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
npm --prefix functions run seed:content -- --project demo-wortwerk-dev
```

Remote seeding requires both `--project <id>` and
`--confirm-project <same-id>`; it uses Application Default Credentials. The
script writes only the existing greetings lesson and its level/unit documents.

In another terminal, run the Android development flavor:

```powershell
flutter run --flavor dev --dart-define=APP_FLAVOR=dev
```

The development flavor uses the emulators by default. Android Emulator connects
through `10.0.2.2`; iOS Simulator and web use `127.0.0.1`. For a physical device,
set `FIREBASE_EMULATOR_HOST` to the computer's LAN address.

Staging and production must be built with real Firebase configuration supplied
as Dart defines: `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`,
`FIREBASE_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID`, and
`FIREBASE_WEB_APP_ID`, and `FIREBASE_STORAGE_BUCKET`. The Android client
configuration file is maintained separately under `android/`. Never commit
service-account credentials or AI keys. Before merging to `main` or pushing a
`v*` tag, set the matching
`STAGING_FIREBASE_*` or `PRODUCTION_FIREBASE_*` repository variables used by
the cloud-build job.

## Checks

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
npm ci --prefix functions
npm --prefix functions run build
```

The GitHub Actions workflow also builds the Android dev flavor and smoke-tests
the Firebase emulators.
