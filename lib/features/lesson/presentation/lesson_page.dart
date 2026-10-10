import 'package:wortwerk/core/l10n/localized_text.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/animations/animated_counter.dart';
import '../../../core/animations/confetti_burst.dart';
import '../../../core/animations/draw_path.dart';
import '../../../core/animations/spring_in.dart';
import '../../../core/animations/shake_widget.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/state/async_resource.dart';
import '../../../design_system/components.dart';
import '../application/lesson_content_controller.dart';
import '../application/lesson_use_cases.dart';
import '../domain/greetings_lesson.dart';
import '../domain/lesson_repository.dart';

final class LessonPage extends StatefulWidget {
  const LessonPage({
    required this.repository,
    required this.contentRepository,
    required this.levelId,
    required this.unitId,
    required this.lessonId,
    super.key,
  });

  final LessonRepository repository;
  final LessonContentRepository contentRepository;
  final String levelId;
  final String unitId;
  final String lessonId;

  @override
  State<LessonPage> createState() => _LessonPageState();
}

final class _LessonPageState extends State<LessonPage> {
  int _questionIndex = 0;
  String? _selectedChoiceId;
  bool _checked = false;
  bool _isSaving = false;
  bool _finalAnswerAdded = false;
  AppFailure? _saveFailure;
  late final LessonContentController _contentController;
  late final CompleteLessonUseCase _completeLesson;
  String? _clientRequestId;
  LessonCompletionResult? _result;
  final List<LessonAnswer> _answers = [];
  final ShakeController _shakeController = ShakeController();

  LearningLesson? get _lesson => switch (_contentController.state) {
    ResourceData<LearningLesson>(:final value) => value,
    ResourceLoading<LearningLesson>(:final previousData) => previousData,
    ResourceOffline<LearningLesson>(:final previousData) => previousData,
    ResourceFailure<LearningLesson>(:final previousData) => previousData,
    _ => null,
  };

  LessonQuestion get _question => _lesson!.questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _contentController = LessonContentController(
      loadLesson: LoadLessonUseCase(widget.contentRepository),
      levelId: widget.levelId,
      unitId: widget.unitId,
      lessonId: widget.lessonId,
    );
    _completeLesson = CompleteLessonUseCase(widget.repository);
    _contentController.refresh();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadLesson() => _contentController.refresh();

  String get _saveFailureMessage {
    final failure = _saveFailure;
    if (failure == null) return '';
    if (failure.kind == AppFailureKind.network ||
        failure.kind == AppFailureKind.timeout) {
      return 'Dein Fortschritt konnte nicht bestätigt werden. Deine Antworten '
          'sind noch da. Bitte versuche erneut, den Fortschritt zu speichern.';
    }
    return failure.message;
  }

  void _checkAnswer() {
    if (_selectedChoiceId == null || _checked) return;
    setState(() => _checked = true);
    // A wrong answer shakes the options once (SPEC §5.5).
    if (_selectedChoiceId != _question.correctChoiceId) {
      _shakeController.shake();
    }
  }

  void _continue() {
    if (_questionIndex == _lesson!.questions.length - 1) {
      _saveProgress();
      return;
    }

    _answers.add(
      LessonAnswer(questionId: _question.id, choiceId: _selectedChoiceId!),
    );
    setState(() {
      _questionIndex++;
      _selectedChoiceId = null;
      _checked = false;
    });
  }

