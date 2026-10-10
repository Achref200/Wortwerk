import 'package:wortwerk/core/l10n/localized_text.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../design_system/components.dart';
import '../../../design_system/wortwerk_theme.dart';
import '../domain/flashcard_review.dart';

final class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({
    required this.repository,
    required this.hapticService,
    super.key,
  });

  final FlashcardRepository repository;
  final HapticService hapticService;

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

final class _FlashcardsPageState extends State<FlashcardsPage> {
  int _index = 0;
  bool _showTranslation = false;
  bool? _remembered;
  bool _isSaving = false;
  String? _clientRequestId;
  String? _saveError;
  FlashcardReviewResult? _result;
  final List<FlashcardReviewAnswer> _answers = [];

  LearningFlashcard get _card => greetingFlashcards[_index];

  void _flipCard() {
    if (_isSaving || _result != null || _remembered != null) return;
    setState(() => _showTranslation = !_showTranslation);
    _emitHaptic(HapticEvent.select);
  }

  Future<void> _rateCard(bool remembered) async {
    if (!_showTranslation ||
        _isSaving ||
        _result != null ||
        _remembered != null) {
      return;
    }
    setState(() => _remembered = remembered);
    _emitHaptic(remembered ? HapticEvent.success : HapticEvent.select);
    await Future<void>.delayed(_motionDuration(context, 360));
    if (!mounted) return;

    _answers.add(
      FlashcardReviewAnswer(cardId: _card.id, remembered: remembered),
    );
    if (_index < greetingFlashcards.length - 1) {
      setState(() {
        _index++;
        _showTranslation = false;
        _remembered = null;
      });
      return;
    }
    await _saveReview();
  }

