import { createHash } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import {
  DocumentReference,
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

const supportedPlatforms = new Set(["android", "ios", "web"]);
const supportedLanguages = new Set(["de", "en"]);

export function validateNotificationId(value: unknown): string {
  if (
    typeof value !== "string" ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(value)
  ) {
    throw new HttpsError("invalid-argument", "A valid notification ID is required.");
  }
  return value;
}

export function notificationDeviceId(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export function parseDeviceRegistration(value: unknown): {
  token: string;
  platform: "android" | "ios" | "web";
  language: "de" | "en";
} {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new HttpsError("invalid-argument", "A device registration is required.");
  }
  const input = value as Record<string, unknown>;
  if (
    Object.keys(input).sort().join(",") !== "language,platform,token" ||
    typeof input.token !== "string" ||
    input.token.length < 100 ||
    input.token.length > 4096 ||
    typeof input.platform !== "string" ||
    !supportedPlatforms.has(input.platform) ||
    typeof input.language !== "string" ||
    !supportedLanguages.has(input.language)
  ) {
    throw new HttpsError("invalid-argument", "The device registration is invalid.");
  }
  return {
    token: input.token,
    platform: input.platform as "android" | "ios" | "web",
    language: input.language as "de" | "en",
  };
}

export function localizedPushContent(
  kind: unknown,
  level: unknown,
  language: unknown,
): { title: string; body: string; deepLink: string } | undefined {
  if (kind !== "levelUnlocked" || typeof level !== "string") return undefined;
  if (language === "en") {
    return {
      title: "A new level is open",
      body: `You unlocked ${level}. Take a look at your next path.`,
      deepLink: "/path",
    };
  }
  return {
    title: "Ein neues Niveau ist offen",
    body: `Du hast ${level} freigeschaltet. Sieh dir deinen nächsten Lernweg an.`,
    deepLink: "/path",
  };
}

export const registerNotificationDevice = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to register this device.");
    }
    const registration = parseDeviceRegistration(request.data);
    if (getApps().length === 0) initializeApp();
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const deviceRef = userRef
      .collection("devices")
      .doc(notificationDeviceId(registration.token));
    await db.runTransaction(async (transaction) => {
      const user = await transaction.get(userRef);
      if (!user.exists) {
        throw new HttpsError("failed-precondition", "Complete onboarding first.");
      }
      transaction.set(
        deviceRef,
        {
          schemaVersion: 1,
          token: registration.token,
          platform: registration.platform,
          language: registration.language,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      transaction.set(
        userRef,
        { pushEnabled: true, updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    });
    return { ok: true };
  },
);

export const disablePushNotifications = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to update notifications.");
    }
    if (request.data?.enabled !== false || Object.keys(request.data ?? {}).length !== 1) {
      throw new HttpsError("invalid-argument", "Only push opt-out is accepted here.");
    }
    if (getApps().length === 0) initializeApp();
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const devices = await userRef.collection("devices").get();
    for (let offset = 0; offset < devices.docs.length; offset += 450) {
      const batch = db.batch();
      for (const device of devices.docs.slice(offset, offset + 450)) {
        batch.delete(device.ref);
      }
      await batch.commit();
    }
    await userRef.set(
      { pushEnabled: false, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return { ok: true };
  },
);

export const markNotificationRead = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to update notifications.");
    }
    const notificationId = validateNotificationId(request.data?.notificationId);
    if (getApps().length === 0) initializeApp();
    const notification = getFirestore()
      .doc(`users/${uid}/notifications/${notificationId}`);
    await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(notification);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Notification was not found.");
      }
      if (snapshot.get("readAt") == null) {
        transaction.update(notification, {
          readAt: FieldValue.serverTimestamp(),
        });
      }
    });
    return { ok: true };
  },
);

