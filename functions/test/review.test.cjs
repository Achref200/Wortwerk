const assert = require("node:assert/strict");
const test = require("node:test");
const {
  FlashcardReviewValidationError,
  greetingCardIds,
  resolveFlashcardReview,
  scoreFlashcardReview,
} = require("../lib/review.js");

function submission(answers, extra = {}) {
  return {
    clientRequestId: "review_request_123",
    answers,
    ...extra,
  };
}

const answers = greetingCardIds.map((cardId, index) => ({
  cardId,
  remembered: index % 2 === 0,
}));

test("scores exactly ten distinct cards and awards one session reward", () => {
  assert.deepEqual(scoreFlashcardReview(submission(answers)), {
    reviewedCount: 10,
    rememberedCount: 5,
    xpAwarded: 10,
  });
});

test("rejects incomplete, duplicate, unknown, and malformed review answers", () => {
  assert.throws(
    () => scoreFlashcardReview(submission(answers.slice(0, 9))),
    FlashcardReviewValidationError,
  );
  assert.throws(
    () =>
      scoreFlashcardReview(
        submission([...answers.slice(0, 9), answers[0]]),
      ),
    /ten unique, known greeting cards/,
  );
  assert.throws(
    () =>
      scoreFlashcardReview(
        submission(
          answers.map((answer, index) =>
            index === 0 ? { ...answer, cardId: "unknown" } : answer,
          ),
        ),
      ),
    /ten unique, known greeting cards/,
  );
  assert.throws(
    () => scoreFlashcardReview(submission(answers, { xpAwarded: 999 })),
    /only clientRequestId and answers/,
  );
});

test("an identical review request is idempotent", () => {
  const input = submission(answers);
  const result = scoreFlashcardReview(input);
  const previous = {
    clientRequestId: input.clientRequestId,
    fingerprint: JSON.stringify(
      [...answers]
        .sort((left, right) => left.cardId.localeCompare(right.cardId))
        .map(({ cardId, remembered }) => [cardId, remembered]),
    ),
    result: { ...result, xpAwarded: 10 },
  };
  assert.deepEqual(resolveFlashcardReview(input, previous), previous.result);
});

test("a review request ID cannot be reused for different ratings", () => {
  const input = submission(answers);
  const previous = {
    clientRequestId: input.clientRequestId,
    fingerprint: "different",
    result: scoreFlashcardReview(input),
  };
  assert.throws(
    () => resolveFlashcardReview(input, previous),
    /cannot be reused for different review answers/,
  );
});
