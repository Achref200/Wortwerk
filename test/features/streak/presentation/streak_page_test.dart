import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/animations/flame_controller.dart';
import 'package:wortwerk/features/secondary/presentation/secondary_pages.dart';
import 'package:wortwerk/features/streak/domain/learning_streak_summary.dart';

final class _FakeLearningStreakRepository implements LearningStreakRepository {
  _FakeLearningStreakRepository(this.stream);

  final Stream<LearningStreakSummary> stream;
  int requests = 0;

  @override
  Stream<LearningStreakSummary> watchSummary() {
    requests++;
    return stream;
  }
}

LearningStreakSummary _summary({
  int current = 0,
  int longest = 0,
  int shields = 2,
  int restWeekday = 0,
  Set<String> activeDayIds = const {},
  bool profileExists = true,
}) => LearningStreakSummary(
  current: current,
  longest: longest,
  shields: shields,
  restWeekday: restWeekday,
  activeDayIds: activeDayIds,
  profileExists: profileExists,
);

void main() {
  testWidgets('shows the honest first-day state and safe weekly rest day', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _FakeLearningStreakRepository(Stream.value(_summary()));
    await tester.pumpWidget(
      MaterialApp(home: StreakPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dein Lernrhythmus'), findsOneWidget);
    expect(
      find.text(
        'Dein erster Lerntag beginnt mit einer kurzen Einheit. '
        'Ein Ruhetag ist jede Woche eingeplant.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('SONNTAG'), findsOneWidget);
    expect(
      find.text(
        '0 von 7 aktiven Tagen · längster Rhythmus: 0 · '
        'Schutztage: 2',
      ),
      findsOneWidget,
    );
    expect(find.text('Eine Lektion beginnen'), findsOneWidget);
    expect(find.bySemanticsLabel('Mo, kein Lerntag'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('renders saved streak and active learning days', (tester) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime.now().toUtc();
    final dayId = _dayId(now);
    final repository = _FakeLearningStreakRepository(
      Stream.value(
        _summary(current: 3, longest: 5, shields: 1, activeDayIds: {dayId}),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: StreakPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lerntage in Folge'), findsOneWidget);
    expect(find.textContaining('1 von 7 aktiven Tagen'), findsOneWidget);
    const weekdayLabels = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
    expect(
      find.bySemanticsLabel(
        '${weekdayLabels[now.weekday % 7]}, heute, Lerntag',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('lights the flame and rolls the count from the saved streak', (
    tester,
  ) async {
    final repository = _FakeLearningStreakRepository(
      Stream.value(_summary(current: 4, longest: 4)),
    );
    await tester.pumpWidget(
      MaterialApp(home: StreakPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedStreakFlame), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('shows a retry action after a stream error', (tester) async {
    final controller = StreamController<LearningStreakSummary>.broadcast();
    final repository = _FakeLearningStreakRepository(controller.stream);
    await tester.pumpWidget(
      MaterialApp(home: StreakPage(repository: repository)),
    );
    await tester.pump();
    controller.addError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(
      find.text('Dein Lernrhythmus konnte gerade nicht geladen werden.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pump();
    expect(repository.requests, 2);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await controller.close();
  });
}

String _dayId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
