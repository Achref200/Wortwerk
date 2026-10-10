# Wortwerk — Build Specification
*Master brief for the AI coding agent · v1.0 · 6 Oct 2026 · Owner: Achref Ben Yaagoub*

---

## 0. How to use this document
**Goal.** Build the Wortwerk mobile app (Flutter, iOS first, Android second) on a real Firebase backend from day one. No mock data layer and no "switch to Firebase later". Development uses the Firebase Emulator Suite, which speaks the real Firebase APIs, so the same code runs against dev, staging and production projects.

**Source-of-truth order (when two sources disagree, the higher one wins):**

1. The Figma file *Wortwerk — German learning app* (layout, spacing, copy, component behaviour). Screens used so far: 05 Home, 06 Level path.
2. This document (behaviour, data, rules, states, motion, haptics).
3. `design/tokens.json` (colors, type, space, radius, motion).
4. `design/screens.html` (reference markup; shows intent, not production code).
**Known conflict to resolve in Figma's favour.** The Figma cards show a very soft elevation. The product direction is *flat*: solid fills, thin ink outlines, **no gradients, no blurred shadows, no glass**. Default elevation token is `none`. If Figma and this rule disagree on a specific card, ask the owner; do not guess.

**Agent working protocol**

1. Read the whole document once. Then work milestone by milestone (chapter 17). Never start a milestone before the previous one passes its Definition of Done.
2. Before writing a feature: write its Cubit/Bloc state classes, its repository interface, its Firestore paths and its failure cases (chapter 11). Then the UI.
3. Every screen ships with **all** its states: loading, content, empty, error, offline, partial. A screen without them is not done.
4. Every user action ships with its feedback: visual response, haptic (chapter 12) and, where relevant, sound-free motion (chapter 5).
5. If a requirement is ambiguous, pick the simplest option consistent with the principles in 1.3, record it in `docs/DECISIONS.md` (date, question, choice, reason) and continue. Do not stop to ask unless the choice is irreversible (data model, bundle id, auth providers).
6. Never invent content, claims or numbers in the UI. Real content comes from Firestore (seeded by `tool/seed`, chapter 18).
7. Never put secrets in the app. The AI key lives only in Cloud Functions (Secret Manager).
**Definition of Done for any ticket**

- Code formatted, `flutter analyze` clean, no TODO without a ticket id.
- Unit tests for Cubit/Bloc and repository; widget test for each state; golden test for visual screens.
- Works offline per chapter 11; failure states reachable and tested.
- Semantics labels, 48 dp targets, text scales to 200 %, reduced-motion path implemented.
- Analytics events from chapter 14 fire; no PII in events.
- Matches Figma at 390×844 and at 360×800, and at 1.3× text scale.

---

## 1. Product and métier

### 1.1 Vision
Wortwerk helps beginners and mid-level learners learn German through **small daily steps, healthy streaks and a friendly AI coach (Fritz)**. It is *not* exam preparation or certification (possible later; keep the data model open for it).

### 1.2 Audience

- **Primary:** adults 18–40 starting German (A1–A2), often for work, study or relocation (including France/Tunisia-based Arabic and French speakers).
- **Secondary:** B1–B2 learners who want confidence and speaking practice.
- UI languages at launch: **English, French, Arabic (RTL)**. Learning content is German. Explanations/hints appear in the user's *explain language* (default = UI language). Fritz replies in German at the learner's level, with an optional one-tap translation.

### 1.3 Product principles (use these to settle any doubt)

1. **Healthy, not addictive.** One rest day per week, streak pauses instead of punishing, no guilt copy, no dark patterns.
2. **One clear next action** on every screen.
3. **Clean, clear, powerful, confident.** Short copy, strong type, generous space, flat color, no decoration that carries no meaning.
4. **Feedback in under 100 ms** for every tap (visual + haptic).
5. **Never lose progress.** Writes are queued offline and reconciled.
6. **Human, not generated-looking.** Flat color, ink outlines, small hand-written notes, slight imperfections. No gradients, no shadows, no glass.

### 1.4 Levels and content model (CEFR)
Levels: **A1, A2, B1, B2, C1, C2**. At launch only **A1–B1 are filled with content**; B2–C2 show as "Bald verfügbar" locked nodes (they exist in the data model).

Hierarchy: Level → Unit (theme, e.g. *Begrüßungen*, *Reisen*, *Arbeit*) → Lesson (8–12 min, 8–12 exercises) → Exercise.

**Exercise types** (each is a widget + a Bloc event set):

Type

Interaction

Feedback

`choice`

Tap one of 3–4 options

Fill green/red, Fritz reaction

`gap`

Tap word into sentence gap

Snap animation, check

`match`

Pair German ↔ explain language

Pair locks with haptic

`order`

Drag words into sentence

Drop snap, check

`listen`

Play audio (TTS or file), pick text

Replay button, slow mode

`speak`

Hold mic, speech-to-text compare

Waveform, tolerance scoring

`translate`

Type short answer

Accept alternatives list

`flash`

Flashcard review (SRS)

Nochmal / Gewusst

Every exercise has: `id`, `type`, `prompt`, `payload`, `correct` (or `accepted[]`), `explanation` (explain language), `skillTags[]` (vocab, grammar, listening, speaking), `difficulty` 1–5.

### 1.5 Placement and onboarding logic

1. Welcome → name → goals (multi-select: Reisen, Arbeit, Alltag, Familie & Freunde, Kultur, Neugier) → daily time (5/10/15/20 min) → self-assessment (Ganz neu / Grundlagen / Gespräche führen / *Teste mich, Fritz*).
2. **"Teste mich"**: adaptive check, 6–8 items, starts at the self-picked level, moves up/down by one level on two consecutive right/wrong answers. Scored server-side (`evaluatePlacement`). Output: `level`, `unitId`, `confidence`.
3. Result screen: *Dein Plan steht* (start level and unit, minutes/day, reminder time, one rest day per week).
4. Notification pre-prompt appears **after** the plan screen, with a short reason, before the system dialog.
5. The plan adapts: after 3 lessons, if average score > 92 % offer to skip ahead; if < 55 % offer an easier unit. Always a suggestion, never automatic.

### 1.6 Progression and unlock rules (server-authoritative)
Next **level** opens when all three are true:

