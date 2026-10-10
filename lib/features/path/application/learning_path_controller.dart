import '../../../core/state/async_resource.dart';
import '../domain/learning_path.dart';
import '../domain/learning_path_repository.dart';

final class LoadLearningPathUseCase {
  const LoadLearningPathUseCase(this._repository);

  final LearningPathRepository _repository;

  Future<LearningPath> call() => _repository.getLearningPath();
}

final class LearningPathController
    extends AsyncResourceController<LearningPath> {
  LearningPathController({required LoadLearningPathUseCase loadPath})
    : super(load: loadPath.call, isEmpty: (path) => path.isEmpty);
}
