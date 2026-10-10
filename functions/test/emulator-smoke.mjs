import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const projectId = process.env.GCLOUD_PROJECT;
if (!projectId?.startsWith("demo-wortwerk-")) {
  throw new Error("Emulator smoke test requires a demo-wortwerk project.");
}

const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
if (!authHost) {
  throw new Error("Firebase Auth emulator is not running.");
}

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!firestoreHost) {
  throw new Error("Firestore emulator is not running.");
}

const app = initializeApp({ projectId }, `smoke-${randomUUID()}`);
const firestore = getFirestore(app);
async function invokeCallable(name, idToken, data) {
  const response = await fetch(
    `http://127.0.0.1:5001/${projectId}/europe-west1/${name}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({ data }),
    },
  );
  const responseBody = await response.text();
  assert.equal(
    response.status,
    200,
    `${name} should succeed: ${responseBody}`,
  );
  return JSON.parse(responseBody);
}
const curriculum = JSON.parse(
  await readFile(new URL("../../content/a1_greetings.json", import.meta.url), "utf8"),
);
await firestore.collection("levels").doc(curriculum.levelId).set({
  schemaVersion: 1,
  levelId: curriculum.levelId,
  title: curriculum.levelId,
  order: 1,
  published: true,
  coreVocabularyCardIds: [
    "greeting_hello",
    "greeting_good_morning",
    "greeting_good_day",
    "greeting_good_evening",
    "greeting_bye",
    "greeting_goodbye_formal",
    "greeting_thanks",
    "greeting_please",
    "greeting_name",
    "greeting_introduce",
  ],
});
await firestore
  .collection("levels")
  .doc(curriculum.levelId)
  .collection("units")
  .doc(curriculum.unitId)
  .set({
    schemaVersion: 1,
    levelId: curriculum.levelId,
    unitId: curriculum.unitId,
    title: curriculum.title,
    topic: curriculum.title,
    order: 1,
    lessonIds: [curriculum.lessonId],
    published: true,
  });
await firestore
  .collection("levels")
  .doc(curriculum.levelId)
  .collection("units")
  .doc(curriculum.unitId)
  .collection("lessons")
  .doc(curriculum.lessonId)
  .set(curriculum);
const reference = firestore.collection("_m0Smoke").doc(randomUUID());
const email = `smoke-${randomUUID()}@wortwerk.invalid`;
const authResponse = await fetch(
  `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key`,
  {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      email,
      password: "emulator-only-password",
      returnSecureToken: true,
    }),
  },
);
assert.equal(authResponse.status, 200, "Auth emulator should accept sign-up.");
const authData = await authResponse.json();

await reference.set({ healthy: true });
const snapshot = await reference.get();
assert.equal(snapshot.get("healthy"), true);
await reference.delete();

const deniedRead = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/_m0Smoke/${randomUUID()}`,
);
assert.equal(deniedRead.status, 403, "Firestore rules must deny public reads.");

const profileName = `projects/${projectId}/databases/(default)/documents/users/${authData.localId}`;
const profileFields = {
  schemaVersion: { integerValue: "1" },
  displayName: { stringValue: "" },
  uiLang: { stringValue: "de" },
  explainLang: { stringValue: "en" },
  level: { stringValue: "A1" },
  unitId: { stringValue: "a1_greetings" },
  goals: { arrayValue: { values: [] } },
  dailyMinutes: { integerValue: "10" },
  restWeekday: { integerValue: "0" },
  timezone: { stringValue: "UTC" },
  onboardingCompleted: { booleanValue: false },
  xpTotal: { integerValue: "0" },
  xpWeek: { integerValue: "0" },
  streak: {
    mapValue: {
      fields: {
        current: { integerValue: "0" },
        longest: { integerValue: "0" },
        shields: { integerValue: "2" },
        lastActiveDayId: { nullValue: null },
      },
    },
  },
};
const profileCommit = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:commit`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({
      writes: [
        {
          update: { name: profileName, fields: profileFields },
          updateMask: { fieldPaths: Object.keys(profileFields) },
          updateTransforms: [
            { fieldPath: "createdAt", setToServerValue: "REQUEST_TIME" },
            { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
          ],
          currentDocument: { exists: false },
        },
      ],
    }),
  },
);
assert.equal(
  profileCommit.status,
  200,
  `An authenticated user should create their own profile: ${await profileCommit.text()}`,
);

const profileRead = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/users/${authData.localId}`,
  { headers: { authorization: `Bearer ${authData.idToken}` } },
);
assert.equal(profileRead.status, 200, "Users should read their own profile.");

