import 'learning_path.dart';

abstract interface class LearningPathRepository {
  Future<LearningPath> getLearningPath();
}
