const assert = require("node:assert/strict");
const test = require("node:test");
const {
  evaluateLevelProgress,
  canAccessLevel,
  nextLevelId,
  previousUnitsUnlocked,
  retainedCoreVocabularyCount,
} = require("../lib/progression.js");

const core = Array.from({ length: 10 }, (_, index) => `word_${index + 1}`);

test("retains a word at a three-day interval or after two correct reviews", () => {
  const states = new Map([
    ["word_1", { intervalDays: 3, correctStreak: 1 }],
    ["word_2", { intervalDays: 1, correctStreak: 2 }],
    ["word_3", { intervalDays: 2, correctStreak: 1 }],
  ]);
  assert.equal(retainedCoreVocabularyCount(core, states), 2);
});

test("evaluates all three server-owned unlock criteria", () => {
  const nineRetained = new Map(
    core.slice(0, 7).map((id) => [id, { intervalDays: 3, correctStreak: 2 }]),
  );
  const ready = evaluateLevelProgress({
    coreVocabularyCardIds: core,
    cardStates: nineRetained,
    fritzConversations: 3,
    reviewRoundsPassed: 1,
  });
  assert.equal(ready.retainedWords, 7);
  assert.equal(ready.retentionMet, true);
  assert.equal(ready.conversationsMet, true);
  assert.equal(ready.reviewMet, true);
  assert.equal(ready.readyToUnlock, true);

  assert.equal(
    evaluateLevelProgress({
      coreVocabularyCardIds: core,
      cardStates: nineRetained,
      fritzConversations: 2,
      reviewRoundsPassed: 1,
    }).readyToUnlock,
    false,
  );
});

test("does not claim a retention threshold without published core words", () => {
  const empty = evaluateLevelProgress({
    coreVocabularyCardIds: [],
    cardStates: new Map(),
    fritzConversations: 3,
    reviewRoundsPassed: 1,
  });
  assert.equal(empty.retentionMet, false);
  assert.equal(empty.readyToUnlock, false);
});

test("maps only the supported CEFR progression sequence", () => {
  assert.equal(nextLevelId("A1"), "A2");
  assert.equal(nextLevelId("C2"), undefined);
  assert.equal(canAccessLevel("A2", "A1", false), true);
  assert.equal(canAccessLevel("A1", "A2", false), false);
  assert.equal(canAccessLevel("A1", "A2", true), true);
});

test("opens a later unit only after every previous lesson passes 60 percent", () => {
  const units = [["lesson_1", "lesson_2"]];
  assert.equal(
    previousUnitsUnlocked(
      units,
      new Map([
        ["lesson_1", { completed: true, accuracy: 0.8 }],
        ["lesson_2", { completed: true, accuracy: 0.6 }],
      ]),
    ),
    true,
  );
  assert.equal(
    previousUnitsUnlocked(
      units,
      new Map([
        ["lesson_1", { completed: true, accuracy: 0.8 }],
        ["lesson_2", { completed: false, accuracy: 1 }],
      ]),
    ),
    false,
  );
  assert.equal(previousUnitsUnlocked([[]], new Map()), false);
});