const groupId = "a1_everyday_smoke";
const group = firestore.collection("groups").doc(groupId);
await group.set({
  schemaVersion: 1,
  groupId,
  name: "A1 Alltag",
  topic: "Alltag und Begrüßungen",
  levelTag: "A1",
  isPublic: true,
  published: true,
  memberCount: 0,
});
const joinResult = await invokeCallable("joinLearningGroup", authData.idToken, {
  groupId,
  confirmAge16: true,
  acceptRulesVersion: 1,
});
assert.equal(joinResult.result.joined, true);
assert.equal(
  (await firestore.doc(`users/${authData.localId}`).get()).get("communityRulesVersion"),
  1,
);
const messageId = randomUUID();
const sendResult = await invokeCallable("sendGroupMessage", authData.idToken, {
  groupId,
  clientRequestId: messageId,
  body: "Hallo zusammen, wie geht es euch?",
});
assert.equal(sendResult.result.messageId, messageId);
assert.equal(
  (await group.collection("messages").doc(messageId).get()).get("status"),
  "visible",
);
const communityMessagePath = `projects/${projectId}/databases/(default)/documents/groups/${groupId}/messages/${messageId}`;
const visibleMessageRead = await fetch(
  `http://${firestoreHost}/v1/${communityMessagePath}`,
  { headers: { authorization: `Bearer ${authData.idToken}` } },
);
assert.equal(visibleMessageRead.status, 200, "Group members can read visible messages.");
const forgedCommunityMessage = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:commit`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({
      writes: [{
        update: {
          name: `projects/${projectId}/databases/(default)/documents/groups/${groupId}/messages/forged-message`,
          fields: { body: { stringValue: "forged" } },
        },
      }],
    }),
  },
);
assert.equal(forgedCommunityMessage.status, 403, "Only trusted Functions can create group messages.");
const communityReporters = [];
for (let index = 0; index < 3; index++) {
  const createReporter = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `reporter-${index}-${randomUUID()}@wortwerk.invalid`,
        password: "emulator-only-password",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(createReporter.status, 200);
  const reporter = await createReporter.json();
  communityReporters.push(reporter);
  await group.collection("members").doc(reporter.localId).set({
    schemaVersion: 1,
    uid: reporter.localId,
    role: "member",
  });
  await invokeCallable("reportGroupMessage", reporter.idToken, {
    groupId,
    messageId,
    reason: "other",
  });
}
assert.equal(
  (await group.collection("messages").doc(messageId).get()).get("status"),
  "hidden",
  "Three distinct reports should hide a community message pending review.",
);
const hiddenMessageRead = await fetch(
  `http://${firestoreHost}/v1/${communityMessagePath}`,
  { headers: { authorization: `Bearer ${authData.idToken}` } },
);
assert.equal(hiddenMessageRead.status, 403, "Auto-hidden messages must leave member feeds.");
await invokeCallable("blockCommunityMember", authData.idToken, {
  otherUid: communityReporters[0].localId,
});
assert.equal(
  (await firestore.doc(`users/${authData.localId}/blocks/${communityReporters[0].localId}`).get()).exists,
  true,
);
const leaveResult = await invokeCallable("leaveLearningGroup", authData.idToken, {
  groupId,
});
assert.equal(leaveResult.result.left, true);
assert.equal((await group.collection("members").doc(authData.localId).get()).exists, false);

