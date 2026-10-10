import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/onboarding/domain/onboarding_progress_repository.dart';
import 'package:wortwerk/features/onboarding/domain/placement_session.dart';

void main() {
  test('onboarding drafts round-trip placement answers and result', () {
    final draft = OnboardingDraft(
      step: 4,
      goals: const ['Alltag', 'Reisen'],
      dailyMinutes: 15,
      selectedLevel: 3,
      testStartingLevel: 0,
      placementAnswers: const [
        PlacementAnswer(questionId: 'a1_greeting', choiceId: 'a1g_a'),
      ],
      placementLevel: LearningLevel.a2,
      placementConfidence: 0.75,
    );

    final restored = OnboardingDraft.tryParse(draft.toJson());

    expect(restored, isNotNull);
    expect(restored!.step, 4);
    expect(restored.goals, ['Alltag', 'Reisen']);
    expect(restored.dailyMinutes, 15);
    expect(restored.placementAnswers.single.questionId, 'a1_greeting');
    expect(restored.placementLevel, LearningLevel.a2);
    expect(restored.placementConfidence, 0.75);
  });

  test('onboarding drafts reject malformed learner and placement data', () {
    expect(
      OnboardingDraft.tryParse({
        'step': 4,
        'goals': ['Alltag'],
        'dailyMinutes': 10,
        'selectedLevel': 1,
        'testStartingLevel': 0,
        'placementAnswers': [
          {'questionId': 'unknown', 'choiceId': 'fake'},
        ],
        'placementLevel': 'C2',
        'placementConfidence': 1,
      }),
      isNull,
    );

    expect(
      OnboardingDraft.tryParse({
        'step': 1,
        'goals': [],
        'dailyMinutes': 99,
        'selectedLevel': 0,
        'testStartingLevel': 0,
        'placementAnswers': [],
      }),
      isNull,
    );
  });
}