1. **Words retained ≥ 70 %** of the level's core vocabulary. A word counts as retained when its SRS interval ≥ 3 days *or* its last two reviews were correct.
2. **3 Fritz conversations** completed for that level (each ≥ 6 learner turns, tagged with the level's topics).
3. **1 review round** passed with ≥ 70 %.
Fritz announces readiness; the learner may also trigger early unlock via *Teste mich*. Next **unit** inside a level opens when the previous unit's lessons are completed with ≥ 60 % average. Locked nodes are always tappable and explain *what is missing* (progress bars for the three criteria).

### 1.7 XP, streak, rest days, chest

- **Active day** = at least one completed lesson, flashcard session of ≥ 10 cards, or Fritz conversation of ≥ 6 turns, counted in the user's own time zone.
- **XP:** lesson 20 (+10 if ≥ 90 %), flashcard session 10, Fritz conversation 40, mission 20–40, level-up 120.
- **Streak:** +1 per active day. **Weekly rest day** (user picks the weekday): never breaks the streak and does not count as a miss.
- **Missed day:** a **streak shield** is consumed automatically (start with 2; +1 per level-up; max 3). Without a shield the streak resets to 0, `longest` is kept, and a one-time *Wiederherstellen* offer (2 lessons within 24 h, once per 30 days) is shown.
- **Weekly chest:** opens at 7 active days in the Monday–Sunday week (4/7 progress shown). Reward: XP and a cosmetic for Fritz (cap, scarf, etc.).
- **Daily missions:** 3 per day (e.g. *10 neue Wörter*, *Eine Lektion beenden*, *Mit Fritz sprechen*), chosen from the user's goals. Challenges: weekly, optional, e.g. *7 Tage in Folge lernen*.
- All counters are computed by Cloud Functions in transactions. The client shows optimistic values flagged `pending` until the server confirms.

---

## 2. Information architecture and navigation
**Router:** `go_router`, typed routes, redirect logic driven by `AuthCubit` and `OnboardingCubit`. Deep links from notifications use the same routes.

**Shell:** custom `WortwerkTabBar` matching Figma: four tabs, active tab = dark pill with icon, label under inactive icons. Tabs: **Start**, **Weg**, **Gruppen**, **Profil**. A floating round **Fritz button** (avatar face) sits bottom-right above the tab bar on every tab and opens the Fritz sheet. On iOS 26 evaluate a native tab bar package; fall back to the custom bar. Keep one `TabBarSpec` so either renders the same items.

Route

Screen

Notes

`/splash`

Splash

Remote Config + auth check, max 1.2 s

`/onboarding/welcome

name

goals

`/auth`

Sign in

Apple, Google, email link; anonymous start allowed, upgrade later

`/home`

Start

Greeting, streak, XP, continue-learning, tasks

`/path`

Weg

Level path, unit nodes, chest, unlock card

`/path/unit/:unitId`

Unit detail

Lesson list

`/lesson/:lessonId`

Lesson player

Full-screen, no tab bar

`/lesson/:lessonId/result`

Lesson result

XP, accuracy, streak update

`/flashcards/:deckId?`

Flashcards

SRS session

`/streak`

Streak and missions

Pushed from Home pill

`/insights`

Insights

Week/month/all charts

`/levelup/:level`

Level-up

Full-screen celebration

`/groups`

Gruppen

Groups, DMs, discover

`/groups/:gid` and `/dm/:pairId`

Chat

`/profile`

Profil

Stats, badges, friends

`/settings/...`

Settings

Learning, Fritz, notifications, account, privacy

`/notifications`

Hinweise

In-app inbox

`/fritz` (sheet)

Fritz

Bottom sheet, snap 0.6 / 0.95

`/update-required`, `/maintenance`, `/offline`

System states

Driven by Remote Config / connectivity

Back behaviour: lesson player asks "Beenden? Fortschritt bleibt erhalten" with *Weiter lernen* (primary) and *Beenden*; partial lesson progress is saved every answer.

---

## 3. Design system

### 3.1 Tokens
Source: `design/tokens.json`. Implement as `ThemeExtension`s: `WColors`, `WType`, `WSpace`, `WRadius`, `WMotion`, `WHaptics`. No raw hex, font size or duration in widgets.

**Color**

Token

Value

Use

`paper`

#F4F1EA

App background

`card`

#FFFDF8

Card fill

`ink`

#1E1D22

Text, outlines, primary button

`muted`

#55525C

Secondary text

`line`

#D9D4C8

Dividers, inactive borders

`streak`

#E8590C

Streak, selected state accent, XP numbers

`success`

#7CC88A

Correct, progress

`error`

#D9534F

Wrong, destructive

`levelA1` … `levelC2`

#F5C2DC · #D4BDEE · #B9D3EE · #BFE3C4 · #F2B890 · #F6E39A

Level identity and cards

Rules: pastel fills carry **ink text**; never white text on pastel. Contrast ≥ 4.5:1 for body, ≥ 3:1 for large text and UI outlines. Dark mode is **out of scope for v1**; structure tokens so it can be added (semantic names only).

**Typography** (verify against Figma text styles; Figma wins)

Style

Font

Size/weight

`display`

Bricolage Grotesque

44 / 800

`title`

Bricolage Grotesque

28 / 800

`heading`

Bricolage Grotesque

20 / 600

`body`

DM Sans

16 / 400, 1.4 line height

`bodyStrong`

DM Sans

16 / 700

`caption`

DM Sans

13 / 500

`note`

Caveat

22–26 / 600, used sparingly for human-feeling notes (max one per screen)

Arabic: use a matching Arabic family (e.g. Noto Sans Arabic) with the same scale; mirror layouts with `Directionality`.

**Space:** 4 · 8 · 12 · 16 · 24 · 32 · 48. Screen padding 20. **Radius:** chip 999, card 24–28, sheet 36, input 999. **Stroke:** 1.5 px ink for emphasised cards, 1 px `line` for quiet ones. **Elevation:** none.

**Motion tokens:** `instant` 100 ms · `fast` 160 ms · `standard` 240 ms · `emphasized` 400 ms · `celebrate` 700–1200 ms. Curves: `easeOutCubic` (standard), `easeInOutCubicEmphasized`, spring (stiffness 300, damping 22). Details in chapter 5.

### 3.2 Component library (build once, in `core/design_system`, showcase in Widgetbook)
Every component has: default, pressed, disabled, loading, error (where relevant), RTL, large-text variants, and a golden test.

Component

Variants / states

`WButton`

primary (ink fill), secondary (outline), ghost, destructive; sizes L (56) / M (48); loading spinner replaces label without width change

`WChip`

filled pastel, outline, selected (ink border + streak accent), counter

`WCard`

pastel, neutral, outlined, tappable (press scale 0.98 / 100 ms)

`WProgressBar`

linear with animated fill; value, indeterminate, segment

`WProgressRing`

sweep animation, center slot

`WStreakPill`

flame + count; lit / unlit / at-risk (pulses once)

`WWeekDots`

filled, today (ring), future, rest day (dash)

`WStreakFlame`

Rive or painter; states `off`, `lit`, `big`, `celebrate`

`WFritz`

3D-style avatar; moods `idle`, `happy`, `thinking`, `listening`, `speaking`, `celebrating`, `sleepy`, `confused`; sizes 24–200

`WFritzButton`

floating avatar button, badge for suggestions

`WTabBar`

4 tabs, active pill, badge dot

`WListTile`

task row with checkbox, XP chip, chevron

`WSheet`

bottom sheet with grabber, snap points

`WToggle`, `WSegmented`, `WTextField`

pill input, error text, character count

`WChatBubble`

incoming, outgoing, system, Fritz, translation toggle, failed (retry), pending

`WEmptyState`

illustration slot + title + body + action

`WErrorState`

icon + title + body + retry; variants: network, server, permission, not-found

`WSkeleton`

shimmer-free pulse (opacity 0.5↔1, 1200 ms), matches final layout

`WBanner`

offline, syncing, update available

`WToast`

success, info, error; top, auto-dismiss 3.5 s, swipe up

`WBadge`

earned, locked, progress

`WLevelNode`

done, current (pulse), chest, locked, gate

`WChart`

bar, line, heatmap, ring; animated, tooltip on long-press

---

## 4. Screen specifications
For each screen: **data**, **states**, **interactions**, **notes**. Haptic and motion names refer to chapters 5 and 12. Copy is German unless noted; all strings go through `intl` ARB files.

### 4.1 Splash
Data: Remote Config (min version, maintenance flag), auth state. Flow: logo + Fritz idle. If maintenance → `/maintenance`; if app below min version → `/update-required`; else route by auth/onboarding. Timeout 3 s then continue with cached config. No haptic.

### 4.2 Onboarding (7 steps)
Progress bar at top (animates per step). Back always available. Selected option: ink outline + streak accent (as in Figma). Primary button disabled until a valid choice. **Haptic:** `select` on every option, `tap` on Weiter. **Motion:** shared-axis horizontal between steps, Fritz changes mood per step. **States:** offline allowed until the *Teste mich* step and account creation; then show `WBanner` offline and let the user pick the self-assessed level instead. Draft persists across app kills.

### 4.3 Home (Figma 05)
Data: user doc, today's `days/{date}`, current lesson, 3 tasks, streak. Layout from Figma: greeting *Guten Morgen, {name}* + subline, streak flame with two stat cards (*7 Tage Streak*, *320 XP Diese Woche*), continue-learning card with a progress bar, *Deine nächsten Aufgaben* list (Lektion, Flashcards, Sprechübung with `+XP`), Fritz floating button, tab bar.

- **Loading:** skeleton cards. **Empty (new user, no history):** streak at 0, task list from plan, note "Los geht's mit deiner ersten Lektion". **All done today:** tasks collapse into a celebration card and a *Zusatzübung* suggestion. **Error:** cached data + banner; if none, `WErrorState`.
- **Interactions:** tap streak pill → `/streak`; tap continue card → lesson (hero transition); tap task → its flow; checkbox is display-only and fills when the server confirms; pull-to-refresh `refresh` haptic.

### 4.4 Level path (Figma 06)
Data: levels, units, user progress, unlock criteria progress. Nodes: A1 done (green dot), A2 current (ink outline, pulse), chest, B1 locked, B2, C1 locked, dotted connectors; bottom card *Bis B1*: 70 % Wörter behalten · 3 Gespräche mit Fritz · 1 Wiederholung with three progress bars.

- Tap a done/current node → unit detail. Tap locked → sheet explaining the missing criteria with a shortcut to the right activity. Tap chest → open if ready (celebrate) else show progress.
- **States:** loading skeleton of nodes, partial (content for a level not yet published shows "Bald verfügbar"), error with retry.
- **Motion:** connectors draw in on first view; current node pulse; completed node pops with `unlock` haptic when it becomes done.

### 4.5 Lesson player
Full screen. Top: close, segmented progress, heart-free (no lives). Body: exercise widget. Bottom: **Prüfen** (primary) then **Weiter**. Fritz mini-reaction in the corner. Save after every answer (`progress/{lessonId}.answers`).

- **Correct:** option fills success, `success` haptic, XP count-up +2. **Wrong:** shake, `error` haptic, correct answer shown with explanation, item re-queued at the end once.
- **Edge cases:** audio fails → show text fallback and a *Nochmal laden* button; mic denied → switch to type-the-answer variant and offer settings link; lesson content missing → `WErrorState` with report button; app backgrounded mid-exercise → resume at the same item.

### 4.6 Lesson result
XP earned (count-up), accuracy ring, new words list, streak update (flame animation if first active day), mission progress, *Weiter* and *Nochmal die Fehler*. If it completes a unit/level criterion, chain into level-up. Server call `completeLesson` runs here; show a skeleton row for XP until confirmed; if offline show "Wird gespeichert" chip.

### 4.7 Flashcards
Card shows article colour chip (der/die/das), word, tap to flip (3D), audio button. Buttons *Nochmal* / *Gewusst* (+ swipe left/right with threshold haptic). SRS: SM-2 variant (`ease`, `intervalDays`, `dueAt`, `lapses`). Session size 10–20, resumable. **Empty:** "Heute ist nichts fällig" with option to learn new words. **Error:** reviews are queued locally and synced.

### 4.8 Streak and missions
See Figma-style layout: big flame + number, week dots, 3-week activity grid, 100-day badge and weekly chest progress, today's missions with XP, shield count, handwritten note. States: at-risk (after 18:00 local and no activity, flame trembles once), broken (flame off, recovery offer), rest day (dash dot + copy "Heute ist Ruhetag").

### 4.9 Insights
Segmented Woche/Monat/Alle. Charts: minutes per day (bars), words learned (line), accuracy by skill (bars), heatmap, level progress ring. Every chart has an empty state ("Noch keine Daten – lerne heute 5 Minuten") and an accessible text summary.

### 4.10 Fritz (AI coach)
Bottom sheet from the floating button; snap 0.6 (quick actions) and 0.95 (full chat). Quick actions: **Erklär mir**, **Übersetze**, **Üben mit mir**, **Sprechen**; suggestion chips from the current lesson; input with mic. Full spec in chapter 8.

### 4.11 Groups and chat
See chapter 9. Tabs: *Gruppen*, *Direkt*, *Entdecken*. Group tile shows level pastel, last message, unread count.

### 4.12 Profile
Avatar (initials or photo), name, level chip, stats (XP, Wörter, Streak), badges grid (earned vs locked with progress), progress to next level, friends, links to settings. Edit profile sheet with validation.

### 4.13 Settings
Lernen (Tagesziel, Erinnerung, Ruhetag), Fritz (Niveau automatisch anpassen, Sprachausgabe, Erklärsprache), Benachrichtigungen (per type), Haptik (on/off), Bewegung reduzieren (follows OS, overridable), Konto (language, email link, sign out, export data, delete account), Datenschutz, Hilfe, Version. Destructive actions need confirm sheets; delete account needs recent login.

### 4.14 Notifications inbox
Grouped Heute/Gestern/Älter; unread dot; swipe to mark read; tap deep-links. Empty: "Alles gelesen". Error: cached list + retry.

### 4.15 Level-up
Sequence in 5.6. Rewards: XP, +1 shield, cosmetic. Primary *Weiter* goes to the path with the new node focused.

---

## 5. Interaction, animation and transitions (the most important chapter)
In a learning app, motion is not decoration. It confirms an action, shows progress, rewards effort and teaches where things are. Every animation below has a **purpose**, a **duration**, a **curve**, a **trigger**, a **reduced-motion fallback** and a **performance rule**.

### 5.1 Global rules

- Target 60 fps (120 fps on ProMotion). Animate only `transform` and `opacity` where possible; avoid `Opacity` widgets on large subtrees (use `FadeTransition` or color alpha); wrap animated regions in `RepaintBoundary`; never rebuild a list to animate one item.
- Use **implicit animations** for simple values (`TweenAnimationBuilder`, `AnimatedContainer`), **explicit controllers** for sequences, **Rive** for the flame and Fritz, **CustomPainter** for charts, rings and the path. Dispose every controller. One `AnimationController` per widget; never drive animations from Bloc state changes that fire faster than 60 Hz.
- **Reduced motion** (OS setting or Settings toggle): replace movement with a 100 ms fade, stop all loops (pulse, flame flicker), skip confetti, jump counters to the final value. Keep haptics unless the haptics toggle is off.
- Animations never block input. Anything over 400 ms is skippable by tap.
- Loops pause when the widget is off-screen or the app is backgrounded (`TickerMode`, `VisibilityDetector`).
- Budget: no frame over 16 ms in profile mode on a 3-year-old mid-range Android; fail the PR if the timeline test regresses by more than 20 %.

### 5.2 Streak
Element

Behaviour

Spec

Counter

Rolls from old to new number digit by digit

600 ms, `easeOutCubic`, digits slide vertically 16 px with fade

Flame (`WStreakFlame`)

Rive state machine, inputs: `lit` (bool), `intensity` 0–3 (num, grows with streak: 1–6, 7–29, 30–99, 100+), `celebrate` (trigger)

Idle flicker 1.8 s loop, amplitude 2 %; `celebrate` = scale 1→1.18→1 spring + 6 spark strokes outward, 700 ms

Flame when lost

Colour drains to grey outline, shrinks to 80 %

400 ms, no loop

At-risk

After the local at-risk time with no activity, the flame trembles once (±3 px, 3 cycles, 360 ms) and the pill outline turns streak orange

Once per session

Week dots (`WWeekDots`)

Filled dots pop in sequence from the first day to today

60 ms stagger, each scale 0→1.15→1 spring, 280 ms; today's ring draws its stroke 300 ms

Activity grid

Cells fade/scale in diagonally on first view

12 ms per cell index, 160 ms each, max 700 ms total

Milestone (7, 30, 100 days)

Full-screen moment: Fritz celebrates, flame scales, badge drops in with bounce, confetti

1.2 s, skippable, once per milestone

Shield used

Shield icon cracks and fades; toast "Dein Streak-Schutz hat dich gerettet"

500 ms

**Increment choreography (after a lesson):** result screen opens → XP count-up (800 ms) → if first active day: flame lights (`lit=true`, `celebrate`) with `streak` haptic → counter rolls → week dot for today fills last. Total ≤ 2.2 s, whole sequence tappable to skip.

### 5.3 Progress and charts

- **Linear progress:** width animates 600 ms `easeOutCubic` from the previous value; never from zero on rebuild (store the last value in the widget state).
- **Ring:** `CustomPainter` arc sweep 700 ms; center number counts up in sync.
- **Lesson segmented bar:** segment fills 240 ms when an exercise is answered; the current segment pulses subtly (opacity 0.6→1, 1.2 s) only while idle.
- **Bars:** grow from baseline, 60 ms stagger, 400 ms each, `easeOutBack` capped at 4 % overshoot. **Lines:** path draws via `PathMetric` 800 ms; points pop after. **Heatmap:** see 5.2.
- **Long-press tooltip** on any chart point: appears in 120 ms with `select` haptic per data point crossed.
- **XP chip:** `+20 XP` floats up 24 px and fades over 700 ms from the answer location, then merges into the XP total with a 120 ms scale.

### 5.4 Level path

- On first view each connector draws in order (`PathMetric`, 500 ms per segment, 120 ms stagger). On later views, no replay.
- Current node: pulse ring 1→1.06 scale and 0.4→0 opacity halo, 1.6 s loop.
- Node unlock: lock "clicks" open (rotation 12° + scale 1.1→1, 300 ms) + `unlock` haptic, the connector to the next node draws.
- Auto-scroll to the current node with `easeInOutCubicEmphasized`, 500 ms, on entry and after level-up.
- Locked node tap: node shakes 2 px × 2 cycles (200 ms), sheet slides up explaining requirements.

### 5.5 Lesson and exercise feedback
Moment

Animation

Haptic

Select option

Press scale 0.98 (100 ms), border becomes ink

`select`

Correct

Option fills `success` 160 ms, check draws 200 ms, Fritz `happy` 700 ms, `+XP` float

`success`

Wrong

Option shakes (±6 px, 3 cycles, 280 ms), fills `error` softly, correct option outlines `success`, explanation sheet slides up 240 ms

`error`

Next exercise

Shared-axis horizontal 300 ms (outgoing 0→−24 px + fade, incoming 24→0 + fade)

none

Flashcard flip

`Matrix4` rotateY 0→π in 320 ms; content swaps at π/2; perspective 0.001

`select`

Flashcard swipe

Card follows finger, rotates up to 8°; past 40 % width a tint (green/orange) fades in; release past threshold flies off in 200 ms, else springs back

`select` at threshold

Match pair

Two items lock together, shrink 4 % and turn pastel, 200 ms

`tap`

Order words

Dragged chip lifts (scale 1.05), gap highlights; on drop snaps with spring 220 ms

`select` on enter gap, `tap` on drop

Speak

Mic ring pulses with input level (0–1 mapped to scale 1–1.25); result chips pop in

`tap` start, `success`/`error` result

Lesson complete

Progress bar completes, screen cross-fades into result 300 ms

`levelUp` light variant

### 5.6 Level-up sequence (≤ 3 s, tap to skip)
0 ms background fades to the new level colour (240 ms) → 150 ms Fritz bounces in (spring from 0.6 scale) → 400 ms `LEVEL GESCHAFFT` + "A1 → A2" scale-in with `levelUp` haptic → 700 ms three reward cards rise in with 120 ms stagger (XP, shield, cosmetic) → 900 ms confetti burst (max 80 particles, 1.2 s, flat colours from the level palette) → *Weiter* button fades in at 1.6 s. Then the path scrolls to the new node.

### 5.7 Navigation and transitions
Transition

Spec

Tab switch

Cross-fade 200 ms; tab pill slides to the new tab 240 ms `easeOutCubic`; icon bounces 1→1.12→1; keep each tab's scroll position

Push (detail)

Shared-axis horizontal 300 ms

Home card → lesson

`Hero` on the card container, 360 ms, content cross-fades

Full-screen takeover (lesson, level-up)

Fade-through 300 ms

Bottom sheets (Fritz, explanations)

Spring slide, drag to dismiss, rubber-band at snap points, scrim fades 0→0.3

Onboarding steps

Shared-axis horizontal, progress bar animates, Fritz mood changes

Toasts / notification banner

Slide from top 240 ms, hold 3.5 s, swipe up to dismiss

Pull to refresh

Fritz bobs while loading; completes with `refresh` haptic

### 5.8 Messaging and AI motion

- **Bubble in:** slide 12 px + fade, 200 ms; own messages appear instantly with a `pending` clock icon that becomes a check when acknowledged.
- **Typing indicator:** three dots, staggered bounce 900 ms loop; Fritz shows `thinking` mood.
- **Fritz streaming:** text appears token by token (batched every 40 ms to avoid rebuild storms); the bubble grows smoothly with `AnimatedSize` (120 ms); scroll sticks to bottom unless the user scrolled up (then show a "↓ Neu" chip).
- **Fritz mood changes:** 200 ms cross-blend between Rive states.
- **Send failure:** bubble turns outline-error with a retry glyph, `error` haptic once.

### 5.9 Micro-interactions catalogue
Buttons press to 0.98 scale in 100 ms and release with a 160 ms spring. Toggles slide 160 ms with `select` haptic. Chips pop on select (1→1.06→1, 160 ms). Checkboxes draw their tick 200 ms. Text fields' border animates to ink 120 ms on focus; error text slides down 160 ms and the field does one 4 px shake. Empty-state illustrations breathe (scale 1→1.02, 3 s) and stop on reduced motion. Skeletons pulse (no shimmer sweep). Numbers anywhere that change (XP, words, streak) use the roll or count-up primitives from `core/animations`.

### 5.10 Implementation kit (`core/animations`)
`AnimatedCounter`, `RollingDigits`, `Staggered` (index → delay), `PressableScale`, `ShakeWidget`, `PulseHalo`, `DrawPath`, `SpringIn`, `ConfettiBurst` (flat shapes), `SharedAxisPage`, `FadeThroughPage`, `FritzController` (mood API), `FlameController`. Each has a widget test that pumps frames and asserts final values, and a reduced-motion test.

---

## 6. Application architecture and state management (Bloc / Cubit)

### 6.1 Stack
Flutter (latest stable, pinned in `.fvmrc`), Dart 3 sealed classes. Packages: `flutter_bloc`, `bloc_concurrency`, `hydrated_bloc`, `equatable`, `freezed` + `json_serializable`, `go_router`, `get_it` + `injectable`, `fpdart` (or a small `Result` type), `intl` + `flutter_localizations`, `rive`, `confetti`, `connectivity_plus`, `speech_to_text`, `flutter_tts`, `cached_network_image`, `widgetbook`. Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_messaging`, `flutter_local_notifications`, `firebase_remote_config`, `firebase_analytics`, `firebase_crashlytics`, `firebase_performance`, `firebase_app_check`, `firebase_storage`, `google_sign_in`, `sign_in_with_apple`. Testing: `bloc_test`, `mocktail`, `alchemist` (goldens), `integration_test`. Pin exact versions in `pubspec.lock` and update monthly.

### 6.2 Structure (feature-first, layered)

```
lib/
  app/            app.dart, router, di, flavors, theme wiring
  core/
    design_system/  tokens, components, widgetbook
    animations/     5.10 kit
    haptics/        HapticService
    error/          AppFailure, mapping from Firebase errors
    network/        ConnectivityCubit, retry policy
    l10n/
  data/           firebase data sources, DTOs, mappers, repositories impl
  domain/         entities, repository interfaces, use cases (only where logic exists)
  features/
    auth/ onboarding/ home/ path/ lesson/ flashcards/ streak/ insights/
    fritz/ groups/ chat/ profile/ settings/ notifications/ system/
      presentation/ (pages, widgets, cubit|bloc, states)
functions/        Cloud Functions (TypeScript)
firebase/         rules, indexes, emulator config, remote config template
tool/seed/        content seeding scripts
docs/             DECISIONS.md, api contracts, runbooks
```
Dependency rule: `presentation → domain ← data`. Firebase types (`DocumentSnapshot`, `User`) never leave `data/`.

### 6.3 Bloc vs Cubit rules

- **Cubit** for state with direct methods and no event ordering needs: settings, profile, home summary, insights, notifications inbox, connectivity, theme/haptics preferences.
- **Bloc** where events need ordering, debouncing or concurrency control: `LessonBloc` (answer, check, next, skip, resume), `FlashcardBloc` (flip, grade, undo), `ChatBloc` (send, retry, loadMore, receive), `FritzBloc` (send, cancel, regenerate), `AuthBloc`, `OnboardingBloc`, `PlacementBloc`.
- Use `bloc_concurrency`: `droppable()` for submit/check buttons, `restartable()` for search and Fritz cancel, `sequential()` for lesson answers and chat sends.
- **State shape:** one sealed state per screen or a single `Equatable` state with `status` enum (`initial, loading, success, empty, failure, offline`) plus data and `pending` flags. Failures carry an `AppFailure` (never a raw exception) and a stable `retryable` flag.
- **Streams:** repositories expose `Stream<T>`; Blocs subscribe with `emit.forEach` / `emit.onEach`; cancel on `close()`. Firestore listeners are attached only while a screen needs them.
- **Side effects** (haptics, navigation, toasts, analytics) go through `BlocListener` or a `UiEffect` stream; **never** from `build()` and never inside reducers.
- Use `BlocSelector`/`buildWhen` so a streak tick does not rebuild the whole Home.
- `hydrated_bloc` only for drafts and ephemeral progress: onboarding draft, in-progress lesson answers, the offline outbox.
- A global `AppBlocObserver` logs transitions in debug and sends non-fatal errors to Crashlytics in release.
- Dependency injection via `get_it`; Blocs are provided per route with `BlocProvider` and created from the container; repositories are singletons.
- Forbidden: `setState` for business state, global mutable singletons for state, `FutureBuilder` for data that changes, business logic in widgets.

### 6.4 Repositories (interfaces first)
`AuthRepository`, `UserRepository`, `ContentRepository` (levels, units, lessons, decks), `ProgressRepository` (lesson progress, days, missions), `SrsRepository`, `StreakRepository` (read-only + callable), `FritzRepository`, `GroupsRepository`, `ChatRepository`, `NotificationsRepository`, `ConfigRepository` (Remote Config), `AnalyticsService`. Every method returns `Future<Result<T, AppFailure>>` or `Stream<Result<...>>`. Offline behaviour is part of each interface's documentation.

### 6.5 Environments and flavors
`dev`, `staging`, `prod`, each a separate Firebase project, bundle id suffix (`.dev`, `.stg`), icon badge and `firebase_options_*.dart` generated with FlutterFire CLI. `dev` points to the **Emulator Suite** by default (Auth, Firestore, Functions, Storage) with a visible "EMULATOR" ribbon; switching to the cloud dev project is a flag, not a code change. CI builds staging on every merge and prod on tags.

---

## 7. Backend: Firebase (real from day one)
Region: pick `europe-west1` (Firestore multi-region `eur3` if available for the plan) for Functions and Firestore. Use **Cloud Functions v2 (TypeScript, Node LTS)**.

### 7.1 Services used
Authentication (Apple, Google, email link, anonymous upgrade), Firestore (offline persistence on), Cloud Functions, Cloud Messaging, Remote Config, Storage (avatars, audio), App Check (App Attest / Play Integrity, enforced), Crashlytics, Analytics, Performance Monitoring, Secret Manager (AI key), Scheduler (via scheduled functions), Emulator Suite, Security Rules tests.

### 7.2 Firestore data model
**User space**

```
users/{uid}
  displayName, photoUrl, uiLang, explainLang, level, unitId, goals[], dailyMinutes,
  reminderTime, restWeekday, timezone, xpTotal, xpWeek, weekStart,
  streak { current, longest, lastActiveDay, shields, recoverableUntil },
  placement { done, level, confidence }, capId, createdAt, lastSeenAt, appVersion
users/{uid}/devices/{deviceId}      fcmToken, platform, lang, updatedAt
users/{uid}/progress/{lessonId}     status, bestScore, attempts, answers{}, completedAt
users/{uid}/cards/{cardId}          deckId, ease, intervalDays, dueAt, reps, lapses, lastResult
users/{uid}/days/{yyyy-MM-dd}       minutes, xp, lessons, cardsReviewed, convoTurns, goalMet
users/{uid}/missions/{yyyy-MM-dd}   items[{id,type,target,progress,xp,done}], allDone
users/{uid}/badges/{badgeId}        earnedAt, progress
users/{uid}/unlocks/{level}         criteria{wordsRetained,convos,review}, unlockedAt
users/{uid}/notifications/{id}      type, title, body, deepLink, readAt, createdAt
users/{uid}/blocks/{otherUid}       createdAt
users/{uid}/aiThreads/{threadId}    mode, level, createdAt, lastAt
users/{uid}/aiThreads/{threadId}/messages/{id}   role, text, createdAt, tokens
```
**Content (read-only for clients, written by admin scripts)**

```
contentMeta/current                 version, publishedAt
levels/{A1..C2}                     title, order, published, coreWordCount
levels/{L}/units/{unitId}           title, order, topic, lessonIds[], published
levels/{L}/units/{unitId}/lessons/{lessonId}   title, order, minutes, exercises[], words[]
decks/{deckId}                      level, unitId, title
decks/{deckId}/cards/{cardId}       de, article, plural, explain{en,fr,ar}, audioPath, example
```
**Community**

```
groups/{gid}                        name, levelTag, description, ownerId, isPublic, memberCount,
                                    lastMessage{text,senderId,at}, createdAt, rulesVersion
groups/{gid}/members/{uid}          role, joinedAt, lastReadAt, muted
groups/{gid}/messages/{mid}         senderId, text, type, replyTo, createdAt, editedAt, deleted, reportCount
dms/{pairId}                        members[uidA,uidB], lastMessage{...}, lastReadBy{uid:ts}   (pairId = sorted uids joined by "_")
dms/{pairId}/messages/{mid}         as above
reports/{id}                        reporterId, targetPath, reason, createdAt, status
```
Modelling rules: documents under 20 KB; no unbounded arrays (use subcollections); denormalise display name and photo into messages only as `senderName` snapshots when needed for list speed; all timestamps are server timestamps; every document carries `schemaVersion`.

### 7.3 Indexes (declare in `firestore.indexes.json`)
`cards`: `dueAt asc` (+ `deckId`); `days`: `__name__ desc` limit queries; `messages`: `createdAt desc`; `groups`: `isPublic` + `levelTag` + `memberCount desc`; `notifications`: `createdAt desc`; `reports`: `status` + `createdAt`.

### 7.4 Security rules (default deny)

- `users/{uid}/**`: read/write only by `request.auth.uid == uid`, **except** server-owned fields: `xpTotal`, `xpWeek`, `streak`, `level`, `unlocks`, `badges`, `missions.done` are **writable only by Cloud Functions** (rules reject client changes via `request.resource.data.diff(resource.data).affectedKeys()`).
- Content collections: read for authenticated users, no client writes.
- Groups: read if public or member; create group requires auth and rate limit through a callable; messages: create only if member, `senderId == auth.uid`, text length 1–2000, `createdAt == request.time`; update only own message within 5 minutes; delete own or admin; no client change to `reportCount`.
- DMs: read/write only if `request.auth.uid in members`, and neither user has blocked the other (checked by function on send; rules enforce membership).
- `reports`: create-only for authenticated users.
- Storage: users write only `avatars/{uid}/*` (images ≤ 2 MB), audio is read-only.
- App Check enforced on Firestore, Functions, Storage.
- Every rule has a test in `firebase/rules-tests` (allow and deny cases), run in CI against the emulator.

### 7.5 Cloud Functions
Function

Type

Purpose

`onUserCreate`

auth trigger

Create `users/{uid}`, initial shields, default settings

`completeLesson`

callable

Validate lesson and answers, compute accuracy, award XP, update `days`, missions, streak, SRS seeds, and check unlock criteria in **one transaction**; idempotent via `clientRequestId`

`recordReviews`

callable

Batch apply flashcard results (SM-2), update `cards`, `days`, missions

`finishConversation`

callable

Validate Fritz conversation length and topics, award XP, count toward unlock

`evaluatePlacement`

callable

Score adaptive check, return level and unit

`claimChest` / `recoverStreak`

callable

Server checks eligibility, grants reward

`fritzChat`

HTTPS streaming / callable

AI proxy, see chapter 8

`dailyMissions`

scheduled hourly

For users whose local time is 04:00–05:00, create tomorrow's missions

`streakGuard`

scheduled hourly

Close the previous day for users whose local midnight passed (consume shield or reset), send at-risk push at the user's evening time

`weeklyReport`

scheduled

Compute weekly summary, create inbox item and push

`onGroupMessageCreate`

firestore trigger

Update `lastMessage`, unread counters, push to members (respect mute/blocks/quiet hours), basic profanity flag

`onReportCreate`

firestore trigger

Increment counters, auto-hide at threshold, notify moderators

`deleteAccount`

callable

Delete the user's data tree, messages anonymised to "Gelöschter Nutzer", tokens, storage files

`exportData`

callable

Create a JSON export in Storage with a signed URL (24 h)

Every callable: verify `auth`, verify App Check, validate input with a schema (zod), rate-limit per uid, return typed errors (`failed-precondition`, `resource-exhausted`, `unauthenticated`), log with a correlation id. Business rules live **only** here; the client displays results.

### 7.6 Time and streak correctness
Store the user's IANA `timezone`; the "day" key is `yyyy-MM-dd` in that zone computed on the server. The client sends its local day only as a hint. Handle: travel (timezone change takes effect from the next day, never removes an earned day), DST (use a timezone library, never add 24 h), device clock skew (use server time), duplicate submissions (idempotency keys).

### 7.7 Remote Config
Keys: `min_version_ios`, `min_version_android`, `maintenance_mode`, `maintenance_message`, `fritz_enabled`, `fritz_daily_limit`, `streak_at_risk_hour`, `feature_groups_enabled`, `content_version`, `xp_values` (JSON). Defaults compiled into the app so the app works if fetch fails.

### 7.8 Offline and sync
Firestore persistence enabled with unlimited cache disabled (cap 100 MB). Content is prefetched per unit when on Wi‑Fi and cached. Writes that need server logic (`completeLesson`, `recordReviews`) go through an **outbox** (`hydrated_bloc`): items persist, retry with exponential backoff (1 s → 60 s, jitter), preserve order, carry `clientRequestId`. UI shows a `pending` chip until confirmed. Conflicts: server wins; the client reconciles from the user document stream.

---

## 8. Fritz, the AI coach
**Architecture.** The app never talks to the AI provider. Flow: app → `fritzChat` Cloud Function (App Check + Auth) → provider API (key in Secret Manager) → streamed back. Provider is swappable behind an interface `LlmProvider { stream(messages, options) }`. The owner will supply the API key; use Secret Manager name `LLM_API_KEY`.

**Modes** (each has its own system prompt template in `functions/prompts/`)

1. **Chat** (default): conversational German at the learner's level.
2. **Erklär mir**: short grammar/vocabulary explanation with 2 examples and a mini-check.
3. **Übersetze**: translate and explain nuances, optionally into the explain language.
4. **Üben mit mir**: role-play dialogues by topic (café, train station, job interview, doctor), with scenario cards.
5. **Sprechen**: spoken exchange using speech-to-text and text-to-speech.
6. **Placement**: structured JSON output for scoring.
**Prompt rules (all modes)**

- German only for replies; level-adapted (A1: ≤ 8 words per sentence, present tense, 600-word vocabulary; A2: simple past forms, connectors; B1: opinions, subordinate clauses). The explain language appears only in short "Hilfe" lines, collapsed by default.
- Be encouraging, never sarcastic or guilt-inducing; correct at most **one or two** errors per turn, show the corrected sentence and a one-line reason.
- Stay in scope: German learning. Politely decline unrelated or unsafe requests and steer back.
- No medical, legal, financial advice; no personal data requests; refuse harassment, sexual or violent content.
- Include context: level, unit topic, recent mistakes (top 5), goals. Never include other users' data.
- Output format for structured modes: strict JSON validated server-side; on invalid JSON retry once, then fall back to a canned response.
**Limits and cost control.** Per-user daily message cap (Remote Config `fritz_daily_limit`, default 40), per-minute rate limit, max input 1000 chars, max output tokens by mode, conversation window of the last 12 turns with a rolling summary, response caching for identical "Erklär mir" topics at the same level. Log token counts (not content) for cost dashboards.

**UX states.** Thinking (mood + typing dots), streaming, cancelled, failed (retry), rate-limited ("Fritz braucht eine Pause. Morgen geht's weiter." with reset time and offline practice cards), offline (input disabled, banner, suggest flashcards), unsafe input (gentle redirect), provider outage (fallback message + auto-retry). Each message has a translate toggle, copy, and a 👎 report action.

**Privacy.** Conversations stored for the user's history; deletable per thread and by account deletion; not used for provider training (set the provider's data-retention option accordingly); a short consent line on first use.

