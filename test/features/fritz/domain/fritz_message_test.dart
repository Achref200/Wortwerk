import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/features/fritz/domain/fritz_message.dart';

void main() {
  test('maps a persisted tutor message without accepting malformed data', () {
    final message = FritzMessage.fromFirestore('assistant_request_12345678', {
      'role': 'assistant',
      'text': 'Guten Morgen!',
      'clientRequestId': 'request_12345678',
      'createdAt': DateTime.utc(2026, 10, 7),
    });

    expect(message.role, FritzMessageRole.tutor);
    expect(message.text, 'Guten Morgen!');
    expect(message.requestId, 'request_12345678');
    expect(
      () => FritzMessage.fromFirestore('bad', const {}),
      throwsFormatException,
    );
  });
}
