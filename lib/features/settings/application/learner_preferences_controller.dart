import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/error/app_failure.dart';
import '../domain/learner_preferences.dart';
import '../domain/learner_preferences_repository.dart';

final class LearnerPreferencesState {
  const LearnerPreferencesState({
    this.preferences = const LearnerPreferences(),
    this.isLoading = true,
    this.isSaving = false,
    this.hasLoaded = false,
    this.failure,
    this.savedAt,
  });

  final LearnerPreferences preferences;
  final bool isLoading;
  final bool isSaving;
  final bool hasLoaded;
  final AppFailure? failure;
  final DateTime? savedAt;

  LearnerPreferencesState copyWith({
    LearnerPreferences? preferences,
    bool? isLoading,
    bool? isSaving,
    bool? hasLoaded,
    AppFailure? failure,
    bool clearFailure = false,
    DateTime? savedAt,
  }) => LearnerPreferencesState(
    preferences: preferences ?? this.preferences,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    failure: clearFailure ? null : failure ?? this.failure,
    savedAt: savedAt ?? this.savedAt,
  );
}

/// Coordinates user preference loading and single-filed, serialized writes.
/// UI values are only committed after the Firebase write succeeds.
final class LearnerPreferencesController extends ChangeNotifier {
  LearnerPreferencesController({required this.repository});

  final LearnerPreferencesRepository repository;
  LearnerPreferencesState _state = const LearnerPreferencesState();
  Future<void> _writeQueue = Future<void>.value();
  bool _disposed = false;

  LearnerPreferencesState get state => _state;

  Future<void> load() async {
    _setState(_state.copyWith(isLoading: true, clearFailure: true));
    try {
      final preferences = await repository.load();
      _setState(
        _state.copyWith(
          preferences: preferences,
          isLoading: false,
          hasLoaded: true,
          clearFailure: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          failure: AppFailure.fromException(error),
        ),
      );
    }
  }

  Future<void> update(LearnerPreferences next) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      if (_disposed) {
        completer.complete();
        return;
      }
      _setState(_state.copyWith(isSaving: true, clearFailure: true));
      try {
        await repository.save(next);
        _setState(
          _state.copyWith(
            preferences: next,
            isSaving: false,
            hasLoaded: true,
            clearFailure: true,
            savedAt: DateTime.now(),
          ),
        );
      } catch (error) {
        _setState(
          _state.copyWith(
            isSaving: false,
            failure: AppFailure.fromException(error),
          ),
        );
      }
      completer.complete();
    });
    return completer.future;
  }

  void _setState(LearnerPreferencesState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
