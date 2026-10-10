import 'package:wortwerk/core/l10n/localized_text.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/pulse_halo.dart';
import '../../../core/state/async_resource.dart';
import '../../../design_system/components.dart';
import '../../../design_system/wortwerk_theme.dart';
import '../application/learning_path_controller.dart';
import '../domain/learning_path.dart';
import '../domain/learning_path_repository.dart';

final class LearningPathPage extends StatefulWidget {
  const LearningPathPage({required this.repository, super.key});

  final LearningPathRepository repository;

  @override
  State<LearningPathPage> createState() => _LearningPathPageState();
}

final class _LearningPathPageState extends State<LearningPathPage> {
  late final LearningPathController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LearningPathController(
      loadPath: LoadLearningPathUseCase(widget.repository),
    )..refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => _buildPath(context, _controller.state),
  );

  Widget _buildPath(BuildContext context, AsyncResource<LearningPath> state) {
    final path = switch (state) {
      ResourceData<LearningPath>(:final value) => value,
      ResourceLoading<LearningPath>(:final previousData) => previousData,
      ResourceOffline<LearningPath>(:final previousData) => previousData,
      ResourceFailure<LearningPath>(:final previousData) => previousData,
      _ => null,
    };
    if (path != null) return _buildLoadedPath(context, path);

    final body = switch (state) {
      ResourceIdle<LearningPath>() || ResourceLoading<LearningPath>() =>
        const WLoadingState(message: 'Dein Lernweg wird geladen.'),
      ResourceEmpty<LearningPath>() ||
      ResourceData<LearningPath>() => const WEmptyState(
        title: 'Dein Lernweg wird vorbereitet.',
        message: 'Ver\u00f6ffentlichte Lektionen erscheinen hier.',
      ),
      ResourceOffline<LearningPath>(:final failure) => WFailureState(
        failure: failure,
        title: 'Dein Lernweg ist gerade offline.',
        onRetry: _controller.refresh,
      ),
      ResourceFailure<LearningPath>(:final failure) => WFailureState(
        failure: failure,
        onRetry: _controller.refresh,
      ),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: body),
        ),
      ),
    );
  }

  Widget _buildLoadedPath(BuildContext context, LearningPath path) {
    final steps = <_PathStep>[];
    for (final level in path.levels) {
      for (final unit in level.units) {
        for (final lesson in unit.lessons) {
          steps.add(
            _PathStep(
              lessonId: lesson.id,
              unitId: unit.id,
              title: lesson.title,
              subtitle: unit.title,
              level: level.id,
              color: _levelColor(level.id),
              icon: Icons.school_outlined,
              available: unit.available,
              completed: lesson.completed,
              lockedBecauseLevel:
                  !unit.available &&
                  level.id != path.startingLevelId &&
                  !path.unlockedLevels.contains(level.id),
            ),
          );
        }
      }
    }
    _PathStep? nextLesson;
    for (final step in steps) {
      if (step.available && !step.completed) {
        nextLesson = step;
        break;
      }
    }
    if (nextLesson == null) {
      for (final step in steps.reversed) {
        if (step.available) {
          nextLesson = step;
          break;
        }
      }
    }
    nextLesson ??= steps.isEmpty ? null : steps.first;
    final targetLesson = nextLesson;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey<String>('learning-path-scroll'),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 128,
              title: const LocalizedText('Dein Lernweg'),
              actions: [
                IconButton(
                  tooltip: 'Lernweg aktualisieren',
                  onPressed: _controller.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: LocalizedText(
                      'Ein Weg, der mit jedem kleinen Schritt w\u00e4chst.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              sliver: SliverList.list(
                children: [
                  if (steps.isEmpty)
                    const WEmptyState(
                      title: 'Dein Lernweg wird vorbereitet.',
                      message:
                          'Ver\u00f6ffentlichte Lektionen erscheinen hier.',
                    )
                  else ...[
                    _PathProgressCard(
                      step: targetLesson!,
                      onPressed: () => targetLesson.available
                          ? _openLesson(context, targetLesson)
                          : _showLockedStep(context, targetLesson),
                    ),
                    const SizedBox(height: 24),
                    Eyebrow(
                      'DEIN WEG \u00b7 ${path.levels.map((level) => level.id).join(' \u00b7 ')}',
                    ),
                    const SizedBox(height: 10),
                    _WindingPath(
                      steps: steps,
                      onStepPressed: (step) => step.available
                          ? _openLesson(context, step)
                          : _showLockedStep(context, step),
                    ),
                    const SizedBox(height: 16),
                    _LevelUnlockProgressCard(
                      fromLevel: path.startingLevelId ?? path.levels.first.id,
                      progress:
                          path.progressByLevel[path.startingLevelId ??
                              path.levels.first.id] ??
                          const LearningLevelProgress(),
                      unlockedLevels: path.unlockedLevels,
                    ),
                    const SizedBox(height: 16),
                    const FlatCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            color: WortwerkColors.streak,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: LocalizedText(
                              'Hier erscheinen nur ver\u00f6ffentlichte Lektionen. Dein Lernweg w\u00e4chst mit den Inhalten.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(String levelId) => switch (levelId) {
    'A1' => WortwerkColors.a1,
    'A2' => WortwerkColors.a2,
    'B1' => WortwerkColors.b1,
    'B2' => WortwerkColors.b2,
    'C1' => WortwerkColors.c1,
    'C2' => WortwerkColors.c2,
    _ => WortwerkColors.paper,
  };

  void _openLesson(BuildContext context, _PathStep step) => context.pushNamed(
    'lesson',
    pathParameters: {'lessonId': step.lessonId},
    queryParameters: {'level': step.level, 'unit': step.unitId},
  );

  Future<void> _showLockedStep(BuildContext context, _PathStep step) {
    final appContext = context;
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(
                step.lockedBecauseLevel ? 'NÄCHSTES NIVEAU' : 'NÄCHSTE EINHEIT',
              ),
              const SizedBox(height: 8),
              LocalizedText(
                step.lockedBecauseLevel
                    ? 'Drei Lernschritte öffnen ${step.level}.'
                    : 'Beende zuerst die vorherige Einheit mit mindestens 60 %.',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              LocalizedText(
                step.lockedBecauseLevel
                    ? 'Behalte 70 % des Kernwortschatzes, führe drei Gespräche mit Fritz und bestehe eine Wiederholung mit mindestens 70 %.'
                    : 'Alle Lektionen der vorherigen Einheit müssen abgeschlossen sein.',
              ),
              const SizedBox(height: 16),
              if (step.lockedBecauseLevel) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      appContext.pushNamed('flashcards');
                    },
                    icon: const Icon(Icons.style_outlined),
                    label: const LocalizedText('Wörter wiederholen'),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    appContext.pushNamed('tutor');
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: const LocalizedText('Mit Fritz üben'),
                ),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const LocalizedText('Verstanden'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _LevelUnlockProgressCard extends StatelessWidget {
  const _LevelUnlockProgressCard({
    required this.fromLevel,
    required this.progress,
    required this.unlockedLevels,
  });

  final String fromLevel;
  final LearningLevelProgress progress;
  final Set<String> unlockedLevels;

  @override
  Widget build(BuildContext context) {
    final nextLevel = switch (fromLevel) {
      'A1' => 'A2',
      'A2' => 'B1',
      'B1' => 'B2',
      'B2' => 'C1',
      'C1' => 'C2',
      _ => null,
    };
    if (nextLevel == null) return const SizedBox.shrink();
    final isUnlocked = unlockedLevels.contains(nextLevel);
    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(isUnlocked ? '$nextLevel FREIGESCHALTET' : 'BIS $nextLevel'),
          const SizedBox(height: 6),
          LocalizedText(
            isUnlocked
                ? '$nextLevel ist bereit. Die Inhalte werden veröffentlicht.'
                : 'Drei kleine Schritte öffnen dein nächstes Niveau.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _UnlockCriterion(
            label: 'Wörter behalten',
            detail: progress.coreVocabularyCount == 0
                ? '0 % · Wortschatz wird vorbereitet'
                : '${progress.retainedWords}/${progress.coreVocabularyCount} Wörter · ${(progress.retentionRatio * 100).round()} %',
            value: progress.retentionRatio,
            complete: progress.retentionMet,
          ),
          const SizedBox(height: 12),
          _UnlockCriterion(
            label: 'Gespräche mit Fritz',
            detail: '${progress.fritzConversations.clamp(0, 3)}/3 Gespräche',
            value: (progress.fritzConversations / 3).clamp(0, 1),
            complete: progress.conversationsMet,
          ),
          const SizedBox(height: 12),
          _UnlockCriterion(
            label: 'Wiederholung bestehen',
            detail: progress.reviewMet
                ? 'Mindestens 70 % erreicht'
                : '1 Runde mit mindestens 70 %',
            value: progress.reviewMet ? 1 : 0,
            complete: progress.reviewMet,
          ),
        ],
      ),
    );
  }
}

final class _UnlockCriterion extends StatelessWidget {
  const _UnlockCriterion({
    required this.label,
    required this.detail,
    required this.value,
    required this.complete,
  });

  final String label;
  final String detail;
  final double value;
  final bool complete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18,
            color: complete ? WortwerkColors.success : WortwerkColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(child: LocalizedText(label)),
          LocalizedText(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: WortwerkColors.line,
          color: complete ? WortwerkColors.success : WortwerkColors.streak,
        ),
      ),
    ],
  );
}

final class _PathProgressCard extends StatelessWidget {
  const _PathProgressCard({required this.step, required this.onPressed});

  final _PathStep step;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Weiterlernen: ${step.title}',
    child: GestureDetector(
      onTap: onPressed,
      child: FlatCard(
        color: step.color,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const _PulsingStartMark(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('ALS N\u00c4CHSTES \u00b7 ${step.level}'),
                  const SizedBox(height: 4),
                  LocalizedText(
                    step.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  LocalizedText(
                    step.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    ),
  );
}

final class _PulsingStartMark extends StatelessWidget {
  const _PulsingStartMark();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0.82, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFEFC),
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: WortwerkColors.line)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.play_arrow_rounded, size: 30),
      ),
    );
  }
}

