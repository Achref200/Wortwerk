import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { canAccessLevel, previousUnitsUnlocked } from "./progression.js";
import { advanceDailyMission } from "./missions.js";

export interface LessonAnswer {
  questionId: string;
  choiceId: string;
}

export interface LessonCompletionResult {
  lessonId: string;
  accuracy: number;
  correctCount: number;
  xpAwarded: number;
}

export interface LessonIdempotencyRecord {
  clientRequestId: string;
  fingerprint: string;
  result: LessonCompletionResult;
}

export interface LearningStreak {
  current: number;
  longest: number;
  shields: number;
  lastActiveDayId: string | null;
}

export interface LessonQuestionDefinition {
  choices: readonly string[];
  correctChoiceId: string;
}

export interface LessonDefinition {
  lessonId: string;
  levelId: string;
  unitId: string;
  questions: Readonly<Record<string, LessonQuestionDefinition>>;
}

export class LessonValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "LessonValidationError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function lessonDefinitionFromDocument(
  value: unknown,
  expected: { levelId: string; unitId: string; lessonId: string },
): LessonDefinition | null {
  if (
    !isRecord(value) ||
    value.published !== true ||
    value.levelId !== expected.levelId ||
    value.unitId !== expected.unitId ||
    value.lessonId !== expected.lessonId ||
    !Array.isArray(value.questions) ||
    value.questions.length === 0 ||
    value.questions.length > 100
  ) {
    return null;
  }

  const questions: Record<string, LessonQuestionDefinition> = {};
  for (const rawQuestion of value.questions) {
    if (
      !isRecord(rawQuestion) ||
      typeof rawQuestion.id !== "string" ||
      !/^[A-Za-z0-9_-]{1,96}$/.test(rawQuestion.id) ||
      !Array.isArray(rawQuestion.choices) ||
      rawQuestion.choices.length < 2 ||
      rawQuestion.choices.length > 8 ||
      typeof rawQuestion.correctChoiceId !== "string" ||
      questions[rawQuestion.id]
    ) {
      return null;
    }
    const choices: string[] = [];
    for (const choice of rawQuestion.choices) {
      if (
        !isRecord(choice) ||
        typeof choice.id !== "string" ||
        !/^[A-Za-z0-9_-]{1,96}$/.test(choice.id) ||
        typeof choice.text !== "string" ||
        choice.text.length === 0 ||
        choice.text.length > 500 ||
        choices.includes(choice.id)
      ) {
        return null;
      }
      choices.push(choice.id);
    }
    if (!choices.includes(rawQuestion.correctChoiceId)) return null;
    questions[rawQuestion.id] = {
      choices,
      correctChoiceId: rawQuestion.correctChoiceId,
    };
  }
  return { ...expected, questions };
}

function submissionCoordinates(input: unknown): {
  levelId: string;
  unitId: string;
  lessonId: string;
} {
  if (!isRecord(input)) {
    throw new LessonValidationError("Choose a valid lesson.");
  }
  if (
    !hasExactKeys(input, [
      "levelId",
      "unitId",
      "lessonId",
      "answers",
      "clientRequestId",
    ])
  ) {
    throw new LessonValidationError(
      "Lesson data must contain levelId, unitId, lessonId, answers, and clientRequestId.",
    );
  }
  const { levelId, unitId, lessonId } = input;
  const clientRequestId = input.clientRequestId;
  if (
    typeof levelId !== "string" ||
    typeof unitId !== "string" ||
    typeof lessonId !== "string" ||
    !/^[A-Za-z0-9_-]{1,64}$/.test(levelId) ||
    !/^[A-Za-z0-9_-]{1,64}$/.test(unitId) ||
    !/^[A-Za-z0-9_-]{1,96}$/.test(lessonId) ||
    typeof clientRequestId !== "string" ||
    !/^[A-Za-z0-9_-]{8,128}$/.test(clientRequestId)
  ) {
    throw new LessonValidationError("Choose a valid lesson.");
  }
  return { levelId, unitId, lessonId };
}

function hasExactKeys(
  value: Record<string, unknown>,
  expectedKeys: readonly string[],
): boolean {
  const actualKeys = Object.keys(value).sort();
  return (
    actualKeys.length === expectedKeys.length &&
    actualKeys.every((key, index) => key === [...expectedKeys].sort()[index])
  );
}

