enum LearningLevel {
  a1('A1', 'a1_greetings', 'Begrüßungen'),
  a2('A2', 'a2_travel', 'Reisen'),
  b1('B1', 'b1_conversation', 'Alltag und Gespräche');

  const LearningLevel(this.label, this.unitId, this.unitTitle);

  final String label;
  final String unitId;
  final String unitTitle;

  LearningLevel advance() => switch (this) {
    LearningLevel.a1 => LearningLevel.a2,
    LearningLevel.a2 => LearningLevel.b1,
    LearningLevel.b1 => LearningLevel.b1,
  };

  LearningLevel retreat() => switch (this) {
    LearningLevel.a1 => LearningLevel.a1,
    LearningLevel.a2 => LearningLevel.a1,
    LearningLevel.b1 => LearningLevel.a2,
  };

  static LearningLevel fromSelfAssessment(int selection) => switch (selection) {
    0 => LearningLevel.a1,
    1 => LearningLevel.a2,
    2 => LearningLevel.b1,
    _ => LearningLevel.a1,
  };

  static LearningLevel? parse(String? value) {
    for (final level in LearningLevel.values) {
      if (level.label == value) return level;
    }
    return null;
  }
}

final class PlacementChoice {
  const PlacementChoice({required this.id, required this.label});

  final String id;
  final String label;
}

final class PlacementQuestion {
  const PlacementQuestion({
    required this.id,
    required this.level,
    required this.prompt,
    required this.choices,
    required this.correctChoiceId,
  });

  final String id;
  final LearningLevel level;
  final String prompt;
  final List<PlacementChoice> choices;
  final String correctChoiceId;

  bool isCorrect(String choiceId) => choiceId == correctChoiceId;
}

final class PlacementAnswer {
  const PlacementAnswer({required this.questionId, required this.choiceId});

  final String questionId;
  final String choiceId;
}

final class PlacementResult {
  const PlacementResult({required this.level, required this.confidence});

  final LearningLevel level;
  final double confidence;
}

abstract interface class PlacementEvaluator {
  Future<PlacementResult> evaluate({
    required LearningLevel startingLevel,
    required List<PlacementAnswer> answers,
  });
}

final class PlacementSession {
  PlacementSession({required this.startingLevel})
    : _currentLevel = startingLevel;

  final LearningLevel startingLevel;
  final List<PlacementAnswer> answers = [];
  LearningLevel _currentLevel;
  int _correctStreak = 0;
  int _incorrectStreak = 0;

  LearningLevel get currentLevel => _currentLevel;
  int get questionNumber => answers.length + 1;
  bool get isComplete => answers.length == PlacementQuestionBank.questionCount;

  PlacementQuestion get currentQuestion {
    if (isComplete) {
      throw StateError('The placement test has already been completed.');
    }
    final answeredQuestionIds = answers.map((answer) => answer.questionId);
    return PlacementQuestionBank.questions.firstWhere(
      (question) =>
          question.level == _currentLevel &&
          !answeredQuestionIds.contains(question.id),
    );
  }

  void answer(String choiceId) {
    if (isComplete) {
      throw StateError('The placement test has already been completed.');
    }

    final question = currentQuestion;
    if (!question.choices.any((choice) => choice.id == choiceId)) {
      throw ArgumentError.value(choiceId, 'choiceId', 'Unknown answer choice');
    }

    answers.add(PlacementAnswer(questionId: question.id, choiceId: choiceId));

    if (question.isCorrect(choiceId)) {
      _correctStreak++;
      _incorrectStreak = 0;
      if (_correctStreak == 2) {
        _currentLevel = _currentLevel.advance();
        _correctStreak = 0;
      }
    } else {
      _incorrectStreak++;
      _correctStreak = 0;
      if (_incorrectStreak == 2) {
        _currentLevel = _currentLevel.retreat();
        _incorrectStreak = 0;
      }
    }
  }
}

abstract final class PlacementQuestionBank {
  static const questionCount = 8;