final class _PathStep {
  const _PathStep({
    required this.lessonId,
    required this.unitId,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.color,
    required this.icon,
    this.available = false,
    this.completed = false,
    this.lockedBecauseLevel = false,
  });

  final String lessonId;
  final String unitId;
  final String title;
  final String subtitle;
  final String level;
  final Color color;
  final IconData icon;
  final bool available;
  final bool completed;
  final bool lockedBecauseLevel;
}

final class _WindingPath extends StatefulWidget {
  const _WindingPath({required this.steps, required this.onStepPressed});

  final List<_PathStep> steps;
  final ValueChanged<_PathStep> onStepPressed;

  @override
  State<_WindingPath> createState() => _WindingPathState();
}

final class _WindingPathState extends State<_WindingPath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _journey = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  @override
  void dispose() {
    _journey.dispose();
    super.dispose();
  }

  static const _centers = <double>[0.28, 0.73, 0.34, 0.70];
  static const _rowHeight = 144.0;
  static const _nodeWidth = 204.0;
  static const _nodeHeight = 106.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (_journey.isAnimating) _journey.stop();
      _journey.value = 1;
    } else if (!_journey.isAnimating && _journey.value < 1) {
      _journey.forward();
    }
    // The current lesson is the first unfinished step — the same node the
    // progress card highlights — so the pulse marks exactly one destination
    // (SPEC §5.4). Falls back to the last step when everything is done.
    var currentIndex = widget.steps.indexWhere((step) => !step.completed);
    if (currentIndex < 0) {
      currentIndex = widget.steps.isEmpty ? -1 : widget.steps.length - 1;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final nodeWidth = math.min(_nodeWidth, width * 0.66).toDouble();
        final height = widget.steps.length * _rowHeight;
        final points = List<Offset>.generate(
          widget.steps.length,
          (index) => Offset(
            width * _centers[index % _centers.length],
            index * _rowHeight + _rowHeight / 2,
          ),
        );

        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 1050),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => AnimatedBuilder(
                    animation: _journey,
                    builder: (context, _) => RepaintBoundary(
                      child: CustomPaint(
                        painter: _PathPainter(
                          points: points,
                          progress: progress,
                          availableSteps: widget.steps
                              .where((step) => step.available)
                              .length,
                          travelerProgress: reduceMotion
                              ? 0.78
                              : _journey.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (var index = 0; index < widget.steps.length; index++)
                Positioned(
                  left: (points[index].dx - nodeWidth / 2)
                      .clamp(0.0, width - nodeWidth)
                      .toDouble(),
                  top: points[index].dy - _nodeHeight / 2,
                  width: nodeWidth,
                  height: _nodeHeight,
                  child: _PathNode(
                    key: ValueKey(
                      'path-node-${widget.steps[index].level}-${widget.steps[index].title}',
                    ),
                    step: widget.steps[index],
                    index: index,
                    isCurrent: index == currentIndex,
                    onPressed: () => widget.onStepPressed(widget.steps[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

final class _PathNode extends StatelessWidget {
  const _PathNode({
    required this.step,
    required this.index,
    required this.onPressed,
    this.isCurrent = false,
    super.key,
  });

  final _PathStep step;
  final int index;
  final VoidCallback onPressed;

  /// Marks the next-to-learn node with a breathing halo (SPEC §5.4).
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: 360 + index * 110),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - progress)),
          child: child,
        ),
      ),
      child: Semantics(
        button: true,
        label:
            '${step.level} ${step.title}. ${step.subtitle}. ${step.completed
                ? 'Abgeschlossen'
                : step.available
                ? 'Jetzt lernen'
                : 'Noch gesperrt'}',

        child: Material(
          color: step.color,
          borderRadius: BorderRadius.circular(WortwerkRadii.card),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(WortwerkRadii.card),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(WortwerkRadii.card),
                border: Border.all(
                  color: step.available
                      ? WortwerkColors.ink
                      : WortwerkColors.line,
                  width: step.available ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final mark = Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFEFC),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          step.completed
                              ? Icons.check_rounded
                              : step.available
                              ? step.icon
                              : Icons.lock_outline_rounded,
                          size: 21,
                        ),
                      );
                      if (!isCurrent) return mark;
                      // The breathing halo from the motion kit; it self-
                      // settles under reduced motion (SPEC §5.10). The
                      // SizedBox pins the layout to the mark so the 58 px
                      // halo paints outside without growing the node row.
                      return SizedBox.square(
                        dimension: 42,
                        child: PulseHalo(
                          color: WortwerkColors.streak,
                          haloSize: 58,
                          haloOpacity: 0.3,
                          child: mark,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('${step.level} · SCHRITT ${index + 1}'),
                        const SizedBox(height: 2),
                        LocalizedText(
                          step.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        LocalizedText(
                          step.completed
                              ? 'Abgeschlossen'
                              : step.available
                              ? 'Jetzt lernen'
                              : step.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: WortwerkColors.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PathPainter extends CustomPainter {
  const _PathPainter({
    required this.points,
    required this.progress,
    required this.availableSteps,
    required this.travelerProgress,
  });

  final List<Offset> points;
  final double progress;
  final int availableSteps;
  final double travelerProgress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final from = points[index - 1];
      final to = points[index];
      final controlY = (from.dy + to.dy) / 2;
      path.cubicTo(from.dx, controlY, to.dx, controlY, to.dx, to.dy);
    }

    final metrics = path.computeMetrics().toList();
    final totalLength = metrics.fold<double>(
      0,
      (length, metric) => length + metric.length,
    );
    var remaining = totalLength * progress;
    final visiblePath = Path();
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final length = math.min(remaining, metric.length);
      visiblePath.addPath(metric.extractPath(0, length), Offset.zero);
      remaining -= length;
    }

    canvas.drawPath(
      visiblePath,
      Paint()
        ..color = WortwerkColors.line
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    if (progress >= 1 && points.length > 1) {
      final activePath = Path()
        ..moveTo(points.first.dx, points.first.dy)
        ..cubicTo(
          points.first.dx,
          (points.first.dy + points[1].dy) / 2,
          points[1].dx,
          (points.first.dy + points[1].dy) / 2,
          points[1].dx,
          points[1].dy,
        );
      final metric = activePath.computeMetrics().first;
      final distance = metric.length * travelerProgress.clamp(0.12, 0.92);
      final tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        final point = tangent.position;
        final halo = Paint()
          ..shader = RadialGradient(
            colors: [
              WortwerkColors.streak.withValues(alpha: 0.34),
              WortwerkColors.streak.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: point, radius: 22));
        canvas.drawCircle(point, 22, halo);
        canvas.drawCircle(point, 6, Paint()..color = const Color(0xFFFFFEFC));
        canvas.drawCircle(point, 4, Paint()..color = WortwerkColors.streak);
      }
    }
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(
        points[index],
        5,
        Paint()
          ..color = index < availableSteps
              ? WortwerkColors.streak
              : WortwerkColors.muted.withValues(alpha: 0.42),
      );
    }
  }

  @override
  bool shouldRepaint(_PathPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.points != points ||
      oldDelegate.availableSteps != availableSteps ||
      oldDelegate.travelerProgress != travelerProgress;
}