---

## 9. Community and messaging
**Scope v1:** public level groups, user-created groups, 1-to-1 messages, text only (images later). Everything German-learning related; group descriptions state the language rule.

**Features**

- Discover groups by level and topic; join/leave; members list; roles (owner, admin, member).
- Realtime chat: Firestore listener on the latest 30 messages, pagination upward with `startAfterDocument`, 30 at a time; date separators; reply-to; edit within 5 min; delete own; long-press menu with `menu` haptic.
- Unread: `members/{uid}.lastReadAt` compared to `lastMessage.at`; badge on tab and tile; marking read when the chat is visible and scrolled to bottom.
- Typing and presence are **omitted in v1** (cost, privacy); design leaves room.
- Send flow: optimistic bubble with `pending`; on server ack show a check; on failure show retry; messages typed offline are queued and sent in order.
- Mute per chat; quiet hours respected by push.
**Safety (required for App Store review of user-generated content)**

- **Report** any message or user (reason list + optional text), **block** user (hides content, prevents DMs), **leave** group.
- Terms and community rules accepted before first post; short rules sheet pinned in every group.
- Server-side checks: length, rate limit (10 messages / 10 s), link and profanity filter, auto-hide at 3 reports pending review.
- Moderator tooling: admin web or Firebase console query documented in `docs/moderation.md`; response target 24 h.
- Minors policy: minimum age 16 (EU digital consent varies; confirm with the owner); DMs disabled for users who declare under 18 unless added by mutual friend request (decision logged in `DECISIONS.md`).
**Empty/error states.** No groups: "Finde eine Gruppe zu deinem Niveau" with suggested groups. No messages: Fritz-style starter prompt ("Sag Hallo!"). Load failure: retry. Blocked or removed: explanatory screen. Group deleted while open: redirect with toast.

