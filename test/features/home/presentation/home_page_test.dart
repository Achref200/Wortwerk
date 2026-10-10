import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/animated_counter.dart';
import 'package:wortwerk/design_system/streak_flame.dart';
import 'package:wortwerk/design_system/wortwerk_theme.dart';
import 'package:wortwerk/features/home/presentation/home_page.dart';
import 'package:wortwerk/features/streak/domain/learning_streak_summary.dart';
import 'package:wortwerk/features/missions/domain/daily_missions.dart';

final class _StreakRepository implements LearningStreakRepository {
  _StreakRepository(Stream<LearningStreakSummary> stream)
    : stream = stream.asBroadcastStream();

  final Stream<LearningStreakSummary> stream;

  @override
  Stream<LearningStreakSummary> watchSummary() => stream;
}

final class _RetryStreakRepository implements LearningStreakRepository {
  _RetryStreakRepository(this.firstStream, this.recoveredSummary);

  final Stream<LearningStreakSummary> firstStream;
  final LearningStreakSummary recoveredSummary;
  int calls = 0;

  @override
  Stream<LearningStreakSummary> watchSummary() =>
      calls++ == 0 ? firstStream : Stream.value(recoveredSummary);
}

final class _DailyMissionsRepository implements DailyMissionsRepository {
  _DailyMissionsRepository(this.stream);
  final Stream<DailyMissions> stream;
  @override
  Stream<DailyMissions> watchToday() => stream;
}

final class _RetryMissionsRepository implements DailyMissionsRepository {
  int calls = 0;

  @override
  Stream<DailyMissions> watchToday() => calls++ == 0
      ? Stream.error(StateError('private mission backend detail'))
      : Stream.value(_missions());
}

DailyMissions _missions({bool complete = false}) => DailyMissions(
  date: '2026-10-09',
  focusGoal: 'Reisen',
  earnedXp: complete ? 70 : 0,
  tasks: [
    DailyMission(
      kind: DailyMissionKind.lesson,
      title: 'Eine Lektion abschließen',
      progress: complete ? 1 : 0,
      target: 1,
      xp: 20,
      completed: complete,
    ),
    DailyMission(
      kind: DailyMissionKind.review,
      title: '10 Wörter wiederholen',
      progress: complete ? 1 : 0,
      target: 1,
      xp: 20,
      completed: complete,
    ),
    DailyMission(
      kind: DailyMissionKind.fritz,
      title: 'Mit Fritz sprechen',
      progress: complete ? 1 : 0,
      target: 1,
      xp: 30,
      completed: complete,
    ),
  ],
);

void main() {
  testWidgets('shows a loading state before daily progress arrives', (
    tester,
  ) async {
    final controller = StreamController<LearningStreakSummary>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: WortwerkTheme.light,
        home: HomePage(
          streakRepository: _StreakRepository(controller.stream),
          missionsRepository: _DailyMissionsRepository(
            Stream.value(_missions()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    expect(
      find.bySemanticsLabel('Dein Tagesfortschritt wird geladen'),
      findsOneWidget,
    );
  });

  testWidgets('renders server-backed daily streak and activity progress', (
    tester,
  ) async {
    final summary = LearningStreakSummary(
      current: 3,
      longest: 5,
      shields: 2,
      restWeekday: 0,
      activeDayIds: const {},
      profileExists: true,
      lessonsCompletedToday: 1,
      flashcardsReviewedToday: 5,
      xpEarnedToday: 24,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: WortwerkTheme.light,
        home: HomePage(
          streakRepository: _StreakRepository(Stream.value(summary)),
          missionsRepository: _DailyMissionsRepository(
            Stream.value(_missions()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('Lerntage in Folge'), findsOneWidget);
    expect(find.text('+24 XP'), findsOneWidget);
    expect(find.text('heute · Pausen sind okay.'), findsOneWidget);
    expect(find.byType(StreakFlame), findsOneWidget);
    expect(find.byType(AnimatedCounter), findsOneWidget);
    expect(find.byType(RollingDigits), findsOneWidget);
    expect(find.text('Kleine Ziele für heute'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Eine Lektion abschließen'), findsNWidgets(2));
    expect(find.text('10 Wörter wiederholen'), findsNWidgets(2));
    expect(find.text('Deine Missionen'), findsOneWidget);
    expect(find.text('Mit Fritz sprechen'), findsOneWidget);
    expect(find.textContaining('Heute im Fokus:'), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
    final progress = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(progress.map((bar) => bar.value), containsAll([1, 0.5]));
  });

  testWidgets('retries an unavailable daily summary', (tester) async {
    final controller = StreamController<LearningStreakSummary>();
    addTearDown(controller.close);
    final repository = _RetryStreakRepository(
      controller.stream,
      LearningStreakSummary(
        current: 1,
        longest: 1,
        shields: 0,
        restWeekday: 0,
        activeDayIds: const {},
        profileExists: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: WortwerkTheme.light,
        home: HomePage(
          streakRepository: repository,
          missionsRepository: _DailyMissionsRepository(
            Stream.value(_missions()),
          ),
        ),
      ),
    );
    controller.addError(StateError('private backend details'));
    await tester.pump();

    expect(find.text('private backend details'), findsNothing);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Lerntag in Folge'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('daily missions show a safe retry and recover', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final missionsRepository = _RetryMissionsRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: WortwerkTheme.light,
        home: HomePage(
          streakRepository: _StreakRepository(
            Stream.value(
              LearningStreakSummary(
                current: 0,
                longest: 0,
                shields: 2,
                restWeekday: 0,
                activeDayIds: const {},
                profileExists: true,
              ),
            ),
          ),
          missionsRepository: missionsRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Deine Tagesmissionen sind gerade nicht verfügbar.'),
      findsOneWidget,
    );
    expect(find.textContaining('private mission backend detail'), findsNothing);
    await tester.ensureVisible(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.text('Deine Missionen'), findsOneWidget);
    expect(missionsRepository.calls, 2);
  });

  testWidgets('celebrates completion and makes extra practice optional', (
    tester,
  ) async {
    final summary = LearningStreakSummary(
      current: 2,
      longest: 2,
      shields: 2,
      restWeekday: 0,
      activeDayIds: const {},
      profileExists: true,
      lessonsCompletedToday: 1,
      flashcardsReviewedToday: 10,
      xpEarnedToday: 30,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: WortwerkTheme.light,
        home: HomePage(
          streakRepository: _StreakRepository(Stream.value(summary)),
          missionsRepository: _DailyMissionsRepository(
            Stream.value(_missions(complete: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zwei Lernschritte erledigt.'), findsOneWidget);
    expect(find.textContaining('freiwillige Zusatzrunde'), findsOneWidget);
    expect(find.text('Alle Missionen geschafft · +70 XP'), findsOneWidget);
    expect(find.text('Eine Lektion abschließen'), findsOneWidget);
    expect(find.text('10 Wörter wiederholen'), findsOneWidget);
  });
}