const deviceToken = `smoke-${randomUUID()}-${"t".repeat(120)}`;
const deviceId = createHash("sha256").update(deviceToken).digest("hex");
const registerDeviceResponse = await fetch(
  `http://127.0.0.1:5001/${projectId}/europe-west1/registerNotificationDevice`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({
      data: { token: deviceToken, platform: "android", language: "en" },
    }),
  },
);
assert.equal(
  registerDeviceResponse.status,
  200,
  "An authenticated learner should register a push device.",
);
assert.equal((await firestore.doc(`users/${authData.localId}`).get()).get("pushEnabled"), true);
const deviceDocument = await firestore
  .doc(`users/${authData.localId}/devices/${deviceId}`)
  .get();
assert.equal(deviceDocument.get("token"), deviceToken);
assert.equal(deviceDocument.get("language"), "en");
const clientDeviceRead = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/users/${authData.localId}/devices/${deviceId}`,
  { headers: { authorization: `Bearer ${authData.idToken}` } },
);
assert.equal(
  clientDeviceRead.status,
  403,
  "Clients must not read stored push tokens.",
);
const disablePushResponse = await fetch(
  `http://127.0.0.1:5001/${projectId}/europe-west1/disablePushNotifications`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({ data: { enabled: false } }),
  },
);
assert.equal(disablePushResponse.status, 200);
assert.equal((await firestore.doc(`users/${authData.localId}`).get()).get("pushEnabled"), false);
assert.equal(
  (await firestore.doc(`users/${authData.localId}/devices/${deviceId}`).get()).exists,
  false,
  "Disabling push must remove stored device tokens.",
);

const smokeNotification = firestore
  .collection("users")
  .doc(authData.localId)
  .collection("notifications")
  .doc("smoke-level-unlocked");
await smokeNotification.set({
  schemaVersion: 1,
  kind: "levelUnlocked",
  level: "A2",
  deepLink: "/path",
  createdAt: FieldValue.serverTimestamp(),
});
const markNotificationResponse = await fetch(
  `http://127.0.0.1:5001/${projectId}/europe-west1/markNotificationRead`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({ data: { notificationId: "smoke-level-unlocked" } }),
  },
);
assert.equal(
  markNotificationResponse.status,
  200,
  "The mark-read callable should accept an owner's notification.",
);
assert.ok((await smokeNotification.get()).get("readAt"));

const forgedNotificationRead = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:commit`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name: `${profileName}/notifications/smoke-level-unlocked`,
            fields: { readAt: { nullValue: null } },
          },
          updateMask: { fieldPaths: ["readAt"] },
        },
      ],
    }),
  },
);
assert.equal(
  forgedNotificationRead.status,
  403,
  "Clients must update notification read state through the trusted callable.",
);

const unlockAuthResponse = await fetch(
  `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key`,
  {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      email: `unlock-${randomUUID()}@wortwerk.invalid`,
      password: "emulator-only-password",
      returnSecureToken: true,
    }),
  },
);
assert.equal(unlockAuthResponse.status, 200);
const unlockAuth = await unlockAuthResponse.json();
const unlockUser = firestore.collection("users").doc(unlockAuth.localId);
await unlockUser.set({
  schemaVersion: 1,
  level: "A1",
  unitId: "a1_greetings",
  onboardingCompleted: true,
  timezone: "UTC",
  restWeekday: 0,
  xpTotal: 0,
  streak: { current: 0, longest: 0, shields: 2, lastActiveDayId: null },
});
await unlockUser.collection("levelProgress").doc("A1").set({
  schemaVersion: 1,
  levelId: "A1",
  fritzConversations: 3,
  reviewRoundsPassed: 0,
});
const coreVocabularyIds = [
  "greeting_hello",
  "greeting_good_morning",
  "greeting_good_day",
  "greeting_good_evening",
  "greeting_bye",
  "greeting_goodbye_formal",
  "greeting_thanks",
  "greeting_please",
  "greeting_name",
  "greeting_introduce",
];
await Promise.all(
  coreVocabularyIds.map((cardId) =>
    unlockUser.collection("cards").doc(cardId).set({
      schemaVersion: 1,
      cardId,
      intervalDays: 1,
      correctStreak: 1,
    }),
  ),
);
const unlockReviewResponse = await fetch(
  `http://127.0.0.1:5001/${projectId}/europe-west1/completeFlashcardReview`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${unlockAuth.idToken}`,
    },
    body: JSON.stringify({
      data: {
        clientRequestId: randomUUID(),
        answers: coreVocabularyIds.map((cardId) => ({
          cardId,
          remembered: true,
        })),
      },
    }),
  },
);
assert.equal(
  unlockReviewResponse.status,
  200,
  `The unlock review should complete: ${await unlockReviewResponse.text()}`,
);
const unlockNotification = await unlockUser
  .collection("notifications")
  .doc("level-unlocked_a2")
  .get();