---

## 10. Notifications
**Channels (Android) / categories (iOS):** `reminders`, `streak`, `missions`, `community`, `fritz`, `system`. Each can be switched off in Settings; the OS permission is separate.

Type

Trigger

Example copy (German)

Deep link

Daily reminder

User's reminder time, only if no active day yet

"10 Minuten Deutsch? Deine Aufgaben warten."

`/home`

Streak at risk

`streak_at_risk_hour` (default 19:00 local), no activity yet, streak ≥ 3

"Dein Streak ist bei 12 Tagen. Eine kurze Lektion reicht."

`/lesson/next`

Shield used

Midnight job consumed a shield

"Dein Streak-Schutz hat dich gerettet."

`/streak`

Mission done / chest ready

Server event

"Truhe bereit – hol dir deine Belohnung."

`/streak`

Level unlocked

Criteria met

"Fritz sagt: Du bist bereit für B1."

`/levelup/B1`

Group message

`onGroupMessageCreate`, not muted, not own

"Lena in A1 Anfänger: Guten Morgen!"

`/groups/:gid`

Weekly report

Sunday evening

"Deine Woche: 48 Wörter, 5 aktive Tage."

`/insights`

Win-back

3 and 7 days inactive, max 2 total

"Kein Stress. Fang mit 5 Minuten an."

