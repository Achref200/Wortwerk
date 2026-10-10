import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/notifications/domain/inbox_notification.dart';
import 'package:wortwerk/features/notifications/domain/notifications_repository.dart';
import 'package:wortwerk/features/notifications/presentation/notifications_page.dart';

void main() {
  testWidgets('shows the live inbox and marks an item read when swiped', (
    tester,
  ) async {
    final repository = _MemoryNotificationsRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: NotificationsPage(repository: repository)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.publish([
      InboxNotification(
        id: 'level-unlocked_a2',
        kind: InboxNotificationKind.levelUnlocked,
        level: 'A2',
        deepLink: '/path',
        createdAt: DateTime.now(),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Ein neues Niveau ist offen'), findsOneWidget);
    expect(
      find.text(
        'Du hast A2 freigeschaltet. Sieh dir deinen nächsten Lernweg an.',
      ),
      findsOneWidget,
    );
    expect(find.text('HEUTE'), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(repository.markedRead, ['level-unlocked_a2']);
  });

  testWidgets('shows retry without exposing backend error details', (
    tester,
  ) async {
    final repository = _MemoryNotificationsRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: NotificationsPage(repository: repository)),
    );
    repository.fail(StateError('private Firestore detail'));
    await tester.pumpAndSettle();

    expect(
      find.text('Deine Hinweise konnten gerade nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.textContaining('private Firestore detail'), findsNothing);
    expect(find.text('Erneut versuchen'), findsOneWidget);

    await tester.tap(find.text('Erneut versuchen'));
    await tester.pump();
    expect(repository.watchCount, 2);
  });

  testWidgets('keeps cached inbox items visible after a stream error', (
    tester,
  ) async {
    final repository = _MemoryNotificationsRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: NotificationsPage(repository: repository)),
    );
    repository.publish([
      InboxNotification(
        id: 'level-unlocked_a2',
        kind: InboxNotificationKind.levelUnlocked,
        level: 'A2',
        createdAt: DateTime.now(),
      ),
    ]);
    await tester.pumpAndSettle();
    repository.fail(StateError('transient network error'));
    await tester.pumpAndSettle();

    expect(find.text('Ein neues Niveau ist offen'), findsOneWidget);
    expect(
      find.text('Deine Hinweise konnten gerade nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.textContaining('transient network error'), findsNothing);
  });
}

final class _MemoryNotificationsRepository implements NotificationsRepository {
  final StreamController<List<InboxNotification>> _controller =
      StreamController<List<InboxNotification>>.broadcast();
  final List<String> markedRead = [];
  int watchCount = 0;

  @override
  Stream<List<InboxNotification>> watchInbox() {
    watchCount++;
    return _controller.stream;
  }

  @override
  Future<void> markRead(String notificationId) async {
    markedRead.add(notificationId);
  }

  @override
  Future<bool> pushEnabled() async => false;

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    required String language,
  }) async {}

  @override
  Future<void> disablePush() async {}

  void publish(List<InboxNotification> notifications) =>
      _controller.add(notifications);

  void fail(Object error) => _controller.addError(error);

  Future<void> dispose() => _controller.close();
}
