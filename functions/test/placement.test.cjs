const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { evaluatePlacement, placementQuestionBank } = require("../lib/placement.js");

const questionDefinitions = Object.entries(placementQuestionBank);

function adaptiveAnswers(correctness, startLevel = "A1") {
  let level = startLevel;
  let correctStreak = 0;
  let incorrectStreak = 0;
  const answers = [];
  const levelOrder = ["A1", "A2", "B1"];
  for (const isCorrect of correctness) {
    const [questionId, question] = questionDefinitions.find(
      ([id, candidate]) =>
        candidate.level === level &&
        !answers.some((answer) => answer.questionId === id),
    );
    answers.push({
      questionId,
      choiceId: isCorrect
        ? question.correctChoiceId
        : question.choices.find((choiceId) => choiceId !== question.correctChoiceId),
    });
    if (isCorrect) {
      correctStreak++;
      incorrectStreak = 0;
      if (correctStreak === 2) {
        level = levelOrder[Math.min(levelOrder.indexOf(level) + 1, 2)];
        correctStreak = 0;
      }
    } else {
      incorrectStreak++;
      correctStreak = 0;
      if (incorrectStreak === 2) {
        level = levelOrder[Math.max(levelOrder.indexOf(level) - 1, 0)];
        incorrectStreak = 0;
      }
    }
  }
  return answers;
}

test("the server and Flutter share the same adaptive question ids and levels", () => {
  const dartQuestions = fs.readFileSync(
    path.resolve(
      __dirname,
      "../../lib/features/onboarding/domain/placement_session.dart",
    ),
    "utf8",
  );
  const dartQuestionsParsed = [
    ...dartQuestions.matchAll(
      /PlacementQuestion\(\s*id: '([a-z0-9_]+)',\s+level: LearningLevel\.([a-z0-9]+),[\s\S]*?choices: \[([\s\S]*?)\],\s+correctChoiceId: '([a-z0-9_]+)'/g,
    ),
  ].map(([, id, level, choicesBlock, correctChoiceId]) => [
    id,
    {
      level: level.toUpperCase(),
      choices: [...choicesBlock.matchAll(/id: '([a-z0-9_]+)'/g)].map(
        ([, choiceId]) => choiceId,
      ),
      correctChoiceId,
    },
  ]);
  assert.deepEqual(
    Object.entries(placementQuestionBank)
      .map(([id, question]) => [id, question])
      .sort(),
    dartQuestionsParsed.sort(),
  );
});

test("adaptive placement raises the estimated starting level after two correct answers", () => {
  const result = evaluatePlacement({
    startLevel: "A1",
    answers: adaptiveAnswers(Array(8).fill(true)),
  });
  assert.deepEqual(result, {
    level: "B1",
    unitId: "b1_conversation",
    confidence: 1,
  });
});

test("adaptive placement lowers the estimated level after two incorrect answers", () => {
  const result = evaluatePlacement({
    startLevel: "B1",
    answers: adaptiveAnswers(Array(8).fill(false), "B1"),
  });
  assert.equal(result.level, "A1");
  assert.equal(result.unitId, "a1_greetings");
  assert.equal(result.confidence, 0);
});

test("adaptive placement accepts six answers and reports measured confidence", () => {
  const result = evaluatePlacement({
    startLevel: "A1",
    answers: adaptiveAnswers([true, true, false, false, true, true]),
  });
  assert.equal(result.level, "A2");
  assert.equal(result.unitId, "a2_travel");
  assert.equal(result.confidence, 4 / 6);
});

test("adaptive placement rejects fewer than six answers", () => {
  assert.throws(
    () =>
      evaluatePlacement({
        startLevel: "A1",
        answers: adaptiveAnswers([true, true, false, false, true]),
      }),
    /6 to 8 answers/,
  );
});

test("adaptive placement rejects skipped difficulty levels and repeated questions", () => {
  const answers = adaptiveAnswers(Array(8).fill(true));
  assert.throws(
    () =>
      evaluatePlacement({
        startLevel: "A1",
        answers: [
          ...answers.slice(0, 2),
          { questionId: "b1_reason", choiceId: "b1r_a" },
          ...answers.slice(3),
        ],
      }),
    /adaptive placement path/,
  );

  assert.throws(
    () =>
      evaluatePlacement({
        startLevel: "A1",
        answers: Array(6).fill({ questionId: "a1_greeting", choiceId: "a1g_a" }),
      }),
    /cannot be answered twice/,
  );
});

test("adaptive placement rejects invalid levels and options", () => {
  assert.throws(
    () => evaluatePlacement({ startLevel: "C2", answers: [] }),
    /starting level/,
  );
  assert.throws(
    () =>
      evaluatePlacement({
        startLevel: "A1",
        answers: adaptiveAnswers(Array(8).fill(true)).map((answer, index) =>
          index === 0 ? { ...answer, choiceId: "forged" } : answer,
        ),
      }),
    /answer choice is invalid/,
  );
});
