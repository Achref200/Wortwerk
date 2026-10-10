const assert = require("node:assert/strict");
const test = require("node:test");
const curriculum = require("../../content/a1_greetings.json");
const lessonDefinition = {
  lessonId: curriculum.lessonId,
  levelId: curriculum.levelId,
  unitId: curriculum.unitId,
  questions: Object.fromEntries(curriculum.questions.map((question) => [
    question.id,
    {
      choices: question.choices.map((choice) => choice.id),
      correctChoiceId: question.correctChoiceId,
    },
  ])),
};
const {
  LessonValidationError,
  advanceLearningStreak,
  lessonDefinitionFromDocument,
  resolveLessonSubmission,
  scoreLessonSubmission,
} = require("../lib/lesson.js");

const correctAnswers = [
  {
    questionId: "greeting_morning",
    choiceId: "morning_guten_morgen",
  },
  {
    questionId: "greeting_name",
    choiceId: "name_wie_heissen",
  },
  {
    questionId: "greeting_introduce",
    choiceId: "introduce_heisse",
  },
  {
    questionId: "greeting_thanks",
    choiceId: "thanks_bitte",
  },
  {
    questionId: "greeting_goodbye",
    choiceId: "goodbye_auf_wiedersehen",
  },
];

test("starts a streak on the first completed learning day", () => {
  assert.deepEqual(
    advanceLearningStreak(
      {
        current: 0,
        longest: 0,
        shields: 2,
        lastActiveDayId: null,
      },
      "2026-10-05",
      0,
    ),
    {
      current: 1,
      longest: 1,
      shields: 2,
      lastActiveDayId: "2026-10-05",
    },
  );
});

test("does not add duplicate activity on the same day", () => {
  const streak = {
    current: 4,
    longest: 7,
    shields: 1,
    lastActiveDayId: "2026-10-05",
  };
  assert.equal(advanceLearningStreak(streak, "2026-10-05", 0), streak);
});

test("weekly rest days preserve the streak without consuming a shield", () => {
  assert.deepEqual(
    advanceLearningStreak(
      {
        current: 4,
        longest: 4,
        shields: 2,
        lastActiveDayId: "2026-10-03",
      },
      "2026-10-05",
      0,
    ),
    {
      current: 5,
      longest: 5,
      shields: 2,
      lastActiveDayId: "2026-10-05",
    },
  );
});

test("missed days consume shields and reset the current streak when exhausted", () => {
  const updated = advanceLearningStreak(
    {
      current: 4,
      longest: 4,
      shields: 1,
      lastActiveDayId: "2026-10-01",
    },
    "2026-10-05",
    0,
  );
  assert.deepEqual(updated, {
    current: 1,
    longest: 4,
    shields: 0,
    lastActiveDayId: "2026-10-05",
  });
});

test("rejects malformed learning day IDs", () => {
  assert.throws(
    () =>
      advanceLearningStreak(
        {
          current: 0,
          longest: 0,
          shields: 2,
          lastActiveDayId: null,
        },
        "not-a-day",
        0,
      ),
    /valid learning day/,
  );
});

function submission(answers = correctAnswers, extra = {}) {
  return {
    levelId: "A1",
    unitId: "a1_greetings",
    lessonId: "a1_greetings",
    answers,
    clientRequestId: "lesson_request_123",
    ...extra,
  };
}

test("scores all five correct answers on the server", () => {
  assert.deepEqual(scoreLessonSubmission(submission(), lessonDefinition), {
    lessonId: "a1_greetings",
    accuracy: 1,
    correctCount: 5,
    xpAwarded: 20,
  });
});

