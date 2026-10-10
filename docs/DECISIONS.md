# Wortwerk decisions

## 2026-10-06 — M0 foundation

| Question | Choice | Reason |
|---|---|---|
| Which Flutter release should local and CI builds use? | Pin the installed stable Flutter `3.47.2` in `.fvmrc` and CI. | Reproducible builds; matches the SDK available for this workspace. |
| How should local development access Firebase before cloud projects are configured? | Use Firebase Emulator Suite with the real Firebase client SDKs and `demo-wortwerk-dev`; never route emulator builds to a live project. | Meets the no-mock requirement without inventing Firebase project IDs or credentials. |
| What should non-development flavors use until Firebase projects exist? | Require explicit project ID, API key, sender ID, and per-platform app IDs at build time; fail clearly when missing. | Prevents accidental use of demo configuration against a live backend. |
| What is the initial failure model? | Use the chapter 11 taxonomy and centralized Firebase exception mapping in `core/error`. | Keeps user-facing copy stable and prevents backend messages from leaking. |
| Which Figma MCP path should be used while Starter quota is exhausted? | No MCP write calls; the owner-provided local Figma development-plugin workflow is the only supported editing path until the monthly limit resets. | Figma MCP returned the Starter-plan tool-call limit error. |
| Which visual direction applies until Figma frames can be verified? | Follow the spec's flat solid fills, ink outlines, no gradients, no shadows and no glass. | This is the explicit product rule; `screens.html` is reference markup, not the authority. |

## 2026-10-06 — UI foundation

| Question | Choice | Reason |
|---|---|---|
| How should the bottom tabs and Fritz shortcut match the supplied iOS reference? | Use a translucent, blurred, outlined capsule for the tab bar and a matching circular Fritz button; keep learning cards flat. | The owner explicitly requested the glass treatment for these two navigation surfaces. |
| What should a new learner see before an account-backed home is available? | Start with a four-step onboarding flow, then show the learning shell with truthful first-run and empty states rather than fabricated progress. | Matches the supplied onboarding references and avoids displaying unsourced streak, XP, or completion data. |
| How should the "Teste mich, Fritz" placement choice determine the initial level? | Ask eight adaptive A1–B1 questions, shift difficulty after two consecutive answers, and use the server `evaluatePlacement` callable for the final level, unit, and confidence. On callable failure, offer retry or the self-assessed route. | Provides a real level-placement result while preserving the spec's explicit offline fallback and keeping scoring server-authoritative. |

## 2026-10-06 — Guest learning and first saved lesson

| Question | Choice | Reason |
|---|---|---|
| Can a learner start without an account? | Yes. Create a Firebase anonymous session before onboarding; offer optional account linking after the plan and in Profile. | The owner chose guest learning followed by account linking. Provider linking retains the anonymous UID and its Firestore data when the credential is not already attached to another account. |
| How should onboarding resume? | Persist the onboarding draft under the authenticated user's own `users/{uid}` document and route completed profiles to Home on the next launch. | This keeps interrupted onboarding and the assessed level across app restarts without a second local-only source of truth. |
| What is the first playable content slice? | One five-question A1 greetings lesson; award XP and write lesson/day progress only from the authenticated `completeLesson` callable. | The first milestone is a tested end-to-end learning loop, not placeholder XP or a client-trusted score. |
| What is the supported placement range in this slice? | A1–B1 only; do not present it as A1–C2 coverage. | C1/C2 questions and curriculum have not been authored or validated. |
| How should Firebase email-link sign-in build its return URL? | Require the owner to provide `AUTH_EMAIL_CONTINUE_URL`, an approved Firebase Authentication continue URL. | A production domain has not been supplied; the app must not invent a domain or make email-link sign-in appear configured when it is not. |

## 2026-10-06 — Streaks and spaced review