`/home`

Rules: max **2 pushes per day** across non-chat types; quiet hours 22:00–08:00 local (configurable); no guilt wording; every push is also stored in `users/{uid}/notifications`; sending is decided server-side and de-duplicated per day; tokens stored per device and refreshed on `onTokenRefresh`; invalid tokens are deleted on send failure.

**Permission flow:** never ask on first launch. After the plan screen show Fritz with one sentence of value and *Erinnerungen aktivieren* / *Später*. If denied, show a quiet banner in Settings with *In den Einstellungen öffnen*; re-ask at most once after a streak of 3 days. **Foreground:** show the in-app `WToast` banner (not a system banner) and update badges. **Background tap:** route through `go_router` after auth is ready (cold start included). iOS badge count = unread inbox items.

---

## 11. Failure, offline and edge-case handling
Principles: never show a blank screen; never lose user input; say what happened in plain words; always offer one next action; log everything non-user-facing to Crashlytics (non-fatal) with context.

`AppFailure` taxonomy: `network`, `timeout`, `unauthenticated`, `permissionDenied`, `notFound`, `rateLimited`, `serverError`, `validation`, `conflict`, `contentMissing`, `unknown`. Each maps to copy, icon, retryable flag and analytics code in one table in `core/error`.

Situation

Detection

