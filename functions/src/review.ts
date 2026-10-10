import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { advanceLearningStreak, dayIdAt, timezoneFromUser } from "./lesson.js";
import { evaluateLevelProgress, nextLevelId } from "./progression.js";
import { advanceDailyMission } from "./missions.js";

export interface FlashcardReviewAnswer {
  cardId: string;
  remembered: boolean;
}

export interface FlashcardReviewResult {
  reviewedCount: number;
  rememberedCount: number;
  xpAwarded: number;
}

export interface FlashcardReviewRecord {
  clientRequestId: string;
  fingerprint: string;
  result: FlashcardReviewResult;
}

export const greetingCardIds = [
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
] as const;
const validCardIds: ReadonlySet<string> = new Set(greetingCardIds);

export class FlashcardReviewValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "FlashcardReviewValidationError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(
  value: Record<string, unknown>,
  expected: readonly string[],
): boolean {
  const actualKeys = Object.keys(value).sort();
  const expectedKeys = [...expected].sort();
  return (
    actualKeys.length === expectedKeys.length &&
    actualKeys.every((key, index) => key === expectedKeys[index])
  );
}

function parseReview(input: unknown): {
  clientRequestId: string;
  answers: FlashcardReviewAnswer[];
} {
  if (
    !isRecord(input) ||
    !hasExactKeys(input, ["clientRequestId", "answers"])
  ) {
    throw new FlashcardReviewValidationError(
      "Review data must contain only clientRequestId and answers.",
    );
  }
  if (
    typeof input.clientRequestId !== "string" ||
    !/^[A-Za-z0-9_-]{8,128}$/.test(input.clientRequestId)
  ) {
    throw new FlashcardReviewValidationError(
      "A valid client request ID is required.",
    );
  }
  if (!Array.isArray(input.answers) || input.answers.length !== 10) {
    throw new FlashcardReviewValidationError(
      "A review session must contain ten distinct cards.",
    );
  }

  const seen = new Set<string>();
  const answers = input.answers.map((answer) => {
    if (
      !isRecord(answer) ||
      !hasExactKeys(answer, ["cardId", "remembered"]) ||
      typeof answer.cardId !== "string" ||
      typeof answer.remembered !== "boolean" ||
      !validCardIds.has(answer.cardId) ||
      seen.has(answer.cardId)
    ) {
      throw new FlashcardReviewValidationError(
        "Review answers must use ten unique, known greeting cards.",
      );
    }
    seen.add(answer.cardId);
    return { cardId: answer.cardId, remembered: answer.remembered };
  });

  return { clientRequestId: input.clientRequestId, answers };
}

function fingerprint(answers: readonly FlashcardReviewAnswer[]): string {
  return JSON.stringify(
    [...answers]
      .sort((left, right) => left.cardId.localeCompare(right.cardId))
      .map(({ cardId, remembered }) => [cardId, remembered]),
  );
}

export function scoreFlashcardReview(input: unknown): FlashcardReviewResult {
  const { answers } = parseReview(input);
  return {
    reviewedCount: answers.length,
    rememberedCount: answers.filter((answer) => answer.remembered).length,
    xpAwarded: 10,
  };
}

export function resolveFlashcardReview(
  input: unknown,
  previous?: FlashcardReviewRecord,
): FlashcardReviewResult {
  const parsed = parseReview(input);
  const result = scoreFlashcardReview(input);
  if (!previous) return result;
  if (previous.clientRequestId !== parsed.clientRequestId) {
    throw new FlashcardReviewValidationError(
      "The stored review request ID does not match.",
    );
  }
  if (previous.fingerprint !== fingerprint(parsed.answers)) {
    throw new FlashcardReviewValidationError(
      "A client request ID cannot be reused for different review answers.",
    );
  }
  return previous.result;
}

function numericField(
  data: Record<string, unknown> | undefined,
  field: string,
): number {
  const value = data?.[field];
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value
    : 0;
}

function validStoredResult(value: unknown): value is FlashcardReviewResult {
  return (
    isRecord(value) &&
    value.reviewedCount === 10 &&
    typeof value.rememberedCount === "number" &&
    Number.isInteger(value.rememberedCount) &&
    value.rememberedCount >= 0 &&
    value.rememberedCount <= 10 &&
    value.xpAwarded === 10
  );
}