  Future<void> _saveProgress() async {
    if (!_checked || _selectedChoiceId == null || _isSaving) return;
    if (!_finalAnswerAdded) {
      _answers.add(
        LessonAnswer(questionId: _question.id, choiceId: _selectedChoiceId!),
      );
      _finalAnswerAdded = true;
    }
    _clientRequestId ??= _newClientRequestId();
    setState(() {
      _isSaving = true;
      _saveFailure = null;
    });

    try {
      final result = await _completeLesson(
        levelId: widget.levelId,
        unitId: widget.unitId,
        lessonId: widget.lessonId,
        answers: List.unmodifiable(_answers),
        clientRequestId: _clientRequestId!,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveFailure = AppFailure.fromException(error);
      });
    }
  }

  String _newClientRequestId() {
    final random = Random.secure();
    final suffix = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'lesson_${DateTime.now().toUtc().microsecondsSinceEpoch}_$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _contentController,
      builder: (context, _) {
        final lesson = _lesson;
        return Scaffold(
          appBar: AppBar(
            title: LocalizedText(lesson?.title ?? 'Deutsch lernen'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: _buildContent(
                      context,
                      _contentController.state,
                      lesson,
                      _result,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    AsyncResource<LearningLesson> state,
    LearningLesson? lesson,
    LessonCompletionResult? result,
  ) {
    if (lesson != null && lesson.questions.isNotEmpty) {
      return result == null
          ? _buildExercise(context, lesson)
          : _buildResult(context, result);
    }
    return switch (state) {
      ResourceIdle<LearningLesson>() || ResourceLoading<LearningLesson>() =>
        const WLoadingState(message: 'Lektion wird geladen …'),
      ResourceEmpty<LearningLesson>() => const WEmptyState(
        title: 'Diese Lektion ist noch nicht bereit.',
        message: 'Sobald neue Übungen verfügbar sind, findest du sie hier.',
      ),
      ResourceOffline<LearningLesson>(:final failure) => WFailureState(
        failure: failure,
        onRetry: _loadLesson,
        title: 'Lektion offline nicht verfügbar.',
      ),
      ResourceFailure<LearningLesson>(:final failure) => WFailureState(
        failure: failure,
        onRetry: _loadLesson,
      ),
      ResourceData<LearningLesson>() => const WEmptyState(
        title: 'Diese Lektion ist noch nicht bereit.',
        message: 'Sobald neue Übungen verfügbar sind, findest du sie hier.',
      ),
    };
  }

  Widget _buildExercise(BuildContext context, LearningLesson lesson) {
    final theme = Theme.of(context);
    final questionNumber = _questionIndex + 1;
    final isCorrect = _selectedChoiceId == _question.correctChoiceId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LocalizedText(
          'Frage $questionNumber von ${lesson.questions.length}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Semantics(
          label:
              'Lektionsfortschritt, Frage $questionNumber von ${lesson.questions.length}',
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: questionNumber / lesson.questions.length,
            ),
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                LinearProgressIndicator(value: value),
          ),
        ),
        const SizedBox(height: 32),
        AnimatedSwitcher(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final position = Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: position, child: child),
            );
          },
          child: Column(
            key: ValueKey(_question.id),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LocalizedText(
                _question.prompt,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              ShakeWidget(
                controller: _shakeController,
                child: RadioGroup<String>(
                  groupValue: _selectedChoiceId,
                  onChanged: (value) =>
                      setState(() => _selectedChoiceId = value),
                  child: Column(
                    children: [
                      for (final choice in _question.choices)
                        RadioListTile<String>(
                          key: ValueKey(choice.id),
                          value: choice.id,
                          enabled: !_checked && !_isSaving,
                          title: LocalizedText(choice.text),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSize(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: _checked
                ? Semantics(
                    key: ValueKey('feedback-${_question.id}'),
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DrawPath(
                            size: const Size(20, 20),
                            strokeWidth: 2.4,
                            color: isCorrect
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                            path: isCorrect
                                ? (Path()
                                    ..moveTo(3, 11)
                                    ..lineTo(8, 16)
                                    ..lineTo(17, 5))
                                : (Path()
                                    ..moveTo(5, 5)
                                    ..lineTo(15, 15)
                                    ..moveTo(15, 5)
                                    ..lineTo(5, 15)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LocalizedText(
                              '${isCorrect ? 'Richtig.' : 'Noch nicht richtig.'} '
                              '${_question.explanation}',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('feedback-empty'),
                    width: double.infinity,
                  ),
          ),
        ),
        if (_saveFailure != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: LocalizedText(
              _saveFailureMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        if (_isSaving) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                LocalizedText('Fortschritt wird gespeichert …'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _isSaving
              ? null
              : !_checked
              ? (_selectedChoiceId == null ? null : _checkAnswer)
              : _questionIndex == lesson.questions.length - 1
              ? _saveProgress
              : _continue,
          child: LocalizedText(
            _isSaving
                ? 'Speichern …'
                : !_checked
                ? 'Antwort prüfen'
                : _saveFailure != null
                ? 'Erneut speichern'
                : _questionIndex == lesson.questions.length - 1
                ? 'Lektion abschließen'
                : 'Weiter',
          ),
        ),
        if (!_checked)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LocalizedText(
              'Dein Fortschritt wird gespeichert, sobald die Lektion bestätigt ist.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, LessonCompletionResult result) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 148,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: ConfettiBurst(
                    particleCount: 32,
                    duration: Duration(milliseconds: 1050),
                    colors: [
                      Color(0xFFE8590C),
                      Color(0xFFBFE3C4),
                      Color(0xFFB9D3EE),
                      Color(0xFFF5C2DC),
                    ],
                  ),
                ),
              ),
              SpringIn(
                beginScale: 0.55,
                duration: const Duration(milliseconds: 520),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: 28,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: DrawPath(
                      size: const Size(38, 38),
                      strokeWidth: 4,
                      color: theme.colorScheme.onPrimaryContainer,
                      path: Path()
                        ..moveTo(5, 20)
                        ..lineTo(15, 30)
                        ..lineTo(34, 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Staggered(
          index: 1,
          child: LocalizedText(
            'Lektion gespeichert',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 12),
        Staggered(
          index: 2,
          child: LocalizedText(
            'Dein Fortschritt wurde vom Server bestätigt.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 24),
        Staggered(
          index: 3,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.58,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: result.accuracy),
                            duration: const Duration(milliseconds: 820),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                CircularProgressIndicator(
                                  value:
                                      MediaQuery.of(context).disableAnimations
                                      ? result.accuracy
                                      : value,
                                  strokeWidth: 6,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor:
                                      theme.colorScheme.outlineVariant,
                                  color: theme.colorScheme.primary,
                                ),
                          ),
                          AnimatedCounter(
                            value: (result.accuracy * 100).round(),
                            suffix: '%',
                            style: theme.textTheme.titleSmall,
                            semanticsLabel:
                                'Accuracy ${(result.accuracy * 100).round()} percent',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const LocalizedText('richtig'),
                  ],
                ),
                Container(
                  width: 1,
                  height: 64,
                  color: theme.colorScheme.outlineVariant,
                ),
                Column(
                  children: [
                    AnimatedCounter(
                      value: result.xpAwarded,
                      prefix: '+',
                      suffix: ' XP',
                      style: theme.textTheme.headlineSmall,
                      semanticsLabel: '+${result.xpAwarded} XP',
                    ),
                    const SizedBox(height: 6),
                    const LocalizedText('verdient'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
