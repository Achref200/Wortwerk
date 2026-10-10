/// Interface languages Wortwerk can render its own UI chrome in.
///
/// Learning content stays German regardless of this value; only the app's own
/// labels, states and copy are translated. The product spec lists English,
/// French and Arabic at launch; French and Arabic are not authored yet, so the
/// catalog currently ships English and German.
enum AppLanguage {
  en(code: 'en', nativeLabel: 'English'),
  de(code: 'de', nativeLabel: 'Deutsch');

  const AppLanguage({required this.code, required this.nativeLabel});

  /// BCP-47 primary subtag used in Firestore and `Locale`.
  final String code;

  /// The language's own endonym, shown in the language picker.
  final String nativeLabel;

  /// Maps a raw code (for example a Firestore `uiLang` value or a platform
  /// locale) onto a supported language, falling back to German.
  static AppLanguage fromCode(String? code) => tryFromCode(code) ?? fallback;

  /// Maps a raw code onto a supported language, or `null` when the code is
  /// absent or unsupported.
  static AppLanguage? tryFromCode(String? code) {
    final normalized = code?.trim().toLowerCase();
    return switch (normalized) {
      'en' => AppLanguage.en,
      'de' => AppLanguage.de,
      _ => null,
    };
  }

  /// Resolves a platform locale tag such as `en_US` or `de-AT`.
  static AppLanguage fromLocaleTag(String? tag) {
    if (tag == null || tag.isEmpty) return fallback;
    final primary = tag.replaceAll('_', '-').split('-').first;
    return fromCode(primary);
  }

  /// When nothing is known about the learner yet, Wortwerk speaks German, the
  /// language of the authored content and the original interface.
  static const AppLanguage fallback = AppLanguage.de;
}
