import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/community_repository.dart';

final class FirebaseCommunityRepository implements CommunityRepository {
  FirebaseCommunityRepository({
    required this._firestore,
    required this._functions,
    required this._auth,
  });

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  String get currentUid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to use learning groups.');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _user =>
      _firestore.collection('users').doc(currentUid);

  @override
  Stream<List<LearningGroup>> watchGroups() => _firestore
      .collection('groups')
      .where('published', isEqualTo: true)
      .where('isPublic', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final groups = snapshot.docs
            .map((document) => _decodeGroup(document.id, document.data()))
            .toList();
        groups.sort((left, right) {
          final level = left.level.compareTo(right.level);
          return level == 0 ? left.name.compareTo(right.name) : level;
        });
        return List.unmodifiable(groups);
      });

  @override
  Stream<Set<String>> watchJoinedGroupIds() => _user.snapshots().map((doc) {
    final raw = doc.data()?['joinedCommunityGroupIds'];
    if (raw is! List) return const <String>{};
    return raw.whereType<String>().toSet();
  });

  @override
  Stream<LearningGroup?> watchGroup(String groupId) =>
      _group(groupId).snapshots().map((document) {
        final data = document.data();
        if (!document.exists || data?['published'] != true) return null;
        return _decodeGroup(document.id, data!);
      });

  @override
  Stream<bool> watchMembership(String groupId) =>
      _group(groupId)
          .collection('members')
          .doc(currentUid)
          .snapshots()
          .map((document) => document.exists);

  @override
  Stream<Set<String>> watchBlockedUids() => _user
      .collection('blocks')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((document) => document.id).toSet());

  @override
  Stream<List<CommunityMessage>> watchMessages(String groupId) =>
      _group(groupId)
          .collection('messages')
          .where('status', isEqualTo: 'visible')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots()
          .map((snapshot) {
            final messages =
                snapshot.docs
                    .map(
                      (document) =>
                          _decodeMessage(document.id, document.data()),
                    )
                    .toList()
                  ..sort(
                    (left, right) => left.createdAt.compareTo(right.createdAt),
                  );
            return List.unmodifiable(messages);
          });

  @override
  Future<void> joinGroup(String groupId) async {
    final result = await _functions.httpsCallable('joinLearningGroup').call({
      'groupId': groupId,
      'confirmAge16': true,
      'acceptRulesVersion': 1,
    });
    _requireOk(result.data);
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final result = await _functions.httpsCallable('leaveLearningGroup').call({
      'groupId': groupId,
    });
    _requireOk(result.data);
  }

  @override
  Future<String> sendMessage({
    required String groupId,
    required String clientRequestId,
    required String body,
  }) async {
    final result = await _functions.httpsCallable('sendGroupMessage').call({
      'groupId': groupId,
      'clientRequestId': clientRequestId,
      'body': body,
    });
    final data = result.data;
    if (data is! Map || data['ok'] != true || data['messageId'] is! String) {
      throw StateError('The group message was not confirmed.');
    }
    return data['messageId'] as String;
  }

  @override
  Future<void> reportMessage({
    required String groupId,
    required String messageId,
    required String reason,
  }) async {
    final result = await _functions.httpsCallable('reportGroupMessage').call({
      'groupId': groupId,
      'messageId': messageId,
      'reason': reason,
    });
    _requireOk(result.data);
  }

  @override
  Future<void> blockMember(String otherUid) async {
    final result = await _functions.httpsCallable('blockCommunityMember').call({
      'otherUid': otherUid,
    });
    _requireOk(result.data);
  }

  DocumentReference<Map<String, dynamic>> _group(String id) =>
      _firestore.collection('groups').doc(id);

  LearningGroup _decodeGroup(String id, Map<String, dynamic> data) {
    final name = data['name'];
    final topic = data['topic'];
    final level = data['levelTag'];
    final count = data['memberCount'];
    if (name is! String || topic is! String || level is! String) {
      throw FormatException('Malformed learning group $id');
    }
    final lastMessage = data['lastMessage'];
    final lastBody = lastMessage is Map ? lastMessage['body'] : null;
    return LearningGroup(
      id: id,
      name: name,
      topic: topic,
      level: level,
      memberCount: count is int && count >= 0 ? count : 0,
      lastMessage: lastBody is String ? lastBody : null,
    );
  }

  CommunityMessage _decodeMessage(String id, Map<String, dynamic> data) {
    final uid = data['uid'];
    final displayName = data['displayName'];
    final body = data['body'];
    final createdAt = data['createdAt'];
    if (uid is! String ||
        displayName is! String ||
        body is! String ||
        createdAt is! Timestamp) {
      throw FormatException('Malformed community message $id');
    }
    return CommunityMessage(
      id: id,
      uid: uid,
      displayName: displayName,
      body: body,
      createdAt: createdAt.toDate(),
    );
  }

  void _requireOk(Object? value) {
    if (value is! Map || value['ok'] != true) {
      throw StateError('The community action was not confirmed.');
    }
  }
}