export const deliverNotificationPush = onDocumentCreated(
  {
    document: "users/{uid}/notifications/{notificationId}",
    region: "europe-west1",
    retry: true,
  },
  async (event) => {
    if (process.env.FUNCTIONS_EMULATOR === "true") return;
    const data = event.data?.data();
    if (!data) return;

    const uid = event.params.uid;
    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const notificationRef = event.data!.ref;
    const language = await db.runTransaction(async (transaction) => {
      const [user, notification] = await Promise.all([
        transaction.get(userRef),
        transaction.get(notificationRef),
      ]);
      if (
        user.get("pushEnabled") !== true ||
        notification.get("pushSentAt") != null
      ) {
        return false as const;
      }
      const startedAt = notification.get("pushStartedAt");
      if (
        notification.get("pushStatus") === "sending" &&
        startedAt != null &&
        typeof startedAt.toDate === "function" &&
        Date.now() - startedAt.toDate().getTime() < 5 * 60 * 1000
      ) {
        return false as const;
      }
      transaction.update(notificationRef, {
        pushStatus: "sending",
        pushStartedAt: FieldValue.serverTimestamp(),
      });
      const preferredLanguage = user.get("uiLang");
      return preferredLanguage === "en" ? "en" : "de";
    });
    if (language === false) return;
    const content = localizedPushContent(data.kind, data.level, language);
    if (!content) {
      await notificationRef.set({ pushStatus: "unsupported_kind" }, { merge: true });
      return;
    }

    const devices = await userRef.collection("devices").get();
    const registrations = devices.docs
      .map((document) => ({
        ref: document.ref,
        token: document.get("token"),
        language: document.get("language"),
      }))
      .filter(
        (device): device is typeof device & { token: string } =>
          typeof device.token === "string" && device.token.length > 0,
      );
    if (registrations.length === 0) {
      await notificationRef.set({ pushStatus: "no_devices" }, { merge: true });
      return;
    }

    const invalidDevices: DocumentReference[] = [];
    let transientFailures = 0;
    const byLanguage = new Map<string, typeof registrations>();
    for (const device of registrations) {
      const deviceLanguage = device.language === "en" ? "en" : "de";
      byLanguage.set(deviceLanguage, [
        ...(byLanguage.get(deviceLanguage) ?? []),
        device,
      ]);
    }
    for (const [deviceLanguage, languageDevices] of byLanguage) {
      const deviceContent = localizedPushContent(
        data.kind,
        data.level,
        deviceLanguage,
      ) ?? content;
      for (let offset = 0; offset < languageDevices.length; offset += 500) {
        const batch = languageDevices.slice(offset, offset + 500);
        const response = await getMessaging().sendEachForMulticast({
          tokens: batch.map(({ token }) => token),
          notification: deviceContent,
          data: {
            notificationId: event.params.notificationId,
            kind: String(data.kind),
            deepLink: deviceContent.deepLink,
          },
          android: {
            priority: "high",
            notification: { channelId: "learning_reminders" },
          },
          apns: { payload: { aps: { sound: "default" } } },
        });
        response.responses.forEach((result, index) => {
          if (result.success) return;
          const code = result.error?.code;
          if (
            code === "messaging/invalid-registration-token" ||
            code === "messaging/registration-token-not-registered"
          ) {
            invalidDevices.push(batch[index].ref);
          } else {
            transientFailures++;
          }
        });
      }
    }
    for (let offset = 0; offset < invalidDevices.length; offset += 500) {
      const cleanup = db.batch();
      for (const invalidDevice of invalidDevices.slice(offset, offset + 500)) {
        cleanup.delete(invalidDevice);
      }
      await cleanup.commit();
    }
    await notificationRef.set(
      {
        pushStatus: "sent",
        pushSentAt: FieldValue.serverTimestamp(),
        invalidDeviceCount: invalidDevices.length,
      },
      { merge: true },
    );
    if (transientFailures > 0) {
      await notificationRef.set(
        { pushStatus: "retrying", pushSentAt: FieldValue.delete() },
        { merge: true },
      );
      throw new Error(`FCM delivery failed for ${transientFailures} device(s).`);
    }
  },
);
