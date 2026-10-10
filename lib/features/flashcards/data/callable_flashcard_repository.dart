import 'package:cloud_functions/cloud_functions.dart';

import '../domain/flashcard_review.dart';

final class CallableFlashcardRepository implements FlashcardRepository {
  const CallableFlashcardRepository(this.functions);

  final FirebaseFunctions functions;

  @override
  Future<FlashcardReviewResult> completeReview({
    required List<FlashcardReviewAnswer> answers,
    required String clientRequestId,
  }) async {
    final response = await functions
        .httpsCallable('completeFlashcardReview')
        .call<Map<String, dynamic>>({
          'answers': [for (final answer in answers) answer.toJson()],
          'clientRequestId': clientRequestId,
        });
    return FlashcardReviewResult.fromJson(response.data);
  }
}
