const assert = require("node:assert/strict");
const test = require("node:test");
const {
  advanceDailyMission,
  dailyMissionKinds,
  newDailyMissionData,
} = require("../lib/missions.js");

const context = {
  dayId: "2026-10-07",
  timezone: "Europe/Paris",
  goals: ["Reisen", "Arbeit"],
};

test("creates three stable daily missions and chooses a goal focus", () => {
  const mission = newDailyMissionData(context);
  assert.deepEqual(Object.keys(mission.tasks), dailyMissionKinds);
  assert.equal(mission.date, context.dayId);
  assert.ok(context.goals.includes(mission.focusGoal));
  assert.equal(mission.completedCount, 0);
});

test("awards mission XP only once when its server event completes", () => {
  const initial = newDailyMissionData(context);
  const first = advanceDailyMission(initial, "lesson_complete", context);
  assert.equal(first.xpAwarded, 20);
  assert.equal(first.data.completedCount, 1);
  const duplicate = advanceDailyMission(
    first.data,
    "lesson_complete",
    context,
  );
  assert.equal(duplicate.xpAwarded, 0);
  assert.equal(duplicate.data.earnedXp, 20);
});

test("separate confirmed activities complete their own mission rows", () => {
  let data = newDailyMissionData(context);
  let earned = 0;
  for (const kind of dailyMissionKinds) {
    const next = advanceDailyMission(data, kind, context);
    data = next.data;
    earned += next.xpAwarded;
  }
  assert.equal(data.completedCount, 3);
  assert.equal(earned, 70);
  assert.equal(data.earnedXp, 70);
});