User experience

System behaviour

No connection at launch

`connectivity_plus` + failed ping

Home from cache with `WBanner` "Offline – dein Fortschritt wird gespeichert"

Firestore cache, outbox active, retries on reconnect

Connection drops mid-lesson

Listener + timeout

Lesson continues from loaded content; completion shows "Wird gespeichert" chip

`completeLesson` queued with `clientRequestId`

Slow network

No data after 300 ms / 10 s

Skeleton at 300 ms; at 10 s message "Das dauert länger" + retry

Cancel and retry with backoff

Callable fails (5xx)

`serverError`

Toast + retry; result screen keeps local values flagged `pending`

Exponential backoff up to 5 tries, then park in outbox

Auth expired / revoked

`unauthenticated`

Sheet "Bitte melde dich neu an"; local drafts kept

Re-auth, replay outbox

Permission denied (rules)

`permissionDenied`

Generic "Das hat leider nicht geklappt"

Crashlytics non-fatal with path

Content missing / unpublished

`contentMissing`

`WErrorState` with *Melden* and *Zurück*

Report to analytics, skip item in lesson if possible

Audio load fails

Player error

Text fallback + *Nochmal laden*

Retry once automatically

Mic permission denied

Permission status

Switch to typed answer; link to settings

Mark exercise as `typed`

