import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/fritz_message.dart';

final class FirebaseFritzChatRepository implements FritzChatRepository {
  FirebaseFritzChatRepository({
    required this.firestore,
    required this.functions,
    required this.uid,
    this.uidProvider,
  });

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final String uid;
  final String Function()? uidProvider;

  @override
  Stream<List<FritzMessage>> watchMessages({required String threadId}) =>
      firestore
          .collection('users')
          .doc(uidProvider?.call() ?? uid)
          .collection('aiThreads')
          .doc(threadId)
          .collection('messages')
          .orderBy('createdAt')
          .limit(100)
          .snapshots()
          .map(
            (snapshot) => List.unmodifiable(
              snapshot.docs.map(
                (document) => FritzMessage.fromFirestore(document.id, {
                  ...document.data(),
                  'createdAt': document.data()['createdAt'] is Timestamp
                      ? (document.data()['createdAt'] as Timestamp).toDate()
                      : document.data()['createdAt'],
                }),
              ),
            ),
          );

  @override
  Future<void> sendMessage({
    required String text,
    required String mode,
    required String threadId,
    required String clientRequestId,
  }) async {
    final response = await functions.httpsCallable('fritzChat').call({
      'message': text,
      'mode': mode,
      'threadId': threadId,
      'clientRequestId': clientRequestId,
    });
    final data = response.data;
    if (data is! Map ||
        data['threadId'] != threadId ||
        data['clientRequestId'] != clientRequestId ||
        data['reply'] is! String ||
        (data['reply'] as String).trim().isEmpty) {
      throw const FormatException('Fritz konnte keine Antwort bestätigen.');
    }
  }
}
