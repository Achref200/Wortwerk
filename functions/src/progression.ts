export interface CardRetentionState {
  intervalDays: number;
  correctStreak: number;
}

export interface LevelProgressSnapshot {
  coreVocabularyCount: number;
  retainedWords: number;
  retentionRatio: number;
  retentionMet: boolean;
  fritzConversations: number;
  conversationsMet: boolean;
  reviewRoundsPassed: number;
  reviewMet: boolean;
  readyToUnlock: boolean;
}

export interface UnitCompletionState {
  completed: boolean;
  accuracy: number;
}

const NEXT_LEVEL: Readonly<Record<string, string>> = {
  A1: "A2",
  A2: "B1",
  B1: "B2",
  B2: "C1",
  C1: "C2",
};
const LEVEL_RANK: Readonly<Record<string, number>> = {
  A1: 1,
  A2: 2,
  B1: 3,
  B2: 4,
  C1: 5,
  C2: 6,
};

export function nextLevelId(levelId: string): string | undefined {
  return NEXT_LEVEL[levelId];
}

export function canAccessLevel(
  currentLevelId: unknown,
  targetLevelId: string,
  hasUnlock: boolean,
): boolean {
  const currentRank =
    typeof currentLevelId === "string" ? LEVEL_RANK[currentLevelId] : undefined;
  const targetRank = LEVEL_RANK[targetLevelId];
  return (
    targetRank !== undefined &&
    ((currentRank !== undefined && targetRank <= currentRank) || hasUnlock)
  );
}

export function previousUnitsUnlocked(
  previousUnits: readonly (readonly string[])[],
  lessonProgress: ReadonlyMap<string, UnitCompletionState>,
): boolean {
  return previousUnits.every((lessonIds) => {
    if (lessonIds.length === 0) return false;
    const states = lessonIds.map((lessonId) => lessonProgress.get(lessonId));
    return (
      states.every((state) => state?.completed === true) &&
      states.reduce((total, state) => total + (state?.accuracy ?? 0), 0) /
        states.length >=
        0.6
    );
  });
}

export function retainedCoreVocabularyCount(
  coreVocabularyCardIds: readonly string[],
  cardStates: ReadonlyMap<string, CardRetentionState>,
): number {
  const uniqueIds = new Set(coreVocabularyCardIds);
  let retained = 0;
  for (const cardId of uniqueIds) {
    const state = cardStates.get(cardId);
    if (state && (state.intervalDays >= 3 || state.correctStreak >= 2)) {
      retained += 1;
    }
  }
  return retained;
}

export function evaluateLevelProgress(input: {
  coreVocabularyCardIds: readonly string[];
  cardStates: ReadonlyMap<string, CardRetentionState>;
  fritzConversations: number;
  reviewRoundsPassed: number;
}): LevelProgressSnapshot {
  const coreVocabularyCount = new Set(input.coreVocabularyCardIds).size;
  const retainedWords = retainedCoreVocabularyCount(
    input.coreVocabularyCardIds,
    input.cardStates,
  );
  const retentionRatio =
    coreVocabularyCount === 0 ? 0 : retainedWords / coreVocabularyCount;
  const retentionMet = coreVocabularyCount > 0 && retentionRatio >= 0.7;
  const fritzConversations = Math.max(0, Math.floor(input.fritzConversations));
  const reviewRoundsPassed = Math.max(0, Math.floor(input.reviewRoundsPassed));
  const conversationsMet = fritzConversations >= 3;
  const reviewMet = reviewRoundsPassed >= 1;
  return {
    coreVocabularyCount,
    retainedWords,
    retentionRatio,
    retentionMet,
    fritzConversations,
    conversationsMet,
    reviewRoundsPassed,
    reviewMet,
    readyToUnlock: retentionMet && conversationsMet && reviewMet,
  };
}
