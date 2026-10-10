import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  evaluatePlacement as scorePlacement,
  PlacementValidationError,
} from "./placement.js";

export { completeLesson } from "./lesson.js";
export { completeFlashcardReview } from "./review.js";
export { fritzChat } from "./fritz.js";
export { getDailyMissions } from "./missions.js";
export {
  blockCommunityMember,
  joinLearningGroup,
  leaveLearningGroup,
  reportGroupMessage,
  sendGroupMessage,
} from "./community.js";
export {
  deliverNotificationPush,
  disablePushNotifications,
  markNotificationRead,
  registerNotificationDevice,
} from "./notifications.js";

const adminApp = getApps()[0] ?? initializeApp();
const firestore = getFirestore(adminApp);

export const health = onCall({ region: "europe-west1" }, () => ({
  ok: true,
}));

export const evaluatePlacement = onCall(
  { region: "europe-west1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before evaluating placement.",
      );
    }
    try {
      const profile = firestore.doc(`users/${request.auth.uid}`);
      const profileSnapshot = await profile.get();
      if (
        !profileSnapshot.exists ||
        profileSnapshot.get("onboardingCompleted") === true
      ) {
        throw new HttpsError(
          "failed-precondition",
          "An incomplete learner profile is required for placement.",
        );
      }
      const result = scorePlacement(request.data);
      await profile.set(
        {
          verifiedPlacement: {
            ...result,
            evaluatedAt: FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      return result;
    } catch (error) {
      if (error instanceof PlacementValidationError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw error;
    }
  },
);