  static const questions = <PlacementQuestion>[
    PlacementQuestion(
      id: 'a1_greeting',
      level: LearningLevel.a1,
      prompt: 'Wie sagt man „Hello“ auf Deutsch?',
      choices: [
        PlacementChoice(id: 'a1g_a', label: 'Hallo'),
        PlacementChoice(id: 'a1g_b', label: 'Danke'),
        PlacementChoice(id: 'a1g_c', label: 'Tschüss'),
        PlacementChoice(id: 'a1g_d', label: 'Bitte'),
      ],
      correctChoiceId: 'a1g_a',
    ),
    PlacementQuestion(
      id: 'a1_polite',
      level: LearningLevel.a1,
      prompt: 'Was passt? „Danke!“ – „___“',
      choices: [
        PlacementChoice(id: 'a1p_a', label: 'Guten Abend'),
        PlacementChoice(id: 'a1p_b', label: 'Bitte'),
        PlacementChoice(id: 'a1p_c', label: 'Tschüss'),
        PlacementChoice(id: 'a1p_d', label: 'Ich heiße'),
      ],
      correctChoiceId: 'a1p_b',
    ),
    PlacementQuestion(
      id: 'a1_name',
      level: LearningLevel.a1,
      prompt: 'Ergänze: „Ich ___ Anna.“',
      choices: [
        PlacementChoice(id: 'a1n_a', label: 'heiße'),
        PlacementChoice(id: 'a1n_b', label: 'heißt'),
        PlacementChoice(id: 'a1n_c', label: 'heißen'),
        PlacementChoice(id: 'a1n_d', label: 'heiß'),
      ],
      correctChoiceId: 'a1n_a',
    ),
    PlacementQuestion(
      id: 'a1_origin',
      level: LearningLevel.a1,
      prompt: 'Wie beantwortest du „Woher kommst du?“',
      choices: [
        PlacementChoice(id: 'a1o_a', label: 'Ich wohne gut.'),
        PlacementChoice(id: 'a1o_b', label: 'Ich komme aus Berlin.'),
        PlacementChoice(id: 'a1o_c', label: 'Ich bin heißen Anna.'),
        PlacementChoice(id: 'a1o_d', label: 'Ich gern Berlin.'),
      ],
      correctChoiceId: 'a1o_b',
    ),
    PlacementQuestion(
      id: 'a1_article',
      level: LearningLevel.a1,
      prompt: 'Welcher Artikel passt? ___ Apfel',
      choices: [
        PlacementChoice(id: 'a1a_a', label: 'Die'),
        PlacementChoice(id: 'a1a_b', label: 'Der'),
        PlacementChoice(id: 'a1a_c', label: 'Das'),
        PlacementChoice(id: 'a1a_d', label: 'Den'),
      ],
      correctChoiceId: 'a1a_b',
    ),
    PlacementQuestion(
      id: 'a1_question',
      level: LearningLevel.a1,
      prompt: 'Was bedeutet „Wie geht es dir?“',
      choices: [
        PlacementChoice(id: 'a1q_a', label: 'Wie heißt du?'),
        PlacementChoice(id: 'a1q_b', label: 'Wie geht’s dir?'),
        PlacementChoice(id: 'a1q_c', label: 'Wo wohnst du?'),
        PlacementChoice(id: 'a1q_d', label: 'Woher kommst du?'),
      ],
      correctChoiceId: 'a1q_b',
    ),
    PlacementQuestion(
      id: 'a1_verb',
      level: LearningLevel.a1,
      prompt: 'Ergänze: „Wir ___ Deutsch.“',
      choices: [
        PlacementChoice(id: 'a1v_a', label: 'lernst'),
        PlacementChoice(id: 'a1v_b', label: 'lerne'),
        PlacementChoice(id: 'a1v_c', label: 'lernen'),
        PlacementChoice(id: 'a1v_d', label: 'lernt'),
      ],
      correctChoiceId: 'a1v_c',
    ),
    PlacementQuestion(
      id: 'a1_time',
      level: LearningLevel.a1,
      prompt: 'Wann ist „Guten Morgen“ passend?',
      choices: [
        PlacementChoice(id: 'a1t_a', label: 'Am Morgen'),
        PlacementChoice(id: 'a1t_b', label: 'Nur beim Essen'),
        PlacementChoice(id: 'a1t_c', label: 'Beim Abschied'),
        PlacementChoice(id: 'a1t_d', label: 'Um Mitternacht'),
      ],
      correctChoiceId: 'a1t_a',
    ),
    PlacementQuestion(
      id: 'a2_travel',
      level: LearningLevel.a2,
      prompt: 'Am Bahnhof: „Wann fährt ___ Zug ab?“',
      choices: [
        PlacementChoice(id: 'a2t_a', label: 'der nächste'),
        PlacementChoice(id: 'a2t_b', label: 'den nächsten'),
        PlacementChoice(id: 'a2t_c', label: 'dem nächste'),
        PlacementChoice(id: 'a2t_d', label: 'die nächstes'),
      ],
      correctChoiceId: 'a2t_a',
    ),
    PlacementQuestion(
      id: 'a2_dative',
      level: LearningLevel.a2,
      prompt: 'Ergänze: „Ich fahre ___ Bus zur Arbeit.“',
      choices: [
        PlacementChoice(id: 'a2d_a', label: 'mit dem'),
        PlacementChoice(id: 'a2d_b', label: 'mit den'),
        PlacementChoice(id: 'a2d_c', label: 'für der'),
        PlacementChoice(id: 'a2d_d', label: 'von das'),
      ],
      correctChoiceId: 'a2d_a',
    ),
    PlacementQuestion(
      id: 'a2_hotel',
      level: LearningLevel.a2,
      prompt: 'Im Hotel: Was bedeutet „Ich habe eine Reservierung“?',
      choices: [
        PlacementChoice(id: 'a2h_a', label: 'I have a reservation.'),
        PlacementChoice(id: 'a2h_b', label: 'I need a taxi.'),
        PlacementChoice(id: 'a2h_c', label: 'I am travelling tomorrow.'),
        PlacementChoice(id: 'a2h_d', label: 'I have lost my key.'),
      ],
      correctChoiceId: 'a2h_a',
    ),
    PlacementQuestion(
      id: 'a2_perfect',
      level: LearningLevel.a2,
      prompt: 'Gestern ___ ich meine Freundin besucht.',
      choices: [
        PlacementChoice(id: 'a2p_a', label: 'habe'),
        PlacementChoice(id: 'a2p_b', label: 'bin'),
        PlacementChoice(id: 'a2p_c', label: 'werde'),
        PlacementChoice(id: 'a2p_d', label: 'hat'),
      ],
      correctChoiceId: 'a2p_a',
    ),
    PlacementQuestion(
      id: 'a2_direction',
      level: LearningLevel.a2,
      prompt: '„Gehen Sie geradeaus und ___ Sie dann links ab.“',
      choices: [
        PlacementChoice(id: 'a2r_a', label: 'biegen'),
        PlacementChoice(id: 'a2r_b', label: 'biegt'),
        PlacementChoice(id: 'a2r_c', label: 'biegst'),
        PlacementChoice(id: 'a2r_d', label: 'gebogen'),
      ],
      correctChoiceId: 'a2r_a',
    ),
    PlacementQuestion(
      id: 'a2_comparison',
      level: LearningLevel.a2,
      prompt: 'Was ist richtig? „Der Zug ist ___ als der Bus.“',
      choices: [
        PlacementChoice(id: 'a2c_a', label: 'schneller'),
        PlacementChoice(id: 'a2c_b', label: 'schnell'),
        PlacementChoice(id: 'a2c_c', label: 'am schnell'),
        PlacementChoice(id: 'a2c_d', label: 'schnellsten'),
      ],
      correctChoiceId: 'a2c_a',
    ),
    PlacementQuestion(
      id: 'a2_pronoun',
      level: LearningLevel.a2,
      prompt: '„Das Geschenk ist ___.“ (for her)',
      choices: [
        PlacementChoice(id: 'a2n_a', label: 'für sie'),
        PlacementChoice(id: 'a2n_b', label: 'für ihr'),
        PlacementChoice(id: 'a2n_c', label: 'mit sie'),
        PlacementChoice(id: 'a2n_d', label: 'zu sie'),
      ],
      correctChoiceId: 'a2n_a',
    ),
    PlacementQuestion(
      id: 'a2_order',
      level: LearningLevel.a2,
      prompt: 'Was bedeutet „obwohl“? „Obwohl es regnet, gehe ich spazieren.“',
      choices: [
        PlacementChoice(id: 'a2o_a', label: 'even though'),
        PlacementChoice(id: 'a2o_b', label: 'because'),
        PlacementChoice(id: 'a2o_c', label: 'before'),
        PlacementChoice(id: 'a2o_d', label: 'therefore'),
      ],
      correctChoiceId: 'a2o_a',
    ),
    PlacementQuestion(
      id: 'b1_reason',
      level: LearningLevel.b1,
      prompt: 'Ergänze: „Ich bleibe zu Hause, ___ ich krank bin.“',
      choices: [
        PlacementChoice(id: 'b1r_a', label: 'weil'),
        PlacementChoice(id: 'b1r_b', label: 'obwohl'),
        PlacementChoice(id: 'b1r_c', label: 'trotzdem'),
        PlacementChoice(id: 'b1r_d', label: 'während'),
      ],
      correctChoiceId: 'b1r_a',
    ),
    PlacementQuestion(
      id: 'b1_subjunctive',
      level: LearningLevel.b1,
      prompt: 'Was ist eine höfliche Bitte?',
      choices: [
        PlacementChoice(id: 'b1s_a', label: 'Könnten Sie mir bitte helfen?'),
        PlacementChoice(id: 'b1s_b', label: 'Du hilfst mir jetzt.'),
        PlacementChoice(id: 'b1s_c', label: 'Hilft mir schnell!'),
        PlacementChoice(id: 'b1s_d', label: 'Ich könnte geholfen.'),
      ],
      correctChoiceId: 'b1s_a',
    ),
    PlacementQuestion(
      id: 'b1_relative',
      level: LearningLevel.b1,
      prompt: '„Das ist die Kollegin, ___ mir geholfen hat.“',
      choices: [
        PlacementChoice(id: 'b1l_a', label: 'die'),
        PlacementChoice(id: 'b1l_b', label: 'der'),
        PlacementChoice(id: 'b1l_c', label: 'den'),
        PlacementChoice(id: 'b1l_d', label: 'das'),
      ],
      correctChoiceId: 'b1l_a',
    ),
    PlacementQuestion(
      id: 'b1_passive',
      level: LearningLevel.b1,
      prompt: 'Was bedeutet „Die Straße wird repariert.“?',
      choices: [
        PlacementChoice(id: 'b1p_a', label: 'Someone is repairing the road.'),
        PlacementChoice(id: 'b1p_b', label: 'The road repaired someone.'),
        PlacementChoice(id: 'b1p_c', label: 'The road needs to be closed.'),
        PlacementChoice(id: 'b1p_d', label: 'The road was already repaired.'),
      ],
      correctChoiceId: 'b1p_a',
    ),
    PlacementQuestion(
      id: 'b1_conjunctive',
      level: LearningLevel.b1,
      prompt: 'Welche Form ist ein Wunsch? „Wenn ich mehr Zeit ___, würde ich öfter lesen.“',
      choices: [
        PlacementChoice(id: 'b1c_a', label: 'hätte'),
        PlacementChoice(id: 'b1c_b', label: 'habe'),
        PlacementChoice(id: 'b1c_c', label: 'hatte'),
        PlacementChoice(id: 'b1c_d', label: 'haben'),
      ],
      correctChoiceId: 'b1c_a',
    ),
    PlacementQuestion(
      id: 'b1_connective',
      level: LearningLevel.b1,
      prompt: '„Der Zug hatte Verspätung; ___ kam ich zu spät.“',
      choices: [
        PlacementChoice(id: 'b1c2_a', label: 'deshalb'),
        PlacementChoice(id: 'b1c2_b', label: 'obwohl'),
        PlacementChoice(id: 'b1c2_c', label: 'sobald'),
        PlacementChoice(id: 'b1c2_d', label: 'falls'),
      ],
      correctChoiceId: 'b1c2_a',
    ),
    PlacementQuestion(
      id: 'b1_opinion',
      level: LearningLevel.b1,
      prompt: 'Wie drückst du eine Meinung vorsichtig aus?',
      choices: [
        PlacementChoice(id: 'b1o_a', label: 'Meiner Meinung nach …'),
        PlacementChoice(id: 'b1o_b', label: 'Zum Frühstück …'),
        PlacementChoice(id: 'b1o_c', label: 'Einen Moment bitte …'),
        PlacementChoice(id: 'b1o_d', label: 'Keine Sorge …'),
      ],
      correctChoiceId: 'b1o_a',
    ),
    PlacementQuestion(
      id: 'b1_consequence',
      level: LearningLevel.b1,
      prompt: '„Falls du Hilfe brauchst, ___ mich bitte an.“',
      choices: [
        PlacementChoice(id: 'b1f_a', label: 'ruf'),
        PlacementChoice(id: 'b1f_b', label: 'rufe ich'),
        PlacementChoice(id: 'b1f_c', label: 'anrufen'),
        PlacementChoice(id: 'b1f_d', label: 'riefst'),
      ],
      correctChoiceId: 'b1f_a',
    ),
  ];

  static PlacementQuestion? findQuestion(String id) {
    for (final question in questions) {
      if (question.id == id) return question;
    }
    return null;
  }
}
