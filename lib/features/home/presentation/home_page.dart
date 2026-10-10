import 'package:wortwerk/core/l10n/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/animated_counter.dart';
import '../../../core/animations/pressable_scale.dart';
import '../../../design_system/components.dart';
import '../../../design_system/fritz_avatar.dart';
import '../../../design_system/streak_flame.dart';
import '../../../design_system/wortwerk_theme.dart';
import '../../streak/domain/learning_streak_summary.dart';
import '../../missions/domain/daily_missions.dart';

final class HomePage extends StatelessWidget {
  const HomePage({
    required this.streakRepository,
    required this.missionsRepository,
    super.key,
  });

  final LearningStreakRepository streakRepository;
  final DailyMissionsRepository missionsRepository;

  @override
  Widget build(BuildContext context) {
    return ScreenContent(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Schön, dass du da bist'),
                  const SizedBox(height: 5),
                  LocalizedText(
                    'Ein kleiner Schritt?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            CircleAction(
              icon: Icons.notifications_none_rounded,
              label: 'Benachrichtigungen',
              onPressed: () => context.push('/notifications'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _HomeProgressPanel(repository: streakRepository),
        const SizedBox(height: 16),
        _HomeDailyMissions(repository: missionsRepository),
        const SizedBox(height: 24),
        SectionHeading(
          title: 'Dein nächster Schritt',
          trailing: 'Dein Weg',
          onTrailingPressed: () => context.go('/path'),
        ),
        const SizedBox(height: 12),
        _LessonCard(onPressed: () => context.push('/lesson/a1_greetings')),
        const SizedBox(height: 24),
        const SectionHeading(title: 'Lernen, wie es dir passt'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                color: WortwerkColors.a1,
                icon: Icons.style_outlined,
                title: 'Wörter üben',
                description: 'Mit Karteikarten',
                onPressed: () => context.push('/flashcards'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                color: WortwerkColors.b2,
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Sprechen',
                description: 'Mit Fritz',
                onPressed: () => context.push('/tutor'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        FlatCard(
          color: const Color(0xFFFFFEFC),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.spa_outlined,
                color: WortwerkColors.streak,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      'Pausen gehören dazu.',
                      style: WortwerkTypography.handwritten,
                    ),
                    const SizedBox(height: 5),
                    LocalizedText(
                      'Ein Ruhetag pro Woche ist erlaubt. Dein Lernweg wartet auf dich.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _HomeDailyMissions extends StatefulWidget {
  const _HomeDailyMissions({required this.repository});

  final DailyMissionsRepository repository;

  @override
  State<_HomeDailyMissions> createState() => _HomeDailyMissionsState();
}

final class _HomeDailyMissionsState extends State<_HomeDailyMissions> {
  late Stream<DailyMissions> _missions;

  @override
  void initState() {
    super.initState();
    _missions = widget.repository.watchToday();
  }

  void _retry() => setState(() => _missions = widget.repository.watchToday());

  void _openMission(BuildContext context, DailyMissionKind kind) {
    switch (kind) {
      case DailyMissionKind.lesson:
        context.push('/lesson/a1_greetings');
      case DailyMissionKind.review:
        context.push('/flashcards');
      case DailyMissionKind.fritz:
        context.push('/tutor');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DailyMissions>(
    stream: _missions,
    builder: (context, snapshot) {
      if (snapshot.hasError && !snapshot.hasData) {
        return FlatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Deine Tagesmissionen sind gerade nicht verfügbar.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        );
      }
      final missions = snapshot.data;
      if (missions == null) {
        return FlatCard(
          child: Semantics(
            liveRegion: true,
            label: 'Tagesmissionen werden geladen',
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );
      }
      return FlatCard(
        key: ValueKey('daily-missions-${missions.date}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Deine Missionen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${missions.completedCount}/${missions.tasks.length}'),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Heute im Fokus: ${missions.focusGoal}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < missions.tasks.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _DailyMissionRow(
                mission: missions.tasks[index],
                onPressed: () =>
                    _openMission(context, missions.tasks[index].kind),
              ),
            ],
            if (missions.isComplete) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Alle Missionen geschafft · +${missions.earnedXp} XP',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

final class _DailyMissionRow extends StatelessWidget {
  const _DailyMissionRow({required this.mission, required this.onPressed});

  final DailyMission mission;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final progress = (mission.progress / mission.target).clamp(0.0, 1.0);
    return Semantics(
      button: !mission.completed,
      label:
          '${mission.title}, ${mission.completed ? 'abgeschlossen' : 'offen'}',
      value: '${(progress * 100).round()} Prozent, ${mission.xp} XP',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: mission.completed ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  mission.completed
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: mission.completed
                      ? WortwerkColors.success
                      : WortwerkColors.streak,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(mission.title)),
                SizedBox(
                  width: 40,
                  child: LinearProgressIndicator(value: progress),
                ),
                const SizedBox(width: 8),
                Text('+${mission.xp}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _HomeProgressPanel extends StatefulWidget {
  const _HomeProgressPanel({required this.repository});

  final LearningStreakRepository repository;

  @override
  State<_HomeProgressPanel> createState() => _HomeProgressPanelState();
}

final class _HomeProgressPanelState extends State<_HomeProgressPanel> {
  late Stream<LearningStreakSummary> _summaryStream;

  @override
  void initState() {
    super.initState();
    _summaryStream = widget.repository.watchSummary();
  }

  void _retry() {
    setState(() => _summaryStream = widget.repository.watchSummary());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LearningStreakSummary>(
      stream: _summaryStream,
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return FlatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: const LocalizedText(
                    'Dein Tagesfortschritt ist gerade nicht verfügbar.',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const LocalizedText('Erneut versuchen'),
                ),
              ],
            ),
          );
        }
        final summary = snapshot.data;
        if (summary == null) {
          return FlatCard(
            child: Semantics(
              liveRegion: true,
              label: 'Dein Tagesfortschritt wird geladen',
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          );
        }
        final done =
            (summary.lessonsCompletedToday > 0 ? 1 : 0) +
            (summary.flashcardsReviewedToday >= 10 ? 1 : 0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PressableScale(
              onPressed: () => context.push('/streak'),
              semanticsLabel: 'Streak und Tagesfortschritt öffnen',
              child: FlatCard(
                color: WortwerkColors.c2,
                child: Row(
                  children: [
                    const StreakFlame(size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RollingDigits(
                                value: summary.current,
                                style: Theme.of(context).textTheme.titleMedium,
                                semanticsLabel: '${summary.current}',
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: LocalizedText(
                                  summary.current == 1
                                      ? 'Lerntag in Folge'
                                      : 'Lerntage in Folge',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              AnimatedCounter(
                                value: summary.xpEarnedToday,
                                prefix: '+',
                                suffix: ' XP',
                                style: Theme.of(context).textTheme.bodyMedium,
                                semanticsLabel:
                                    '${summary.xpEarnedToday} XP heute',
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: LocalizedText(
                                  'heute · Pausen sind okay.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 360),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.035),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: done == 2
                  ? FlatCard(
                      key: const ValueKey('daily-goals-complete'),
                      color: WortwerkColors.b2,
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LocalizedText(
                                  'Zwei Lernschritte erledigt.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 4),
                                LocalizedText(
                                  'Deine Missionen zeigen, was heute noch offen ist. Eine Pause oder freiwillige Zusatzrunde ist auch okay.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => context.push('/flashcards'),
                            tooltip: 'Freiwillig weiterüben',
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                    )
                  : FlatCard(
                      key: const ValueKey('daily-goals-progress'),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: LocalizedText(
                                  'Kleine Ziele für heute',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              LocalizedText('$done / 2'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _TodayTask(
                            title: 'Eine Lektion abschließen',
                            progress: summary.lessonsCompletedToday > 0 ? 1 : 0,
                            onPressed: () =>
                                context.push('/lesson/a1_greetings'),
                          ),
                          const SizedBox(height: 8),
                          _TodayTask(
                            title: '10 Wörter wiederholen',
                            progress: (summary.flashcardsReviewedToday / 10)
                                .clamp(0.0, 1.0),
                            onPressed: () => context.push('/flashcards'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

final class _TodayTask extends StatelessWidget {
  const _TodayTask({
    required this.title,
    required this.progress,
    required this.onPressed,
  });

  final String title;
  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final complete = progress >= 1;
    return Semantics(
      button: true,
      label: title + (complete ? ', abgeschlossen' : ', offen'),
      value: complete
          ? 'Erledigt'
          : 'Fortschritt: ${(progress * 100).round()} Prozent',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Icon(
                complete ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: complete
                    ? WortwerkColors.success
                    : WortwerkColors.streak,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LocalizedText(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 54,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) =>
                      LinearProgressIndicator(value: value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      color: WortwerkColors.a2,
      padding: const EdgeInsets.fromLTRB(20, 20, 14, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFEFC),
                    borderRadius: BorderRadius.all(
                      Radius.circular(WortwerkRadii.pill),
                    ),
                  ),
                  child: const LocalizedText(
                    'A1 · EINHEIT 1',
                    style: TextStyle(
                      color: WortwerkColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LocalizedText(
                  'Begrüßungen',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 5),
                LocalizedText(
                  'Hallo sagen und sich vorstellen',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: WortwerkColors.ink),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const LocalizedText('Lektion beginnen'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const FritzAvatar(size: 84),
        ],
      ),
    );
  }
}

final class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(WortwerkRadii.card),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(WortwerkRadii.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 138),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WortwerkRadii.card),
            border: Border.all(color: WortwerkColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 23),
              const SizedBox(height: 18),
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
      ),
    );
  }
}
