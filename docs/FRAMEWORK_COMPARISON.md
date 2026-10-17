# Wortwerk framework comparison

Wortwerk Native is a side-by-side interaction prototype. The Flutter app remains intact and both clients can use the same Firebase emulator project, Firestore rules, Functions, and emulator seed.

| Area | Flutter app | Expo / React Native comparison |
| --- | --- | --- |
| Backend | Existing Firebase repositories and callable Functions | Firebase JS SDK reads Firestore and invokes the same callable Functions |
| Daily loop | Existing Home, streak, missions, and learning routes | Live streak and mission listeners, lesson CTA, review CTA, and Fritz entry |
| Learning path | Existing Flutter path and lesson experience | Published Firestore lessons, unlock/progress display, SVG road, and server-scored lesson submission |
| Interaction | Flutter animation and haptic components | Reanimated transitions, animated progress, spring presses, haptics, card flip, and reduced-motion handling |
| Responsive layout | Flutter constraints and breakpoints | Window-based compact-phone and wider-screen layouts; a 560 px content cap |
| Missing data / network | Existing Flutter error and empty-state handling | Explicit loading, retry, unavailable, empty-path, and completed-path states in the comparison flows |
| Feature coverage | Broader route and domain set | Core learning plus profile editing, settings, inbox, streak history, guest-account linking, and joined-group chat; still not full parity |

## How to compare

Run both clients against the same imported emulator state. On each device size, follow onboarding, open Home, complete one lesson, inspect the path and streak update, finish a review, and visit Groups and Fritz. Record interaction latency, animation smoothness, layout stability at narrow and wide widths, and recovery after stopping/restarting the emulator. Repeat with reduced motion enabled.

## Verified on web

The Expo client was exercised end to end in a browser against the repository's emulator project (`demo-wortwerk-dev`, Firebase Auth + Firestore + Functions + seeded content), driven through the same interface a person uses:

- Guest sign-in and learner setup wrote the profile and reached the onboarding view.
- Home rendered live streak, week dots, XP, and the three daily missions from the `getDailyMissions` callable.
- The learning path rendered the published A1 lesson node straight from Firestore, including the "you are here" marker and unlock state.
- In the original browser run, the then-five-question lesson opened and the trusted `completeLesson` function saved `+20 XP`, `5 von 5 richtig`. The authored source has since expanded to ten questions; the emulator smoke now builds all answers from the versioned source and validates the new scorer result.
- Returning to Home showed the server-persisted result: one day of streak, 40 XP today, the completed lesson ticked in the week strip, and the mission at `1/1`.
- The same flow was repeated with reduced motion enabled; layout and state stayed correct with transitions suppressed.

Still outstanding: a device-level comparison in Expo Go or a development build alongside Flutter on real phones. That comparison has not been run from this workspace, so this prototype is not yet a complete migration recommendation.

The React Native profile and community coverage was expanded after the original comparison run. The current details, the data model/seed process, tests, and remaining parity gaps are tracked in [WORTWERK_NATIVE_TRANSFORMATION.md](WORTWERK_NATIVE_TRANSFORMATION.md). The ten-question A1 greetings lesson remains the only published curriculum lesson.
