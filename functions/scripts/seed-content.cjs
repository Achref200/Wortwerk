const { readFile } = require('node:fs/promises');
const path = require('node:path');
const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { validateCurriculum } = require('./content-validation.cjs');

function argument(name) {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

async function readCurriculum() {
  const directory = path.resolve(__dirname, '../../content');
  const manifest = JSON.parse(await readFile(path.join(directory, 'manifest.json'), 'utf8'));
  const lessons = {};
  for (const source of manifest.sources ?? []) {
    lessons[source] = JSON.parse(await readFile(path.join(directory, source), 'utf8'));
  }
  const validation = validateCurriculum(manifest, lessons);
  if (!validation.valid) throw new Error(`Curriculum validation failed:\n- ${validation.issues.join('\n- ')}`);
  return { directory, manifest, lessons, validation };
}

function publicationDocuments(db, manifest, sourceLessons) {
  const published = Object.values(sourceLessons).filter((lesson) => lesson.published === true);
  const documents = [];
  const levels = new Map();
  const units = new Map();
  for (const lesson of published) {
    const level = levels.get(lesson.levelId) ?? { levelId: lesson.levelId, title: lesson.levelId, order: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].indexOf(lesson.levelId) + 1, published: true };
    levels.set(lesson.levelId, level);
    const unitKey = `${lesson.levelId}/${lesson.unitId}`;
    const unit = units.get(unitKey) ?? { levelId: lesson.levelId, unitId: lesson.unitId, title: lesson.unitTitle ?? lesson.title, topic: lesson.unitTitle ?? lesson.title, order: lesson.unitOrder ?? 1, lessonIds: [], published: true };
    unit.lessonIds.push(lesson.lessonId);
    units.set(unitKey, unit);
  }
  for (const [levelId, value] of levels) {
    const coreVocabularyCardIds = manifest.coreVocabularyCardIds?.[levelId];
    documents.push({ ref: db.collection('levels').doc(levelId), data: { ...value, schemaVersion: 1, ...(Array.isArray(coreVocabularyCardIds) ? { coreVocabularyCardIds } : {}) }, kind: 'level' });
  }
  for (const unit of units.values()) {
    const { levelId, unitId, ...data } = unit;
    documents.push({ ref: db.collection('levels').doc(levelId).collection('units').doc(unitId), data: { ...data, schemaVersion: 1 }, kind: 'unit' });
  }
  for (const lesson of Object.values(sourceLessons)) {
    documents.push({ ref: db.collection('levels').doc(lesson.levelId).collection('units').doc(lesson.unitId).collection('lessons').doc(lesson.lessonId), data: lesson, kind: 'lesson' });
  }
  documents.push({ ref: db.collection('contentMeta').doc('current'), data: { schemaVersion: 1, contentVersion: manifest.contentVersion, publishedLessons: published.map((lesson) => lesson.lessonId).sort() }, kind: 'manifest' });
  return documents;
}

function sameDocumentPayload(existing, expected) {
  const compare = (left, right) => {
    if (Array.isArray(right)) return Array.isArray(left) && left.length === right.length && left.every((value, index) => compare(value, right[index]));
    if (right && typeof right === 'object') {
      return left && typeof left === 'object' && Object.keys(right).every((key) => compare(left[key], right[key]));
    }
    return left === right;
  };
  return Object.keys(expected).every((key) => key === 'updatedAt' || compare(existing[key], expected[key]));
}

async function main() {
  const { manifest, lessons, validation } = await readCurriculum();
  const summary = `${validation.lessonCount} lessons, ${validation.exerciseCount} exercises, content v${manifest.contentVersion}`;
  if (process.argv.includes('--dry-run')) {
    console.log(`Validated ${summary}. Dry run: no Firebase connection or writes.`);
    return;
  }
  const projectId = argument('--project');
  if (!projectId) throw new Error('Pass an explicit target with --project <firebase-project-id>.');
  const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (!usingEmulator && argument('--confirm-project') !== projectId) throw new Error('Remote seeding requires --confirm-project with the same project ID.');
  const app = initializeApp({ projectId, ...(usingEmulator ? {} : { credential: applicationDefault() }) });
  try {
    const db = getFirestore(app);
    const documents = publicationDocuments(db, manifest, lessons);
    const plan = { create: [], update: [], skip: [] };
    for (let offset = 0; offset < documents.length; offset += 450) {
      const chunk = documents.slice(offset, offset + 450);
      const snapshots = await Promise.all(chunk.map((document) => document.ref.get()));
      chunk.forEach((document, index) => {
        const snapshot = snapshots[index];
        if (!snapshot.exists) plan.create.push(document);
        else if (sameDocumentPayload(snapshot.data(), document.data)) plan.skip.push(document);
        else plan.update.push(document);
      });
    }
    const writes = [...plan.create, ...plan.update];
    let created = 0; let updated = 0; let failed = 0;
    for (let offset = 0; offset < writes.length; offset += 450) {
      const chunk = writes.slice(offset, offset + 450);
      const batch = db.batch();
      for (const document of chunk) {
        batch.set(document.ref, { ...document.data, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      }
      try { await batch.commit(); }
      catch (error) { failed += chunk.length; console.error(`Seed failed for ${projectId}: created ${created}, updated ${updated}, skipped ${plan.skip.length}, failed ${failed}.`); throw error; }
      const createdInChunk = chunk.filter((document) => plan.create.includes(document)).length;
      created += createdInChunk; updated += chunk.length - createdInChunk;
    }
    console.log(`Published ${summary} to ${usingEmulator ? 'emulator project ' : 'Firebase project '}${projectId}; created ${created}, updated ${updated}, skipped ${plan.skip.length}, failed ${failed}. Learner progress was not modified.`);
  } finally { await app.delete(); }
}

if (require.main === module) main().catch((error) => { console.error(error.message); process.exitCode = 1; });
module.exports = { readCurriculum, publicationDocuments, sameDocumentPayload };
