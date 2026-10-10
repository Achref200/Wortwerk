import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { dayIdAt, timezoneFromUser } from "./lesson.js";

export const dailyMissionKinds = [
  "lesson_complete",
  "review_session",
  "fritz_conversation",
] as const;

export type DailyMissionKind = (typeof dailyMissionKinds)[number];

const definitions: Readonly<
  Record<DailyMissionKind, { titleKey: string; target: number; xp: number }>
> = {
  lesson_complete: { titleKey: "complete_a_lesson", target: 1, xp: 20 },
  review_session: { titleKey: "review_ten_words", target: 1, xp: 20 },
  fritz_conversation: { titleKey: "talk_with_fritz", target: 1, xp: 30 },
};

export interface DailyMissionTask {
  kind: DailyMissionKind;
  titleKey: string;
  target: number;
  progress: number;
  xp: number;
  completed: boolean;
  completedAt?: unknown;
}

export function newDailyMissionData(input: {
  dayId: string;
  timezone: string;
  goals: readonly string[];
}): Record<string, unknown> {
  const tasks = Object.fromEntries(
    dailyMissionKinds.map((kind) => [
      kind,
      {
        kind,
        titleKey: definitions[kind].titleKey,
        target: definitions[kind].target,
        progress: 0,
        xp: definitions[kind].xp,
        completed: false,
      } satisfies DailyMissionTask,
    ]),
  );
  const sortedGoals = [...new Set(input.goals)].sort();
  const focusGoal = sortedGoals.length === 0
    ? "alltag"
    : sortedGoals[
        [...input.dayId].reduce((sum, character) => sum + character.charCodeAt(0), 0) %
          sortedGoals.length
      ];
  return {
    schemaVersion: 1,
    date: input.dayId,
    timezone: input.timezone,
    focusGoal,
    tasks,
    completedCount: 0,
    earnedXp: 0,
  };
}

export function advanceDailyMission(
  previous: Record<string, unknown> | undefined,
  kind: DailyMissionKind,
  input: { dayId: string; timezone: string; goals: readonly string[] },
): { data: Record<string, unknown>; xpAwarded: number } {
  const source = previous ?? newDailyMissionData(input);
  const sourceTasks = isRecord(source.tasks) ? source.tasks : {};
  const tasks: Record<string, DailyMissionTask> = {};
  for (const missionKind of dailyMissionKinds) {
    const raw = sourceTasks[missionKind];
    const definition = definitions[missionKind];
    tasks[missionKind] = {
      kind: missionKind,
      titleKey: definition.titleKey,
      target: definition.target,
      progress: safeCount(isRecord(raw) ? raw.progress : 0),
      xp: definition.xp,
      completed: isRecord(raw) && raw.completed === true,
      ...(isRecord(raw) && raw.completedAt
        ? { completedAt: raw.completedAt }
        : {}),
    };
  }
  const task = tasks[kind];
  let xpAwarded = 0;
  if (!task.completed) {
    task.progress = Math.min(task.target, task.progress + 1);
    if (task.progress >= task.target) {
      task.completed = true;
      task.completedAt = FieldValue.serverTimestamp();
      xpAwarded = task.xp;
    }
  }
  const completedCount = dailyMissionKinds.reduce(
    (total, missionKind) => total + Number(tasks[missionKind].completed),
    0,
  );
  return {
    data: {
      ...source,
      date: input.dayId,
      timezone: input.timezone,
      tasks,
      completedCount,
      earnedXp: safeCount(source.earnedXp) + xpAwarded,
      updatedAt: FieldValue.serverTimestamp(),
    },
    xpAwarded,
  };
}

export const getDailyMissions = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to load daily missions.");
    }
    if (getApps().length === 0) initializeApp();
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const result = await db.runTransaction(async (transaction) => {
      const userSnapshot = await transaction.get(userRef);
      const user = userSnapshot.data();
      if (!userSnapshot.exists || user?.onboardingCompleted !== true) {
        throw new HttpsError(
          "failed-precondition",
          "Complete onboarding before loading daily missions.",
        );
      }
      const timezone = timezoneFromUser(user);
      const dayId = dayIdAt(new Date(), timezone);
      const missionRef = userRef.collection("missions").doc(dayId);
      const missionSnapshot = await transaction.get(missionRef);
      let data = missionSnapshot.data();
      if (!missionSnapshot.exists) {
        data = newDailyMissionData({
          dayId,
          timezone,
          goals: Array.isArray(user.goals)
            ? user.goals.filter((goal): goal is string => typeof goal === "string")
            : [],
        });
        transaction.create(missionRef, {
          ...data,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return { dayId, data: data ?? {} };
    });
    return result;
  },
);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function safeCount(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? value
    : 0;
}
