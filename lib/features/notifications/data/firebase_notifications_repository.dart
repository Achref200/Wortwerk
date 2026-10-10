import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/inbox_notification.dart';
import '../domain/notifications_repository.dart';

final class FirebaseNotificationsRepository implements NotificationsRepository {
  FirebaseNotificationsRepository({
    required this._firestore,
    required this._functions,
    required String uid,
    this._uidProvider,
  }) : _initialUid = uid;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String _initialUid;
  final String Function()? _uidProvider;

  CollectionReference<Map<String, dynamic>> get _inbox => _firestore
      .collection('users')
      .doc(_uidProvider?.call() ?? _initialUid)
      .collection('notifications');

  @override
  Stream<List<InboxNotification>> watchInbox() => _inbox
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((document) => _decode(document.id, document.data()))
            .toList(growable: false),
      );

  @override
  Future<void> markRead(String notificationId) async {
    final result = await _functions
        .httpsCallable('markNotificationRead')
        .call<Map<String, dynamic>>({'notificationId': notificationId});
    if (result.data['ok'] != true) {
      throw StateError('The notification read state was not confirmed.');
    }
  }

  @override
  Future<bool> pushEnabled() async {
    final profile = await _firestore
        .collection('users')
        .doc(_uidProvider?.call() ?? _initialUid)
        .get();
    return profile.data()?['pushEnabled'] == true;
  }

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    required String language,
  }) async {
    final result = await _functions
        .httpsCallable('registerNotificationDevice')
        .call<Map<String, dynamic>>({
          'token': token,
          'platform': platform,
          'language': language,
        });
    if (result.data['ok'] != true) {
      throw StateError('The device registration was not confirmed.');
    }
  }

  @override
  Future<void> disablePush() async {
    final result = await _functions
        .httpsCallable('disablePushNotifications')
        .call<Map<String, dynamic>>({'enabled': false});
    if (result.data['ok'] != true) {
      throw StateError('The push preference was not confirmed.');
    }
  }

  InboxNotification _decode(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final readAt = data['readAt'];
    final rawKind = data['kind'];
    final rawLevel = data['level'];
    final rawDeepLink = data['deepLink'];
    if (createdAt is! Timestamp || rawKind is! String) {
      throw FormatException('Malformed notification $id');
    }
    return InboxNotification(
      id: id,
      kind: InboxNotificationKind.values.firstWhere(
        (kind) => kind.name == rawKind,
        orElse: () => InboxNotificationKind.unknown,
      ),
      createdAt: createdAt.toDate(),
      level: rawLevel is String ? rawLevel : null,
      deepLink: rawDeepLink is String ? rawDeepLink : null,
      readAt: readAt is Timestamp ? readAt.toDate() : null,
    );
  }
}
