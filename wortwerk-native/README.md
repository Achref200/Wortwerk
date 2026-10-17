# Wortwerk Native

An Expo and React Native comparison client. The Flutter application at the repository root remains the primary app; this project uses a separate native application id so both can be installed side by side.

## Run against the local Firebase emulators

From the repository root, install the Functions dependencies, build the server, and start Firebase emulators:

```powershell
npm ci --prefix functions
npm --prefix functions run build
npx firebase-tools emulators:start --project demo-wortwerk-dev
```

In a second terminal:

```powershell
cd wortwerk-native
npm install
npx expo start
```

If your machine has Java 17 rather than Java 21, run the emulators through the pinned older CLI, because firebase-tools 14 and later refuse to start on Java 17:

```powershell
npx firebase-tools@13 emulators:start --project demo-wortwerk-dev
```

In a third terminal, seed the existing authored lesson and published groups into the local emulator:

```powershell
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
npm --prefix functions run seed:content -- --project demo-wortwerk-dev
npm --prefix functions run seed:community -- --project demo-wortwerk-dev
```

For the browser build, open http://localhost:8081 after `npx expo start --web`. The Expo client was verified end to end this way: guest sign-in, onboarding, live Home missions and streak, the seeded learning path, a server-scored lesson, and the persisted streak/XP/mission update on return.

The app defaults to the `demo-wortwerk-dev` emulator project and localhost emulator ports from the root `firebase.json`. Android Emulator uses `10.0.2.2`; iOS Simulator and web use `127.0.0.1`. To connect Expo Go on a physical phone, set `EXPO_PUBLIC_FIREBASE_EMULATOR_HOST` to the development computer's LAN address before starting Expo.

For a real Firebase project, set `EXPO_PUBLIC_USE_FIREBASE_EMULATORS=false` and provide `EXPO_PUBLIC_FIREBASE_API_KEY`, `EXPO_PUBLIC_FIREBASE_PROJECT_ID`, `EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN`, `EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET`, `EXPO_PUBLIC_FIREBASE_SENDER_ID`, and `EXPO_PUBLIC_FIREBASE_APP_ID`. Enable anonymous sign-in and deploy the repository's existing Firestore rules, indexes, and Functions first. Do not put provider or service-account secrets in `EXPO_PUBLIC_*` values.

## Comparison scope

The client reads published learning content and user progress from Firestore, calls the existing trusted Functions for mission creation, lesson completion, flashcard review, community joins, and Fritz messages, and keeps profile mutations within the existing Firestore rules. There is no seeded app state in the client: empty, loading, and failure views are explicit when backend data is absent or unavailable.

The current React Native slice includes guest onboarding, a live Home dashboard, a published-content learning path and server-scored lessons, animated ten-card review, group discovery/joining and member chat with report/block/leave callables, profile editing, saved learning preferences, the notification inbox/read state, a streak calendar, guest-to-email account linking, Fritz speech playback, and the existing persisted tutor thread. See [the transformation status report](../docs/WORTWERK_NATIVE_TRANSFORMATION.md) for exact behavior and verified curriculum counts.

It is still not full Flutter feature parity or a store-ready release. The published curriculum is only one A1 lesson with ten multiple-choice exercises. Adaptive placement is not in the React Native onboarding, speech-to-text is unavailable, Fritz AI remains disabled in the emulator, push-device registration and scheduled reminders are not configured, existing-account recovery on a second device needs a verified flow, and account deletion/social sign-in are not implemented. No native Android/iOS comparison has been run for the new profile or group-chat screens.

Animations honor the system reduced-motion preference. Layout width responds to the current window size, with a compact-phone breakpoint and a wider two-column Home layout. Compare on the same device and emulator data to judge transitions, touch feedback, layout changes, startup time, and scrolling behavior fairly.