assert.equal(unlockNotification.get("kind"), "levelUnlocked");
assert.equal(unlockNotification.get("level"), "A2");
assert.equal(unlockNotification.get("deepLink"), "/path");

const forgedPlacement = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:commit`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name: profileName,
            fields: {
              verifiedPlacement: {
                mapValue: {
                  fields: {
                    level: { stringValue: "B1" },
                    unitId: { stringValue: "b1_conversation" },
                    confidence: { doubleValue: 1 },
                  },
                },
              },
            },
          },
          updateMask: { fieldPaths: ["verifiedPlacement"] },
        },
      ],
    }),
  },
);
assert.equal(
  forgedPlacement.status,
  403,
  "Clients must not be able to forge a verified placement.",
);

const placementResponse = await fetch(
  `http://127.0.0.1:5001/${projectId}/europe-west1/evaluatePlacement`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({
      data: {
        startLevel: "A1",
        answers: [
          { questionId: "a1_greeting", choiceId: "a1g_a" },
          { questionId: "a1_polite", choiceId: "a1p_b" },
          { questionId: "a2_travel", choiceId: "a2t_a" },
          { questionId: "a2_dative", choiceId: "a2d_a" },
          { questionId: "b1_reason", choiceId: "b1r_a" },
          { questionId: "b1_subjunctive", choiceId: "b1s_a" },
          { questionId: "b1_relative", choiceId: "b1l_a" },
          { questionId: "b1_passive", choiceId: "b1p_a" },
        ],
      },
    }),
  },
);
assert.equal(
  placementResponse.status,
  200,
  "Placement function should score an adaptive assessment.",
);
assert.deepEqual(await placementResponse.json(), {
  result: { level: "B1", unitId: "b1_conversation", confidence: 1 },
});

