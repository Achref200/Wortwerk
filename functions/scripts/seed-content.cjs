const { readFile } = require("node:fs/promises");
const path = require("node:path");
const { applicationDefault, initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

function argument(name) {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

async function main() {
  const projectId = argument("--project");
  if (!projectId) {
    throw new Error("Pass an explicit target with --project <firebase-project-id>.");
  }
  const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (!usingEmulator && argument("--confirm-project") !== projectId) {
    throw new Error(
      "Remote seeding requires --confirm-project with the same project ID.",
    );
  }

  const content = JSON.parse(
    await readFile(path.resolve(__dirname, "../../content/a1_greetings.json"), "utf8"),
  );
  const app = initializeApp({
    projectId,
    ...(usingEmulator ? {} : { credential: applicationDefault() }),
  });
  const db = getFirestore(app);
  const level = db.collection("levels").doc(content.levelId);
  const unit = level.collection("units").doc(content.unitId);
  const lesson = unit.collection("lessons").doc(content.lessonId);
  const contentMeta = db.collection("contentMeta").doc("current");
  const batch = db.batch();

  batch.set(contentMeta, {
    schemaVersion: 1,
    contentVersion: content.schemaVersion,
    publishedLessons: [content.lessonId],
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(level, {
    schemaVersion: 1,
    levelId: content.levelId,
    title: content.levelId,
    order: 1,
    published: true,
    coreVocabularyCardIds: [
      "greeting_hello",
      "greeting_good_morning",
      "greeting_good_day",
      "greeting_good_evening",
      "greeting_bye",
      "greeting_goodbye_formal",
      "greeting_thanks",
      "greeting_please",
      "greeting_name",
      "greeting_introduce",
    ],
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(unit, {
    schemaVersion: 1,
    levelId: content.levelId,
    unitId: content.unitId,
    title: content.title,
    topic: content.title,
    order: 1,
    lessonIds: [content.lessonId],
    published: true,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  batch.set(lesson, {
    ...content,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log(`Published ${content.levelId}/${content.unitId}/${content.lessonId} to ${projectId}.`);
  await app.delete();
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
