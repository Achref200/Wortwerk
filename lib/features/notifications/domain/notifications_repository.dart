import 'inbox_notification.dart';

abstract interface class NotificationsRepository {
  Stream<List<InboxNotification>> watchInbox();

  Future<void> markRead(String notificationId);

  Future<bool> pushEnabled();

  Future<void> registerDevice({
    required String token,
    required String platform,
    required String language,
  });

  Future<void> disablePush();
}
