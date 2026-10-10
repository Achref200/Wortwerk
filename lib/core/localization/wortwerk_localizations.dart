import 'package:flutter/widgets.dart';

/// Small, app-owned UI catalog. German remains the source language so
/// curriculum examples and text loaded from Firestore stay untouched unless a
/// specific UI phrase has an English equivalent here.
final class WortwerkLocalizations {
  const WortwerkLocalizations(this.locale);

  final Locale locale;

  bool get isEnglish => locale.languageCode == 'en';

  String text(String source) =>
      isEnglish ? _english[source] ?? _translatePattern(source) : source;

  static WortwerkLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<WortwerkLocalizations>(context, WortwerkLocalizations);

  static const supportedLocales = <Locale>[Locale('de'), Locale('en')];

  static const LocalizationsDelegate<WortwerkLocalizations> delegate =
      _WortwerkLocalizationsDelegate();

  static String _translatePattern(String source) {
    final onboardingStep = RegExp(r'^(\d+) von 4$').firstMatch(source);
    if (onboardingStep != null) {
      return 'Step ${onboardingStep.group(1)} of 4';
    }
    final question = RegExp(r'^Frage (\d+) von (\d+)$').firstMatch(source);
    if (question != null) {
      return 'Question ${question.group(1)} of ${question.group(2)}';
    }
    final cardCount = RegExp(r'^KARTE (\d+) VON (\d+)$').firstMatch(source);
    if (cardCount != null) {
      return 'CARD ${cardCount.group(1)} OF ${cardCount.group(2)}';
    }
    final minutes = RegExp(r'^(\d+) Min$').firstMatch(source);
    if (minutes != null) return '${minutes.group(1)} min';
    final streakSingular = RegExp(r'^(\d+) Lerntag in Folge$')
        .firstMatch(source);
    if (streakSingular != null) {
      return '${streakSingular.group(1)} learning day in a row';
    }
    final streak = RegExp(r'^(\d+) Lerntage in Folge$').firstMatch(source);
    if (streak != null) return '${streak.group(1)} learning days in a row';
    final xp = RegExp(r'^(\d+) XP heute$').firstMatch(source);
    if (xp != null) return '${xp.group(1)} XP today';
    final progress = RegExp(r'^(\d+) / (\d+)$').firstMatch(source);
    if (progress != null) return '${progress.group(1)} / ${progress.group(2)}';
    final days = RegExp(
      r'^(\d+) von 7 aktiven Tagen · längster Rhythmus: (\d+) · Schutztage: (\d+)$',
    ).firstMatch(source);
    if (days != null) {
      return '${days.group(1)} of 7 active days · longest streak: '
          '${days.group(2)} · streak shields: ${days.group(3)}';
    }
    final xpToday = RegExp(r'^\+(\d+) XP heute · Pausen sind okay\.$')
        .firstMatch(source);
    if (xpToday != null) {
      return '+${xpToday.group(1)} XP today · Rest is part of learning.';
    }
    final lockedLevel = RegExp(
      r'^Drei Lernschritte öffnen (A1|A2|B1|B2|C1|C2)\.$',
    ).firstMatch(source);
    if (lockedLevel != null) {
      return 'Three learning milestones unlock ${lockedLevel.group(1)}.';
    }
    final upcomingLevel = RegExp(r'^ALS NÄCHSTES · (A1|A2|B1|B2|C1|C2)$')
        .firstMatch(source);
    if (upcomingLevel != null) return 'UP NEXT · ${upcomingLevel.group(1)}';
    final goalSummary = RegExp(r'^Alltag und Reisen – passend für (.+)\.$')
        .firstMatch(source);
    if (goalSummary != null) {
      return 'Everyday life and travel, tailored to ${goalSummary.group(1)}.';
    }
    final planMinutes = RegExp(r'^(\d+) Minuten am Tag$').firstMatch(source);
    if (planMinutes != null) {
      return '${planMinutes.group(1)} minutes a day';
    }
    final confidence = RegExp(
      r'^Einstufung abgeschlossen · (\d+)% der Antworten richtig$',
    ).firstMatch(source);
    if (confidence != null) {
      return 'Placement complete · ${confidence.group(1)}% correct';
    }
    return source;
  }

