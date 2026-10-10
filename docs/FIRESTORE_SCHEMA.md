# Firestore schema and provisioning status

Firestore is a document database: collections appear when trusted code writes
documents; empty collections cannot be pre-created as tables. This file records
the intended document boundaries and separates paths used by working features
from paths reserved for features that do not have a backend yet.

## Provisioning boundary

The repository's default Firebase project is `demo-wortwerk-dev` and the dev
app uses the Emulator Suite. The Console URL for `wortwerk-35912` does not
provide credentials. No Firebase CLI login or Google Cloud credentials were
available during this change, so no remote database, indexes, or rules were
changed. Do not point the default alias at production to provision it.

To provision the local development database, run the emulator command in the
README. Apply rules and indexes to a separately configured staging project only
after its Firebase project ID and deployment credentials are supplied through
the normal release environment. Deploying rules or indexes does not create
content documents.

## Active paths

| Path | Owner and purpose | Current state |
|---|---|---|
| `users/{uid}` | Client creates the initial profile, saves validated onboarding choices and user-owned settings, and may edit the display name; trusted Functions update XP, streak, active level, and other server-owned progress. | Implemented; rules restrict profile edits to validated owner fields and protect progress fields. Profile settings currently include daily goal, reminder time, rest weekday, adaptive-level preference, speech output preference, and notification category preferences. |
| `users/{uid}/days/{yyyy-MM-dd}` | Functions aggregate activity by the learner's IANA timezone. | Implemented for XP, lesson completions/attempts, card reviews, and Fritz turns; one qualifying Fritz conversation adds 40 XP and activates that day; read by the streak summary. |
| `users/{uid}/missions/{yyyy-MM-dd}` | Server-generated goal-focused daily missions and completion totals. | `getDailyMissions` initializes three mission records. First confirmed lesson completion, ten-card review, or six-turn Fritz conversation marks its matching task and awards 20/20/30 XP once. Owner read is permitted; client writes are denied. |
| `users/{uid}/progress/{lessonId}` | Functions store lesson completion and best aggregate result. | Implemented for the single A1 greetings lesson. |
| `users/{uid}/progress/{lessonId}/requests/{clientRequestId}` | `completeLesson` idempotency receipt. | Written only by Functions; owner read is permitted. |
| `users/{uid}/levelProgress/{levelId}` | Server-owned aggregate criteria for level progression. | Review and Fritz transactions maintain retained core words, qualifying conversations, and passing review rounds. Owners can read; clients cannot write. |
| `users/{uid}/unlocks/{levelId}` | Server-owned level access grant. | Created once when all published level criteria are met; `completeLesson` requires the learner's current/earlier level or this grant. Owners can read; clients cannot write. |
| `users/{uid}/cards/{cardId}` | Functions store per-card spaced-repetition schedule. | Implemented for reviewed cards; owner read is permitted. |
| `users/{uid}/notifications/{notificationId}` | Trusted events create learner inbox items; `markNotificationRead` sets `readAt`. | Owner read only. A level unlock creates a localized `levelUnlocked` notification in the same transaction as the unlock and reward; authenticated token registration and push delivery are implemented, with platform credentials still required. |
| `users/{uid}/devices/{deviceId}` | Authenticated callable stores the user's FCM token and language/platform metadata. | Server-only token records; authenticated disable removes registrations. Physical platform delivery setup remains external. |
| `users/{uid}/reviewSessions/{clientRequestId}` | `completeFlashcardReview` idempotency receipt. | Implemented; owner read is permitted. |
| `users/{uid}/aiThreads/{threadId}` and `/messages/{messageId}` | Server-owned Fritz thread and persisted learner/tutor messages. | `fritzChat` writes; the learner can read only their own messages. Client writes are denied. |
| `users/{uid}/fritzUsage/{dayId}` and `/fritzRateLimits/current` | Server-owned daily and per-minute Fritz request counters. | Implemented inside callable transactions; client access is denied. |
| `users/{uid}/fritzRequests/{clientRequestId}` | Server-owned Fritz idempotency receipt and request fingerprint. | Implemented; Admin SDK only. Reusing an ID for different message content is rejected. |
| `levels/A1` and `levels/A1/units/a1_greetings/lessons/a1_greetings` | Published A1 path and lesson authored in the content source. | Level seed declares the ten core vocabulary IDs; server scoring and progression use published documents. The path joins per-lesson completions and server-owned unlock criteria. `content/a1_greetings.json` remains the lesson source. |

