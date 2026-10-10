import 'package:flutter_test/flutter_test.dart';
import 'package:wortwerk/core/l10n/app_language.dart';
import 'package:wortwerk/core/l10n/wortwerk_strings.dart';

void main() {
  const english = WortwerkStrings(AppLanguage.en);
  const german = WortwerkStrings(AppLanguage.de);

  test('translates known app chrome and leaves lesson content untouched', () {
    expect(english.fromSource('Schön, dass du da bist'), 'Good to see you');
    expect(
      german.fromSource('Schön, dass du da bist'),
      'Schön, dass du da bist',
    );

    const lessonPrompt = 'Wie begrüßt du jemanden am Morgen?';
    expect(english.fromSource(lessonPrompt), lessonPrompt);
  });

  test('translates variable onboarding copy', () {
    expect(english.fromSource('Frage 2 von 6'), 'Question 2 of 6');
    expect(english.fromSource('10 Minuten am Tag'), '10 minutes a day');
  });
}