  static const Map<String, String> _english = {
    'Wortwerk konnte nicht gestartet werden.': 'Wortwerk could not start.',
    'Diese Seite gibt es noch nicht.': 'This page is not available yet.',
    'Zurück zum Start': 'Back to Home',
    'Erneut versuchen': 'Try again',
    'Erneut laden': 'Reload',
    'Erneut speichern': 'Save again',
    'Erneut': 'Again',
    'Weiter als Gast': 'Continue as guest',
    'Konto verknüpfen': 'Link an account',
    'Dein Profil': 'Your profile',
    'Deine Reise beginnt hier.': 'Your journey starts here.',
    'Melde dich an, um deinen Lernfortschritt geräteübergreifend zu sichern.':
        'Create an account to keep your learning progress across devices.',
    'Lernplan ansehen': 'View learning plan',
    'Dein Lernweg': 'Your learning path',
    'Level und Einheiten': 'Levels and units',
    'Lernrhythmus': 'Learning rhythm',
    'Benachrichtigungen': 'Notifications',
    'Schön, dass du da bist': 'Good to see you',
    'Ein kleiner Schritt?': 'Ready for a small step?',
    'Dein nächster Schritt': 'Your next step',
    'Dein Weg': 'Your path',
    'Lernen, wie es dir passt': 'Learn your way',
    'Wörter üben': 'Practice words',
    'Mit Karteikarten': 'With flashcards',
    'Sprechen': 'Speaking',
    'Mit Fritz': 'With Fritz',
    'Pausen gehören dazu.': 'Rest is part of learning.',
    'Ein Ruhetag pro Woche ist erlaubt. Dein Lernweg wartet auf dich.': 'One rest day each week is part of your plan. Your path will be here when you return.',
    'Dein Tagesfortschritt ist gerade nicht verfügbar.':
        'Today’s progress is unavailable right now.',
    'Dein Tagesfortschritt wird geladen': 'Loading today’s progress',
    'Lektion beginnen': 'Start lesson',
    'Dein Lernrhythmus': 'Your learning rhythm',
    'Dranbleiben, ohne Druck.': 'Keep going at your own pace.',
    'Einstellungen werden geladen': 'Loading settings',
    'Einstellungen': 'Settings',
    'LERNEN': 'LEARNING',
    'Tagesziel': 'Daily goal',
    'Erinnerung': 'Reminder',
    'Ruhetag pro Woche': 'Weekly rest day',
    'Niveau anpassen': 'Adapt difficulty',
    'Lernplan folgt deinem Fortschritt.': 'Your plan adapts to your progress.',
    'Sprachausgabe': 'Speech',
    'Wörter laut anhören.': 'Listen to words aloud.',
    'BENACHRICHTIGUNGEN': 'NOTIFICATIONS',
    'Lernerinnerung': 'Learning reminder',
    'Gruppennachrichten': 'Group messages',
    'Wochenbericht': 'Weekly summary',
    'Änderungen gelten in dieser Vorschau. Einstellungen werden mit deinem Profil gespeichert, sobald du angemeldet bist.':
        'These settings are saved to your profile when you are signed in.',
    'Hinweise': 'Updates',
    'Du bist auf dem Laufenden.': 'You’re all caught up.',
    'Noch keine Hinweise.': 'No updates yet.',
    'Deine Lernmomente und Neuigkeiten erscheinen hier.':
        'Learning milestones and news will appear here.',
    'Weiterlernen': 'Keep learning',
    'Gemeinsam lernen': 'Learn together',
    'Finde eine Gruppe, die zu deinem Lernweg passt.':
        'Find a group that fits your learning path.',
    'Dein Platz ist noch frei.': 'Your place is waiting.',
    'Gruppen und Nachrichten erscheinen hier, sobald du beitrittst.':
        'Groups and messages will appear here when you join one.',
    'Gruppen werden gerade vorbereitet.': 'Groups are not available yet.',
    'Gruppen entdecken': 'Explore groups',
    'Miteinander': 'Community',
    'Übe freundlich, respektvoll und in deinem Tempo. Nachrichten und Gruppen werden von dir kontrolliert.': 'Learn kindly, respectfully, and at your own pace. You control your messages and groups.',
    'Alle': 'All',
    'Mein Niveau': 'My level',
    'Freunde': 'Friends',
    'Nochmal': 'Again',
    'Gewusst': 'Got it',
    'Karte umdrehen': 'Flip card',
    'Zurück zum Lernweg': 'Back to learning path',
    'Eine Lektion starten': 'Start a lesson',
    'Deutsch lernen': 'Learn German',
    'Fortschritt wird gespeichert …': 'Saving progress …',
    'Dein Lernfortschritt wird gespeichert …': 'Saving your progress …',
    'Lektion offline nicht verfügbar.': 'This lesson is unavailable offline.',
    'Verstanden': 'Got it',
    'Wörter wiederholen': 'Review words',
    'Mit Fritz üben': 'Practice with Fritz',
    'Dein Lernweg wird vorbereitet.': 'Your learning path is being prepared.',
    'Veröffentlichte Lektionen erscheinen hier.':
        'Published lessons will appear here.',
    'E-Mail-Adresse': 'Email address',
    'Passwort': 'Password',
    'Mindestens sechs Zeichen': 'At least six characters',
    'Passwort anzeigen': 'Show password',
    'Passwort verbergen': 'Hide password',
    'Anmelden': 'Sign in',
    'Konto erstellen': 'Create account',
    'Konto mit Passwort erstellen': 'Create an account with a password',
    'Passwort vergessen?': 'Forgot password?',
    'Noch kein Konto? Jetzt erstellen': 'New here? Create an account',
    'Schon ein Konto? Anmelden': 'Already have an account? Sign in',
    'Stattdessen E-Mail-Link senden': 'Send me a sign-in link instead',
    'Dein Lernen – überall dabei.': 'Your learning, wherever you go.',
    'Starte als Gast und verknüpfe dein Konto, wann immer du möchtest. So bleibt dein Lernfortschritt mit derselben Sitzung verbunden.': 'Start as a guest and link an account when you’re ready. Your progress stays with the same learning profile.',
    'Mit Google fortfahren': 'Continue with Google',
    'Mit Apple fortfahren': 'Continue with Apple',
    'Gib zuerst deine E-Mail-Adresse ein.': 'Enter your email address first.',
    'Dein Passwort braucht mindestens sechs Zeichen.':
        'Your password needs at least six characters.',
    'Dein Konto ist erstellt. Dein Lernfortschritt ist verknüpft.':
        'Your account is ready. Your learning progress is linked.',
    'Du bist angemeldet.': 'You’re signed in.',
    'Weiter': 'Continue',
    'Prüfen': 'Check',
    'Erklären': 'Explain',
    'Übersetzen': 'Translate',
    'Üben': 'Practice',
    'Zurück': 'Back',
    'Laden …': 'Loading …',
    'Noch keine Daten – lerne heute 5 Minuten':
        'No data yet. Learn for five minutes today.',
    'Ein neuer Abschnitt': 'A new chapter',
    'Ein Schritt, auf den du stolz sein kannst.': 'A step you can be proud of.',
    'Dein Lernweg wird geladen.': 'Loading your learning path.',
    'Deutsch': 'German',
    'APP LANGUAGE': 'APP LANGUAGE',
    'Sprache': 'Language',
    'Schön, dass du wieder da bist.': 'Good to see you again.',
    'Start': 'Home',
    'Weg': 'Path',
    'Gruppen': 'Groups',
    'Profil': 'Profile',
    'Fritz übt mit dir': 'Practice with Fritz',
    'Auf Deutsch, Schritt für Schritt.': 'German practice, one step at a time.',
    'Neues Gespräch': 'New conversation',
    'Fritz ist ein KI-Lernassistent. Teile keine Passwörter oder vertraulichen Daten.': 'Fritz is an AI learning assistant. Do not share passwords or sensitive information.',
    'Fritz wird bereit …': 'Getting Fritz ready …',
    'Der Gesprächsverlauf ist nicht verfügbar.':
        'The conversation history is unavailable.',
    'Der gespeicherte Verlauf ist veraltet.':
        'The saved conversation is out of date.',
    'Verlauf erneut laden': 'Reload conversation',
    'Womit möchtest du anfangen?': 'What would you like to work on?',
    'Schreib einen Satz auf Deutsch. Fritz übt mit dir auf deinem Niveau.': 'Write a sentence in German. Fritz will practise with you at your level.',
    'Schreib auf Deutsch …': 'Write in German …',
    'Senden': 'Send',
    'Verwerfen': 'Discard',
    'Fritz braucht eine kurze Pause. Versuche es später erneut.':
        'Fritz needs a short break. Please try again later.',
    'Fritz ist noch nicht eingerichtet. Lernkarten kannst du weiter üben.':
        'Fritz is not set up yet. You can still practise flashcards.',
    'Fritz konnte gerade nicht antworten. Deine Nachricht bleibt erhalten.':
        'Fritz could not reply just now. Your message is saved.',
    'Keine Verbindung. Deine Nachricht bleibt erhalten.':
        'You are offline. Your message is saved.',
    'Hallo! Ich bin Fritz.': 'Hi! I’m Fritz.',
    'Dein Deutsch-Begleiter.': 'Your German learning companion.',
    'Kleine Schritte, jeden Tag, ohne Druck.':
        'Small steps every day, without pressure.',
    'Lernen in deinem Tempo': 'Learn at your own pace',
    'Pausen sind Teil des Plans': 'Rest is part of the plan',
    "Los geht's": 'Let’s go',
    'Loslernen': 'Start learning',
    'Speichert …': 'Saving …',
    'Nochmal versuchen': 'Try again',
    'Einen Moment …': 'One moment …',
    'Wofür lernst du Deutsch?': 'Why are you learning German?',
    'Wähle alles aus, was zu dir passt.': 'Choose everything that fits you.',
    'Wie viel Zeit hast du am Tag?': 'How much time do you have each day?',
    'Lieber wenig, aber regelmäßig. Du kannst das jederzeit ändern.':
        'A little, regularly, goes a long way. You can change this anytime.',
    'Wo stehst du gerade?': 'Where are you starting from?',
    'Es gibt kein richtig oder falsch.': 'There is no right or wrong answer.',
    'Ganz neu': 'I’m new to German',
    'Ich starte bei null.': 'I’m starting from the beginning.',
    'Grundlagen': 'I know the basics',
    'Einfache Sätze gehen schon.': 'I can already make simple sentences.',
    'Gespräche führen': 'I can have conversations',
    'Mir fehlen Wörter und Sicherheit.': 'I need more words and confidence.',
    '2 Minuten, 6–8 kurze Fragen.': 'A quick quiz with 6–8 questions.',
    'Auf welchem Niveau möchtest du beginnen?':
        'What level would you like to start at?',
    'Fritz passt die nächsten 8 kurzen Fragen an deine Antworten an.':
        'Fritz adapts the next eight short questions to your answers.',
    'Dein Lernplan passt sich an dich an – ganz ohne Prüfung.':
        'Your learning plan adapts to you, without a test.',
    'Fritz wertet aus …': 'Fritz is checking your answers …',
    'Dein Ergebnis wartet.': 'Your result is ready.',
    'Deine Antworten werden sicher eingeordnet.':
        'Your answers are being assessed securely.',
    'Deine Antworten sind noch da. Du kannst es erneut versuchen.':
        'Your answers are saved. You can try again.',
    'Mein Niveau selbst auswählen': 'Choose my level myself',
    'Teste mich, Fritz': 'Test my level',
    'Dein Plan steht.': 'Your plan is ready.',
    'Ein guter Anfang, den du jederzeit anpassen kannst.':
        'A good starting point you can change anytime.',
    'Fritz hat deinen Startpunkt anhand deiner Antworten gefunden.':
        'Fritz chose your starting point based on your answers.',
    'DEIN START': 'YOUR START',
    'DEIN ERGEBNIS': 'YOUR RESULT',
    'Ein Ruhetag pro Woche ist erlaubt': 'One rest day each week is built in',
    'Der Plan passt sich an dich an.': 'Your plan adapts to you.',
    'Lernweg aktualisieren': 'Refresh learning path',
    'Ein Weg, der mit jedem kleinen Schritt wächst.':
        'A path that grows with every small step.',
    'Dein Lernweg ist gerade offline.':
        'Your learning path is offline right now.',
    'Hier erscheinen nur veröffentlichte Lektionen. Dein Lernweg wächst mit den Inhalten.': 'Only published lessons appear here. Your path grows as new content is released.',
    'NÄCHSTES NIVEAU': 'NEXT LEVEL',
    'NÄCHSTE EINHEIT': 'NEXT UNIT',
    'Beende zuerst die vorherige Einheit mit mindestens 60 %.':
        'Complete the previous unit with at least 60% first.',
    'Behalte 70 % des Kernwortschatzes, führe drei Gespräche mit Fritz und bestehe eine Wiederholung mit mindestens 70 %.': 'Retain 70% of core vocabulary, complete three conversations with Fritz, and pass one review with at least 70%.',
    'Alle Lektionen der vorherigen Einheit müssen abgeschlossen sein.':
        'Complete every lesson in the previous unit first.',
    'Wörter behalten': 'Words retained',
    'Gespräche mit Fritz': 'Conversations with Fritz',
    'Wiederholung bestehen': 'Pass a review',
    '0 % · Wortschatz wird vorbereitet': '0% · Vocabulary is being prepared',
    'Mindestens 70 % erreicht': 'At least 70% reached',
    '1 Runde mit mindestens 70 %': '1 review with at least 70%',
    'Lektion wird geladen …': 'Loading lesson …',
    'Diese Lektion ist noch nicht bereit.': 'This lesson is not ready yet.',
    'Sobald neue Übungen verfügbar sind, findest du sie hier.':
        'New exercises will appear here when they are ready.',
    'Speichern …': 'Saving …',
    'Antwort prüfen': 'Check answer',
    'Lektion abschließen': 'Finish lesson',
    'Noch nicht richtig.': 'Not quite.',
    'Richtig.': 'Correct.',
    'Dein Fortschritt wird gespeichert, sobald die Lektion bestätigt ist.':
        'Your progress is saved when you submit the lesson.',
    'Lektion gespeichert': 'Lesson saved',
    'Dein Fortschritt wurde vom Server bestätigt.':
        'Your progress has been confirmed by the server.',
    'Wiederholung geschafft!': 'Review complete!',
    'Erinnere dich: Was bedeutet das Wort?': 'What does the word mean?',
    'Denk erst nach – tippe dann zum Umdrehen.':
        'Take a moment to remember, then tap to flip.',
    'sicher': 'remembered',
    'Gespeichert · Deine Karten haben jetzt einen persönlichen Wiederholungsrhythmus.':
        'Saved · Your cards now have a personal review schedule.',
    'Lernkarten': 'Flashcards',
    'Kleine Ziele für heute': 'Small goals for today',
    'Deine Ziele sind geschafft.': 'You have finished today’s goals.',
    'Ein guter Moment für eine Pause — oder eine freiwillige Zusatzrunde.':
        'A good time for a break, or an optional extra round.',
    'Freiwillig weiterüben': 'Do an optional extra round',
    'Eine Lektion abschließen': 'Finish a lesson',
    '10 Wörter wiederholen': 'Review 10 words',
    'abgeschlossen': 'complete',
    'offen': 'not started',
    'Erledigt': 'Done',
    'Begrüßungen': 'Greetings',
    'Hallo sagen und sich vorstellen': 'Say hello and introduce yourself',
    '1 Lerntag in Folge': '1 learning day in a row',
    'Lerntag in Folge': 'learning day in a row',
    'Lerntage in Folge': 'learning days in a row',
    'Dein erster Lerntag beginnt mit einer kurzen Einheit. Ein Ruhetag ist jede Woche eingeplant.': 'Your first learning day starts with a short session. One rest day is built into each week.',
    'Schön, dass du wieder da bist. Dein Rhythmus bleibt dein eigener.':
        'Good to see you again. Your rhythm is yours to choose.',
    'Diese Woche': 'This week',
    'Ein kleiner Schritt für heute': 'One small step for today',
    'Eine Lektion beginnen': 'Start a lesson',
    '5 kurze Fragen · A1': '5 short questions · A1',
    'Ein Wort wiederholen': 'Review a word',
    'Karteikarten': 'Flashcards',
    'Einen Satz mit Fritz üben': 'Practise a sentence with Fritz',
    'Gesprächsvorschau': 'Conversation preview',
    'Ein Ruhetag pro Woche unterbricht deinen Lernrhythmus nicht. Ein verpasster Tag ist kein Grund, dich schlecht zu fühlen.': 'A weekly rest day will not break your rhythm. Missing a day is nothing to feel bad about.',
    'Heute': 'Today',
    'Sonntag': 'Sunday',
    'Montag': 'Monday',
    'Dienstag': 'Tuesday',
    'Mittwoch': 'Wednesday',
    'Donnerstag': 'Thursday',
    'Freitag': 'Friday',
    'Samstag': 'Saturday',
    'Mo': 'Mo',
    'Di': 'Tu',
    'Mi': 'We',
    'Do': 'Th',
    'Fr': 'Fr',
    'Sa': 'Sa',
    'So': 'Su',
    'DEIN RUHETAG': 'YOUR REST DAY',
    'Frag mich auf Deutsch.': 'Ask me in German.',
    'Schließen': 'Close',
    'Wobei kann ich helfen?': 'What can I help with?',
    'Zum Ausprobieren': 'Try one of these',
    'Fritz übt mit dir auf deinem Niveau.':
        'Fritz practises with you at your level.',
    'Lernfortschritt wird gespeichert': 'Saving learning progress',
    'Eine Nachricht schreiben': 'Write a message',
    'Richtig geraten': 'Correct guess',
    'Falsch': 'Not quite',
  };
}

final class _WortwerkLocalizationsDelegate
    extends LocalizationsDelegate<WortwerkLocalizations> {
  const _WortwerkLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => WortwerkLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<WortwerkLocalizations> load(Locale locale) async =>
      WortwerkLocalizations(locale);

  @override
  bool shouldReload(_WortwerkLocalizationsDelegate old) => false;
}
