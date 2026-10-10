import 'package:cloud_functions/cloud_functions.dart';

import '../domain/placement_session.dart';

final class CallablePlacementEvaluator implements PlacementEvaluator {
  const CallablePlacementEvaluator(this.functions);

  final FirebaseFunctions functions;

  @override
  Future<PlacementResult> evaluate({
    required LearningLevel startingLevel,
    required List<PlacementAnswer> answers,
  }) async {
    final response = await functions
        .httpsCallable('evaluatePlacement')
        .call<Map<String, dynamic>>({
          'startLevel': startingLevel.label,
          'answers': [
            for (final answer in answers)
              {'questionId': answer.questionId, 'choiceId': answer.choiceId},
          ],
        });
    final levelValue = response.data['level'];
    final level = levelValue is String ? LearningLevel.parse(levelValue) : null;
    final confidenceValue = response.data['confidence'];
    if (level == null || confidenceValue is! num) {
      throw const FormatException('Placement result is incomplete.');
    }
    final confidence = confidenceValue.toDouble();
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw const FormatException('Placement confidence is out of range.');
    }
    if (response.data['unitId'] != level.unitId) {
      throw const FormatException('Placement result has an invalid unit.');
    }
    return PlacementResult(level: level, confidence: confidence);
  }
}
