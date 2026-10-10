const { applicationDefault, initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");

function argument(name) {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

const seedGroups = [
  {
    id: "a1_alltag",
    name: "A1 · Alltag",
    topic: "Begrüßungen und erste Gespräche",
    levelTag: "A1",
    levelOrder: 1,
  },
  {
    id: "a2_reisen",
    name: "A2 · Unterwegs",
    topic: "Reisen, Wege und kleine Abenteuer",
    levelTag: "A2",
    levelOrder: 2,
  },
  {
    id: "b1_gespraeche",
    name: "B1 · Gespräche",
    topic: "Meinungen teilen und im Alltag sicher sprechen",
    levelTag: "B1",
    levelOrder: 3,
  },
];

async function main() {
  const projectId = argument("--project");
  if (!projectId) {
    throw new Error("Pass an explicit target with --project <firebase-project-id>.");
  }
  const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (!usingEmulator && argument("--confirm-project") !== projectId) {
    throw new Error("Remote seeding requires --confirm-project with the same project ID.");
  }
  const app = initializeApp({
    projectId,
    ...(usingEmulator ? {} : { credential: applicationDefault() }),
  });
  const db = getFirestore(app);
  const batch = db.batch();
  for (const group of seedGroups) {
    batch.set(db.collection("groups").doc(group.id), {
      schemaVersion: 1,
      ...group,
      isPublic: true,
      published: true,
      languageRule: "German practice; support each other kindly.",
      rulesVersion: 1,
      memberCount: 0,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await batch.commit();
  console.log(`Published ${seedGroups.length} learning groups to ${projectId}.`);
  await app.delete();
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
