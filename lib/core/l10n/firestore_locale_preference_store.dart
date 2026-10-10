import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_language.dart';
import 'locale_controller.dart';

/// Persists the interface language to the learner's own profile document
/// (`users/{uid}.uiLang`), the field the product spec reserves for it and the
/// Firestore rules allow a client to change.
final class FirestoreLocalePreferenceStore implements LocalePreferenceStore {
  FirestoreLocalePreferenceStore({
    required this._firestore,
    required String uid,
    this._uidProvider,
  }) : _initialUid = uid;

  final FirebaseFirestore _firestore;
  final String _initialUid;
  final String Function()? _uidProvider;

  DocumentReference<Map<String, dynamic>> get _profile =>
      _firestore.collection('users').doc(_uidProvider?.call() ?? _initialUid);

  @override
  Future<AppLanguage?> load() async {
    final snapshot = await _profile.get();
    return AppLanguage.tryFromCode(snapshot.data()?['uiLang'] as String?);
  }

  @override
  Future<void> save(AppLanguage language) async {
    await _profile.set({
      'uiLang': language.code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