| Question | Choice | Reason |
|---|---|---|
| Who advances streaks and activity totals? | Only authenticated lesson and flashcard-review Cloud Functions update streaks, XP, and daily activity. The weekly streak UI reads the saved profile and day summaries. | Client-calculated progress could be forged or double-awarded on retries. |
| How does a learner protect a streak? | Start with two server-owned shields and Sunday as the default rest day. A completed lesson or review session records one active learning day; same-day activity does not increment the streak twice. | Supports a weekly recovery day while keeping activity tied to a verified learning action. |
| What is the first spaced-repetition schedule? | A ten-card A1 greeting session returns missed cards to a 10-minute learning step and doubles remembered-card intervals up to 30 days. A new session awards 10 XP; its request ID makes retries idempotent. | Delivers one persisted review loop without presenting the initial card catalog as full A1–C2 coverage. |
| Are the current path locks backed by completion-based unlocking? | No. The playable path opens the A1 greetings lesson; later levels remain explicitly unavailable until curriculum, retention, conversation, review, and server unlock criteria exist. | Avoids implying progression was earned when those counters and events are not yet implemented. |

## Owner setup still required

- The owner supplied the Android Firebase client configuration. Keep staging/production build defines and other platform configurations explicit; do not infer them from the Android file.
- This workspace has no Git repository or remote, so the CI workflow cannot be observed as a GitHub Actions run here. Initialize/connect the project before expecting CI results.
- Android SDK platforms/NDK are not installed or licensed on this machine, and the local JDK is 17 while Firebase Emulator Suite requires 21. Android and emulator smoke builds must run on a provisioned machine or CI until those prerequisites are installed and accepted by the owner.
- The local Figma plugin must be run in Figma Desktop by an editor with access to the Wortwerk file; this environment cannot bypass the exhausted MCP quota.

## Open decisions from the specification

The specification's default decisions are used until the owner changes them: minimum age 16 with restricted DMs; UI chrome follows the user's interface language; AI uses a provider-agnostic interface with the key only in Secret Manager; Fritz and the flame use Rive with a flat painter fallback; the custom tab pill follows the Figma source; and v1 has no monetisation.

## 2026-10-07 — Published path and tutor safety

| Question | Choice | Reason |
|---|---|---|
| What should the level path show before more curriculum exists? | Render only published Firestore levels, units, and lessons, and join server-owned completion records. Do not show example A2/B1 nodes as if they were available product content. | The spec prohibits invented data; the available curriculum currently contains one A1 lesson. |
| When may Fritz call an external provider? | Keep `FRITZ_AI_ENABLED` false by default. Enable it only after all exposed keys have been revoked and replacement credentials have been stored in Firebase Secret Manager. Bind idempotency request IDs to a hash of thread, mode, and message. | Prevents accidental use of credentials disclosed in chat and prevents changed payloads from reusing an earlier AI result. |

## 2026-10-07 — Password account flow

| Question | Choice | Reason |
|---|---|---|
| How does email/password registration preserve a learner who started as a guest? | Link the email/password credential to the current anonymous Firebase user so the UID and its Firestore data stay the same. Signing into a separate existing account does not merge guest progress; explain that before submission. | Keeps the common guest-to-account path seamless and avoids unsafe client-side merging of server-owned progress. |
| Where are model credentials stored? | Firebase Secret Manager only. Do not make a file intended for pasting provider keys. Keep provider order and the feature gate as non-secret Functions configuration. | Keys pasted in chat or stored in app/client files are exposed; server-side secret storage is already supported by the Fritz callable. |

## 2026-10-07 — Interface language preference

| Question | Choice | Reason |
|---|---|---|
| How should learners and developers switch app chrome between English and German? | Use a live Settings selector backed by `users/{uid}.uiLang`, initialized from the device language until an explicit profile preference exists. Translate known interface copy and keep unknown authored learning content in German. | The product is German learning, while developers and learners need readable app controls; learner-authored lesson content must not be mistranslated by broad string replacement. |

## 2026-10-07 — Notification ownership

| Question | Choice | Reason |
|---|---|---|
| Who creates inbox events and changes read state? | Trusted Functions create notification documents in the same transaction as the corresponding server-owned event; clients read their own inbox and call `markNotificationRead` to set `readAt`. | Prevents forged reward or social notifications while keeping inbox state synchronized across a learner's devices. |

