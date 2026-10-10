const assert = require("node:assert/strict");
const test = require("node:test");
const {
  parseCommunityMessage,
  parseGroupId,
  parseReportReason,
} = require("../lib/community.js");

test("community messages are trimmed and bounded plain text", () => {
  assert.deepEqual(
    parseCommunityMessage({
      groupId: "a1_everyday",
      clientRequestId: "request_id_1234",
      body: "  Hallo zusammen!  ",
    }),
    {
      groupId: "a1_everyday",
      clientRequestId: "request_id_1234",
      body: "Hallo zusammen!",
    },
  );
  assert.throws(
    () => parseCommunityMessage({
      groupId: "a1_everyday",
      clientRequestId: "request_id_1234",
      body: "visit https://example.com",
    }),
    { code: "invalid-argument" },
  );
  assert.throws(
    () => parseCommunityMessage({
      groupId: "a1_everyday",
      clientRequestId: "request_id_1234",
      body: "x".repeat(2001),
    }),
    { code: "invalid-argument" },
  );
  assert.throws(
    () => parseCommunityMessage({
      groupId: "a1_everyday",
      clientRequestId: "short",
      body: "Hallo",
    }),
    { code: "invalid-argument" },
  );
});

test("group IDs and report reasons use fixed allow-lists", () => {
  assert.equal(parseGroupId("a1_everyday"), "a1_everyday");
  assert.throws(() => parseGroupId("../users"), { code: "invalid-argument" });
  assert.equal(parseReportReason("harassment"), "harassment");
  assert.throws(() => parseReportReason("free-form"), { code: "invalid-argument" });
});
