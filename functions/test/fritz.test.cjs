const assert = require("node:assert/strict");
const test = require("node:test");
const { Timestamp } = require("firebase-admin/firestore");
const {
  advanceFritzConversation,
  buildSystemPrompt,
  FritzProviderUnavailableError,
  fritzProviderCallsEnabled,
  fritzRequestFingerprint,
  generateTutorReply,
  parseFritzChatInput,
  parseFritzProviderOrder,
  pendingRequestIsActive,
} = require("../lib/fritz.js");

const input = {
  message: "Wie sage ich Guten Morgen?",
  mode: "chat",
  history: [{ role: "assistant", text: "Hallo! Was möchtest du üben?" }],
  learner: {
    level: "A1",
    unitId: "a1_greetings",
    goals: ["Alltag"],
  },
};
const chatRequest = {
  message: input.message,
  mode: input.mode,
  threadId: "main",
  clientRequestId: "fritz_request_12345678",
};

test("keeps the tutor instruction scoped to safe German learning", () => {
  const prompt = buildSystemPrompt("explain", input.learner);
  assert.match(prompt, /ausschließlich auf Deutsch/);
  assert.match(prompt, /höchstens acht Wörter pro Satz/);
  assert.match(prompt, /genau zwei Beispiele/);
  assert.match(prompt, /Passwörter, API-Schlüssel/);
});

test("validates chat input and rejects extra client-controlled fields", () => {
  const parsed = parseFritzChatInput({
    ...chatRequest,
  });
  assert.equal(parsed.threadId, "main");
  assert.equal(parsed.mode, "chat");
  assert.equal(parsed.message, input.message);
  assert.throws(
    () =>
      parseFritzChatInput({
        ...chatRequest,
        message: "x".repeat(1001),
      }),
    { code: "invalid-argument" },
  );
  assert.throws(
    () =>
      parseFritzChatInput({
        ...chatRequest,
        clientScore: 100,
      }),
    { code: "invalid-argument" },
  );
});

test("allows changing the provider order only as a complete permutation", () => {
  assert.deepEqual(
    parseFritzProviderOrder("openai,gemini,nvidia"),
    ["openai", "gemini", "nvidia"],
  );
  assert.throws(
    () => parseFritzProviderOrder("openai,openai,nvidia"),
    { code: "failed-precondition" },
  );
});

test("provider calls stay disabled unless the operator explicitly enables them", () => {
  assert.equal(fritzProviderCallsEnabled("false"), false);
  assert.equal(fritzProviderCallsEnabled(""), false);
  assert.equal(fritzProviderCallsEnabled("TRUE"), false);
  assert.equal(fritzProviderCallsEnabled("true"), true);
});

test("request fingerprints bind retries to the same thread, mode and message", () => {
  const parsed = parseFritzChatInput({
    message: input.message,
    mode: input.mode,
    threadId: "lesson_practice",
    clientRequestId: "fritz_request_12345678",
  });
  assert.equal(fritzRequestFingerprint(parsed), fritzRequestFingerprint(parsed));
  assert.notEqual(
    fritzRequestFingerprint(parsed),
    fritzRequestFingerprint({ ...parsed, message: "Was kostet das?" }),
  );
  assert.notEqual(
    fritzRequestFingerprint(parsed),
    fritzRequestFingerprint({ ...parsed, mode: "explain" }),
  );
  assert.notEqual(
    fritzRequestFingerprint(parsed),
    fritzRequestFingerprint({ ...parsed, threadId: "other_thread" }),
  );
});

test("pending Fritz requests expire after the callable timeout window", () => {
  const now = 1_800_000_000_000;
  assert.equal(
    pendingRequestIsActive(
      { status: "pending", updatedAt: Timestamp.fromMillis(now - 60_000) },
      now,
    ),
    true,
  );
  assert.equal(
    pendingRequestIsActive(
      { status: "pending", updatedAt: Timestamp.fromMillis(now - 90_000) },
      now,
    ),
    false,
  );
  assert.equal(pendingRequestIsActive({ status: "completed" }, now), false);
  assert.equal(pendingRequestIsActive({ status: "pending" }, now), true);
});

test("counts one qualifying Fritz conversation after six learner turns", () => {
  let thread;
  for (let turn = 1; turn <= 6; turn += 1) {
    const progress = advanceFritzConversation(thread);
    assert.equal(progress.learnerTurnCount, turn);
    assert.equal(progress.justCompleted, turn === 6);
    thread = {
      learnerTurnCount: progress.learnerTurnCount,
      qualifyingConversationCompleted: progress.completed,
    };
  }

  const nextTurn = advanceFritzConversation(thread);
  assert.equal(nextTurn.learnerTurnCount, 7);
  assert.equal(nextTurn.completed, true);
  assert.equal(nextTurn.justCompleted, false);
});

test("falls back to the next configured provider after a provider failure", async () => {
  const requests = [];
  const fetcher = async (url, options) => {
    requests.push({ url, options });
    if (url.includes("integrate.api.nvidia.com")) {
      return { ok: false, json: async () => ({ error: "not for logs" }) };
    }
    return {
      ok: true,
      json: async () => ({
        candidates: [
          { content: { parts: [{ text: "Guten Morgen! Das ist richtig." }] } },
        ],
      }),
    };
  };
  const result = await generateTutorReply(
    input,
    [
      { name: "nvidia", key: "nvidia-test-key" },
      { name: "gemini", key: "gemini-test-key" },
    ],
    fetcher,
    ["nvidia", "gemini"],
  );

  assert.equal(result.provider, "gemini");
  assert.equal(result.reply, "Guten Morgen! Das ist richtig.");
  assert.equal(requests.length, 2);
  assert.equal(
    requests[0].options.headers.authorization,
    "Bearer nvidia-test-key",
  );
  assert.equal(
    requests[1].options.headers["x-goog-api-key"],
    "gemini-test-key",
  );
  assert.equal(requests[1].url.includes("gemini-test-key"), false);
});

test("returns a useful reply from the configured provider without fallback", async () => {
  const result = await generateTutorReply(
    input,
    [{ name: "openai", key: "openai-test-key" }],
    async (url, options) => {
      assert.equal(url, "https://api.openai.com/v1/chat/completions");
      const body = JSON.parse(options.body);
      assert.equal(body.messages[0].role, "system");
      assert.equal(body.messages[1].role, "assistant");
      assert.equal(body.messages[2].content, input.message);
      return {
        ok: true,
        json: async () => ({
          choices: [{ message: { content: "„Guten Morgen“ ist richtig." } }],
        }),
      };
    },
    ["openai"],
  );

  assert.equal(result.provider, "openai");
  assert.equal(result.reply, "„Guten Morgen“ ist richtig.");
});

test("does not return provider exception details or send a blank response", async () => {
  await assert.rejects(
    () => generateTutorReply(input, [], async () => assert.fail("no key sent")),
    FritzProviderUnavailableError,
  );
  await assert.rejects(
    () =>
      generateTutorReply(
        input,
        [{ name: "openai", key: "openai-test-key" }],
        async () => ({
          ok: true,
          json: async () => ({
            choices: [{ message: { content: " " } }],
          }),
        }),
        ["openai"],
      ),
    FritzProviderUnavailableError,
  );
});
