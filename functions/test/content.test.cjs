const test = require('node:test');
const assert = require('node:assert/strict');
const { readCurriculum } = require('../scripts/seed-content.cjs');
const { validateCurriculum } = require('../scripts/content-validation.cjs');

test('the versioned curriculum sources validate with stable unique exercises', async () => {
  const { validation, manifest } = await readCurriculum();
  assert.equal(validation.valid, true);
  assert.equal(validation.lessonCount, 1);
  assert.equal(validation.exerciseCount, 10);
  assert.equal(manifest.contentVersion, 1);
});

test('curriculum validation rejects an expected answer outside the choices', async () => {
  const { manifest, lessons } = await readCurriculum();
  const corrupted = structuredClone(lessons);
  corrupted['a1_greetings.json'].questions[0].correctChoiceId = 'missing_answer';
  const result = validateCurriculum(manifest, corrupted);
  assert.equal(result.valid, false);
  assert.ok(result.issues.some((issue) => issue.includes('answer outside its choices')));
});

test('curriculum validation detects repeated lesson and exercise IDs', async () => {
  const { manifest, lessons } = await readCurriculum();
  const extra = structuredClone(lessons['a1_greetings.json']);
  extra.unitId = 'a1_first_words';
  extra.lessonId = 'a1_greetings';
  extra.questions[1].id = extra.questions[0].id;
  const extendedManifest = { ...manifest, sources: [...manifest.sources, 'duplicate.json'] };
  const result = validateCurriculum(extendedManifest, { ...lessons, 'duplicate.json': extra });
  assert.equal(result.valid, false);
  assert.ok(result.issues.some((issue) => issue.includes('duplicates lesson ID')));
  assert.ok(result.issues.some((issue) => issue.includes('invalid or duplicate stable ID')));
});

test('curriculum validation rejects drafts used as prerequisites', async () => {
  const { manifest, lessons } = await readCurriculum();
  const draft = structuredClone(lessons['a1_greetings.json']);
  draft.published = false;
  const next = structuredClone(lessons['a1_greetings.json']);
  next.lessonId = 'a1_first_words';
  next.prerequisites = ['a1_greetings'];
  const nextManifest = { ...manifest, sources: ['draft.json', 'next.json'] };
  const result = validateCurriculum(nextManifest, { 'draft.json': draft, 'next.json': next });
  assert.equal(result.valid, false);
  assert.ok(result.issues.some((issue) => issue.includes('unpublished prerequisite')));
});

test('curriculum validation rejects prerequisite cycles and repeated exercise IDs across lessons', async () => {
  const { manifest, lessons } = await readCurriculum();
  const first = structuredClone(lessons['a1_greetings.json']);
  const second = structuredClone(first);
  second.lessonId = 'a1_first_words';
  second.order = 2;
  first.prerequisites = ['a1_first_words'];
  second.prerequisites = ['a1_greetings'];
  second.questions[0].id = first.questions[0].id;
  const nextManifest = { ...manifest, sources: ['first.json', 'second.json'] };
  const result = validateCurriculum(nextManifest, { 'first.json': first, 'second.json': second });
  assert.equal(result.valid, false);
  assert.ok(result.issues.some((issue) => issue.includes('prerequisite cycle')));
  assert.ok(result.issues.some((issue) => issue.includes('duplicates exercise ID')));
});
