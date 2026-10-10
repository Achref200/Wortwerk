import 'placement_session.dart';

final class OnboardingDraft {
  const OnboardingDraft({
    required this.step,
    required this.goals,
    required this.dailyMinutes,
    required this.selectedLevel,
    required this.testStartingLevel,
    this.placementAnswers = const [],
    this.placementLevel,
    this.placementConfidence,
  });

  final int step;
  final List<String> goals;
  final int dailyMinutes;
  final int selectedLevel;
  final int testStartingLevel;
  final List<PlacementAnswer> placementAnswers;
  final LearningLevel? placementLevel;
  final double? placementConfidence;

  Map<String, Object?> toJson() => {
    'step': step,
    'goals': goals,
    'dailyMinutes': dailyMinutes,
    'selectedLevel': selectedLevel,
    'testStartingLevel': testStartingLevel,
    'placementAnswers': [
      for (final answer in placementAnswers)
        {'questionId': answer.questionId, 'choiceId': answer.choiceId},
    ],
    'placementLevel': placementLevel?.label,
    'placementConfidence': placementConfidence,
  };

  static OnboardingDraft? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final step = value['step'];
    final goals = value['goals'];
    final dailyMinutes = value['dailyMinutes'];
    final selectedLevel = value['selectedLevel'];
    final testStartingLevel = value['testStartingLevel'];
    final answers = value['placementAnswers'];
    final placementLevelValue = value['placementLevel'];
    final placementConfidenceValue = value['placementConfidence'];
    if (step is! int ||
        step < 0 ||
        step > 4 ||
        goals is! List ||
        !goals.every((goal) => goal is String) ||
        dailyMinutes is! int ||
        ![5, 10, 15, 20].contains(dailyMinutes) ||
        selectedLevel is! int ||
        selectedLevel < 0 ||
        selectedLevel > 3 ||
        testStartingLevel is! int ||
        testStartingLevel < 0 ||
        testStartingLevel > 2 ||
        answers is! List ||
        (placementLevelValue != null &&
            (placementLevelValue is! String ||
                LearningLevel.parse(placementLevelValue) == null)) ||
        (placementConfidenceValue != null &&
            (placementConfidenceValue is! num ||
                !placementConfidenceValue.isFinite ||
                placementConfidenceValue < 0 ||
                placementConfidenceValue > 1)) ||
        ((placementLevelValue == null) != (placementConfidenceValue == null))) {
      return null;
    }

    final parsedAnswers = <PlacementAnswer>[];
    for (final answer in answers) {
      if (answer is! Map<String, dynamic> ||
          answer['questionId'] is! String ||
          answer['choiceId'] is! String) {
        return null;
      }
      parsedAnswers.add(
        PlacementAnswer(
          questionId: answer['questionId'] as String,
          choiceId: answer['choiceId'] as String,
        ),
      );
    }

    return OnboardingDraft(
      step: step,
      goals: List.unmodifiable(goals.cast<String>()),
      dailyMinutes: dailyMinutes,
      selectedLevel: selectedLevel,
      testStartingLevel: testStartingLevel,
      placementAnswers: List.unmodifiable(parsedAnswers),
      placementLevel: placementLevelValue is String
          ? LearningLevel.parse(placementLevelValue)
          : null,
      placementConfidence: placementConfidenceValue is num
          ? placementConfidenceValue.toDouble()
          : null,
    );
  }
}

abstract interface class OnboardingProgressRepository {
  Future<bool> ensureGuestProfile();

  Future<OnboardingDraft?> loadDraft();

  Future<void> saveDraft(OnboardingDraft draft);

  Future<void> completeOnboarding({
    required OnboardingDraft draft,
    required LearningLevel level,
    required PlacementResult? placement,
  });
}