## 2026-10-07 — Push delivery boundary

| Question | Choice | Reason |
|---|---|---|
| How should push registration and delivery work? | The app requests permission only after its explanation, registers tokens through authenticated callables, stores device records under the signed-in user's server-only `devices` collection, and sends localized level-unlock pushes from a Firestore trigger. | Keeps tokens out of client writes and the Flutter bundle, supports per-device language, and ties push delivery to confirmed server events. |
| What should development emulators do with FCM? | The app does not request FCM tokens while using Firebase emulators; Functions skip external FCM delivery in emulator mode. | Firebase Emulator Suite does not emulate FCM delivery, and local tests must not send real notifications. |
| Which platform setup may the repository provide? | Android permission/channel and iOS remote-notification background mode are configured in source; APNs credentials, Xcode Push Notifications capability, and web VAPID/service-worker configuration remain deployment inputs. | Platform signing credentials and browser push keys belong to the Firebase project owner, not source control. |

## 2026-10-07 — Community starter slice

| Question | Choice | Reason |
|---|---|---|
| What is enabled first for learner community? | Curated public groups with callable-only join, leave, send, report, and block flows. Require a 16+ self-attestation and rules version 1 before membership; record timestamps, not date of birth. | Establishes a server-owned, rate-limited group workflow while keeping consent evidence minimal. Product/legal owners must confirm the age and rules policy before release. |
| When can a reported message be hidden automatically? | Hide after three distinct members report it; reports are unique per reporter and message. | A simple initial safety threshold is testable, while human moderation tooling is still needed. |
| Are direct messages available? | No. Keep DMs disabled until mutual friendship, recipient controls, server-side block enforcement, reporting, and abuse response exist. | Private conversations require stronger recipient and moderation controls than public group chat. |

## 2026-10-07 — Spoken German practice

| Question | Choice | Reason |
|---|---|---|
| How does voice input reach Fritz? | Request microphone/speech permission only when the learner taps dictation; use the platform German recognizer for a short phrase; show the transcript in the composer and send it only after the learner submits. Do not persist raw audio. | Keeps speech under explicit learner control and reuses the existing validated tutor text flow. Platform recognizers can use device-specific services; the app does not claim speech processing is always offline. |
| How is tutor speech played? | Add an explicit German read-aloud action to tutor replies and use the platform TTS engine. | Playback is optional per reply and does not begin without a learner action. |

## 2026-10-08 — bloc 9.2.1 close() deadlock in widget tests

| Question | Choice | Reason |
|---|---|---|
| How should widget tests tear down `Bloc` instances? | Harnesses use fire-and-forget teardown (`addTearDown(() => unawaited(bloc.close()))`) instead of awaiting close inside the test body or runAsync. | bloc 9.2.1 `Bloc.close()` (not Cubit) never completes inside a `testWidgets` fake-async zone, even when idle; `tester.runAsync(() => bloc.close())` rescues a bare bloc but not blocs whose controllers/subscriptions were created in the fake zone (AuthSessionBloc). Unawaited teardown drains on the real event loop outside the test isolate's awaited chain. Plain `test()` bloc tests with `addTearDown(bloc.close)` are unaffected. Revisit if bloc is upgraded past 9.2.1. |

## 2026-10-09 â€” learner motion feedback

| Question | Choice | Reason |
|---|---|---|
| Which moments receive motion first? | Use finite, event-driven motion for answer feedback, server-confirmed lesson rewards, streak/XP changes, and full-screen learner route changes. Keep reduced-motion behavior in the shared motion kit. | Motion should communicate a learner action or saved progress, not add an ambient loop that competes with practice or accessibility. |
| How should lesson completion celebrate? | Start its check draw, accuracy ring, and XP count only after the completion callable succeeds; keep the confetti burst short and capped. | The animation must represent persisted progress and avoid implying a reward when the backend save failed. |
