import { createHash } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

const communityRulesVersion = 1;
const validReasons = new Set([
  "harassment",
  "spam",
  "unsafe",
  "other",
]);

export interface CommunityMessageInput {
  groupId: string;
  clientRequestId: string;
  body: string;
}

export function parseCommunityMessage(value: unknown): CommunityMessageInput {
  if (!isRecord(value) ||
      Object.keys(value).sort().join(",") !== "body,clientRequestId,groupId") {
    throw new HttpsError("invalid-argument", "A community message is required.");
  }
  const groupId = parseGroupId(value.groupId);
  const clientRequestId = value.clientRequestId;
  const body = typeof value.body === "string" ? value.body.trim() : "";
  if (
    typeof clientRequestId !== "string" ||
    !/^[A-Za-z0-9_-]{12,80}$/.test(clientRequestId) ||
    body.length < 1 ||
    body.length > 2000 ||
    /https?:\/\/|www\./i.test(body) ||
    /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(body)
  ) {
    throw new HttpsError("invalid-argument", "The message is not allowed.");
  }
  return { groupId, clientRequestId, body };
}

export function parseGroupId(value: unknown): string {
  if (typeof value !== "string" || !/^[a-z0-9_-]{3,40}$/.test(value)) {
    throw new HttpsError("invalid-argument", "A valid group ID is required.");
  }
  return value;
}

export function parseReportReason(value: unknown): string {
  if (typeof value !== "string" || !validReasons.has(value)) {
    throw new HttpsError("invalid-argument", "Choose a report reason.");
  }
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function ensureAdmin() {
  if (getApps().length === 0) initializeApp();
  return getFirestore();
}

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to use groups.");
  return uid;
}

function validateMembershipProfile(
  profile: FirebaseFirestore.DocumentData | undefined,
  ageConfirmed: unknown,
  acceptedRulesVersion: unknown,
) {
  if (!profile) throw new HttpsError("failed-precondition", "Complete onboarding first.");
  if (ageConfirmed !== true || acceptedRulesVersion !== communityRulesVersion) {
    throw new HttpsError("failed-precondition", "Confirm the community rules and age requirement first.");
  }
}

