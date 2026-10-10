import 'package:wortwerk/core/l10n/localized_text.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components.dart';
import '../../../design_system/fritz_avatar.dart';
import '../../../design_system/wortwerk_theme.dart';
import '../../../core/l10n/wortwerk_strings.dart';
import '../../notifications/application/push_notifications_controller.dart';
import '../domain/onboarding_progress_repository.dart';
import '../domain/placement_session.dart';

final class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.placementEvaluator,
    required this.progressRepository,
    required this.pushNotifications,
    super.key,
  });

  final PlacementEvaluator placementEvaluator;
  final OnboardingProgressRepository progressRepository;
  final PushNotificationsController pushNotifications;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

final class _OnboardingPageState extends State<OnboardingPage> {
  static const _goals = [
    'Reisen',
    'Arbeit',
    'Alltag',
    'Familie & Freunde',
    'Kultur',
    'Neugier',
  ];
  static const _minutes = [5, 10, 15, 20];
  static const _levels = [
    ('Ganz neu', 'Ich starte bei null.'),
    ('Grundlagen', 'Einfache Sätze gehen schon.'),
    ('Gespräche führen', 'Mir fehlen Wörter und Sicherheit.'),
    ('Teste mich, Fritz', '2 Minuten, 6–8 kurze Fragen.'),
  ];

  int _step = 0;
  final Set<String> _selectedGoals = {'Alltag'};
  int _selectedMinutes = 10;
  int _selectedLevel = 0;
  int _testStartingLevel = 0;
  String? _selectedAnswer;
  PlacementSession? _placementSession;
  PlacementResult? _placementResult;
  bool _isScoring = false;
  bool _isSaving = false;
  bool _isRestoring = false;
  bool _restoreFailed = false;
  String? _placementError;
  String? _progressError;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  OnboardingDraft _draft({
    int? step,
    List<PlacementAnswer>? placementAnswers,
    PlacementResult? placementResult,
    bool clearPlacementResult = false,
  }) => OnboardingDraft(
    step: step ?? _step,
    goals: List.unmodifiable(_selectedGoals),
    dailyMinutes: _selectedMinutes,
    selectedLevel: _selectedLevel,
    testStartingLevel: _testStartingLevel,
    placementAnswers:
        placementAnswers ?? _placementSession?.answers ?? const [],
    placementLevel: clearPlacementResult
        ? null
        : placementResult?.level ?? _placementResult?.level,
    placementConfidence: clearPlacementResult
        ? null
        : placementResult?.confidence ?? _placementResult?.confidence,
  );

