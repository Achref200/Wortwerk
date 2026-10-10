import 'dart:math';

final class LearningGroup {
  const LearningGroup({
    required this.id,
    required this.name,
    required this.topic,
    required this.level,
    required this.memberCount,
    this.lastMessage,
  });

  final String id;
  final String name;
  final String topic;
  final String level;
  final int memberCount;
  final String? lastMessage;
}

final class CommunityMessage {
  const CommunityMessage({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String displayName;
  final String body;
  final DateTime createdAt;
}

abstract interface class CommunityRepository {
  Stream<List<LearningGroup>> watchGroups();

  Stream<Set<String>> watchJoinedGroupIds();

  Stream<LearningGroup?> watchGroup(String groupId);

  Stream<bool> watchMembership(String groupId);

  Stream<Set<String>> watchBlockedUids();

  Stream<List<CommunityMessage>> watchMessages(String groupId);

  String get currentUid;

  Future<void> joinGroup(String groupId);

  Future<void> leaveGroup(String groupId);

  Future<String> sendMessage({
    required String groupId,
    required String clientRequestId,
    required String body,
  });

  Future<void> reportMessage({
    required String groupId,
    required String messageId,
    required String reason,
  });

  Future<void> blockMember(String otherUid);
}

String newCommunityRequestId() {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(
    32,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}
