import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/learning_path.dart';
import '../domain/learning_path_repository.dart';

final class FirestoreLearningPathRepository implements LearningPathRepository {
  FirestoreLearningPathRepository({
    required this.firestore,
    required String uid,
    this.uidProvider,
  }) : _initialUid = uid;

  final FirebaseFirestore firestore;
  final String _initialUid;
  final String Function()? uidProvider;
  DocumentReference<Map<String, dynamic>> get _user =>
      firestore.collection('users').doc(uidProvider?.call() ?? _initialUid);

  @override
  Future<LearningPath> getLearningPath() async {
    final results = await Future.wait<dynamic>([
      firestore.collection('levels').where('published', isEqualTo: true).get(),
      _user.collection('progress').get(),
      _user.collection('levelProgress').get(),
      _user.collection('unlocks').get(),
      _user.get(),
    ]);
    final levelSnapshots = results[0];
    final progressSnapshots = results[1];
    final levelProgressSnapshots = results[2];
    final unlockSnapshots = results[3];
    final userData = results[4].data() ?? const <String, dynamic>{};
    final startingLevelId = _optionalString(userData['level']);
    final startingUnitId = _optionalString(userData['unitId']);
    final unlockedLevels = unlockSnapshots.docs
        .map((document) => document.id)
        .toSet();
    final progressByLevel = {
      for (final document in levelProgressSnapshots.docs)
        document.id: LearningLevelProgress(
          coreVocabularyCount: _nonNegativeInt(
            document.data()['coreVocabularyCount'],
          ),
          retainedWords: _nonNegativeInt(document.data()['retainedWords']),
          fritzConversations: _nonNegativeInt(
            document.data()['fritzConversations'],
          ),
          reviewRoundsPassed: _nonNegativeInt(
            document.data()['reviewRoundsPassed'],
          ),
        ),
    };
    final progressByLessonId = {
      for (final document in progressSnapshots.docs)
        document.id: document.data(),
    };
    final levels = <LearningPathLevel>[];

    for (final levelDocument in levelSnapshots.docs) {
      final levelData = levelDocument.data();
      final levelId = _requiredString(levelData, 'levelId');
      if (levelId != levelDocument.id) {
        throw const FormatException(
          'Published level ID does not match its path.',
        );
      }
      final levelTitle = _requiredString(levelData, 'title');
      final levelOrder = _requiredOrder(levelData, 'order');
      final unitSnapshots = await levelDocument.reference
          .collection('units')
          .where('published', isEqualTo: true)
          .get();
      final units = <LearningPathUnit>[];

      for (final unitDocument in unitSnapshots.docs) {
        final unitData = unitDocument.data();
        final unitId = _requiredString(unitData, 'unitId');
        if (unitId != unitDocument.id) {
          throw const FormatException(
            'Published unit ID does not match its path.',
          );
        }
        final unitTitle = _requiredString(unitData, 'title');
        final unitOrder = _requiredOrder(unitData, 'order');
        final lessonSnapshots = await unitDocument.reference
            .collection('lessons')
            .where('published', isEqualTo: true)
            .get();
        final lessons = <LearningPathLesson>[];

        for (final lessonDocument in lessonSnapshots.docs) {
          final lessonData = lessonDocument.data();
          final lessonId = _requiredString(lessonData, 'lessonId');
          if (lessonId != lessonDocument.id) {
            throw const FormatException(
              'Published lesson ID does not match its path.',
            );
          }
          final lessonTitle = _requiredString(lessonData, 'title');
          final lessonOrder = _requiredOrder(lessonData, 'order');
          final progressData = progressByLessonId[lessonId];
          lessons.add(
            LearningPathLesson(
              id: lessonId,
              title: lessonTitle,
              order: lessonOrder,
              completed: progressData?['completed'] == true,
              bestAccuracy: _accuracy(progressData?['accuracy']),
            ),
          );
        }

        lessons.sort((left, right) => left.order.compareTo(right.order));
        units.add(
          LearningPathUnit(
            id: unitId,
            title: unitTitle,
            order: unitOrder,
            lessons: List.unmodifiable(lessons),
          ),
        );
      }

      units.sort((left, right) => left.order.compareTo(right.order));
      final levelRank = _levelRank(levelId);
      final startingLevelRank = _levelRank(startingLevelId);
      final hasLevelAccess =
          (levelRank != null &&
              startingLevelRank != null &&
              levelRank <= startingLevelRank) ||
          unlockedLevels.contains(levelId);
      for (var index = 0; index < units.length; index++) {
        final unit = units[index];
        final isPlacementUnit =
            levelId == startingLevelId && unit.id == startingUnitId;
        final precedingUnits = units
            .take(index)
            .map(
              (previous) => previous.lessons
                  .map((lesson) => lesson.id)
                  .toList(growable: false),
            )
            .toList(growable: false);
        final previousLessonProgress = {
          for (final previous in units.take(index))
            for (final lesson in previous.lessons) lesson.id: lesson,
        };
        final previousUnitsMeetCriteria =
            precedingUnits.isNotEmpty &&
            precedingUnits.every((lessonIds) {
              if (lessonIds.isEmpty) return false;
              final lessons = lessonIds
                  .map((lessonId) => previousLessonProgress[lessonId])
                  .toList(growable: false);
              return lessons.every((lesson) => lesson?.completed == true) &&
                  lessons
                              .map((lesson) => lesson?.bestAccuracy ?? 0)
                              .reduce((left, right) => left + right) /
                          lessons.length >=
                      0.6;
            });
        final available =
            hasLevelAccess &&
            (unit.order == 1 || isPlacementUnit || previousUnitsMeetCriteria);
        units[index] = LearningPathUnit(
          id: unit.id,
          title: unit.title,
          order: unit.order,
          lessons: unit.lessons,
          available: available,
        );
      }
      levels.add(
        LearningPathLevel(
          id: levelId,
          title: levelTitle,
          order: levelOrder,
          units: List.unmodifiable(units),
        ),
      );
    }

    levels.sort((left, right) => left.order.compareTo(right.order));
    return LearningPath(
      levels: List.unmodifiable(levels),
      progressByLevel: Map.unmodifiable(progressByLevel),
      unlockedLevels: Set.unmodifiable(unlockedLevels),
      startingLevelId: startingLevelId,
      startingUnitId: startingUnitId,
    );
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('Published path content is missing $field.');
  }

  static int _requiredOrder(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is int && value >= 0) return value;
    throw FormatException('Published path content has an invalid $field.');
  }

  static double _accuracy(Object? value) {
    if (value is! num || !value.isFinite) return 0;
    return value.toDouble().clamp(0, 1);
  }

  static int _nonNegativeInt(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.floor() : 0;

  static String? _optionalString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _levelRank(String? levelId) => switch (levelId) {
    'A1' => 1,
    'A2' => 2,
    'B1' => 3,
    'B2' => 4,
    'C1' => 5,
    'C2' => 6,
    _ => null,
  };
}