  Future<bool> _saveDraft(OnboardingDraft draft) async {
    if (_isSaving) return false;
    setState(() {
      _isSaving = true;
      _progressError = null;
    });
    try {
      await widget.progressRepository.saveDraft(draft);
      return true;
    } catch (error) {
      debugPrint('onboarding_draft_save_failed $error');
      if (mounted) {
        setState(() {
          _progressError =
              'Dein Fortschritt konnte noch nicht gespeichert werden. '
              'Prüfe deine Verbindung und versuche es erneut.';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _restoreDraft() async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
      _restoreFailed = false;
      _progressError = null;
    });
    try {
      final draft = await widget.progressRepository.loadDraft();
      if (draft == null) return;

      PlacementSession? session;
      if (draft.placementAnswers.isNotEmpty) {
        session = PlacementSession(
          startingLevel: LearningLevel.fromSelfAssessment(
            draft.testStartingLevel,
          ),
        );
        for (final answer in draft.placementAnswers) {
          if (session.currentQuestion.id != answer.questionId) {
            throw const FormatException(
              'Saved placement answers are not an adaptive path.',
            );
          }
          session.answer(answer.choiceId);
        }
      }
      if (!mounted) return;
      setState(() {
        _step = draft.step;
        _selectedGoals
          ..clear()
          ..addAll(draft.goals);
        _selectedMinutes = draft.dailyMinutes;
        _selectedLevel = draft.selectedLevel;
        _testStartingLevel = draft.testStartingLevel;
        _placementSession = session;
        _placementResult = draft.placementLevel == null
            ? null
            : PlacementResult(
                level: draft.placementLevel!,
                confidence: draft.placementConfidence ?? 0,
              );
        _selectedAnswer = null;
      });
      if (session?.isComplete == true && draft.step == 3) {
        await _scorePlacement();
      }
    } catch (error) {
      debugPrint('onboarding_draft_restore_failed $error');
      if (mounted) {
        setState(() {
          _restoreFailed = true;
          _progressError =
              'Dein gespeicherter Lernplan konnte nicht geladen werden.';
        });
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _continue() async {
    if (_isRestoring || _isSaving) return;
    if (_step < 2) {
      final nextStep = _step + 1;
      if (!await _saveDraft(_draft(step: nextStep)) || !mounted) return;
      setState(() => _step = nextStep);
      return;
    }
    if (_step == 2) {
      if (_selectedLevel == 3) {
        final session = PlacementSession(
          startingLevel: LearningLevel.fromSelfAssessment(_testStartingLevel),
        );
        if (!await _saveDraft(_draft(step: 3, placementAnswers: const [])) ||
            !mounted) {
          return;
        }
        _placementSession = session;
        _placementResult = null;
        _placementError = null;
        _selectedAnswer = null;
        setState(() => _step = 3);
      } else {
        if (!await _saveDraft(_draft(step: 4, placementAnswers: const [])) ||
            !mounted) {
          return;
        }
        setState(() {
          _placementResult = null;
          _step = 4;
        });
      }
      return;
    }
    if (_step == 3) {
      if (_placementError != null) {
        await _scorePlacement();
        return;
      }
      final session = _placementSession;
      final answer = _selectedAnswer;
      if (session == null || _isScoring) return;
      if (_progressError != null) {
        if (await _saveDraft(_draft(placementAnswers: session.answers)) &&
            mounted &&
            session.isComplete) {
          await _scorePlacement();
        }
        return;
      }
      if (session.isComplete && _placementError != null) {
        await _scorePlacement();
        return;
      }
      if (answer == null) return;
      session.answer(answer);
      if (session.isComplete) {
        if (!await _saveDraft(_draft(placementAnswers: session.answers)) ||
            !mounted) {
          return;
        }
        await _scorePlacement();
      } else {
        setState(() => _selectedAnswer = null);
        await _saveDraft(_draft(placementAnswers: session.answers));
      }
      return;
    }
    final level =
        _placementResult?.level ??
        LearningLevel.fromSelfAssessment(_selectedLevel);
    setState(() {
      _isSaving = true;
      _progressError = null;
    });
    try {
      await widget.progressRepository.completeOnboarding(
        draft: _draft(step: 4),
        level: level,
        placement: _placementResult,
      );
      if (mounted) context.go('/account');
    } catch (error) {
      debugPrint('onboarding_completion_failed $error');
      if (mounted) {
        setState(() {
          _progressError =
              'Dein Plan konnte noch nicht gespeichert werden. '
              'Prüfe deine Verbindung und versuche es erneut.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _scorePlacement() async {
    final session = _placementSession;
    if (session == null || !session.isComplete || _isScoring) return;

    setState(() {
      _isScoring = true;
      _placementError = null;
    });
    try {
      final result = await widget.placementEvaluator.evaluate(
        startingLevel: session.startingLevel,
        answers: List.unmodifiable(session.answers),
      );
      if (!mounted) return;
      setState(() {
        _placementResult = result;
        _step = 4;
      });
    } on FirebaseFunctionsException catch (error) {
      debugPrint('placement_evaluation_failed ${error.code}');
      if (!mounted) return;
      setState(() {
        _placementError =
            'Fritz konnte die Einstufung gerade nicht bestätigen. '
            'Versuche es noch einmal oder wähle dein Niveau selbst.';
      });
    } on FormatException {
      debugPrint('placement_evaluation_failed invalid_result');
      if (!mounted) return;
      setState(() {
        _placementError =
            'Die Einstufung ist unvollständig. Bitte versuche es noch einmal '
            'oder wähle dein Niveau selbst.';
      });
    } finally {
      if (mounted) setState(() => _isScoring = false);
    }
    if (_placementResult != null && mounted) {
      await _saveDraft(
        _draft(
          step: 4,
          placementAnswers: session.answers,
          placementResult: _placementResult,
        ),
      );
    }
  }

  Future<void> _goBack() async {
    if (_isSaving || _isRestoring) return;
    if (_step == 4) {
      if (!await _saveDraft(
            _draft(
              step: 2,
              placementAnswers: const [],
              placementResult: null,
              clearPlacementResult: true,
            ),
          ) ||
          !mounted) {
        return;
      }
      setState(() {
        _step = 2;
        _placementSession = null;
        _placementResult = null;
        _placementError = null;
      });
      return;
    }
    if (_step == 3) {
      if (!await _saveDraft(
            _draft(
              step: 2,
              placementAnswers: const [],
              clearPlacementResult: true,
            ),
          ) ||
          !mounted) {
        return;
      }
      setState(() {
        _step = 2;
        _placementSession = null;
        _selectedAnswer = null;
        _placementError = null;
      });
      return;
    }
    if (_step > 0) {
      final previousStep = _step - 1;
      if (!await _saveDraft(_draft(step: previousStep)) || !mounted) return;
      setState(() => _step = previousStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoreFailed) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 16),
                  LocalizedText(
                    _progressError!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _isRestoring ? null : _restoreDraft,
                    child: const LocalizedText('Erneut laden'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_isRestoring) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: WortwerkColors.ink),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_progressError case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: FlatCard(
                  color: const Color(0xFFFFE7E3),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: LocalizedText(error)),
                    ],
                  ),
                ),
              ),
            if (_step > 0) _progressHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _step == 0
                      ? _welcomeStep()
                      : _step == 1
                      ? _goalsStep()
                      : _step == 2
                      ? _placementStep()
                      : _step == 3
                      ? _quizStep()
                      : _planStep(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _isSaving ||
                          (_step == 1 && _selectedGoals.isEmpty) ||
                          _step == 3 &&
                              _selectedAnswer == null &&
                              _placementError == null &&
                              _progressError == null ||
                          _isScoring ||
                          _isRestoring
                      ? null
                      : _continue,
                  child: LocalizedText(
                    _step == 0
                        ? "Los geht's"
                        : _step == 4
                        ? 'Loslernen'
                        : _isSaving
                        ? 'Speichert …'
                        : _step == 3 && _placementError != null
                        ? 'Nochmal versuchen'
                        : _step == 3 && _isScoring
                        ? 'Einen Moment …'
                        : 'Weiter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            tooltip: 'Zurück',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(WortwerkRadii.pill),
              child: LinearProgressIndicator(
                value: _step / 4,
                minHeight: 6,
                backgroundColor: const Color(0x331E1D22),
                color: WortwerkColors.streak,
              ),
            ),
          ),
          const SizedBox(width: 12),
          LocalizedText(
            '$_step von 4',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _welcomeStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 42),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 196,
                  height: 196,
                  decoration: BoxDecoration(
                    color: WortwerkColors.a2,
                    shape: BoxShape.circle,
                    border: Border.all(color: WortwerkColors.ink, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const FritzAvatar(size: 146),
                ),
                const SizedBox(height: 32),
                LocalizedText(
                  'Hallo! Ich bin Fritz.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                LocalizedText(
                  'Dein Deutsch-Begleiter.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                LocalizedText(
                  'Kleine Schritte, jeden Tag, ohne Druck.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 26),
                const _WelcomePromise(
                  icon: Icons.favorite_border_rounded,
                  text: 'Lernen in deinem Tempo',
                ),
                const SizedBox(height: 10),
                const _WelcomePromise(
                  icon: Icons.spa_outlined,
                  text: 'Pausen sind Teil des Plans',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _goalsStep() {
    return _StepContent(
      title: 'Wofür lernst du Deutsch?',
      subtitle: 'Wähle alles aus, was zu dir passt.',
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final goal in _goals)
              FilterChip(
                label: LocalizedText(goal),
                selected: _selectedGoals.contains(goal),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGoals.add(goal);
                    } else {
                      _selectedGoals.remove(goal);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 30),
        LocalizedText(
          'Wie viel Zeit hast du am Tag?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in _minutes)
              ChoiceChip(
                label: LocalizedText('$minutes Min'),
                selected: _selectedMinutes == minutes,
                onSelected: (_) => setState(() => _selectedMinutes = minutes),
              ),
          ],
        ),
        const SizedBox(height: 18),
        LocalizedText(
          'Lieber wenig, aber regelmäßig. Du kannst das jederzeit ändern.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _placementStep() {
    return _StepContent(
      title: 'Wo stehst du gerade?',
      subtitle: 'Es gibt kein richtig oder falsch.',
      children: [
        for (var index = 0; index < _levels.length; index++) ...[
          _SelectableCard(
            selected: _selectedLevel == index,
            onTap: () => setState(() {
              _selectedLevel = index;
              _placementError = null;
            }),
            title: _levels[index].$1,
            description: _levels[index].$2,
            trailing: index == 3
                ? const Icon(Icons.auto_awesome_outlined)
                : null,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        if (_selectedLevel == 3) ...[
          LocalizedText(
            'Auf welchem Niveau möchtest du beginnen?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (var index = 0; index < 3; index++)
                ChoiceChip(
                  label: LocalizedText(LearningLevel.values[index].label),
                  selected: _testStartingLevel == index,
                  onSelected: (_) => setState(() => _testStartingLevel = index),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LocalizedText(
            'Fritz passt die nächsten 8 kurzen Fragen an deine Antworten an.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ] else
          LocalizedText(
            'Dein Lernplan passt sich an dich an – ganz ohne Prüfung.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }

  Widget _quizStep() {
    final session = _placementSession;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (session.isComplete) {
      return _StepContent(
        title: _placementError == null && _progressError == null
            ? 'Fritz wertet aus …'
            : 'Dein Ergebnis wartet.',
        subtitle: _placementError == null && _progressError == null
            ? 'Deine Antworten werden sicher eingeordnet.'
            : 'Deine Antworten sind noch da. Du kannst es erneut versuchen.',
        children: [
          if (_placementError == null && _progressError == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(color: WortwerkColors.ink),
              ),
            )
          else
            FlatCard(
              color: const Color(0xFFFFE7E3),
              child: LocalizedText(
                _placementError!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: WortwerkColors.ink),
              ),
            ),
          if (_placementError != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _placementSession = null;
                  _placementError = null;
                  _selectedLevel = 0;
                  _step = 2;
                }),
                child: const LocalizedText('Mein Niveau selbst auswählen'),
              ),
            ),
          ],
        ],
      );
    }
    final question = session.currentQuestion;
    return _StepContent(
      title: 'Teste mich, Fritz',
      subtitle:
          'Wir beginnen mit ${session.startingLevel.label}. '
          'Deine nächsten Fragen passen sich deinen Antworten an.',
      children: [
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(WortwerkRadii.pill),
          child: LinearProgressIndicator(
            value: session.questionNumber / PlacementQuestionBank.questionCount,
            minHeight: 7,
            backgroundColor: const Color(0x331E1D22),
            color: WortwerkColors.streak,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: LocalizedText(
                'Frage ${session.questionNumber} von ${PlacementQuestionBank.questionCount}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: WortwerkColors.a2,
                borderRadius: BorderRadius.all(
                  Radius.circular(WortwerkRadii.pill),
                ),
              ),
              child: LocalizedText(
                question.level.label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: WortwerkColors.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FlatCard(
          color: _levelColor(question.level),
          child: LocalizedText(
            question.prompt,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        for (final choice in question.choices) ...[
          _QuizOption(
            label: choice.label,
            selected: _selectedAnswer == choice.id,
            onTap: _isScoring
                ? null
                : () => setState(() {
                    _selectedAnswer = choice.id;
                    _placementError = null;
                  }),
          ),
          const SizedBox(height: 10),
        ],
        if (_isScoring) ...[
          const SizedBox(height: 6),
          const Center(
            child: CircularProgressIndicator(
              color: WortwerkColors.ink,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 8),
          LocalizedText(
            'Fritz erstellt deinen Lernplan …',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (_placementError case final error?) ...[
          const SizedBox(height: 4),
          FlatCard(
            color: const Color(0xFFFFE7E3),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: WortwerkColors.ink,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LocalizedText(
                    error,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: WortwerkColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _placementSession = null;
                _placementError = null;
                _selectedLevel = 0;
                _step = 2;
              }),
              child: const LocalizedText('Mein Niveau selbst auswählen'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _planStep() {
    final selectedGoals = _selectedGoals.isEmpty
        ? 'deine Ziele'
        : _selectedGoals.take(2).join(' & ');
    final result = _placementResult;
    final selectedStartingLevel = LearningLevel.fromSelfAssessment(
      _selectedLevel,
    );
    final startingLevel = result?.level ?? selectedStartingLevel;
    final startingPoint = '${startingLevel.label} · ${startingLevel.unitTitle}';
    return _StepContent(
      title: 'Dein Plan steht.',
      subtitle: result == null
          ? 'Ein guter Anfang, den du jederzeit anpassen kannst.'
          : 'Fritz hat deinen Startpunkt anhand deiner Antworten gefunden.',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: WortwerkColors.a2,
            borderRadius: BorderRadius.circular(WortwerkRadii.card),
            border: Border.all(color: WortwerkColors.ink, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                result == null ? 'DEIN START' : 'DEIN ERGEBNIS',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: WortwerkColors.ink, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              LocalizedText(
                startingPoint,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              LocalizedText('Alltag und Reisen – passend für $selectedGoals.'),
              if (result != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 19),
                    const SizedBox(width: 7),
                    Expanded(
                      child: LocalizedText(
                        'Einstufung abgeschlossen · ${(result.confidence * 100).round()}% der Antworten richtig',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 20),
                  const SizedBox(width: 8),
                  LocalizedText('$_selectedMinutes Minuten am Tag'),
                ],
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.spa_outlined, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: LocalizedText('Ein Ruhetag pro Woche ist erlaubt'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _WelcomePromise(
          icon: Icons.tune_rounded,
          text: 'Der Plan passt sich an dich an.',
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: widget.pushNotifications,
          builder: (context, _) {
            final strings = WortwerkLocalizations.of(context);
            final controller = widget.pushNotifications;
            return FlatCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notifications_active_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LocalizedText(
                              strings(WText.pushPromptTitle),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            LocalizedText(strings(WText.pushPromptBody)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: controller.isWorking
                        ? null
                        : () async {
                            if (controller.enabled) {
                              await controller.disable();
                            } else {
                              await controller.enable(strings.language.code);
                            }
                          },
                    icon: Icon(
                      controller.enabled
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    label: LocalizedText(
                      strings(
                        controller.enabled
                            ? WText.pushDisable
                            : WText.pushEnable,
                      ),
                    ),
                  ),
                  if (controller.problem case final problem?) ...[
                    const SizedBox(height: 8),
                    LocalizedText(
                      strings(_pushProblemText(problem)),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  WText _pushProblemText(PushNotificationProblem problem) => switch (problem) {
    PushNotificationProblem.unavailable => WText.pushUnavailable,
    PushNotificationProblem.permissionDenied => WText.pushPermissionDenied,
    PushNotificationProblem.tokenUnavailable => WText.pushTokenUnavailable,
    PushNotificationProblem.serverError => WText.pushServerError,
  };
}

final class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                LocalizedText(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                LocalizedText(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 26),
                ...children,
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _WelcomePromise extends StatelessWidget {
  const _WelcomePromise({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: WortwerkColors.streak),
        const SizedBox(width: 8),
        Flexible(
          child: LocalizedText(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

final class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.description,
    this.trailing,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? WortwerkColors.a2 : const Color(0xFFFFFEFC),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? WortwerkColors.ink : WortwerkColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    LocalizedText(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? WortwerkColors.ink : WortwerkColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _levelColor(LearningLevel level) => switch (level) {
  LearningLevel.a1 => WortwerkColors.a1,
  LearningLevel.a2 => WortwerkColors.a2,
  LearningLevel.b1 => WortwerkColors.b1,
};

final class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? WortwerkColors.ink : const Color(0xFFFFFEFC),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? WortwerkColors.ink : WortwerkColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: LocalizedText(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: selected ? Colors.white : WortwerkColors.ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20,
                color: selected ? Colors.white : WortwerkColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
