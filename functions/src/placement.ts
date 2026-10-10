export type PlacementLevel = "A1" | "A2" | "B1";

export interface PlacementAnswer {
  questionId: string;
  choiceId: string;
}

export interface PlacementResult {
  level: PlacementLevel;
  unitId: string;
  confidence: number;
}

interface QuestionDefinition {
  level: PlacementLevel;
  choices: readonly string[];
  correctChoiceId: string;
}

export class PlacementValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PlacementValidationError";
  }
}

export const placementQuestionBank: Readonly<
  Record<string, QuestionDefinition>
> = {
  a1_greeting: {
    level: "A1",
    choices: ["a1g_a", "a1g_b", "a1g_c", "a1g_d"],
    correctChoiceId: "a1g_a",
  },
  a1_polite: {
    level: "A1",
    choices: ["a1p_a", "a1p_b", "a1p_c", "a1p_d"],
    correctChoiceId: "a1p_b",
  },
  a1_name: {
    level: "A1",
    choices: ["a1n_a", "a1n_b", "a1n_c", "a1n_d"],
    correctChoiceId: "a1n_a",
  },
  a1_origin: {
    level: "A1",
    choices: ["a1o_a", "a1o_b", "a1o_c", "a1o_d"],
    correctChoiceId: "a1o_b",
  },
  a1_article: {
    level: "A1",
    choices: ["a1a_a", "a1a_b", "a1a_c", "a1a_d"],
    correctChoiceId: "a1a_b",
  },
  a1_question: {
    level: "A1",
    choices: ["a1q_a", "a1q_b", "a1q_c", "a1q_d"],
    correctChoiceId: "a1q_b",
  },
  a1_verb: {
    level: "A1",
    choices: ["a1v_a", "a1v_b", "a1v_c", "a1v_d"],
    correctChoiceId: "a1v_c",
  },
  a1_time: {
    level: "A1",
    choices: ["a1t_a", "a1t_b", "a1t_c", "a1t_d"],
    correctChoiceId: "a1t_a",
  },
  a2_travel: {
    level: "A2",
    choices: ["a2t_a", "a2t_b", "a2t_c", "a2t_d"],
    correctChoiceId: "a2t_a",
  },
  a2_dative: {
    level: "A2",
    choices: ["a2d_a", "a2d_b", "a2d_c", "a2d_d"],
    correctChoiceId: "a2d_a",
  },
  a2_hotel: {
    level: "A2",
    choices: ["a2h_a", "a2h_b", "a2h_c", "a2h_d"],
    correctChoiceId: "a2h_a",
  },
  a2_perfect: {
    level: "A2",
    choices: ["a2p_a", "a2p_b", "a2p_c", "a2p_d"],
    correctChoiceId: "a2p_a",
  },
  a2_direction: {
    level: "A2",
    choices: ["a2r_a", "a2r_b", "a2r_c", "a2r_d"],
    correctChoiceId: "a2r_a",
  },
  a2_comparison: {
    level: "A2",
    choices: ["a2c_a", "a2c_b", "a2c_c", "a2c_d"],
    correctChoiceId: "a2c_a",
  },
  a2_pronoun: {
    level: "A2",
    choices: ["a2n_a", "a2n_b", "a2n_c", "a2n_d"],
    correctChoiceId: "a2n_a",
  },
  a2_order: {
    level: "A2",
    choices: ["a2o_a", "a2o_b", "a2o_c", "a2o_d"],
    correctChoiceId: "a2o_a",
  },
  b1_reason: {
    level: "B1",
    choices: ["b1r_a", "b1r_b", "b1r_c", "b1r_d"],
    correctChoiceId: "b1r_a",
  },
  b1_subjunctive: {
    level: "B1",
    choices: ["b1s_a", "b1s_b", "b1s_c", "b1s_d"],
    correctChoiceId: "b1s_a",
  },
  b1_relative: {
    level: "B1",
    choices: ["b1l_a", "b1l_b", "b1l_c", "b1l_d"],
    correctChoiceId: "b1l_a",
  },
  b1_passive: {
    level: "B1",
    choices: ["b1p_a", "b1p_b", "b1p_c", "b1p_d"],
    correctChoiceId: "b1p_a",
  },
  b1_conjunctive: {
    level: "B1",
    choices: ["b1c_a", "b1c_b", "b1c_c", "b1c_d"],
    correctChoiceId: "b1c_a",
  },
  b1_connective: {
    level: "B1",
    choices: ["b1c2_a", "b1c2_b", "b1c2_c", "b1c2_d"],
    correctChoiceId: "b1c2_a",
  },
  b1_opinion: {
    level: "B1",
    choices: ["b1o_a", "b1o_b", "b1o_c", "b1o_d"],
    correctChoiceId: "b1o_a",
  },
  b1_consequence: {
    level: "B1",
    choices: ["b1f_a", "b1f_b", "b1f_c", "b1f_d"],
    correctChoiceId: "b1f_a",
  },
};

const levels: readonly PlacementLevel[] = ["A1", "A2", "B1"];

const unitIds: Record<PlacementLevel, string> = {
  A1: "a1_greetings",
  A2: "a2_travel",
  B1: "b1_conversation",
};

function nextLevel(level: PlacementLevel): PlacementLevel {
  return levels[Math.min(levels.indexOf(level) + 1, levels.length - 1)];
}

function previousLevel(level: PlacementLevel): PlacementLevel {
  return levels[Math.max(levels.indexOf(level) - 1, 0)];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function evaluatePlacement(input: unknown): PlacementResult {
  if (!isRecord(input)) {
    throw new PlacementValidationError("Placement data must be an object.");
  }

  const startLevel = input.startLevel;
  if (
    typeof startLevel !== "string" ||
    !levels.includes(startLevel as PlacementLevel)
  ) {
    throw new PlacementValidationError("Choose a valid starting level.");
  }

  const answersInput = input.answers;
  if (
    !Array.isArray(answersInput) ||
    answersInput.length < 6 ||
    answersInput.length > 8
  ) {
    throw new PlacementValidationError(
      "A placement test must contain 6 to 8 answers.",
    );
  }

  let level: PlacementLevel = startLevel as PlacementLevel;
  let correctStreak = 0;
  let incorrectStreak = 0;
  let correctCount = 0;
  const seenQuestionIds = new Set<string>();

  for (const answerInput of answersInput) {
    if (
      !isRecord(answerInput) ||
      typeof answerInput.questionId !== "string" ||
      typeof answerInput.choiceId !== "string"
    ) {
      throw new PlacementValidationError("A placement answer is invalid.");
    }

    const { questionId, choiceId } = answerInput;
    if (seenQuestionIds.has(questionId)) {
      throw new PlacementValidationError(
        "A placement question cannot be answered twice.",
      );
    }
    seenQuestionIds.add(questionId);

    const question = placementQuestionBank[questionId];
    if (!question || question.level !== level) {
      throw new PlacementValidationError(
        "The questions do not match the adaptive placement path.",
      );
    }
    if (!question.choices.includes(choiceId)) {
      throw new PlacementValidationError(
        "A placement answer choice is invalid.",
      );
    }

    if (choiceId === question.correctChoiceId) {
      correctCount++;
      correctStreak++;
      incorrectStreak = 0;
      if (correctStreak === 2) {
        level = nextLevel(level);
        correctStreak = 0;
      }
    } else {
      incorrectStreak++;
      correctStreak = 0;
      if (incorrectStreak === 2) {
        level = previousLevel(level);
        incorrectStreak = 0;
      }
    }
  }

  return {
    level,
    unitId: unitIds[level],
    confidence: correctCount / answersInput.length,
  };
}
