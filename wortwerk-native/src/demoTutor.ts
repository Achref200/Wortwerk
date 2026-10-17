import AsyncStorage from '@react-native-async-storage/async-storage';

export type TutorMessage = { id: string; role: 'user' | 'assistant'; text: string };

function storageKey(uid: string) { return `wortwerk.demo-coach.v1.${uid}`; }

export async function loadDemoTutorMessages(uid: string): Promise<TutorMessage[]> {
  const raw = await AsyncStorage.getItem(storageKey(uid));
  if (!raw) return [];
  try {
    const value: unknown = JSON.parse(raw);
    if (!Array.isArray(value)) return [];
    return value.filter((item): item is TutorMessage => item && typeof item === 'object' && typeof item.id === 'string' && (item.role === 'user' || item.role === 'assistant') && typeof item.text === 'string').slice(-80);
  } catch { return []; }
}

export async function saveDemoTutorMessages(uid: string, messages: TutorMessage[]) {
  await AsyncStorage.setItem(storageKey(uid), JSON.stringify(messages.slice(-80)));
}

/** Predictable offline practice. It is deliberately described as demo coaching, never as an AI reply. */
export function answerInDemo(text: string, level: string): string {
  const message = text.trim();
  const lower = message.toLocaleLowerCase('de-DE');

  if (/café|cafe|barista|bestell|kaffee|kuchen/.test(lower)) {
    return 'Guten Tag! Was möchten Sie bestellen?\n\nDu kannst sagen: „Ich möchte einen Kaffee, bitte.“';
  }
  if (/bahnhof|ticket|reise|reisen|zug|fahren/.test(lower)) {
    return 'Guten Tag! Wohin möchten Sie fahren?\n\nEin hilfreicher Satz: „Eine Fahrkarte nach Berlin, bitte.“';
  }
  if (/vorstell|hei[ßs]e|name|introduc/.test(lower)) {
    return 'Hallo! Ich heiße Fritz. Wie heißt du?\n\nDu kannst antworten: „Ich heiße …“';
  }
  if (/\b(hello|hi|good morning)\b/.test(lower)) {
    return 'Auf Deutsch sagen wir „Hallo“ oder „Guten Morgen“.\n\nUnd jetzt du: Wie begrüßt du jemanden am Nachmittag?';
  }
  if (/\b(warum|why|what does|bedeutet|übersetz|translate)\b/.test(lower)) {
    return 'Gern! „Bitte“ hat zwei häufige Bedeutungen: Du kannst damit höflich um etwas bitten oder dich bedanken.\n\nMagst du einen Beispielsatz versuchen?';
  }
  if (/\b(hallo|guten morgen|guten tag|guten abend|servus)\b/.test(lower)) {
    return 'Hallo! Schön, dass du übst. Wie geht es dir heute?\n\nDu kannst sagen: „Mir geht es gut.“';
  }
  if (/\b(ich bin|ich hei[ßs]e|ich wohne|ich komme|ich mag|ich lerne)\b/.test(lower)) {
    const polished = message.charAt(0).toLocaleUpperCase('de-DE') + message.slice(1).replace(/[.!?]*$/, '.');
    return `Sehr gut — dein Satz lautet: „${polished}“\n\nFüge noch einen Grund oder ein Detail hinzu. Zum Beispiel: „… und ich lerne jeden Tag Deutsch.“`;
  }
  if (message.endsWith('?')) {
    return `Gute Frage! In diesem Demo-Gespräch üben wir Deutsch auf Niveau ${level}.\n\nSchreib deine Frage als einfachen deutschen Satz — ich helfe dir mit einem passenden Übungsbeispiel.`;
  }
  if (message.length > 0) {
    return `Danke, dass du es auf Deutsch versuchst. Ein guter nächster Satz auf Niveau ${level} beginnt zum Beispiel mit „Ich möchte …“ oder „Ich brauche …“.\n\nWelchen Satz möchtest du damit bilden?`;
  }
  return 'Womit möchtest du anfangen? Schreib einen kurzen Satz auf Deutsch oder wähle eine Übung aus.';
}
