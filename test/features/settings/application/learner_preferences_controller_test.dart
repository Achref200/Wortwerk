import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/settings/application/learner_preferences_controller.dart';
import 'package:wortwerk/features/settings/domain/learner_preferences.dart';
import 'package:wortwerk/features/settings/domain/learner_preferences_repository.dart';

void main() {
  test('loads saved preferences and commits only successful writes', () async {
    final repository = _MemoryPreferencesRepository();
    final controller = LearnerPreferencesController(repository: repository);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.state.hasLoaded, isTrue);
    expect(controller.state.preferences.dailyMinutes, 10);

    repository.failure = StateError('write unavailable');
    await controller.update(
      controller.state.preferences.copyWith(dailyMinutes: 20),
    );
    expect(controller.state.preferences.dailyMinutes, 10);
    expect(controller.state.failure, isNotNull);

    repository.failure = null;
    await controller.update(
      controller.state.preferences.copyWith(restWeekday: 3),
    );
    expect(controller.state.preferences.restWeekday, 3);
    expect(controller.state.failure, isNull);
    expect(controller.state.savedAt, isNotNull);
  });
}

final class _MemoryPreferencesRepository
    implements LearnerPreferencesRepository {
  LearnerPreferences preferences = const LearnerPreferences();
  Object? failure;

  @override
  Future<LearnerPreferences> load() async => preferences;

  @override
  Future<void> save(LearnerPreferences preferences) async {
    final error = failure;
    if (error != null) throw error;
    this.preferences = preferences;
  }
}