const onboardingDraft = {
  step: { integerValue: "4" },
  goals: { arrayValue: { values: [{ stringValue: "Alltag" }] } },
  dailyMinutes: { integerValue: "10" },
  selectedLevel: { integerValue: "3" },
  testStartingLevel: { integerValue: "0" },
  placementAnswers: {
    arrayValue: {
      values: [
        ["a1_greeting", "a1g_a"],
        ["a1_polite", "a1p_b"],
        ["a2_travel", "a2t_a"],
        ["a2_dative", "a2d_a"],
        ["b1_reason", "b1r_a"],
        ["b1_subjunctive", "b1s_a"],
        ["b1_relative", "b1l_a"],
        ["b1_passive", "b1p_a"],
      ].map(([questionId, choiceId]) => ({
        mapValue: {
          fields: {
            questionId: { stringValue: questionId },
            choiceId: { stringValue: choiceId },
          },
        },
      })),
    },
  },
  placementLevel: { stringValue: "B1" },
  placementConfidence: { doubleValue: 1 },
};
const completeOnboardingCommit = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:commit`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name: profileName,
            fields: {
              level: { stringValue: "B1" },
              unitId: { stringValue: "b1_conversation" },
              goals: { arrayValue: { values: [{ stringValue: "Alltag" }] } },
              dailyMinutes: { integerValue: "10" },
              placement: {
                mapValue: {
                  fields: {
                    done: { booleanValue: true },
                    level: { stringValue: "B1" },
                    confidence: { doubleValue: 1 },
                    source: { stringValue: "quiz" },
                  },
                },
              },
              onboardingCompleted: { booleanValue: true },
              onboardingDraft: { mapValue: { fields: onboardingDraft } },
            },
          },
          updateMask: {
            fieldPaths: [
              "level",
              "unitId",
              "goals",
              "dailyMinutes",
              "placement",
              "onboardingCompleted",
              "onboardingDraft",
            ],
          },
          updateTransforms: [
            { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
          ],
          currentDocument: { exists: true },
        },
      ],
    }),
  },
);
assert.equal(
  completeOnboardingCommit.status,
  200,
  `A learner should save their onboarding plan: ${await completeOnboardingCommit.text()}`,
);
const dailyMissionResponse = await invokeCallable(
  "getDailyMissions",
  authData.idToken,
  {},
);
const missionDayId = dailyMissionResponse.result.dayId;
assert.equal(typeof missionDayId, "string");
const missionDocument = firestore
  .doc(`users/${authData.localId}/missions/${missionDayId}`);
assert.equal((await missionDocument.get()).get("completedCount"), 0);

const lessonAnswers = [
  { questionId: "greeting_morning", choiceId: "morning_guten_morgen" },
  { questionId: "greeting_name", choiceId: "name_wie_heissen" },
  { questionId: "greeting_introduce", choiceId: "introduce_heisse" },
  { questionId: "greeting_thanks", choiceId: "thanks_bitte" },
  { questionId: "greeting_goodbye", choiceId: "goodbye_auf_wiedersehen" },
];
const firstLessonRequestId = randomUUID();
async function completeLesson(clientRequestId) {
  return fetch(
    `http://127.0.0.1:5001/${projectId}/europe-west1/completeLesson`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${authData.idToken}`,
      },
      body: JSON.stringify({
        data: {
          levelId: "A1",
          unitId: "a1_greetings",
          lessonId: "a1_greetings",
          answers: lessonAnswers,
          clientRequestId,
        },
      }),
    },
  );
}

const firstLessonResponse = await completeLesson(firstLessonRequestId);
assert.equal(firstLessonResponse.status, 200, "The lesson callable should save progress.");
assert.deepEqual(await firstLessonResponse.json(), {
  result: {
    lessonId: "a1_greetings",
    accuracy: 1,
    correctCount: 5,
    xpAwarded: 20,
  },
});
assert.equal(
  (await missionDocument.get()).get("tasks.lesson_complete.completed"),
  true,
  "A confirmed lesson should complete the matching daily mission.",
);

const duplicateLessonResponse = await completeLesson(firstLessonRequestId);
assert.equal(
  duplicateLessonResponse.status,
  200,
  "An identical lesson request should be idempotent.",
);
assert.deepEqual(await duplicateLessonResponse.json(), {
  result: {
    lessonId: "a1_greetings",
    accuracy: 1,
    correctCount: 5,
    xpAwarded: 20,
  },
});

const repeatLessonResponse = await completeLesson(randomUUID());
assert.equal(repeatLessonResponse.status, 200);
assert.equal(
  (await repeatLessonResponse.json()).result.xpAwarded,
  0,
  "Replaying a completed lesson must not mint more XP.",
);