test("published Firestore lesson documents provide the scoring definition", () => {
  const definition = lessonDefinitionFromDocument(curriculum, {
    levelId: "A1",
    unitId: "a1_greetings",
    lessonId: "a1_greetings",
  });
  assert.ok(definition);
  const oneQuestion = {
    levelId: "A1",
    unitId: "a1_greetings",
    lessonId: "a1_greetings",
    answers: [{ questionId: "greeting_morning", choiceId: "morning_guten_morgen" }],
    clientRequestId: "dynamic_lesson_req_1",
  };
  assert.deepEqual(scoreLessonSubmission(oneQuestion, {
    ...definition,
    questions: { greeting_morning: definition.questions.greeting_morning },
  }), {
    lessonId: "a1_greetings",
    accuracy: 1,
    correctCount: 1,
    xpAwarded: 12,
  });
  assert.equal(
    lessonDefinitionFromDocument({ ...curriculum, published: false }, {
      levelId: "A1",
      unitId: "a1_greetings",
      lessonId: "a1_greetings",
    }),
    null,
  );
});

test("recomputes accuracy and XP from selected choice IDs", () => {
  const answers = correctAnswers.map((answer, index) =>
    index === 1 ? { ...answer, choiceId: "name_woher" } : answer,
  );
  assert.deepEqual(scoreLessonSubmission(submission(answers), lessonDefinition), {
    lessonId: "a1_greetings",
    accuracy: 0.8,
    correctCount: 4,
    xpAwarded: 18,
  });
});

test("accepts answers in any order and requires all five distinct questions", () => {
  assert.equal(
    scoreLessonSubmission(submission([...correctAnswers].reverse()), lessonDefinition).accuracy,
    1,
  );
  assert.throws(
    () => scoreLessonSubmission(submission(correctAnswers.slice(0, 4)), lessonDefinition),
    LessonValidationError,
  );
  assert.throws(
    () =>
      scoreLessonSubmission(
        submission([
          ...correctAnswers.slice(0, 4),
          correctAnswers[0],
        ]),
        lessonDefinition,
      ),
    /answered twice/,
  );
});

test("rejects unknown question IDs, choices, request IDs, and client scores", () => {
  assert.throws(
    () =>
      scoreLessonSubmission(
        submission(
          correctAnswers.map((answer, index) =>
            index === 0
              ? { ...answer, questionId: "invented_question" }
              : answer,
          ),
        ),
        lessonDefinition,
      ),
    /question ID is invalid/,
  );
  assert.throws(
    () =>
      scoreLessonSubmission(
        submission(
          correctAnswers.map((answer, index) =>
            index === 0 ? { ...answer, choiceId: "invented_choice" } : answer,
          ),
        ),
        lessonDefinition,
      ),
    /answer choice is invalid/,
  );
  assert.throws(
    () => scoreLessonSubmission(submission(correctAnswers, { clientScore: 5 }), lessonDefinition),
    /must contain levelId, unitId, lessonId, answers, and clientRequestId/,
  );
  assert.throws(
    () =>
      scoreLessonSubmission(
        submission(correctAnswers, { clientRequestId: "short" }),
        lessonDefinition,
      ),
    /valid client request ID/,
  );
});

test("an identical client request returns its original result without rescoring", () => {
  const input = submission();
  const original = scoreLessonSubmission(input, lessonDefinition);
  const previous = {
    clientRequestId: input.clientRequestId,
    fingerprint: JSON.stringify(
      [...correctAnswers]
        .sort((left, right) => left.questionId.localeCompare(right.questionId))
        .map(({ questionId, choiceId }) => [questionId, choiceId]),
    ),
    result: { ...original, xpAwarded: 22 },
  };

  assert.deepEqual(resolveLessonSubmission(input, lessonDefinition, previous), previous.result);
  assert.deepEqual(
    resolveLessonSubmission(
      submission([...correctAnswers].reverse()),
      lessonDefinition,
      previous,
    ),
    previous.result,
  );
});

test("a request ID cannot be reused for a different answer payload", () => {
  const input = submission();
  const previous = {
    clientRequestId: input.clientRequestId,
    fingerprint: "different-payload",
    result: scoreLessonSubmission(input, lessonDefinition),
  };

  assert.throws(
    () => resolveLessonSubmission(input, lessonDefinition, previous),
    /cannot be reused for different answers/,
  );
});
