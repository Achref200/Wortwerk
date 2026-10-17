import {
  type User,
  onAuthStateChanged,
  signInAnonymously,
} from 'firebase/auth';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  type DocumentData,
  type Unsubscribe,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { auth, db, functions } from './firebase';
import type { LevelId } from './theme';

export type MissionKind = 'lesson_complete' | 'review_session' | 'fritz_conversation';
export type DailyMission = {
  kind: MissionKind;
  title: string;
  progress: number;
  target: number;
  xp: number;
  completed: boolean;
};
export type LearnerProfile = {
  displayName: string;
  level: LevelId;
  unitId: string;
  goals: string[];
  timezone: string;
  onboardingCompleted: boolean;
  xpTotal: number;
  dailyMinutes: number;
  learningPreferences?: { style: 'structured' | 'conversation' | 'visual' | 'variety'; feedback: 'gentle' | 'direct' };
  learningPlan?: { targetDaysPerWeek: 3 | 5 | 7; dailyMinutes: number; levelSource: 'quiz' | 'self_assessment'; confidence: number };
  streak: { current: number; longest: number; shields: number; lastActiveDayId?: string | null };
  restWeekday: number;
  uiLang?: string;
  reminderTime?: string;
  adaptiveLevelEnabled?: boolean;
  speechOutputEnabled?: boolean;
  notificationPreferences?: { learningReminder: boolean; groupMessages: boolean; weeklySummary: boolean };
  pushEnabled?: boolean;
};
export type LessonQuestion = {
  id: string;
  type?: 'multiple_choice';
  instruction?: string;
  prompt: string;
  explanation: string;
  correctChoiceId: string;
  choices: { id: string; text: string }[];
};
export type LearningLesson = {
  levelId: string;
  unitId: string;
  lessonId: string;
  title: string;
  questions: LessonQuestion[];
};
export type PathLesson = { id: string; title: string; completed: boolean; accuracy: number; order: number; questionCount: number };
export type PathUnit = { id: string; title: string; order: number; available: boolean; lessons: PathLesson[] };
export type PathLevel = { id: LevelId; title: string; order: number; units: PathUnit[] };
export type LearningPath = { levels: PathLevel[]; currentLevel: string; currentUnit: string; progressByLevel: Record<string, { coreVocabularyCount: number; retainedWords: number; fritzConversations: number; reviewRoundsPassed: number }> };
export type HomeSnapshot = {
  profile: LearnerProfile;
  activeDayIds: Set<string>;
  lessonsCompletedToday: number;
  flashcardsReviewedToday: number;
  xpEarnedToday: number;
};

const missionTitles: Record<string, string> = {
  complete_a_lesson: 'Eine Lektion abschließen',
  review_ten_words: '10 Wörter wiederholen',
  talk_with_fritz: 'Mit Fritz sprechen',
};

export function watchAuth(callback: (user: User | null) => void): Unsubscribe {
  return onAuthStateChanged(auth, callback);
}

export async function ensureGuest(): Promise<User> {
  if (auth.currentUser) return auth.currentUser;
  return (await signInAnonymously(auth)).user;
}

