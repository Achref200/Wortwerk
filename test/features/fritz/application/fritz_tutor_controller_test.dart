import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/error/app_failure.dart';
import 'package:wortwerk/features/fritz/application/fritz_tutor_controller.dart';
import 'package:wortwerk/features/fritz/domain/fritz_message.dart';

final class _FakeFritzChatRepository implements FritzChatRepository {
  final StreamController<List<FritzMessage>> messages =
      StreamController<List<FritzMessage>>.broadcast();
  final List<
    ({String text, String mode, String threadId, String clientRequestId})
  >
  sent = [];
  final List<Object> outcomes = [];

  @override
  Stream<List<FritzMessage>> watchMessages({required String threadId}) =>
      messages.stream;

  @override
  Future<void> sendMessage({
    required String text,
    required String mode,
    required String threadId,
    required String clientRequestId,
  }) async {
    sent.add((
      text: text,
      mode: mode,
      threadId: threadId,
      clientRequestId: clientRequestId,
    ));
    if (outcomes.isEmpty) return;
    final outcome = outcomes.removeAt(0);
    if (outcome is Exception) throw outcome;
  }

  Future<void> close() => messages.close();
}

void main() {
  test('loads the server-owned thread stream', () async {
    final repository = _FakeFritzChatRepository();
    final controller = FritzTutorController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.close);

    expect(controller.isLoading, isTrue);
    repository.messages.add(const []);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isLoading, isFalse);
    expect(controller.hasMessages, isFalse);
  });

  test('retries a failed chat with its original id and mode', () async {
    final repository = _FakeFritzChatRepository()
      ..outcomes.add(
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'network unavailable',
        ),
      );
    final controller = FritzTutorController(
      repository: repository,
      threadId: 'lesson_practice',
    );
    addTearDown(controller.dispose);
    addTearDown(repository.close);

    await controller.send('Ich möchte üben.', mode: 'practice');

    expect(controller.sendFailure?.kind, AppFailureKind.network);
    expect(controller.messages, hasLength(1));
    expect(controller.messages.single.text, 'Ich möchte üben.');
    expect(repository.sent, hasLength(1));

    await controller.retrySend();

    expect(controller.sendFailure, isNull);
    expect(repository.sent, hasLength(2));
    expect(
      repository.sent[1].clientRequestId,
      repository.sent[0].clientRequestId,
    );
    expect(repository.sent[1].threadId, 'lesson_practice');
    expect(repository.sent[1].mode, 'practice');
    expect(controller.messages, isEmpty);
  });

  test(
    'uses Firestore messages and removes the optimistic duplicate',
    () async {
      final repository = _FakeFritzChatRepository();
      final controller = FritzTutorController(repository: repository);
      addTearDown(controller.dispose);
      addTearDown(repository.close);
      await controller.send('Guten Morgen!');

      final requestId = repository.sent.single.clientRequestId;
      repository.messages.add([
        FritzMessage(
          id: 'user_$requestId',
          requestId: requestId,
          role: FritzMessageRole.learner,
          text: 'Guten Morgen!',
          createdAt: DateTime.utc(2026),
        ),
        FritzMessage(
          id: 'assistant_$requestId',
          requestId: requestId,
          role: FritzMessageRole.tutor,
          text: 'Guten Morgen! Wie geht es dir?',
          createdAt: DateTime.utc(2026),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.messages, hasLength(2));
      expect(controller.messages.map((message) => message.role), [
        FritzMessageRole.learner,
        FritzMessageRole.tutor,
      ]);
    },
  );

  test('rejects overlong input without sending it', () async {
    final repository = _FakeFritzChatRepository();
    final controller = FritzTutorController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.close);

    await controller.send('a' * 1001);

    expect(controller.sendFailure?.kind, AppFailureKind.validation);
    expect(repository.sent, isEmpty);
  });

  test('lets the learner discard a failed message and continue', () async {
    final repository = _FakeFritzChatRepository()
      ..outcomes.add(
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'network unavailable',
        ),
      );
    final controller = FritzTutorController(repository: repository);
    addTearDown(controller.dispose);
    addTearDown(repository.close);

    await controller.send('Erste Nachricht');
    expect(controller.sendFailure, isNotNull);
    expect(controller.retryText, 'Erste Nachricht');

    controller.discardFailedSend();
    expect(controller.sendFailure, isNull);
    expect(controller.retryText, isNull);
    expect(controller.messages, isEmpty);

    await controller.send('Neue Nachricht');
    expect(repository.sent.map((request) => request.text), [
      'Erste Nachricht',
      'Neue Nachricht',
    ]);
  });
}