Speech recognition unavailable

Plugin error

Same as above; Fritz speaking mode disabled with explanation

Feature flag local

TTS unavailable

Plugin error

Show text only

Retry next session

Fritz rate limit

`rateLimited`

"Fritz braucht eine Pause" with reset time + offline practice

Server counters

Fritz provider outage

5xx / timeout 20 s

Message with retry; suggest flashcards

Circuit breaker for 60 s

Message send fails

Write error

Bubble with retry icon, keeps text

Queue in outbox, order preserved

Blocked / removed from group

Rules / membership

Explanation screen

Remove local cache

Account deleted elsewhere

Auth state

Sign-out screen

Clear caches

Forced update

Remote Config

`/update-required` with store button, blocks app

Check on resume

Maintenance

Remote Config

`/maintenance` message + retry

Poll every 60 s

Time zone / clock change

Device tz vs stored

Prompt "Zeitzone ändern?" once

Server confirms; never drop earned days

Low storage / cache full

Write errors

Toast, content streams without cache

Evict oldest cache

Image fails

`errorBuilder`

Colour block with initials/icon

Retry on scroll

Duplicate tap / double submit

Bloc `droppable()`

Button shows loading, ignores taps

Idempotency key

App killed mid-lesson

Hydrated state

Resume card on Home: "Weiter bei Aufgabe 6"

Restore answers

First run with empty Firestore (bad deploy)

Zero levels

`WErrorState` "Inhalte werden vorbereitet"

Alert via logs

Corrupt local state

Deserialise failure

Reset that store, keep auth

Report non-fatal

**Empty states (required copy slots):** Home (no history), Path (level not published), Flashcards (nothing due), Streak (no activity yet), Insights (no data), Groups (none joined), Chat (no messages), Notifications (all read), Search (no results), Badges (none earned), Friends (none). Each has an illustration slot, one sentence, one action.

**Validation rules:** display name 2–30 chars; message 1–2000; group name 3–40; reminder time within 06:00–22:30; inline errors under fields, never only toasts.

---

## 12. Haptics and feedback catalogue
`HapticService` wraps platform haptics (use `HapticFeedback` and, for richer patterns, a Core Haptics-capable package behind the same interface). It reads two preferences: user toggle `haptics` and OS reduce-haptics where exposed. All calls go through named events so the pattern can be tuned in one place.

Event

Pattern

Used in

`tap`

light impact

Buttons, send, drop, checkbox

`select`

selection click

Chips, options, toggles, tab switch, flip, pickers, chart scrub

`success`

medium impact, 70 ms gap, light impact

Correct answer, mission done, save

`error`

two light impacts 90 ms apart (or notification-error)

Wrong answer, send fail, validation shake

`warning`

one heavy tap

Destructive confirm opens, at-risk streak

`streak`

heavy impact + light after 120 ms

Streak increment, shield saved

`unlock`

medium + light + success sequence

Node unlock, chest open

`levelUp`

rising pattern: light, medium, heavy over 400 ms

Level-up, lesson complete

`menu`

medium impact

Long-press menus

`refresh`

light impact when threshold crossed

Pull to refresh

Rules: one haptic per user action; no haptics during passive animations except `levelUp`/`streak`; never more than 4 events per second; pair each haptic with a visual change within 100 ms; no sound by default (a subtle sound pack is a later option controlled by a toggle, defaulting off).

**Response-time rules:** tap acknowledgement ≤ 100 ms; local optimistic UI update ≤ 100 ms; server confirmation may lag but shows `pending`; any wait over 300 ms shows a skeleton or spinner in place; any wait over 10 s offers retry and cancel.

---

## 13. Accessibility and localization
**Accessibility (target WCAG 2.2 AA)**

- Semantics: every interactive widget has a label, role, state and hint; decorative art is excluded; streak, XP and progress announce meaningful text ("Streak: 12 Tage, heute noch offen").
- Targets ≥ 48×48 dp; spacing ≥ 8 dp between targets.
- Text scales to 200 % without clipping (use flexible layouts, `FittedBox` only for numbers); minimum 12 sp.
- Colour is never the only signal: correct/wrong also use icon and text; level colours also carry the level label.
- Screen readers: lesson focus moves to the new exercise prompt; correct/wrong results are announced; chat announces new messages politely; Fritz streaming announces on completion.
- Reduced motion, bold text, high contrast, and haptics toggles respected.
- Keyboard and switch access: logical focus order; `Esc`/back closes sheets.
- Audit with VoiceOver and TalkBack on each release; record results in `docs/a11y-report.md`.
**Localization**

- ARB files for `en`, `fr`, `ar`; German strings for learning content live in Firestore, not ARB. UI German chrome in Figma (e.g. *Start, Weg, Gruppen, Profil*) is kept as the **brand voice** and also localised through ARB so it can follow the UI language later; ask the owner if the chrome should stay German for all users (log decision).
- RTL: mirror layout, icons that imply direction, progress fills, and swipe directions; German text stays LTR inside RTL screens (use `Bidi` isolates). Numbers use Western digits by default (setting later).
- Plurals and genders via ICU messages; dates and numbers via `intl`.
- Fonts: ensure glyph coverage; fallbacks defined; test long French strings (+30 % length).

---

## 14. Analytics and observability
No PII in events (no names, emails, message text). Events use `snake_case`, include `level`, `app_version`, `flavor`.

Event

Parameters

`onboarding_step`

step, selected

`placement_completed`

level, confidence, duration

`lesson_started` / `lesson_completed`

lessonId, unitId, accuracy, duration, offline

`exercise_answered`

type, correct, attempt

`flashcard_session`

cards, accuracy

`streak_extended` / `streak_lost` / `shield_used`

length

`mission_completed`, `chest_opened`

type

`level_unlocked`

from, to, via (criteria/test)

`fritz_message_sent`

mode, length bucket, outcome

`group_joined`, `message_sent`, `report_submitted`

groupLevel

`notification_received` / `notification_opened`

type

`paywall`-free: *none in v1*

`error_shown`

failureType, screen, retryable

`offline_sync`

queued, flushed, latency

Crashlytics: custom keys `uid_hash`, `level`, `flavor`, last route. Performance Monitoring traces: `cold_start`, `lesson_load`, `complete_lesson_roundtrip`, `fritz_first_token`. Dashboards and alerts: crash-free sessions < 99.5 %, `complete_lesson` error rate > 2 %, Fritz error rate > 5 %, notification open rate drops 30 % week over week, Firestore reads per DAU above budget.

---

## 15. Testing strategy
Layer

What

Tools

Gate

Unit

