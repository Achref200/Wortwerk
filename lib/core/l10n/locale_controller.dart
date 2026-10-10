import 'package:flutter/foundation.dart';

import 'app_language.dart';

/// Persists the learner's explicit interface-language choice.
///
/// The store is best-effort: a failed read or write must never block the UI,
/// because the language is also mirrored in memory by [LocaleController].
abstract interface class LocalePreferenceStore {
  /// Returns the stored language, or `null` when the account has no explicit
  /// preference yet.
  Future<AppLanguage?> load();

  Future<void> save(AppLanguage language);
}

/// Owns the active interface language and notifies the tree when it changes.
///
/// Resolution order: an explicit stored preference wins; otherwise the device
/// language is used when the app has not recorded one yet.
final class LocaleController extends ChangeNotifier {
  LocaleController({
    required this._store,
    AppLanguage initialLanguage = AppLanguage.fallback,
  }) : _language = initialLanguage;

  final LocalePreferenceStore _store;
  AppLanguage _language;

  AppLanguage get language => _language;

  /// Loads the persisted preference, falling back to the current value when
  /// nothing is stored or the read fails.
  Future<void> load() async {
    try {
      final stored = await _store.load();
      if (stored != null && stored != _language) {
        _language = stored;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('locale_preference_load_failed ${error.runtimeType}');
    }
  }

  /// Switches the interface language and persists the choice best-effort.
  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    try {
      await _store.save(language);
    } catch (error) {
      debugPrint('locale_preference_save_failed ${error.runtimeType}');
    }
  }

  /// The language implied by the current platform locale, defaulting to the
  /// source language when the platform locale is unsupported.
  static AppLanguage deviceLanguage() {
    final tag = PlatformDispatcher.instance.locale.toLanguageTag();
    return AppLanguage.fromLocaleTag(tag);
  }
}
