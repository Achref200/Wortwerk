enum InboxNotificationKind {
  levelUnlocked,
  learningReminder,
  groupMessage,
  unknown,
}

final class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.level,
    this.deepLink,
    this.readAt,
  });

  final String id;
  final InboxNotificationKind kind;
  final DateTime createdAt;
  final String? level;
  final String? deepLink;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}
