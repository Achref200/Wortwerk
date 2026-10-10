import 'package:wortwerk/features/lesson/domain/greetings_lesson.dart';

const a1GreetingsLesson = LearningLesson(
  id: 'a1_greetings',
  levelId: 'A1',
  unitId: 'a1_greetings',
  title: 'A1 · Begrüßungen',
  questions: [
    LessonQuestion(
      id: 'greeting_morning',
      prompt: 'Du triffst jemanden am Morgen. Was sagst du?',
      choices: [
        LessonChoice(id: 'morning_guten_morgen', text: 'Guten Morgen'),
        LessonChoice(id: 'morning_guten_abend', text: 'Guten Abend'),
        LessonChoice(id: 'morning_gute_nacht', text: 'Gute Nacht'),
        LessonChoice(id: 'morning_tschuess', text: 'Tschüss'),
      ],
      correctChoiceId: 'morning_guten_morgen',
      explanation: '„Guten Morgen“ sagt man am Morgen.',
    ),
    LessonQuestion(
      id: 'greeting_name',
      prompt: 'Wie fragst du höflich nach dem Namen?',
      choices: [
        LessonChoice(id: 'name_wie_heissen', text: 'Wie heißen Sie?'),
        LessonChoice(id: 'name_woher', text: 'Woher kommen Sie?'),
        LessonChoice(id: 'name_wie_alt', text: 'Wie alt sind Sie?'),
        LessonChoice(id: 'name_was_machen', text: 'Was machen Sie?'),
      ],
      correctChoiceId: 'name_wie_heissen',
      explanation: '„Wie heißen Sie?“ ist die höfliche Frage nach dem Namen.',
    ),
    LessonQuestion(
      id: 'greeting_introduce',
      prompt: 'Ergänze die Vorstellung: „Ich ___ Mia.“',
      choices: [
        LessonChoice(id: 'introduce_heisse', text: 'heiße'),
        LessonChoice(id: 'introduce_heisst', text: 'heißt'),
        LessonChoice(id: 'introduce_heissen', text: 'heißen'),
        LessonChoice(id: 'introduce_seid', text: 'seid'),
      ],
      correctChoiceId: 'introduce_heisse',
      explanation: 'Mit „Ich heiße …“ stellst du dich vor.',
    ),
    LessonQuestion(
      id: 'greeting_thanks',
      prompt: 'Jemand sagt „Danke“. Was antwortest du freundlich?',
      choices: [
        LessonChoice(id: 'thanks_bitte', text: 'Bitte'),
        LessonChoice(id: 'thanks_hallo', text: 'Hallo'),
        LessonChoice(id: 'thanks_guten_tag', text: 'Guten Tag'),
        LessonChoice(id: 'thanks_entschuldigung', text: 'Entschuldigung'),
      ],
      correctChoiceId: 'thanks_bitte',
      explanation: 'Auf „Danke“ antwortet man oft mit „Bitte“.',
    ),
    LessonQuestion(
      id: 'greeting_goodbye',
      prompt: 'Du verabschiedest dich höflich. Was kannst du sagen?',
      choices: [
        LessonChoice(id: 'goodbye_auf_wiedersehen', text: 'Auf Wiedersehen'),
        LessonChoice(id: 'goodbye_guten_morgen', text: 'Guten Morgen'),
        LessonChoice(id: 'goodbye_danke', text: 'Danke'),
        LessonChoice(id: 'goodbye_bitte', text: 'Bitte'),
      ],
      correctChoiceId: 'goodbye_auf_wiedersehen',
      explanation: '„Auf Wiedersehen“ ist eine höfliche Verabschiedung.',
    ),
  ],
);