function parseSubmission(
  input: unknown,
  definition: LessonDefinition,
): {
  clientRequestId: string;
  answers: LessonAnswer[];
} {
  if (
    !isRecord(input) ||
    !hasExactKeys(input, [
      "levelId",
      "unitId",
      "lessonId",
      "answers",
      "clientRequestId",
    ])
  ) {
    throw new LessonValidationError(
      "Lesson data must contain levelId, unitId, lessonId, answers, and clientRequestId.",
    );
  }
  if (
    input.levelId !== definition.levelId ||
    input.unitId !== definition.unitId ||
    input.lessonId !== definition.lessonId
  ) {
    throw new LessonValidationError("Choose a valid lesson.");
  }
  if (
    typeof input.clientRequestId !== "string" ||
    !/^[A-Za-z0-9_-]{8,128}$/.test(input.clientRequestId)
  ) {
    throw new LessonValidationError("A valid client request ID is required.");
  }
  const expectedQuestionIds = Object.keys(definition.questions).sort();
  if (
    expectedQuestionIds.length === 0 ||
    !Array.isArray(input.answers) ||
    input.answers.length !== expectedQuestionIds.length
  ) {
    throw new LessonValidationError(
      "A lesson submission must answer each question exactly once.",
    );
  }

  const seen = new Set<string>();
  const answers: LessonAnswer[] = [];
  for (const answer of input.answers) {
    if (
      !isRecord(answer) ||
      !hasExactKeys(answer, ["questionId", "choiceId"]) ||
      typeof answer.questionId !== "string" ||
      typeof answer.choiceId !== "string"
    ) {
      throw new LessonValidationError("A lesson answer is invalid.");
    }
    const question = definition.questions[answer.questionId];
    if (!question) {
      throw new LessonValidationError("A lesson question ID is invalid.");
    }
    if (seen.has(answer.questionId)) {
      throw new LessonValidationError(
        "A lesson question cannot be answered twice.",
      );
    }
    if (!question.choices.includes(answer.choiceId)) {
      throw new LessonValidationError("A lesson answer choice is invalid.");
    }
    seen.add(answer.questionId);
    answers.push({
      questionId: answer.questionId,
      choiceId: answer.choiceId,
    });
  }

  if (expectedQuestionIds.some((questionId) => !seen.has(questionId))) {
    throw new LessonValidationError(
      "The lesson must include every expected question exactly once.",
    );
  }
  return { clientRequestId: input.clientRequestId, answers };
}

function fingerprint(answers: readonly LessonAnswer[]): string {
  return JSON.stringify(
    [...answers]
      .sort((left, right) => left.questionId.localeCompare(right.questionId))
      .map(({ questionId, choiceId }) => [questionId, choiceId]),
  );
}

export function scoreLessonSubmission(
  input: unknown,
  definition: LessonDefinition,
): LessonCompletionResult {
  const { answers } = parseSubmission(input, definition);
  const correctCount = answers.reduce((count, answer) => {
    return count +
      Number(
        definition.questions[answer.questionId].correctChoiceId ===
          answer.choiceId,
      );
  }, 0);
  return {
    lessonId: definition.lessonId,
    accuracy: correctCount / answers.length,
    correctCount,
    xpAwarded: 10 + correctCount * 2,
  };
}

export function resolveLessonSubmission(
  input: unknown,
  definition: LessonDefinition,
  previous?: LessonIdempotencyRecord,
): LessonCompletionResult {
  const parsed = parseSubmission(input, definition);
  const computed = scoreLessonSubmission(input, definition);
  if (!previous) return computed;
  if (previous.clientRequestId !== parsed.clientRequestId) {
    throw new LessonValidationError("The stored request ID does not match.");
  }
  if (previous.fingerprint !== fingerprint(parsed.answers)) {
    throw new LessonValidationError(
      "A client request ID cannot be reused for different answers.",
    );
  }
  return previous.result;
}

export function timezoneFromUser(
  userData: Record<string, unknown> | undefined,
): string {
  const timezone = userData?.timezone;
  if (typeof timezone !== "string" || timezone.length === 0) return "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: timezone });
    return timezone;
  } catch {
    return "UTC";
  }
}

