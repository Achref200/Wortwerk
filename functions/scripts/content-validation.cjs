const SAFE_ID = /^[a-z0-9][a-z0-9_-]{1,79}$/;
const LEVELS = new Set(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);

function validateCurriculum(manifest, lessons) {
  const issues = [];
  if (!manifest || manifest.schemaVersion !== 1 || !Number.isInteger(manifest.contentVersion) || manifest.contentVersion < 1 || !Array.isArray(manifest.sources)) {
    return { valid: false, issues: ['manifest: expected schemaVersion 1, positive contentVersion and a sources list'], lessonCount: 0, exerciseCount: 0 };
  }
  if (new Set(manifest.sources).size !== manifest.sources.length) issues.push('manifest: duplicate source filename');
  if (manifest.sources.some((source) => typeof source !== 'string' || !/^[a-z0-9_-]+\.json$/.test(source))) issues.push('manifest: source names must be safe JSON filenames');
  const expected = new Set(manifest.sources);
  const actual = new Set(Object.keys(lessons));
  for (const source of expected) if (!actual.has(source)) issues.push(`manifest: missing source ${source}`);
  for (const source of actual) if (!expected.has(source)) issues.push(`manifest: unlisted source ${source}`);
  const ids = new Set();
  const globalExerciseIds = new Set();
  let exerciseCount = 0;
  const published = new Set(Object.values(lessons).filter((lesson) => lesson?.published === true).map((lesson) => lesson.lessonId));
  for (const [source, lesson] of Object.entries(lessons)) {
    const prefix = `${source}:`;
    if (!lesson || typeof lesson !== 'object' || Array.isArray(lesson)) { issues.push(`${prefix} expected an object`); continue; }
    if (lesson.schemaVersion !== 1 || lesson.contentVersion !== manifest.contentVersion || !LEVELS.has(lesson.levelId) || !SAFE_ID.test(lesson.unitId ?? '') || !SAFE_ID.test(lesson.lessonId ?? '')) issues.push(`${prefix} has an invalid schema/content version, CEFR level or stable identifier`);
    if (typeof lesson.title !== 'string' || lesson.title.trim().length < 3 || lesson.title.length > 120) issues.push(`${prefix} needs a concise title`);
    if (typeof lesson.description !== 'string' || !lesson.description.trim() || !Number.isInteger(lesson.estimatedMinutes) || lesson.estimatedMinutes < 1 || !Number.isInteger(lesson.xpReward) || lesson.xpReward < 0 || !Array.isArray(lesson.learningObjectives) || lesson.learningObjectives.length === 0 || !Array.isArray(lesson.vocabularyTags) || !Array.isArray(lesson.grammarTags) || !Array.isArray(lesson.prerequisites)) issues.push(`${prefix} is missing learning objectives or lesson metadata`);
    if (!Number.isInteger(lesson.order) || lesson.order < 1) issues.push(`${prefix} order must be a positive integer`);
    if (typeof lesson.published !== 'boolean') issues.push(`${prefix} must declare published true or false`);
    if (!Array.isArray(lesson.questions) || lesson.questions.length < 5 || lesson.questions.length > 100) { issues.push(`${prefix} must contain 5 to 100 exercises`); continue; }
    if (ids.has(lesson.lessonId)) issues.push(`${prefix} duplicates lesson ID ${lesson.lessonId}`);
    ids.add(lesson.lessonId);
    if (lesson.prerequisites !== undefined && (!Array.isArray(lesson.prerequisites) || lesson.prerequisites.some((id) => typeof id !== 'string' || id === lesson.lessonId || !published.has(id)))) issues.push(`${prefix} references a missing, self or unpublished prerequisite`);
    const exerciseIds = new Set();
    for (const [index, exercise] of lesson.questions.entries()) {
      exerciseCount++;
      const itemPrefix = `${prefix} exercise ${index + 1}:`;
      if (!exercise || typeof exercise !== 'object' || !SAFE_ID.test(exercise.id ?? '') || exerciseIds.has(exercise.id)) { issues.push(`${itemPrefix} invalid or duplicate stable ID`); continue; }
      exerciseIds.add(exercise.id);
      if (globalExerciseIds.has(exercise.id)) issues.push(`${itemPrefix} duplicates exercise ID ${exercise.id} in another lesson`);
      globalExerciseIds.add(exercise.id);
      if (exercise.type !== 'multiple_choice' || typeof exercise.instruction !== 'string' || !exercise.instruction.trim() || exercise.difficulty !== lesson.levelId || !Array.isArray(exercise.vocabularyTags) || !Array.isArray(exercise.grammarTags)) issues.push(`${itemPrefix} needs a supported type, instruction, CEFR difficulty and learning tags`);
      if (typeof exercise.prompt !== 'string' || !exercise.prompt.trim() || exercise.prompt.length > 500) issues.push(`${itemPrefix} needs a bounded prompt`);
      if (typeof exercise.explanation !== 'string' || !exercise.explanation.trim() || exercise.explanation.length > 800) issues.push(`${itemPrefix} needs a useful explanation`);
      if (!Array.isArray(exercise.choices) || exercise.choices.length < 2 || exercise.choices.length > 8) { issues.push(`${itemPrefix} needs 2 to 8 answer choices`); continue; }
      const choiceIds = exercise.choices.map((choice) => choice?.id);
      if (choiceIds.some((id) => typeof id !== 'string' || !SAFE_ID.test(id)) || new Set(choiceIds).size !== choiceIds.length || !choiceIds.includes(exercise.correctChoiceId)) issues.push(`${itemPrefix} has duplicate/invalid choices or an answer outside its choices`);
      if (exercise.choices.some((choice) => typeof choice?.text !== 'string' || !choice.text.trim() || choice.text.length > 300)) issues.push(`${itemPrefix} has empty or oversized choice text`);
    }
  }
  const publishedLessons = new Map(Object.values(lessons).filter((lesson) => lesson?.published === true).map((lesson) => [lesson.lessonId, lesson]));
  const visited = new Set();
  const active = new Set();
  const visit = (lessonId) => {
    if (active.has(lessonId)) { issues.push(`curriculum: prerequisite cycle contains ${lessonId}`); return; }
    if (visited.has(lessonId)) return;
    active.add(lessonId);
    for (const prerequisite of publishedLessons.get(lessonId)?.prerequisites ?? []) if (publishedLessons.has(prerequisite)) visit(prerequisite);
    active.delete(lessonId);
    visited.add(lessonId);
  };
  for (const lessonId of publishedLessons.keys()) visit(lessonId);
  return { valid: issues.length === 0, issues, lessonCount: ids.size, exerciseCount };
}

module.exports = { validateCurriculum };