const flashcardAnswers = [
  "greeting_hello",
  "greeting_good_morning",
  "greeting_good_day",
  "greeting_good_evening",
  "greeting_bye",
  "greeting_goodbye_formal",
  "greeting_thanks",
  "greeting_please",
  "greeting_name",
  "greeting_introduce",
].map((cardId, index) => ({ cardId, remembered: index % 2 === 0 }));
const reviewRequestId = randomUUID();
async function completeFlashcardReview(clientRequestId) {
  return fetch(
    `http://127.0.0.1:5001/${projectId}/europe-west1/completeFlashcardReview`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${authData.idToken}`,
      },
      body: JSON.stringify({
        data: { answers: flashcardAnswers, clientRequestId },
      }),
    },
  );
}

const reviewResponse = await completeFlashcardReview(reviewRequestId);
assert.equal(
  reviewResponse.status,
  200,
  "The flashcard review callable should save a completed session.",
);
assert.deepEqual(await reviewResponse.json(), {
  result: { reviewedCount: 10, rememberedCount: 5, xpAwarded: 10 },
});
assert.equal(
  (await missionDocument.get()).get("tasks.review_session.completed"),
  true,
  "A confirmed ten-card review should complete the matching daily mission.",
);

const duplicateReviewResponse = await completeFlashcardReview(reviewRequestId);
assert.equal(
  duplicateReviewResponse.status,
  200,
  "An identical flashcard review request should be idempotent.",
);
assert.deepEqual(await duplicateReviewResponse.json(), {
  result: { reviewedCount: 10, rememberedCount: 5, xpAwarded: 10 },
});

const updatedProfileResponse = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/users/${authData.localId}`,
  { headers: { authorization: `Bearer ${authData.idToken}` } },
);
assert.equal(updatedProfileResponse.status, 200);
const updatedProfile = await updatedProfileResponse.json();
assert.equal(updatedProfile.fields.xpTotal.integerValue, "70");
assert.equal(updatedProfile.fields.streak.mapValue.fields.current.integerValue, "1");
const activeDayId =
  updatedProfile.fields.streak.mapValue.fields.lastActiveDayId.stringValue;
const activeDayResponse = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/users/${authData.localId}/days/${activeDayId}`,
  { headers: { authorization: `Bearer ${authData.idToken}` } },
);
assert.equal(activeDayResponse.status, 200);
assert.equal(
  (await activeDayResponse.json()).fields.flashcardsReviewed.integerValue,
  "10",
);
const cardProgressResponse = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/users/${authData.localId}/cards/greeting_hello`,
  { headers: { authorization: `Bearer ${authData.idToken}` } },
);
assert.equal(cardProgressResponse.status, 200);
assert.equal(
  (await cardProgressResponse.json()).fields.intervalDays.integerValue,
  "1",
);

const progressRead = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/users/${authData.localId}/progress/a1_greetings`,
  { headers: { authorization: `Bearer ${authData.idToken}` } },
);
assert.equal(progressRead.status, 200, "Learners should read saved lesson progress.");
assert.equal(
  (await progressRead.json()).fields.xpAwardedTotal.integerValue,
  "20",
  "Duplicate requests and lesson retries must not over-award XP.",
);

const forgedXp = await fetch(
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:commit`,
  {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${authData.idToken}`,
    },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name: profileName,
            fields: { xpTotal: { integerValue: "999" } },
          },
          updateMask: { fieldPaths: ["xpTotal"] },
        },
      ],
    }),
  },
);
assert.equal(forgedXp.status, 403, "Clients must not change server-owned XP.");

const functionResponse = await fetch(
  `http://127.0.0.1:5001/${projectId}/europe-west1/health`,
  {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ data: {} }),
  },
);
assert.equal(functionResponse.status, 200, "Functions emulator should answer.");
assert.deepEqual(await functionResponse.json(), { result: { ok: true } });

await app.delete();
console.log(
  "Firebase Auth, push device lifecycle, community consent/chat/report/block, Functions, authenticated placement, owner-scoped profiles, atomic level-unlock notifications and protected XP emulator smoke tests passed.",
);