  Future<void> _saveReview() async {
    if (_isSaving || _answers.length != greetingFlashcards.length) return;
    _clientRequestId ??= _newClientRequestId();
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final result = await widget.repository.completeReview(
        answers: List.unmodifiable(_answers),
        clientRequestId: _clientRequestId!,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isSaving = false;
      });
    } catch (error) {
      debugPrint('flashcard_review_failed ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError =
            'Deine Wiederholung konnte nicht gespeichert werden. '
            'Deine Antworten sind noch da – versuche es erneut.';
      });
    }
  }

  String _newClientRequestId() {
    final random = Random.secure();
    final suffix = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'review_${DateTime.now().toUtc().microsecondsSinceEpoch}_$suffix';
  }

  void _emitHaptic(HapticEvent event) {
    unawaited(
      widget.hapticService.emit(event).catchError((Object error) {
        debugPrint('flashcard_haptic_failed ${error.runtimeType}');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const LocalizedText('Wörter üben'),
        actions: [
          if (result == null)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: LocalizedText(
                  'A1',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: result == null
                  ? _buildReview(context)
                  : _buildCompletion(context, result),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final questionNumber = _index + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            LocalizedText(
              'KARTE $questionNumber VON ${greetingFlashcards.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            LocalizedText(
              '${_answers.where((answer) => answer.remembered).length} sicher',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label:
              'Wortschatzfortschritt, Karte $questionNumber von ${greetingFlashcards.length}',
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: questionNumber / greetingFlashcards.length),
            duration: _motionDuration(context, 360),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                LinearProgressIndicator(value: value),
          ),
        ),
        const SizedBox(height: 26),
        LocalizedText(
          _showTranslation
              ? 'Erinnere dich: Was bedeutet das Wort?'
              : 'Denk erst nach – tippe dann zum Umdrehen.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 0.94,
              child: _ReviewCard(
                key: ValueKey(_card.id),
                card: _card,
                showTranslation: _showTranslation,
                remembered: _remembered,
                onTap: _flipCard,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_showTranslation)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving || _remembered != null
                      ? null
                      : () => _rateCard(false),
                  icon: const Icon(Icons.replay_rounded),
                  label: const LocalizedText('Nochmal'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: WortwerkColors.ink,
                    disabledForegroundColor: WortwerkColors.ink,
                    backgroundColor: _remembered == false
                        ? WortwerkColors.c1
                        : null,
                    disabledBackgroundColor: _remembered == false
                        ? WortwerkColors.c1
                        : null,
                    side: const BorderSide(color: WortwerkColors.c1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving || _remembered != null
                      ? null
                      : () => _rateCard(true),
                  icon: const Icon(Icons.check_rounded),
                  label: const LocalizedText('Gewusst'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: WortwerkColors.success,
                    disabledBackgroundColor: WortwerkColors.success,
                    foregroundColor: WortwerkColors.ink,
                    disabledForegroundColor: WortwerkColors.ink,
                  ),
                ),
              ),
            ],
          )
        else
          FilledButton.icon(
            onPressed: _flipCard,
            icon: const Icon(Icons.flip_rounded),
            label: const LocalizedText('Karte umdrehen'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        if (_saveError case final error?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: LocalizedText(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.tonal(
            onPressed: _isSaving ? null : _saveReview,
            child: const LocalizedText('Erneut speichern'),
          ),
        ],
        if (_isSaving) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            label: 'Wiederholung wird gespeichert',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                LocalizedText('Dein Lernfortschritt wird gespeichert …'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletion(BuildContext context, FlashcardReviewResult result) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? 1 : 0.82, end: 1),
        duration: _motionDuration(context, 700),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 62,
                color: WortwerkColors.streak,
              ),
            ),
            const SizedBox(height: 18),
            LocalizedText(
              'Wiederholung geschafft!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            LocalizedText(
              '${result.reviewedCount} Wörter angeschaut · '
              '${result.rememberedCount} sicher erinnert',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            FlatCard(
              color: WortwerkColors.c2,
              child: Column(
                children: [
                  LocalizedText(
                    '+${result.xpAwarded} XP',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    'Gespeichert · Deine Karten haben jetzt einen '
                    'persönlichen Wiederholungsrhythmus.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const LocalizedText('Zurück zum Lernweg'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go('/lesson/a1_greetings'),
              child: const LocalizedText('Eine Lektion starten'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.card,
    required this.showTranslation,
    required this.remembered,
    required this.onTap,
    super.key,
  });

  final LearningFlashcard card;
  final bool showTranslation;
  final bool? remembered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      label: [
        if (showTranslation) ...[
          'Karte ${card.german}: ${card.translation}',
          if (remembered == true) 'Gut erinnert',
          if (remembered == false) 'Kommt bald wieder',
        ] else
          'Karte ${card.german}. Tippe, um die Übersetzung zu sehen.',
      ].join('. '),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: showTranslation ? pi : 0),
        duration: _motionDuration(context, 520),
        curve: Curves.easeInOutCubic,
        builder: (context, angle, _) {
          final showingBack = angle >= pi / 2;
          final face = _CardFace(
            card: card,
            showingBack: showingBack,
            remembered: remembered,
            onTap: onTap,
          );
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateY(reduceMotion ? 0 : angle),
            child: showingBack && !reduceMotion
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: face,
                  )
                : face,
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
}

final class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.showingBack,
    required this.remembered,
    required this.onTap,
  });

  final LearningFlashcard card;
  final bool showingBack;
  final bool? remembered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = remembered == true
        ? WortwerkColors.success
        : remembered == false
        ? WortwerkColors.c1
        : showingBack
        ? const Color(0xFFFFFEFC)
        : card.color;
    final statusIcon = !showingBack
        ? Icons.touch_app_outlined
        : remembered == true
        ? Icons.check_circle_rounded
        : remembered == false
        ? Icons.replay_rounded
        : Icons.check_circle_outline_rounded;
    final statusText = !showingBack
        ? 'Tippe zum Umdrehen'
        : remembered == true
        ? 'Gut erinnert · kommt später wieder'
        : remembered == false
        ? 'Kommt bald wieder · in deinem Tempo'
        : 'Sag es einmal laut.';
    return AnimatedContainer(
      duration: _motionDuration(context, 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(WortwerkRadii.card),
        border: Border.all(
          color: remembered == null && showingBack
              ? WortwerkColors.streak
              : WortwerkColors.ink,
          width: remembered == null && showingBack ? 2 : 1.3,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(WortwerkRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(WortwerkRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 330;
                final wordSize = (constraints.maxWidth * 0.15).clamp(
                  24.0,
                  40.0,
                );
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Eyebrow(
                          showingBack
                              ? 'BEDEUTUNG'
                              : card.partOfSpeech.toUpperCase(),
                        ),
                        SizedBox(height: compact ? 12 : 20),
                        LocalizedText(
                          showingBack ? card.translation : card.german,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(fontSize: wordSize),
                        ),
                        SizedBox(height: compact ? 12 : 22),
                        AnimatedSwitcher(
                          duration: _motionDuration(context, 180),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                          child: Icon(
                            statusIcon,
                            key: ValueKey(statusIcon),
                            size: 25,
                            color: WortwerkColors.ink,
                          ),
                        ),
                        SizedBox(height: compact ? 6 : 10),
                        AnimatedSwitcher(
                          duration: _motionDuration(context, 180),
                          child: LocalizedText(
                            statusText,
                            key: ValueKey(statusText),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: WortwerkColors.ink,
                                  fontSize: compact ? 12 : null,
                                  fontWeight: remembered == null
                                      ? FontWeight.normal
                                      : FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Duration _motionDuration(BuildContext context, int milliseconds) =>
    MediaQuery.of(context).disableAnimations
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