Domain logic, SM-2, streak math (client display), mappers, validators

`test`

≥ 90 % domain

Bloc/Cubit

Every event → state sequence, failures, concurrency (`droppable`, `restartable`)

`bloc_test`, `mocktail`

Every Bloc, all states

Widget

Each component state; each screen in loading/content/empty/error/offline

`flutter_test`

All screens, all states

Golden

Components and 14 key screens × states × (1.0×, 1.3× text, RTL)

`alchemist`

No unreviewed diffs

Animation

Frame-pumped tests assert end values, reduced-motion path

`flutter_test`

Every `core/animations` widget

Integration

Onboarding → first lesson → streak; offline lesson → sync; Fritz limit; chat send/retry; notification deep link

`integration_test` + Emulator Suite

Must pass on iOS sim and Android emu

Rules

Allow and deny matrix for every collection and field

`@firebase/rules-unit-testing`

100 % of rules paths

Functions

Every callable: success, invalid input, unauth, rate limit, idempotency, transaction races

`firebase-functions-test` + emulator

≥ 90 % lines

Load

Chat fan-out, `completeLesson` concurrency

k6 or Artillery against emulator/staging

p95 < 800 ms

Performance

Frame timing on lesson, path, level-up; cold start

Flutter DevTools, `flutter drive --profile`

No frame > 16 ms median device; cold start < 2 s

Accessibility

Semantics tests + manual screen-reader pass

`meetsGuideline` matchers

AA checklist

Security

Rules fuzz, secrets scan, dependency audit

CI

No high findings

Manual QA

Exploratory per release using the matrix below

TestFlight / Play internal

Sign-off sheet

**Device matrix:** iPhone SE (small), iPhone 15/16, iPhone 16 Pro Max; Pixel 6a, Samsung A-series low-end, one tablet. OS: current and previous major.

**Scenario matrix (must be scripted):** fresh install, reinstall with existing account, offline first launch, airplane mode mid-lesson, flaky 2G throttle, time-zone change, midnight rollover during a lesson, DST change day, two devices on one account, token refresh, notification permission denied then granted, mic denied, background kill mid-lesson, large text + RTL + reduced motion, 1,000-message group, blocked user, deleted account, forced update, maintenance flag.

**CI:** format, analyze, unit/bloc/widget/golden tests, rules and functions tests on the emulator, build flavors, upload staging builds; protected main branch; conventional commits.

---

## 16. Audit, security and compliance checklist
**Security**

- App Check enforced; rules default deny; server-owned fields protected; callables validated and rate-limited; no secrets in the repo or the app bundle; Secret Manager for the AI key; least-privilege service accounts; dependency and licence scan in CI.
- No client-side trust for XP, streak, level, unlocks.
- Input sanitisation on messages (plain text only, links rendered non-clickable unless allow-listed).
- Biometric/lock not required, but sign-out clears local caches and outbox.
**Privacy and legal (EU/France and Tunisia users)**

- Privacy policy and terms linked in onboarding, settings and store listings; consent for notifications and analytics (analytics default **on only after consent** in the EU).
- Data minimisation: store only what the features need; no precise location; message content only in chats and AI history.
- Rights: in-app **export** and **delete account** (functions in 7.5); retention policy documented (e.g. AI threads 12 months unless the user keeps them).
- Age gate at sign-up; confirm minimum age with the owner.
- Apple: Sign in with Apple offered alongside Google; privacy nutrition labels; UGC rules (report, block, filter, contact info); account deletion in app. Google Play: Data safety form, target API level, deletion URL.
**Quality audit before each release:** design audit against Figma (spacing, type, colour, states), motion audit against chapter 5, haptics audit against chapter 12, accessibility audit, performance audit, copy audit (tone, no guilt), content audit (random sample of 20 exercises per unit by a German speaker).

---

## 17. Delivery plan (milestones with Definition of Done)
#

Milestone

Scope

Done when

M0

Foundation

Repo, flavors, Firebase projects (dev/stg/prod), Emulator Suite, CI, lint rules, DI, router skeleton, `AppFailure`, `HapticService`, observers

App boots on all flavors against emulators; CI green

M1

Design system

Tokens, components with states, Widgetbook, goldens, Rive assets placeholders (flat Fritz/flame), animation kit

Gallery complete; goldens approved

M2

Auth and onboarding

Apple/Google/email link/anonymous, 7-step onboarding, placement flow (function), plan screen, notification pre-prompt

New user reaches Home with real Firestore data

M3

Content and lessons

Seed scripts, content repository, lesson player (all exercise types), result screen, `completeLesson`

A1 Unit 1 playable end to end, offline-safe

M4

Flashcards (SRS)

Decks, review session, `recordReviews`, due queue

SRS intervals verified by tests

M5

Streak, XP, missions

Functions (`streakGuard`, `dailyMissions`), Home, Streak screen, week dots, chest, shields, animations

Streak correct across timezone/DST tests

M6

Path and unlocks

Level path, unit detail, criteria progress, unlock logic, level-up

Level unlock works via criteria and test

M7

Fritz

`fritzChat`, modes, sheet UI, limits, safety

All modes work; limits and failures tested

M8

Community

Groups, DMs, moderation tools, push

Report/block flows pass review checklist

M9

Notifications and settings

FCM, inbox, settings, profile, insights

All notification types verified on devices

M10

Hardening

Offline matrix, a11y, performance, localisation (en/fr/ar), security audit

All chapter 11 and 15 scenarios pass

M11

Beta

TestFlight/Play internal, crash and analytics review, store assets

Crash-free ≥ 99.5 % over 7 days

Each milestone ends with: demo script, updated `DECISIONS.md`, test report, and a screenshot set per screen/state.

---

## 18. Content, assets and handoff
**Content seed (`tool/seed`).** A Node script using the Admin SDK reads JSON/CSV from `content/` and writes `levels/units/lessons/decks/cards`, bumps `contentMeta/current.version`, and is idempotent. Launch scope: A1 (6 units), A2 (6 units), B1 (4 units); about 30 core words per unit with article, plural, example sentence, explanations in en/fr/ar, and audio (TTS generated files stored in Storage or on-device TTS fallback). Sample unit — **A1 · Begrüßungen:** words *Hallo, Tschüss, Danke, Bitte, Guten Morgen, Guten Abend, Ja, Nein, Entschuldigung, Wie heißt du?, Ich heiße…, Woher kommst du?*; lessons: Hallo und Tschüss; Sich vorstellen; Höflich sein; Mini-Dialog mit Fritz. Content must be reviewed by a German speaker before release.

**Assets.** Fritz: Rive file with moods (idle, happy, thinking, listening, speaking, celebrating, sleepy, confused) in the *flat* style (solid colours, ink outline, black cap with red/gold band, no gradients or shadows). Flame: Rive state machine with `lit`, `intensity`, `celebrate`. Icons: one consistent 24 px outline set (Start, Weg, Gruppen, Profil, mic, send, bell, settings). App icon and launch screen use Fritz on `paper`. Fonts: Bricolage Grotesque, DM Sans, Caveat, plus an Arabic family.

**Hand-over pack (`wortwerk-agent-pack`).**

```
README.md                 how to use the pack
design/screens.html       all 16 boards as reference markup
design/tokens.json        design tokens
screenshots/              PNG exports from Figma, one per frame (see naming)
```
Screenshot naming: `NN-screen-name@2x.png`, e.g. `05-home@2x.png`, `06-level-path@2x.png`, plus state variants `05-home-empty@2x.png`, `05-home-offline@2x.png`. Export from Figma at 2× (select frames → Export). Screenshots of the final Figma frames take precedence over `screens.html`.

**Open decisions (owner to confirm; agent logs the default and proceeds)**

1. Minimum age and DM policy (default 16, DMs limited).
2. UI chrome language: German for all users or follow UI language (default follow UI language, brand words stay German).
3. AI provider and model (default: provider-agnostic interface, key supplied by owner).
4. Rive vs painter for Fritz/flame (default Rive; painter fallback).
5. Native iOS tab bar vs custom pill (default custom, matching Figma).
6. Monetisation (default none in v1; data model unaffected).
7. Sound effects (default off, haptics on).