export const completeFlashcardReview = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to save review progress.");
    }

    let parsed: ReturnType<typeof parseReview>;
    let result: FlashcardReviewResult;
    try {
      parsed = parseReview(request.data);
      result = scoreFlashcardReview(request.data);
    } catch (error) {
      if (error instanceof FlashcardReviewValidationError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    if (getApps().length === 0) initializeApp();
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const reviewRef = userRef
      .collection("reviewSessions")
      .doc(parsed.clientRequestId);
    try {
      return await db.runTransaction(async (transaction) => {
        const [userSnapshot, reviewSnapshot] = await Promise.all([
          transaction.get(userRef),
          transaction.get(reviewRef),
        ]);
        const userData = userSnapshot.data();
        if (!userSnapshot.exists || userData?.onboardingCompleted !== true) {
          throw new HttpsError(
            "failed-precondition",
            "Complete onboarding before saving review progress.",
          );
        }

        if (reviewSnapshot.exists) {
          const saved = reviewSnapshot.data();
          if (
            !saved ||
            saved.clientRequestId !== parsed.clientRequestId ||
            typeof saved.fingerprint !== "string" ||
            !validStoredResult(saved.result)
          ) {
            throw new HttpsError(
              "internal",
              "The saved review request record is invalid.",
            );
          }
          try {
            return resolveFlashcardReview(request.data, {
              clientRequestId: saved.clientRequestId,
              fingerprint: saved.fingerprint,
              result: saved.result,
            });
          } catch (error) {
            if (error instanceof FlashcardReviewValidationError) {
              throw new HttpsError("already-exists", error.message);
            }
            throw error;
          }
        }

        const timezone = timezoneFromUser(userData);
        const dayId = dayIdAt(new Date(), timezone);
        const dayRef = userRef.collection("days").doc(dayId);
        const levelId =
          typeof userData.level === "string" &&
          ["A1", "A2", "B1", "B2", "C1", "C2"].includes(userData.level)
            ? userData.level
            : "A1";
        const levelRef = db.collection("levels").doc(levelId);
        const levelProgressRef = userRef
          .collection("levelProgress")
          .doc(levelId);
        const unlockLevelId = nextLevelId(levelId);
        const unlockRef = unlockLevelId
          ? userRef.collection("unlocks").doc(unlockLevelId)
          : undefined;
        const levelSnapshot = await transaction.get(levelRef);
        const levelProgressSnapshot = await transaction.get(levelProgressRef);
        const unlockSnapshot = unlockRef
          ? await transaction.get(unlockRef)
          : undefined;
        const coreVocabularyCardIds = Array.isArray(
          levelSnapshot.get("coreVocabularyCardIds"),
        )
          ? (levelSnapshot.get("coreVocabularyCardIds") as unknown[]).filter(
              (cardId): cardId is string =>
                typeof cardId === "string" && cardId.length > 0,
            )
          : [];
        const cardIds = [
          ...new Set([
            ...coreVocabularyCardIds,
            ...parsed.answers.map(({ cardId }) => cardId),
          ]),
        ];
        const cardRefsById = new Map(
          cardIds.map((cardId) => [
            cardId,
            userRef.collection("cards").doc(cardId),
          ]),
        );
        const cardSnapshots = await transaction.getAll(
          ...cardRefsById.values(),
        );
        const cardSnapshotById = new Map(
          cardSnapshots.map((snapshot) => [snapshot.id, snapshot]),
        );
        const daySnapshot = await transaction.get(dayRef);
        const missionRef = userRef.collection("missions").doc(dayId);
        const missionSnapshot = await transaction.get(missionRef);
        const streak = isRecord(userData.streak) ? userData.streak : undefined;
        const restWeekday =
          typeof userData.restWeekday === "number" &&
          Number.isInteger(userData.restWeekday) &&
          userData.restWeekday >= 0 &&
          userData.restWeekday <= 6
            ? userData.restWeekday
            : 0;
        const updatedStreak = advanceLearningStreak(
          {
            current: numericField(streak, "current"),
            longest: numericField(streak, "longest"),
            shields: numericField(streak, "shields"),
            lastActiveDayId:
              typeof streak?.lastActiveDayId === "string"
                ? streak.lastActiveDayId
                : null,
          },
          dayId,
          restWeekday,
        );
        const dayData = daySnapshot.data();
        const reviewedAt = new Date();

        const reviewUpdates = [];
        const cardStates = new Map();
        for (const cardId of coreVocabularyCardIds) {
          const cardData = cardSnapshotById.get(cardId)?.data();
          cardStates.set(cardId, {
            intervalDays: numericField(cardData, "intervalDays"),
            correctStreak: numericField(cardData, "correctStreak"),
          });
        }
        for (let index = 0; index < parsed.answers.length; index++) {
          const answer = parsed.answers[index];
          const previous = cardSnapshotById.get(answer.cardId)?.data();
          const previousInterval = numericField(previous, "intervalDays");
          const intervalDays = answer.remembered
            ? Math.min(30, previousInterval === 0 ? 1 : previousInterval * 2)
            : 0;
          const correctStreak = answer.remembered
            ? numericField(previous, "correctStreak") + 1
            : 0;
          const dueAt = new Date(
            reviewedAt.getTime() +
              (intervalDays === 0 ? 10 * 60_000 : intervalDays * 86_400_000),
          );
          reviewUpdates.push({
            ref: cardRefsById.get(answer.cardId)!,
            data: {
              schemaVersion: 1,
              cardId: answer.cardId,
              intervalDays,
              repetitions: numericField(previous, "repetitions") + 1,
              correctStreak,
              lastRemembered: answer.remembered,
              dueAt: Timestamp.fromDate(dueAt),
              lastReviewedAt: FieldValue.serverTimestamp(),
            },
          });
          if (coreVocabularyCardIds.includes(answer.cardId)) {
            cardStates.set(answer.cardId, { intervalDays, correctStreak });
          }
        }

        const previousLevelProgress = levelProgressSnapshot.data();
        const reviewRoundsPassed =
          numericField(previousLevelProgress, "reviewRoundsPassed") +
          Number(result.rememberedCount / result.reviewedCount >= 0.7);
        const progression = evaluateLevelProgress({
          coreVocabularyCardIds,
          cardStates,
          fritzConversations: numericField(
            previousLevelProgress,
            "fritzConversations",
          ),
          reviewRoundsPassed,
        });
        const missionUpdate = advanceDailyMission(
          missionSnapshot.data(),
          "review_session",
          {
            dayId,
            timezone,
            goals: Array.isArray(userData.goals)
              ? userData.goals.filter(
                  (goal): goal is string => typeof goal === "string",
                )
              : [],
          },
        );
        const unlockAwarded =
          progression.readyToUnlock &&
          userData.level === levelId &&
          unlockSnapshot?.exists !== true;
        const unlockXp = unlockAwarded ? 120 : 0;
        if (unlockAwarded) {
          updatedStreak.shields = Math.min(3, updatedStreak.shields + 1);
        }

        for (const update of reviewUpdates) {
          transaction.set(update.ref, update.data, { merge: true });
        }

        transaction.set(
          userRef,
          {
            xpTotal:
              numericField(userData, "xpTotal") +
              result.xpAwarded +
              unlockXp +
              missionUpdate.xpAwarded,
            ...(unlockAwarded && unlockLevelId ? { level: unlockLevelId } : {}),
            streak: updatedStreak,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        transaction.set(
          dayRef,
          {
            schemaVersion: 1,
            date: dayId,
            timezone,
            xpTotal:
              numericField(dayData, "xpTotal") +
              result.xpAwarded +
              unlockXp +
              missionUpdate.xpAwarded,
            flashcardsReviewed:
              numericField(dayData, "flashcardsReviewed") +
              result.reviewedCount,
            flashcardSessions:
              numericField(dayData, "flashcardSessions") + 1,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        transaction.set(
          missionRef,
          {
            ...missionUpdate.data,
            ...(missionSnapshot.exists
              ? {}
              : { createdAt: FieldValue.serverTimestamp() }),
          },
          { merge: true },
        );
        transaction.set(
          levelProgressRef,
          {
            schemaVersion: 1,
            levelId,
            ...progression,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        if (unlockAwarded && unlockRef && unlockLevelId) {
          transaction.create(unlockRef, {
            schemaVersion: 1,
            levelId: unlockLevelId,
            fromLevelId: levelId,
            unlockedAt: FieldValue.serverTimestamp(),
            criteria: progression,
          });
          transaction.create(
            userRef.collection("notifications").doc(
              `level-unlocked_${unlockLevelId.toLowerCase()}`,
            ),
            {
              schemaVersion: 1,
              kind: "levelUnlocked",
              level: unlockLevelId,
              deepLink: "/path",
              createdAt: FieldValue.serverTimestamp(),
            },
          );
        }
        transaction.create(reviewRef, {
          schemaVersion: 1,
          clientRequestId: parsed.clientRequestId,
          fingerprint: fingerprint(parsed.answers),
          result,
          completedAt: FieldValue.serverTimestamp(),
        });
        return result;
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Could not save review progress.");
    }
  },
);