All new documents written by the lesson/review/Fritz/mission transactions include
`schemaVersion: 1`. The client cannot directly write progress, day totals, SRS
schedules, or idempotency records. The Admin SDK used by Cloud Functions
bypasses Firestore Security Rules, so server input validation and transaction
logic remain the write boundary.

Rerun `functions/scripts/seed-content.cjs` in the development emulator after
updating this progression slice so `levels/A1.coreVocabularyCardIds` is present.

## Planned paths from the product specification

These are schema targets, not provisioned or populated collections. They must
remain inaccessible from clients until their server workflows, data contracts,
and security rules are implemented.

```text
contentMeta/current
levels/{levelId}
  units/{unitId}
    lessons/{lessonId}
decks/{deckId}
  cards/{cardId}
users/{uid}
  devices/{deviceId}
  badges/{badgeId}
  unlocks/{levelId}
dms/{pairId}/messages/{messageId}
```

Published curriculum is readable by authenticated learners and writable only
through admin publishing tools. `functions/scripts/seed-content.cjs` publishes
the existing greetings lesson and its level/unit documents. It requires an
explicit Firebase project ID, and remote runs require a second matching
`--confirm-project` argument. The emulator smoke flow loads the same source
lesson before exercising the callable. The current lesson text was migrated
from the app; this does not constitute independent German-speaker review or
complete curriculum authoring. No additional curriculum or sample learners
were seeded.

## Community paths (development slice)

| Path | Owner and purpose | Current state |
|---|---|---|
| `groups/{groupId}` | Curated public group metadata and latest-message summary. | Emulator seed provides three starter groups; only published, public groups are discoverable. |
| `groups/{groupId}/members/{uid}` | Server-owned membership and join timestamp. | Join requires a signed-in account, age 16+ self-attestation, and rules version 1 acceptance. Join/leave are callable-only. |
| `groups/{groupId}/messages/{messageId}` | Server-owned text messages, author identity, visibility, and report count. | Members can read visible messages; send is callable-only, bounded, link-free, idempotent, and rate-limited. Three distinct reports hide a message. |
| `users/{uid}/blocks/{otherUid}` | Learner-owned block preference, created by callable. | Read-only to the owner; client writes denied. Current app hides blocked authors after reading the block list; this does not filter the Firestore query itself. |
| `reports/{reportId}` | Moderation record for a message report. | Callable-only; duplicate reports by the same user are rejected. Console review workflow is in `docs/moderation.md`. |
| `users/{uid}.age16AttestedAt`, `.communityRulesAcceptedAt`, `.communityRulesVersion`, `.joinedCommunityGroupIds` | Consent evidence and discoverability summary. | Timestamps/version are set by the join callable, with no date of birth collected. |

The development slice has no direct messages, friend requests, group creation,
read receipts, pagination, moderator console, or profanity/language-quality
filter. Do not treat self-attestation as a release policy decision. Mission and
notification documents are server-owned. Notifications support the inbox and
level-unlock event; push setup and reminder scheduling remain. Fritz's thread
read and server-write boundaries are described in Active paths; model use
remains gated by `FRITZ_AI_ENABLED=false` until exposed credentials are revoked
and replacement credentials are configured in Secret Manager.

## Operational files

- `firestore.rules` is the client authorization boundary.
- `firestore.indexes.json` declares the composite queries in `docs/SPEC.md`.
- `firebase.json` binds both files for emulator and explicit deployments.
- `content/a1_greetings.json` is the only current lesson source document; the
  app and completion function both load the corresponding Firestore document.
- Firestore's single-field indexes cover the current date range query; the
  declared composites support the planned due-card, feed, discovery, inbox, and
  report queries.

Firestore creates each collection on the first document write. Avoid writing
empty marker documents solely to make a collection appear in the Console.