export function dayIdAt(date: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const part = (type: string) =>
    parts.find((candidate) => candidate.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

function dayIdToUtcDate(dayId: string): Date | undefined {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dayId);
  if (!match) return undefined;
  const [, year, month, day] = match;
  const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
  return date.toISOString().slice(0, 10) === dayId ? date : undefined;
}

export function advanceLearningStreak(
  streak: LearningStreak,
  today: string,
  restWeekday: number,
): LearningStreak {
  if (!dayIdToUtcDate(today)) {
    throw new Error("A valid learning day is required.");
  }
  if (streak.lastActiveDayId === today) return streak;

  const lastActiveDate = streak.lastActiveDayId
    ? dayIdToUtcDate(streak.lastActiveDayId)
    : undefined;
  let current = streak.current;
  let shields = streak.shields;

  if (!lastActiveDate) {
    current = 0;
  } else {
    const todayDate = dayIdToUtcDate(today)!;
    for (
      let missedDate = new Date(lastActiveDate.getTime() + 86_400_000);
      missedDate < todayDate;
      missedDate = new Date(missedDate.getTime() + 86_400_000)
    ) {
      if (missedDate.getUTCDay() === restWeekday) continue;
      if (shields > 0) {
        shields--;
      } else {
        current = 0;
      }
    }
  }

  current++;
  return {
    current,
    longest: Math.max(streak.longest, current),
    shields,
    lastActiveDayId: today,
  };
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

function isStoredResult(
  value: unknown,
  definition: LessonDefinition,
): value is LessonCompletionResult {
  return (
    isRecord(value) &&
    value.lessonId === definition.lessonId &&
    typeof value.accuracy === "number" &&
    Number.isFinite(value.accuracy) &&
    value.accuracy >= 0 &&
    value.accuracy <= 1 &&
    typeof value.correctCount === "number" &&
    Number.isInteger(value.correctCount) &&
    value.correctCount >= 0 &&
    value.correctCount <= Object.keys(definition.questions).length &&
    typeof value.xpAwarded === "number" &&
    Number.isInteger(value.xpAwarded) &&
    value.xpAwarded >= 0
  );
}

export const completeLesson = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to save lesson progress.");
    }

    let coordinates: ReturnType<typeof submissionCoordinates>;
    try {
      coordinates = submissionCoordinates(request.data);
    } catch (error) {
      if (error instanceof LessonValidationError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }

    if (getApps().length === 0) initializeApp();
    const db = getFirestore();
    const levelRef = db.collection("levels").doc(coordinates.levelId);
    const unitRef = levelRef.collection("units").doc(coordinates.unitId);
    const lessonRef = unitRef
      .collection("lessons")
      .doc(coordinates.lessonId);
    const [levelSnapshot, unitSnapshot, contentSnapshot] = await Promise.all([
      levelRef.get(),
      unitRef.get(),
      lessonRef.get(),
    ]);
    if (
      levelSnapshot.data()?.published !== true ||
      unitSnapshot.data()?.published !== true
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This lesson is not currently available.",
      );
    }
    const definition = lessonDefinitionFromDocument(
      contentSnapshot.data(),
      coordinates,
    );
    if (!definition) {
      throw new HttpsError(
        "failed-precondition",
        "This lesson is not currently available.",
      );
    }
    const targetUnitOrder = unitSnapshot.get("order");
    const previousUnitLessonIds: string[][] = [];
    if (typeof targetUnitOrder === "number" && targetUnitOrder > 1) {
      const publishedUnits = await levelRef
        .collection("units")
        .where("published", "==", true)
        .get();
      for (const previousUnit of publishedUnits.docs) {
        const order = previousUnit.get("order");
        if (typeof order !== "number" || order >= targetUnitOrder) continue;
        const previousLessons = await previousUnit.ref
          .collection("lessons")
          .where("published", "==", true)
          .get();
        previousUnitLessonIds.push(
          previousLessons.docs.map((document) => document.id),
        );
      }
    }

    let parsed: ReturnType<typeof parseSubmission>;
    let score: LessonCompletionResult;
    try {
      parsed = parseSubmission(request.data, definition);
      score = scoreLessonSubmission(request.data, definition);
    } catch (error) {
      if (error instanceof LessonValidationError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }
    const userRef = db.collection("users").doc(uid);
    const progressRef = userRef
      .collection("progress")
      .doc(definition.lessonId);
    const requestRef = progressRef
      .collection("requests")
      .doc(parsed.clientRequestId);
    const targetUnlockRef = userRef
      .collection("unlocks")
      .doc(definition.levelId);
    const now = new Date();

    try {
      return await db.runTransaction(async (transaction) => {
        const [requestSnapshot, progressSnapshot, userSnapshot, unlockSnapshot] =
          await Promise.all([
            transaction.get(requestRef),
            transaction.get(progressRef),
            transaction.get(userRef),
            transaction.get(targetUnlockRef),
          ]);

        const userData = userSnapshot.data();
        if (!userSnapshot.exists || userData?.onboardingCompleted !== true) {
          throw new HttpsError(
            "failed-precondition",
            "Complete onboarding before saving lesson progress.",
          );
        }
        if (
          !canAccessLevel(
            userData.level,
            definition.levelId,
            unlockSnapshot.exists,
          )
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Schließe zuerst die Aufgaben für dieses Niveau ab.",
          );
        }
        const startsInThisUnit =
          userData.level === definition.levelId &&
          userData.unitId === definition.unitId;
        if (previousUnitLessonIds.length > 0 && !startsInThisUnit) {
          const previousLessonIds = [
            ...new Set(previousUnitLessonIds.flat()),
          ];
          const previousProgressSnapshots = await transaction.getAll(
            ...previousLessonIds.map((lessonId) =>
              userRef.collection("progress").doc(lessonId),
            ),
          );
          const previousProgress = new Map(
            previousProgressSnapshots.map((snapshot) => {
              const data = snapshot.data();
              return [
                snapshot.id,
                {
                  completed: data?.completed === true,
                  accuracy: numericField(data, "accuracy"),
                },
              ];
            }),
          );
          if (!previousUnitsUnlocked(previousUnitLessonIds, previousProgress)) {
            throw new HttpsError(
              "failed-precondition",
              "Schließe zuerst die vorherige Einheit mit mindestens 60 % ab.",
            );
          }
        }
        const timezone = timezoneFromUser(userData);
        const dayId = dayIdAt(now, timezone);
        const dayRef = userRef.collection("days").doc(dayId);
        const missionRef = userRef.collection("missions").doc(dayId);
        const [daySnapshot, missionSnapshot] = await Promise.all([
          transaction.get(dayRef),
          transaction.get(missionRef),
        ]);

        if (requestSnapshot.exists) {
          const stored = requestSnapshot.data();
          if (
            !stored ||
            stored.clientRequestId !== parsed.clientRequestId ||
            typeof stored.fingerprint !== "string" ||
            !isStoredResult(stored.result, definition)
          ) {
            throw new HttpsError(
              "internal",
              "The saved lesson request record is invalid.",
            );
          }
          try {
            return resolveLessonSubmission(request.data, definition, {
              clientRequestId: stored.clientRequestId,
              fingerprint: stored.fingerprint,
              result: stored.result,
            });
          } catch (error) {
            if (error instanceof LessonValidationError) {
              throw new HttpsError("already-exists", error.message);
            }
            throw error;
          }
        }

        const answerFingerprint = fingerprint(parsed.answers);
        const progressData = progressSnapshot.data();
        const dayData = daySnapshot.data();
        const isFirstCompletion = progressData?.completed !== true;
        const result = isFirstCompletion
          ? score
          : { ...score, xpAwarded: 0 };
        const missionUpdate = isFirstCompletion
          ? advanceDailyMission(missionSnapshot.data(), "lesson_complete", {
              dayId,
              timezone,
              goals: Array.isArray(userData.goals)
                ? userData.goals.filter(
                    (goal: unknown): goal is string => typeof goal === "string",
                  )
                : [],
            })
          : { data: missionSnapshot.data() ?? {}, xpAwarded: 0 };
        const previousStreak = isRecord(userData.streak)
          ? userData.streak
          : undefined;
        const activeDayId =
          typeof previousStreak?.lastActiveDayId === "string"
            ? previousStreak.lastActiveDayId
            : null;
        const restWeekday =
          typeof userData.restWeekday === "number" &&
          Number.isInteger(userData.restWeekday) &&
          userData.restWeekday >= 0 &&
          userData.restWeekday <= 6
            ? userData.restWeekday
            : 0;
        const updatedStreak = advanceLearningStreak(
          {
            current: numericField(previousStreak, "current"),
            longest: numericField(previousStreak, "longest"),
            shields: numericField(previousStreak, "shields"),
            lastActiveDayId: activeDayId,
          },
          dayId,
          restWeekday,
        );

        transaction.set(
          userRef,
          {
            streak: updatedStreak,
            updatedAt: FieldValue.serverTimestamp(),
            ...(result.xpAwarded + missionUpdate.xpAwarded > 0
              ? {
                  xpTotal:
                    numericField(userData, "xpTotal") +
                    result.xpAwarded +
                    missionUpdate.xpAwarded,
                }
              : {}),
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
              missionUpdate.xpAwarded,
            lessonsCompleted:
              numericField(dayData, "lessonsCompleted") +
              Number(numericField(dayData, "lessonsCompleted") === 0),
            lessonAttempts: numericField(dayData, "lessonAttempts") + 1,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        if (isFirstCompletion) {
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
        }
        transaction.set(
          progressRef,
          {
            schemaVersion: 1,
            lessonId: definition.lessonId,
            completed: true,
            completionCount:
              numericField(progressData, "completionCount") + 1,
            accuracy: Math.max(
              numericField(progressData, "accuracy"),
              result.accuracy,
            ),
            correctCount: Math.max(
              numericField(progressData, "correctCount"),
              result.correctCount,
            ),
            xpAwardedTotal:
              numericField(progressData, "xpAwardedTotal") + result.xpAwarded,
            answers: parsed.answers,
            lastCompletedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        transaction.create(requestRef, {
          schemaVersion: 1,
          clientRequestId: parsed.clientRequestId,
          fingerprint: answerFingerprint,
          result,
          completedAt: FieldValue.serverTimestamp(),
        });
        return result;
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Could not save lesson progress.");
    }
  },
);