export const joinLearningGroup = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    if (!isRecord(request.data) ||
        Object.keys(request.data).sort().join(",") !== "acceptRulesVersion,confirmAge16,groupId") {
      throw new HttpsError("invalid-argument", "Review the group rules before joining.");
    }
    const groupId = parseGroupId(request.data.groupId);
    const db = ensureAdmin();
    const userRef = db.collection("users").doc(uid);
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = groupRef.collection("members").doc(uid);
    const joined = await db.runTransaction(async (transaction) => {
      const [user, group, member] = await Promise.all([
        transaction.get(userRef),
        transaction.get(groupRef),
        transaction.get(memberRef),
      ]);
      if (!group.exists || group.get("published") !== true || group.get("isPublic") !== true) {
        throw new HttpsError("not-found", "This learning group is unavailable.");
      }
      validateMembershipProfile(user.data(), request.data.confirmAge16, request.data.acceptRulesVersion);
      transaction.set(userRef, {
        communityAge16ConfirmedAt: FieldValue.serverTimestamp(),
        communityRulesVersion,
        joinedCommunityGroupIds: FieldValue.arrayUnion(groupId),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      if (member.exists) return false;
      transaction.set(memberRef, {
        schemaVersion: 1,
        uid,
        role: "member",
        joinedAt: FieldValue.serverTimestamp(),
        lastReadAt: Timestamp.fromMillis(0),
      });
      transaction.update(groupRef, {
        memberCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    return { ok: true, joined };
  },
);

export const leaveLearningGroup = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const groupId = parseGroupId(isRecord(request.data) ? request.data.groupId : undefined);
    if (!isRecord(request.data) || Object.keys(request.data).join(",") !== "groupId") {
      throw new HttpsError("invalid-argument", "A valid group is required.");
    }
    const db = ensureAdmin();
    const userRef = db.collection("users").doc(uid);
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = groupRef.collection("members").doc(uid);
    const left = await db.runTransaction(async (transaction) => {
      const [group, member] = await Promise.all([
        transaction.get(groupRef),
        transaction.get(memberRef),
      ]);
      if (!group.exists) throw new HttpsError("not-found", "This group is unavailable.");
      if (!member.exists) return false;
      transaction.delete(memberRef);
      transaction.update(groupRef, {
        memberCount: Math.max(0, Number(group.get("memberCount") ?? 0) - 1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        joinedCommunityGroupIds: FieldValue.arrayRemove(groupId),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return true;
    });
    return { ok: true, left };
  },
);

export const sendGroupMessage = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const input = parseCommunityMessage(request.data);
    const db = ensureAdmin();
    const userRef = db.collection("users").doc(uid);
    const groupRef = db.collection("groups").doc(input.groupId);
    const memberRef = groupRef.collection("members").doc(uid);
    const rateRef = userRef.collection("communityRateLimits").doc("messages");
    const receiptRef = userRef.collection("communityRequests").doc(input.clientRequestId);
    const messageRef = groupRef.collection("messages").doc(input.clientRequestId);
    const now = Date.now();
    const result = await db.runTransaction(async (transaction) => {
      const [user, group, member, rate, receipt] = await Promise.all([
        transaction.get(userRef),
        transaction.get(groupRef),
        transaction.get(memberRef),
        transaction.get(rateRef),
        transaction.get(receiptRef),
      ]);
      if (!group.exists || group.get("published") !== true || !member.exists) {
        throw new HttpsError("permission-denied", "Join this group before posting.");
      }
      if (!user.exists || user.get("communityRulesVersion") !== communityRulesVersion || !user.get("communityAge16ConfirmedAt")) {
        throw new HttpsError("failed-precondition", "Review the community rules before posting.");
      }
      if (receipt.exists) {
        if (receipt.get("bodyHash") !== hash(input.body)) {
          throw new HttpsError("already-exists", "This message ID was already used.");
        }
        return { messageId: receipt.get("messageId") as string, duplicate: true };
      }
      const previous = Array.isArray(rate.get("sentAtMs"))
        ? (rate.get("sentAtMs") as unknown[]).filter(
          (entry): entry is number => typeof entry === "number" && entry > now - 10_000,
        )
        : [];
      if (previous.length >= 10) {
        throw new HttpsError("resource-exhausted", "Take a short pause before sending another message.");
      }
      const displayName = typeof user.get("displayName") === "string" && user.get("displayName").trim()
        ? user.get("displayName").trim().slice(0, 30)
        : "Lernende Person";
      const message = {
        schemaVersion: 1,
        uid,
        displayName,
        body: input.body,
        status: "visible",
        reportCount: 0,
        createdAt: FieldValue.serverTimestamp(),
      };
      transaction.create(messageRef, message);
      transaction.create(receiptRef, {
        schemaVersion: 1,
        groupId: input.groupId,
        messageId: messageRef.id,
        bodyHash: hash(input.body),
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(rateRef, { sentAtMs: [...previous, now] }, { merge: true });
      transaction.update(groupRef, {
        lastMessage: { body: input.body.slice(0, 120), uid, displayName },
        lastMessageAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { messageId: messageRef.id, duplicate: false };
    });
    return { ok: true, ...result };
  },
);

export const reportGroupMessage = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    if (!isRecord(request.data) ||
        Object.keys(request.data).sort().join(",") !== "groupId,messageId,reason") {
      throw new HttpsError("invalid-argument", "Choose what you want to report.");
    }
    const groupId = parseGroupId(request.data.groupId);
    const messageId = parseGroupId(request.data.messageId);
    const reason = parseReportReason(request.data.reason);
    const db = ensureAdmin();
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = groupRef.collection("members").doc(uid);
    const messageRef = groupRef.collection("messages").doc(messageId);
    const reportId = hash(`${groupId}:${messageId}:${uid}`);
    const reportRef = db.collection("reports").doc(reportId);
    const result = await db.runTransaction(async (transaction) => {
      const [member, message, report] = await Promise.all([
        transaction.get(memberRef),
        transaction.get(messageRef),
        transaction.get(reportRef),
      ]);
      if (!member.exists || !message.exists) {
        throw new HttpsError("not-found", "This group message is unavailable.");
      }
      if (message.get("uid") === uid) {
        throw new HttpsError("failed-precondition", "You cannot report your own message.");
      }
      if (report.exists) return { reported: false, hidden: message.get("status") === "hidden" };
      const reportCount = Number(message.get("reportCount") ?? 0) + 1;
      const hidden = reportCount >= 3;
      transaction.create(reportRef, {
        schemaVersion: 1,
        type: "groupMessage",
        groupId,
        messageId,
        reporterUid: uid,
        reason,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(messageRef, {
        reportCount,
        ...(hidden ? { status: "hidden", hiddenAt: FieldValue.serverTimestamp() } : {}),
      });
      return { reported: true, hidden };
    });
    return { ok: true, ...result };
  },
);

export const blockCommunityMember = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    if (!isRecord(request.data) || Object.keys(request.data).join(",") !== "otherUid") {
      throw new HttpsError("invalid-argument", "Choose a learner to block.");
    }
    const otherUid = request.data.otherUid;
    if (typeof otherUid !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(otherUid) || otherUid === uid) {
      throw new HttpsError("invalid-argument", "That block request is invalid.");
    }
    const db = ensureAdmin();
    await db.collection("users").doc(uid).collection("blocks").doc(otherUid).set({
      schemaVersion: 1,
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
  },
);

function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}
