enum FritzMessageRole { learner, tutor }

final class FritzMessage {
  const FritzMessage({
    required this.id,
    required this.requestId,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final FritzMessageRole role;
  final String text;
  final DateTime createdAt;

  factory FritzMessage.fromFirestore(String id, Map<String, dynamic> data) {
    final rawRole = data['role'];
    final requestId = data['clientRequestId'];
    final text = data['text'];
    final createdAt = data['createdAt'];
    if ((rawRole != 'user' && rawRole != 'assistant') ||
        requestId is! String ||
        text is! String ||
        text.isEmpty ||
        createdAt is! DateTime) {
      throw const FormatException('Die Fritz-Nachricht ist ungültig.');
    }
    return FritzMessage(
      id: id,
      requestId: requestId,
      role: rawRole == 'user'
          ? FritzMessageRole.learner
          : FritzMessageRole.tutor,
      text: text,
      createdAt: createdAt,
    );
  }
}

abstract interface class FritzChatRepository {
  Stream<List<FritzMessage>> watchMessages({required String threadId});

  Future<void> sendMessage({
    required String text,
    required String mode,
    required String threadId,
    required String clientRequestId,
  });
}
