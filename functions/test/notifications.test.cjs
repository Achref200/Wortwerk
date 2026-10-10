const assert = require("node:assert/strict");
const test = require("node:test");
const {
  localizedPushContent,
  notificationDeviceId,
  parseDeviceRegistration,
  validateNotificationId,
} = require("../lib/notifications.js");

test("notification IDs are bounded safe document identifiers", () => {
  assert.equal(validateNotificationId("level-unlocked_a2"), "level-unlocked_a2");
  assert.throws(() => validateNotificationId("../other-user"), {
    code: "invalid-argument",
  });
  assert.throws(() => validateNotificationId("x".repeat(129)), {
    code: "invalid-argument",
  });
  assert.throws(() => validateNotificationId(undefined), {
    code: "invalid-argument",
  });
});

test("device registration accepts only supported token metadata", () => {
  const token = "x".repeat(120);
  assert.deepEqual(parseDeviceRegistration({ token, platform: "ios", language: "en" }), {
    token,
    platform: "ios",
    language: "en",
  });
  assert.equal(notificationDeviceId(token).length, 64);
  assert.notEqual(notificationDeviceId(token), token);
  assert.throws(() => parseDeviceRegistration({ token: "short", platform: "web", language: "en" }), {
    code: "invalid-argument",
  });
  assert.throws(() => parseDeviceRegistration({ token, platform: "desktop", language: "en" }), {
    code: "invalid-argument",
  });
  assert.throws(() => parseDeviceRegistration({ token, platform: "web", language: "fr" }), {
    code: "invalid-argument",
  });
});

test("level-unlock push copy follows the device language", () => {
  assert.equal(localizedPushContent("levelUnlocked", "A2", "en").title, "A new level is open");
  assert.equal(localizedPushContent("levelUnlocked", "A2", "de").deepLink, "/path");
  assert.equal(localizedPushContent("unknown", "A2", "en"), undefined);
});