export async function ensureProfile(user: User): Promise<LearnerProfile> {
  const reference = doc(db, 'users', user.uid);
  const snapshot = await getDoc(reference);
  if (!snapshot.exists()) {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
    await setDoc(reference, {
      schemaVersion: 1,
      displayName: 'Deutschlernende Person',
      uiLang: 'de',
      explainLang: 'de',
      level: 'A1',
      unitId: 'a1_greetings',
      goals: ['Alltag'],
      dailyMinutes: 10,
      timezone,
      onboardingCompleted: false,
      xpTotal: 0,
      xpWeek: 0,
      streak: { current: 0, longest: 0, shields: 2, lastActiveDayId: null },
      restWeekday: 0,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    return {
      displayName: 'Deutschlernende Person', level: 'A1', unitId: 'a1_greetings',
      goals: ['Alltag'], timezone, onboardingCompleted: false, xpTotal: 0,
      dailyMinutes: 10, streak: { current: 0, longest: 0, shields: 2 }, restWeekday: 0,
    };
  }
  return parseProfile(snapshot.data());
}

export async function finishOnboarding(input: {
  uid: string; goals: string[]; dailyMinutes: number; targetDaysPerWeek: 3 | 5 | 7;
  level: 'A1' | 'A2' | 'B1'; source: 'quiz' | 'self_assessment'; confidence: number;
  style: 'structured' | 'conversation' | 'visual' | 'variety'; feedback: 'gentle' | 'direct';
}): Promise<void> {
  const unitId = { A1: 'a1_greetings', A2: 'a2_travel', B1: 'b1_conversation' }[input.level];
  const selectedLevel = ['A1', 'A2', 'B1'].indexOf(input.level);
  await updateDoc(doc(db, 'users', input.uid), {
    level: input.level,
    unitId,
    goals: input.goals,
    dailyMinutes: input.dailyMinutes,
    placement: { done: input.source === 'quiz', level: input.level, confidence: input.confidence, source: input.source },
    learningPreferences: { style: input.style, feedback: input.feedback },
    learningPlan: { targetDaysPerWeek: input.targetDaysPerWeek, dailyMinutes: input.dailyMinutes, levelSource: input.source, confidence: input.confidence },
    onboardingCompleted: true,
    onboardingDraft: {
      step: 4,
      goals: input.goals,
      dailyMinutes: input.dailyMinutes,
      targetDaysPerWeek: input.targetDaysPerWeek,
      learningStyle: input.style,
      feedbackStyle: input.feedback,
      selectedLevel,
      testStartingLevel: selectedLevel,
      placementAnswers: [],
    },
    updatedAt: serverTimestamp(),
  });
}

export function listenHome(
  uid: string,
  next: (value: HomeSnapshot) => void,
  error: (reason: Error) => void,
): Unsubscribe {
  const userRef = doc(db, 'users', uid);
  let profile: LearnerProfile | undefined;
  let days: DocumentData[] | undefined;
  let failed = false;
  let daysStop: Unsubscribe | undefined;
  let subscribedTimezone: string | undefined;
  const emit = () => {
    if (!profile || !days || failed) return;
    const today = dayIdInZone(new Date(), profile.timezone);
    const activity = days.find((day) => day.date === today);
    next({
      profile,
      activeDayIds: new Set(days.filter(isActiveDay).map((day) => String(day.date))),
      lessonsCompletedToday: safeNumber(activity?.lessonsCompleted),
      flashcardsReviewedToday: safeNumber(activity?.flashcardsReviewed),
      xpEarnedToday: safeNumber(activity?.xpTotal),
    });
  };
  const profileStop = onSnapshot(userRef, (snapshot) => {
    if (!snapshot.exists()) { failed = true; error(new Error('profile-missing')); return; }
    try {
      profile = parseProfile(snapshot.data());
      if (profile.timezone !== subscribedTimezone) {
        subscribedTimezone = profile.timezone;
        days = undefined;
        daysStop?.();
        const [monday, sunday] = currentWeekBounds(profile.timezone);
        daysStop = onSnapshot(query(
          collection(userRef, 'days'),
          where('date', '>=', monday),
          where('date', '<=', sunday),
          orderBy('date', 'asc'),
        ), (activity) => { days = activity.docs.map((item) => item.data()); emit(); }, (reason) => { failed = true; error(reason); });
      }
      emit();
    }
    catch (reason) { failed = true; error(reason instanceof Error ? reason : new Error('profile-invalid')); }
  }, (reason) => { failed = true; error(reason); });
  return () => { profileStop(); daysStop?.(); };
}

export function watchMissions(
  uid: string,
  next: (value: { date: string; focusGoal: string; earnedXp: number; tasks: DailyMission[] }) => void,
  error: (reason: Error) => void,
): Unsubscribe {
  let cancelled = false;
  let stop: Unsubscribe | undefined;
  httpsCallable(functions, 'getDailyMissions')().then((result) => {
    const payload = result.data as { dayId?: unknown };
    if (typeof payload?.dayId !== 'string') throw new Error('missions-invalid');
    if (cancelled) return;
    stop = onSnapshot(doc(db, 'users', uid, 'missions', payload.dayId), (snapshot) => {
      try {
        const value = snapshot.data();
        if (!snapshot.exists() || !value || typeof value.tasks !== 'object') {
          error(new Error('missions-empty')); return;
        }
        const rawTasks = value.tasks as Record<string, Record<string, unknown>>;
        const kinds: MissionKind[] = ['lesson_complete', 'review_session', 'fritz_conversation'];
        const tasks = kinds.map((kind) => {
          const row = rawTasks[kind];
          const titleKey = String(row?.titleKey ?? '');
          if (!row || !missionTitles[titleKey]) throw new Error('missions-invalid');
          return {
            kind, title: missionTitles[titleKey],
            progress: safeNumber(row.progress), target: safeNumber(row.target),
            xp: safeNumber(row.xp), completed: row.completed === true,
          };
        });
        next({ date: payload.dayId as string, focusGoal: String(value.focusGoal ?? 'Alltag'), earnedXp: safeNumber(value.earnedXp), tasks });
      } catch { error(new Error('missions-invalid')); }
    }, error);
  }).catch((reason: unknown) => {
    if (!cancelled) error(reason instanceof Error ? reason : new Error('missions-unavailable'));
  });
  return () => { cancelled = true; stop?.(); };
}

export async function loadLearningPath(uid: string): Promise<LearningPath> {
  const userSnapshot = await getDoc(doc(db, 'users', uid));
  if (!userSnapshot.exists()) throw new Error('profile-missing');
  const profile = userSnapshot.data();
  const [levelSnapshot, progressSnapshot, levelProgressSnapshot, unlockSnapshot] = await Promise.all([
    getDocs(query(collection(db, 'levels'), where('published', '==', true))),
    getDocs(collection(db, 'users', uid, 'progress')),
    getDocs(collection(db, 'users', uid, 'levelProgress')),
    getDocs(collection(db, 'users', uid, 'unlocks')),
  ]);
  const progress = new Map(progressSnapshot.docs.map((item) => [item.id, item.data()]));
  const progressByLevel = Object.fromEntries(levelProgressSnapshot.docs.map((item) => [item.id, {
    coreVocabularyCount: safeNumber(item.data().coreVocabularyCount),
    retainedWords: safeNumber(item.data().retainedWords),
    fritzConversations: safeNumber(item.data().fritzConversations),
    reviewRoundsPassed: safeNumber(item.data().reviewRoundsPassed),
  }]));
  const unlocked = new Set(unlockSnapshot.docs.map((item) => item.id));
  const levels: PathLevel[] = [];
  for (const levelDoc of levelSnapshot.docs) {
    const levelData = levelDoc.data();
    if (!isLevel(levelData.levelId) || levelData.levelId !== levelDoc.id) continue;
    const unitDocs = await getDocs(query(collection(db, 'levels', levelDoc.id, 'units'), where('published', '==', true)));
    const units: PathUnit[] = [];
    for (const unitDoc of unitDocs.docs) {
      const unitData = unitDoc.data();
      const lessonDocs = await getDocs(query(collection(db, 'levels', levelDoc.id, 'units', unitDoc.id, 'lessons'), where('published', '==', true)));
      units.push({
        id: unitDoc.id,
        title: typeof unitData.title === 'string' ? unitData.title : unitDoc.id,
        order: safeNumber(unitData.order),
        available: false,
        lessons: lessonDocs.docs.map((item) => {
          const data = item.data(); const saved = progress.get(item.id);
          return { id: item.id, title: String(data.title ?? item.id), order: safeNumber(data.order), completed: saved?.completed === true, accuracy: typeof saved?.accuracy === 'number' ? saved.accuracy : 0, questionCount: Array.isArray(data.questions) ? data.questions.length : 0 };
        }).sort((a, b) => a.order - b.order),
      });
    }
    units.sort((a, b) => a.order - b.order);
    const levelRank = rank(levelDoc.id); const activeRank = rank(String(profile.level ?? 'A1'));
    const levelAllowed = levelRank !== 0 && (levelRank <= activeRank || unlocked.has(levelDoc.id));
    for (let i = 0; i < units.length; i++) {
      const previous = units.slice(0, i);
      const previousMeet = previous.length > 0 && previous.every((unit) => unit.lessons.length > 0 && unit.lessons.every((lesson) => lesson.completed) && unit.lessons.reduce((sum, lesson) => sum + lesson.accuracy, 0) / unit.lessons.length >= 0.6);
      units[i].available = levelAllowed && (units[i].order === 1 || (levelDoc.id === profile.level && units[i].id === profile.unitId) || previousMeet);
    }
    levels.push({ id: levelData.levelId, title: String(levelData.title ?? levelData.levelId), order: safeNumber(levelData.order), units });
  }
  levels.sort((a, b) => a.order - b.order);
  return { levels, currentLevel: String(profile.level ?? 'A1'), currentUnit: String(profile.unitId ?? ''), progressByLevel };
}

export async function loadLesson(levelId: string, unitId: string, lessonId: string): Promise<LearningLesson> {
  const reference = doc(db, 'levels', levelId, 'units', unitId, 'lessons', lessonId);
  const snapshot = await getDoc(reference);
  const raw = snapshot.data();
  if (!snapshot.exists() || !raw || raw.published === false || !Array.isArray(raw.questions)) throw new Error('lesson-unavailable');
  const questions = raw.questions.map((value: unknown) => {
    const question = value as Record<string, unknown>;
    if (typeof question.id !== 'string' || typeof question.prompt !== 'string' || typeof question.explanation !== 'string' || typeof question.correctChoiceId !== 'string' || !Array.isArray(question.choices)) throw new Error('lesson-invalid');
    const choices = question.choices.map((choice: unknown) => {
      const row = choice as Record<string, unknown>;
      if (typeof row.id !== 'string' || typeof row.text !== 'string') throw new Error('lesson-invalid');
      return { id: row.id, text: row.text };
    });
    if (choices.length < 2 || !choices.some((choice: { id: string }) => choice.id === question.correctChoiceId)) throw new Error('lesson-invalid');
    return { id: question.id, type: question.type === 'multiple_choice' ? 'multiple_choice' as const : undefined, instruction: typeof question.instruction === 'string' ? question.instruction : undefined, prompt: question.prompt, explanation: question.explanation, correctChoiceId: question.correctChoiceId, choices };
  });
  return { levelId: String(raw.levelId), unitId: String(raw.unitId), lessonId: String(raw.lessonId), title: String(raw.title), questions };
}

export async function completeLesson(input: { lesson: LearningLesson; answers: { questionId: string; choiceId: string }[]; requestId: string }) {
  const complete = httpsCallable(functions, 'completeLesson');
  return (await complete({
    levelId: input.lesson.levelId,
    unitId: input.lesson.unitId,
    lessonId: input.lesson.lessonId,
    answers: input.answers,
    clientRequestId: input.requestId,
  })).data as { accuracy: number; xpAwarded: number; correctCount: number };
}

export const signOutLearner = () => auth.signOut();

export async function saveProfilePreferences(uid: string, values: Record<string, unknown>): Promise<void> {
  const allowed = new Set(['displayName', 'uiLang', 'goals', 'dailyMinutes', 'timezone', 'reminderTime', 'restWeekday', 'adaptiveLevelEnabled', 'speechOutputEnabled', 'notificationPreferences']);
  if (!Object.keys(values).length || Object.keys(values).some((key) => !allowed.has(key))) throw new Error('profile-update-invalid');
  await updateDoc(doc(db, 'users', uid), { ...values, updatedAt: serverTimestamp() });
}

export async function loadNotifications(uid: string) {
  const snapshot = await getDocs(query(collection(db, 'users', uid, 'notifications'), orderBy('createdAt', 'desc')));
  return snapshot.docs.map((item) => {
    const data = item.data();
    return { id: item.id, kind: String(data.kind ?? ''), level: typeof data.level === 'string' ? data.level : undefined, read: data.readAt != null, createdAt: data.createdAt?.toDate?.() instanceof Date ? data.createdAt.toDate() as Date : undefined };
  });
}

export async function markNotificationRead(notificationId: string) {
  return (await httpsCallable(functions, 'markNotificationRead')({ notificationId })).data as { ok: boolean };
}

export async function setPushEnabled(enabled: boolean) {
  if (enabled) throw new Error('push-device-registration-required');
  return (await httpsCallable(functions, 'disablePushNotifications')({ enabled: false })).data as { ok: boolean };
}

export const greetingCards = [
  ['greeting_hello', 'Hallo!', 'Hello!', 'Begrüßung'],
  ['greeting_good_morning', 'Guten Morgen', 'Good morning', 'Begrüßung'],
  ['greeting_good_day', 'Guten Tag', 'Good day', 'Begrüßung'],
  ['greeting_good_evening', 'Guten Abend', 'Good evening', 'Begrüßung'],
  ['greeting_bye', 'Tschüss', 'Bye', 'Abschied'],
  ['greeting_goodbye_formal', 'Auf Wiedersehen', 'Goodbye', 'Abschied · höflich'],
  ['greeting_thanks', 'Danke', 'Thank you', 'Höflich sein'],
  ['greeting_please', 'Bitte', 'Please · You’re welcome', 'Höflich sein'],
  ['greeting_name', 'Wie heißt du?', 'What is your name?', 'Kennenlernen'],
  ['greeting_introduce', 'Ich heiße …', 'My name is …', 'Kennenlernen'],
] as const;

export async function completeReview(answers: { cardId: string; remembered: boolean }[], requestId: string) {
  return (await httpsCallable(functions, 'completeFlashcardReview')({ clientRequestId: requestId, answers })).data as { reviewedCount: number; rememberedCount: number; xpAwarded: number };
}

export function parseProfile(data: DocumentData): LearnerProfile {
  const streak = data.streak && typeof data.streak === 'object' ? data.streak : {};
  return {
    displayName: typeof data.displayName === 'string' ? data.displayName : 'Deutschlernende Person',
    level: isLevel(data.level) ? data.level : 'A1',
    unitId: typeof data.unitId === 'string' ? data.unitId : 'a1_greetings',
    goals: Array.isArray(data.goals) ? data.goals.filter((goal: unknown): goal is string => typeof goal === 'string') : [],
    timezone: typeof data.timezone === 'string' ? data.timezone : 'UTC',
    onboardingCompleted: data.onboardingCompleted === true,
    xpTotal: safeNumber(data.xpTotal),
    dailyMinutes: safeNumber(data.dailyMinutes) || 10,
    learningPreferences: parseLearningPreferences(data.learningPreferences),
    learningPlan: parseLearningPlan(data.learningPlan),
    streak: { current: safeNumber(streak.current), longest: safeNumber(streak.longest), shields: safeNumber(streak.shields), lastActiveDayId: typeof streak.lastActiveDayId === 'string' ? streak.lastActiveDayId : null },
    restWeekday: safeNumber(data.restWeekday),
    uiLang: typeof data.uiLang === 'string' ? data.uiLang : 'de',
    reminderTime: typeof data.reminderTime === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(data.reminderTime) ? data.reminderTime : '18:00',
    adaptiveLevelEnabled: data.adaptiveLevelEnabled !== false,
    speechOutputEnabled: data.speechOutputEnabled !== false,
    notificationPreferences: data.notificationPreferences && typeof data.notificationPreferences === 'object' ? {
      learningReminder: (data.notificationPreferences as Record<string, unknown>).learningReminder !== false,
      groupMessages: (data.notificationPreferences as Record<string, unknown>).groupMessages !== false,
      weeklySummary: (data.notificationPreferences as Record<string, unknown>).weeklySummary === true,
    } : { learningReminder: true, groupMessages: true, weeklySummary: false },
    pushEnabled: data.pushEnabled === true,
  };
}

function safeNumber(value: unknown): number { return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0; }
function parseLearningPreferences(value: unknown): LearnerProfile['learningPreferences'] {
  if (!value || typeof value !== 'object') return undefined;
  const item = value as Record<string, unknown>;
  const style = ['structured', 'conversation', 'visual', 'variety'].includes(String(item.style)) ? item.style as NonNullable<LearnerProfile['learningPreferences']>['style'] : 'variety';
  return { style, feedback: item.feedback === 'direct' ? 'direct' : 'gentle' };
}
function parseLearningPlan(value: unknown): LearnerProfile['learningPlan'] {
  if (!value || typeof value !== 'object') return undefined;
  const item = value as Record<string, unknown>;
  const target = item.targetDaysPerWeek === 3 || item.targetDaysPerWeek === 7 ? item.targetDaysPerWeek : 5;
  return { targetDaysPerWeek: target, dailyMinutes: [5, 10, 15, 20].includes(Number(item.dailyMinutes)) ? Number(item.dailyMinutes) : 10, levelSource: item.levelSource === 'quiz' ? 'quiz' : 'self_assessment', confidence: Math.max(0, Math.min(1, Number(item.confidence) || 0)) };
}
function isLevel(value: unknown): value is LevelId { return value === 'A1' || value === 'A2' || value === 'B1' || value === 'B2' || value === 'C1' || value === 'C2'; }
function rank(value: string): number { return ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].indexOf(value) + 1; }
function isActiveDay(data: DocumentData): boolean { return safeNumber(data.lessonsCompleted) > 0 || safeNumber(data.flashcardsReviewed) >= 10 || safeNumber(data.fritzConversations) > 0; }
function dayIdInZone(date: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function currentWeekBounds(timezone: string): [string, string] {
  const todayId = dayIdInZone(new Date(), timezone);
  const [year, month, day] = todayId.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  const mondayOffset = (date.getUTCDay() + 6) % 7;
  date.setUTCDate(date.getUTCDate() - mondayOffset);
  const start = date.toISOString().slice(0, 10);
  date.setUTCDate(date.getUTCDate() + 6);
  return [start, date.toISOString().slice(0, 10)];
}

