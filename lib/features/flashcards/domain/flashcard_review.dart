import 'package:flutter/material.dart';

import '../../../design_system/wortwerk_theme.dart';

final class LearningFlashcard {
  const LearningFlashcard({
    required this.id,
    required this.german,
    required this.translation,
    required this.partOfSpeech,
    required this.color,
  });

  final String id;
  final String german;
  final String translation;
  final String partOfSpeech;
  final Color color;
}

const greetingFlashcards = <LearningFlashcard>[
  LearningFlashcard(
    id: 'greeting_hello',
    german: 'Hallo!',
    translation: 'Hello!',
    partOfSpeech: 'Begrüßung',
    color: WortwerkColors.a1,
  ),
  LearningFlashcard(
    id: 'greeting_good_morning',
    german: 'Guten Morgen',
    translation: 'Good morning',
    partOfSpeech: 'Begrüßung',
    color: WortwerkColors.a2,
  ),
  LearningFlashcard(
    id: 'greeting_good_day',
    german: 'Guten Tag',
    translation: 'Good day',
    partOfSpeech: 'Begrüßung',
    color: WortwerkColors.b1,
  ),
  LearningFlashcard(
    id: 'greeting_good_evening',
    german: 'Guten Abend',
    translation: 'Good evening',
    partOfSpeech: 'Begrüßung',
    color: WortwerkColors.b2,
  ),
  LearningFlashcard(
    id: 'greeting_bye',
    german: 'Tschüss',
    translation: 'Bye',
    partOfSpeech: 'Abschied',
    color: WortwerkColors.c1,
  ),
  LearningFlashcard(
    id: 'greeting_goodbye_formal',
    german: 'Auf Wiedersehen',
    translation: 'Goodbye',
    partOfSpeech: 'Abschied · höflich',
    color: WortwerkColors.c2,
  ),
  LearningFlashcard(
    id: 'greeting_thanks',
    german: 'Danke',
    translation: 'Thank you',
    partOfSpeech: 'Höflich sein',
    color: WortwerkColors.a1,
  ),
  LearningFlashcard(
    id: 'greeting_please',
    german: 'Bitte',
    translation: 'Please · You’re welcome',
    partOfSpeech: 'Höflich sein',
    color: WortwerkColors.a2,
  ),
  LearningFlashcard(
    id: 'greeting_name',
    german: 'Wie heißt du?',
    translation: 'What is your name?',
    partOfSpeech: 'Kennenlernen',
    color: WortwerkColors.b1,
  ),
  LearningFlashcard(
    id: 'greeting_introduce',
    german: 'Ich heiße …',
    translation: 'My name is …',
    partOfSpeech: 'Kennenlernen',
    color: WortwerkColors.b2,
  ),
];

final class FlashcardReviewAnswer {
  const FlashcardReviewAnswer({required this.cardId, required this.remembered});

  final String cardId;
  final bool remembered;

  Map<String, Object> toJson() => {'cardId': cardId, 'remembered': remembered};
}

final class FlashcardReviewResult {
  const FlashcardReviewResult({
    required this.reviewedCount,
    required this.rememberedCount,
    required this.xpAwarded,
  });

  final int reviewedCount;
  final int rememberedCount;
  final int xpAwarded;

  factory FlashcardReviewResult.fromJson(Map<String, dynamic> json) {
    final reviewedCount = json['reviewedCount'];
    final rememberedCount = json['rememberedCount'];
    final xpAwarded = json['xpAwarded'];
    if (reviewedCount is! int ||
        rememberedCount is! int ||
        xpAwarded is! int ||
        reviewedCount != greetingFlashcards.length ||
        rememberedCount < 0 ||
        rememberedCount > reviewedCount ||
        xpAwarded < 0) {
      throw const FormatException('The saved review result is invalid.');
    }
    return FlashcardReviewResult(
      reviewedCount: reviewedCount,
      rememberedCount: rememberedCount,
      xpAwarded: xpAwarded,
    );
  }
}

abstract interface class FlashcardRepository {
  Future<FlashcardReviewResult> completeReview({
    required List<FlashcardReviewAnswer> answers,
    required String clientRequestId,
  });
}
