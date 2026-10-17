import { useEffect, useState } from 'react';
import { Alert, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { EmailAuthProvider, linkWithCredential, sendEmailVerification, sendPasswordResetEmail } from 'firebase/auth';
import { collection, getDocs, limit, orderBy, query } from 'firebase/firestore';
import Animated, { FadeInDown, useReducedMotion } from 'react-native-reanimated';
import { auth, db } from '../firebase';
import { loadNotifications, markNotificationRead, saveProfilePreferences, setPushEnabled, type LearnerProfile } from '../data';
import { colors } from '../theme';
import { Card, FriendlyEmpty, PrimaryButton, SectionTitle, Tap, ui } from '../ui';

type Props = { uid: string; profile: LearnerProfile; width: number; onBack: () => void; onSaved: (profile: LearnerProfile) => void; onOpen: (route: 'settings' | 'notifications' | 'streak' | 'account' | 'edit-profile') => void };
type NotificationItem = { id: string; kind: string; level?: string; read: boolean; createdAt?: Date };

export function EditProfileScreen({ uid, profile, width, onBack, onSaved }: Props) {
  const [name, setName] = useState(profile.displayName);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const save = async () => {
    const displayName = name.trim();
    if (displayName.length < 2 || displayName.length > 64) { setError('Der Name muss 2 bis 64 Zeichen haben.'); return; }
    setBusy(true); setError('');
    try { await saveProfilePreferences(uid, { displayName }); onSaved({ ...profile, displayName }); onBack(); }
    catch { setError('Dein Name konnte nicht gespeichert werden. Prüfe die Verbindung und versuche es erneut.'); }
    finally { setBusy(false); }
  };
  return <Screen title="Profil bearbeiten" eyebrow="DEIN AUFTRITT" width={width} onBack={onBack}>
    <Card><Text style={s.label}>Anzeigename</Text><TextInput value={name} onChangeText={setName} maxLength={64} autoCapitalize="words" accessibilityLabel="Anzeigename" style={s.input} /><Text style={s.hint}>Dieser Name erscheint in deinem Lernprofil.</Text></Card>
    {error ? <Text style={s.error}>{error}</Text> : null}<PrimaryButton title={busy ? 'Wird gespeichert …' : 'Änderungen speichern'} busy={busy} onPress={() => void save()} />
  </Screen>;
}

export function SettingsScreen({ uid, profile, width, onBack, onSaved, onOpen }: Props) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [reminderValue, setReminderValue] = useState(profile.reminderTime ?? '18:00');
  const prefs = profile.notificationPreferences ?? { learningReminder: true, groupMessages: true, weeklySummary: false };
  const update = async (values: Record<string, unknown>) => {
    setBusy(true); setError('');
    try { await saveProfilePreferences(uid, values); onSaved({ ...profile, ...values } as LearnerProfile); }
    catch { setError('Die Einstellung konnte nicht gespeichert werden. Bitte versuche es erneut.'); }
    finally { setBusy(false); }
  };
  return <Screen title="Einstellungen" eyebrow="DEIN LERNRHYTHMUS" width={width} onBack={onBack}>
    <SectionTitle kicker="TÄGLICHES ZIEL" title={`${profile.dailyMinutes} Minuten`} />
    <Card><View style={s.wrap}>{[5, 10, 15, 20].map((n) => <Chip key={n} label={`${n} Min.`} selected={profile.dailyMinutes === n} onPress={() => void update({ dailyMinutes: n })} />)}</View></Card>
    <SectionTitle kicker="PAUSEN" title="Ruhetag" />
    <Card><View style={s.wrap}>{['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'].map((day, index) => <Chip key={day} label={day} selected={profile.restWeekday === index} onPress={() => void update({ restWeekday: index })} />)}</View></Card>
    <SectionTitle kicker="ERINNERUNG" title="Lernzeit" />
    <Card><Text style={s.hint}>Uhrzeit in deiner lokalen Zeitzone · {profile.timezone}</Text><TextInput value={reminderValue} onChangeText={setReminderValue} onEndEditing={() => { if (/^([01]\d|2[0-3]):[0-5]\d$/.test(reminderValue)) void update({ reminderTime: reminderValue }); else setError('Gib die Zeit im 24-Stunden-Format HH:MM ein.'); }} keyboardType="numbers-and-punctuation" maxLength={5} accessibilityLabel="Erinnerungszeit, 24 Stunden" style={[s.input, { marginTop: 10, width: 115 }]} /><Text style={s.hint}>Format HH:MM. Die Einstellung wird gespeichert; eine geplante Geräteerinnerung ist noch nicht eingerichtet.</Text></Card>
    <SectionTitle kicker="DEINE ERFAHRUNG" title="Lernhilfe" />
    <Card>
      <SettingRow title="App-Sprache" detail="Die React Native Oberfläche ist derzeit auf Deutsch" value={false} trailing="DE" onPress={() => Alert.alert('Weitere Sprache folgt', 'Englische Inhalte sind im Profilmodell vorbereitet. Die App-Oberfläche ist noch nicht vollständig übersetzt, deshalb bleibt sie auf Deutsch.')} />
      <SettingRow title="Adaptive Lernstufe" detail="Die Präferenz wird gespeichert; automatische Lernpfad-Anpassung folgt noch." value={false} trailing={profile.adaptiveLevelEnabled === false ? 'AUS' : 'SPÄTER'} onPress={() => Alert.alert('Adaptive Einstufung folgt', 'Der Lernpfad berücksichtigt diese Einstellung noch nicht. Die vorhandene Platzierungsfunktion muss zuerst in das React Native Onboarding integriert werden.')} />
      <SettingRow title="Sprachausgabe" detail="Deutsche Beispielsätze anhören" value={profile.speechOutputEnabled ?? true} onPress={() => void update({ speechOutputEnabled: !(profile.speechOutputEnabled ?? true) })} />
    </Card>
    <SectionTitle kicker="BENACHRICHTIGUNGEN" title="Deine Auswahl" />
    <Card>
      <SettingRow title="Lernhinweise" detail="Erinnerungen an deine Lernzeit" value={prefs.learningReminder} onPress={() => void update({ notificationPreferences: { ...prefs, learningReminder: !prefs.learningReminder } })} />
      <SettingRow title="Gruppennachrichten" detail="Neuigkeiten aus Lerngruppen" value={prefs.groupMessages} onPress={() => void update({ notificationPreferences: { ...prefs, groupMessages: !prefs.groupMessages } })} />
      <SettingRow title="Wochenrückblick" detail="Eine Übersicht deines Lernrhythmus" value={prefs.weeklySummary} onPress={() => void update({ notificationPreferences: { ...prefs, weeklySummary: !prefs.weeklySummary } })} />
      <SettingRow title="Mitteilungen verwalten" detail="Deine Wortwerk Inbox öffnen" value={false} onPress={() => onOpen('notifications')} />
      <SettingRow title="Push-Mitteilungen" detail={profile.pushEnabled ? 'Auf diesem Konto eingeschaltet' : 'Gerätebereitstellung nicht verbunden'} value={profile.pushEnabled === true} onPress={() => {
        if (!profile.pushEnabled) { Alert.alert('Gerätebereitstellung fehlt', 'Push ist noch nicht auf diesem Gerät registriert. Diese Einstellung kann Push nicht fälschlich aktivieren.'); return; }
        Alert.alert('Push ausschalten?', 'Registrierte Geräte werden von Wortwerk abgemeldet.', [{ text: 'Abbrechen', style: 'cancel' }, { text: 'Ausschalten', style: 'destructive', onPress: () => { setBusy(true); void setPushEnabled(false).then(() => onSaved({ ...profile, pushEnabled: false })).catch(() => setError('Push konnte nicht ausgeschaltet werden.')).finally(() => setBusy(false)); } }]);
      }} />
    </Card>
    <Text style={s.hint}>Die Mitteilungskategorien werden in deinem Profil gespeichert. Geräteerinnerungen und kategoriebezogener Versand sind noch nicht eingerichtet.</Text>
    {busy ? <Text style={s.hint}>Wird sicher gespeichert …</Text> : null}{error ? <Text style={s.error}>{error}</Text> : null}
    <View style={{ height: 18 }} />
  </Screen>;
}

export function NotificationsScreen({ uid, width, onBack }: Props) {
  const [items, setItems] = useState<NotificationItem[]>();
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const reducedMotion = useReducedMotion();
  useEffect(() => { let active = true; void loadNotifications(uid).then((result) => { if (active) setItems(result); }).catch(() => { if (active) setError('Deine Mitteilungen konnten nicht geladen werden.'); }); return () => { active = false; }; }, [uid, reload]);
  const markRead = async (item: NotificationItem) => { if (item.read) return; setItems((old) => old?.map((row) => row.id === item.id ? { ...row, read: true } : row)); try { await markNotificationRead(item.id); } catch { setItems((old) => old?.map((row) => row.id === item.id ? { ...row, read: false } : row)); setError('Der Gelesen-Status konnte nicht gespeichert werden.'); } };
  return <Screen title="Mitteilungen" eyebrow="DEIN WORTWERK POSTFACH" width={width} onBack={onBack}>
    {error ? <FriendlyEmpty title="Postfach gerade nicht erreichbar" body={error} onRetry={() => { setError(''); setItems(undefined); setReload((n) => n + 1); }} /> : !items ? <Text style={s.hint}>Dein Postfach wird geöffnet …</Text> : items.length === 0 ? <Card><Text style={s.cardTitle}>Alles ruhig hier</Text><Text style={s.hint}>Wenn du ein neues Niveau freischaltest, findest du die Nachricht hier.</Text></Card> : items.map((item, index) => <Animated.View key={item.id} entering={reducedMotion ? undefined : FadeInDown.delay(Math.min(index * 45, 270))}><Tap onPress={() => void markRead(item)} accessibilityLabel={`${item.read ? 'Gelesen' : 'Ungelesen'}: ${notificationTitle(item)}`}><Card style={[s.notification, !item.read && s.unread]}><View style={s.row}><View style={s.spark}><Text style={{ color: colors.ink, fontWeight: '900' }}>✦</Text></View><View style={{ flex: 1 }}><Text style={s.cardTitle}>{notificationTitle(item)}</Text><Text style={s.hint}>{notificationBody(item)}</Text>{item.createdAt ? <Text style={s.date}>{new Intl.DateTimeFormat('de-DE', { dateStyle: 'medium' }).format(item.createdAt)}</Text> : null}</View><Text style={s.readMark}>{item.read ? '✓' : '●'}</Text></View></Card></Tap></Animated.View>)}
  </Screen>;
}

export function StreakScreen({ uid, profile, width, onBack }: Props) {
  const [days, setDays] = useState<{ date: string; xp: number }[]>();
  const [error, setError] = useState(false);
  const [reload, setReload] = useState(0);
  useEffect(() => { let active = true; void getDocs(query(collection(db, 'users', uid, 'days'), orderBy('date', 'desc'), limit(35))).then((result) => { if (active) setDays(result.docs.map((item) => ({ date: String(item.data().date ?? item.id), xp: Number(item.data().xpTotal ?? 0) })).filter((day) => /^\d{4}-\d{2}-\d{2}$/.test(day.date))); }).catch(() => { if (active) setError(true); }); return () => { active = false; }; }, [uid, reload]);
  const active = new Set((days ?? []).filter((day) => day.xp > 0).map((day) => day.date));
  const today = new Date(); const start = new Date(today); start.setDate(today.getDate() - 27); start.setDate(start.getDate() - ((start.getDay() + 6) % 7));
  const calendar = Array.from({ length: 35 }, (_, i) => { const date = new Date(start); date.setDate(start.getDate() + i); const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`; return { key, day: date.getDate(), on: active.has(key), month: date.getMonth() }; });
  return <Screen title="Dein Lernrhythmus" eyebrow="KLEINE SCHRITTE ZÄHLEN" width={width} onBack={onBack}>
    <Card style={s.streakHero}><Text style={s.streakEmoji}>✦</Text><Text style={s.streakCount}>{profile.streak.current}</Text><Text style={s.streakCaption}>LERNTAGE IN FOLGE</Text><Text style={s.hint}>Dein längster Rhythmus: {profile.streak.longest} Tage · {profile.streak.shields} Lernschutz</Text></Card>
    <SectionTitle kicker="LETZTE 5 WOCHEN" title="Jeder Schritt zählt" />
    <Card><View style={s.calendar}>{calendar.map((cell, i) => <View key={cell.key} accessibilityLabel={`${cell.key}${cell.on ? ', gelernt' : ''}`} style={[s.calendarDay, cell.on && s.calendarOn, cell.month !== today.getMonth() && s.calendarFaded]}><Text style={[s.calendarText, cell.on && { color: colors.card }]}>{cell.day}</Text></View>)}</View><View style={[s.row, { marginTop: 16 }]}><View style={s.legendDot} /><Text style={s.hint}>Ein aktiver Lerntag wird auf deinem Gerät gezeigt.</Text></View></Card>
    {error ? <FriendlyEmpty title="Rhythmus gerade nicht erreichbar" body="Dein Profilwert bleibt sichtbar. Die Tagesübersicht konnte nicht geladen werden." onRetry={() => { setError(false); setDays(undefined); setReload((n) => n + 1); }} /> : !days ? <Text style={s.hint}>Deine Lerntage werden geladen …</Text> : null}
  </Screen>;
}

export function AccountScreen({ width, onBack }: Props) {
  const [email, setEmail] = useState(''); const [password, setPassword] = useState(''); const [busy, setBusy] = useState(false); const [message, setMessage] = useState(''); const [error, setError] = useState('');
  const user = auth.currentUser;
  const createOrLink = async () => {
    if (!email.includes('@') || password.length < 8) { setError('Gib eine gültige E-Mail und ein Passwort mit mindestens 8 Zeichen ein.'); return; }
    setBusy(true); setError(''); setMessage('');
    try {
      if (user?.isAnonymous) await linkWithCredential(user, EmailAuthProvider.credential(email.trim(), password));
      else throw new Error('account-already-linked');
      if (auth.currentUser) await sendEmailVerification(auth.currentUser); setMessage('Dein Konto ist gesichert. Prüfe dein Postfach, um die E-Mail zu bestätigen.'); setPassword('');
    } catch (reason) { const code = reason && typeof reason === 'object' && 'code' in reason ? String((reason as { code: unknown }).code) : ''; setError(code.includes('email-already-in-use') ? 'Diese E-Mail gehört schon zu einem Konto. Melde dich mit diesem Konto auf einem Gerät an, auf dem dein Lernstand liegt, und verknüpfe es dort.' : code.includes('credential-already-in-use') ? 'Dieses Anmeldeverfahren gehört bereits zu einem anderen Konto.' : code === 'account-already-linked' ? 'Dieses Lernkonto hat bereits eine Anmeldung. Verwende „Passwort zurücksetzen“, falls du Hilfe beim Zugang brauchst.' : 'Das Konto konnte nicht gesichert werden. Prüfe E-Mail, Passwort und Netzwerk.'); }
    finally { setBusy(false); }
  };
  const reset = async () => { if (!email.includes('@')) { setError('Gib zuerst deine E-Mail-Adresse ein.'); return; } setBusy(true); setError(''); try { await sendPasswordResetEmail(auth, email.trim()); setMessage('Falls ein Konto mit dieser E-Mail existiert, kommt eine Anleitung zum Zurücksetzen.'); } catch { setError('Die E-Mail zum Zurücksetzen konnte gerade nicht gesendet werden.'); } finally { setBusy(false); } };
  return <Screen title="Konto sichern" eyebrow="DEIN FORTSCHRITT BLEIBT DEINER" width={width} onBack={onBack}>
    <Card><Text style={s.cardTitle}>{user?.isAnonymous ? 'Gastkonto sichern' : 'E-Mail-Konto'}</Text><Text style={s.hint}>{user?.isAnonymous ? 'Verbinde deine E-Mail mit diesem Lernkonto, damit du deinen Fortschritt auf einem weiteren Gerät behalten kannst.' : `Dieses Lernkonto ist mit ${user?.email ?? 'einer E-Mail'} verbunden.`}</Text>{user?.isAnonymous ? <><TextInput value={email} onChangeText={setEmail} autoCapitalize="none" autoComplete="email" keyboardType="email-address" placeholder="name@beispiel.de" style={[s.input, { marginTop: 16 }]} accessibilityLabel="E-Mail-Adresse"/><TextInput value={password} onChangeText={setPassword} secureTextEntry autoComplete="new-password" placeholder="Mindestens 8 Zeichen" style={[s.input, { marginTop: 10 }]} accessibilityLabel="Passwort"/><View style={{ height: 14 }}/><PrimaryButton title={busy ? 'Wird gesichert …' : 'Konto erstellen & verknüpfen'} busy={busy} onPress={() => void createOrLink()} /></> : <Text style={[s.hint, { marginTop: 14 }]}>{user?.emailVerified ? 'Deine E-Mail ist bestätigt.' : 'Prüfe dein Postfach, um deine E-Mail zu bestätigen.'}</Text>}<TextInput value={email} onChangeText={setEmail} autoCapitalize="none" autoComplete="email" keyboardType="email-address" placeholder={user?.email ?? 'name@beispiel.de'} style={[s.input, { marginTop: 12 }]} accessibilityLabel="E-Mail zum Zurücksetzen"/><Tap onPress={() => void reset()} style={{ minHeight: 50, justifyContent: 'center', alignItems: 'center' }}><Text style={s.link}>Passwort zurücksetzen</Text></Tap>
      {message ? <Text style={s.success}>{message}</Text> : null}{error ? <Text style={s.error}>{error}</Text> : null}
    </Card>
    <Card><Text style={s.cardTitle}>Konto löschen</Text><Text style={s.hint}>Die App bietet das Löschen noch nicht an, weil dafür ein bestätigter Serverprozess alle Lern-, Geräte- und Gesprächsdaten sicher entfernen muss. So wird keine halbe Löschung versprochen.</Text></Card>
  </Screen>;
}

function Screen({ title, eyebrow, width, onBack, children }: { title: string; eyebrow: string; width: number; onBack: () => void; children: React.ReactNode }) {
  return <ScrollView contentContainerStyle={[ui.scroll, { paddingTop: 8 }]} showsVerticalScrollIndicator={false}><View style={{ width }}><Tap onPress={onBack} accessibilityLabel="Zurück" style={s.back}><Text style={s.link}>← Zurück</Text></Tap><View style={s.header}><Text style={s.eyebrow}>{eyebrow}</Text><Text style={s.title}>{title}</Text></View>{children}<View style={{ height: 25 }}/></View></ScrollView>;
}
function Chip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) { return <Tap onPress={onPress} style={[s.chip, selected && s.chipSelected]}><Text style={[s.chipText, selected && s.chipTextSelected]}>{label}</Text></Tap>; }
function SettingRow({ title, detail, value, trailing, onPress }: { title: string; detail: string; value: boolean; trailing?: string; onPress: () => void }) { return <Tap onPress={onPress} style={s.setting}><View style={{ flex: 1 }}><Text style={s.cardTitle}>{title}</Text><Text style={s.hint}>{detail}</Text></View><View style={[s.switch, value && s.switchOn]}><View style={[s.switchKnob, value && s.switchKnobOn]} /></View>{trailing ? <Text style={s.trailing}>{trailing}</Text> : null}</Tap>; }
function notificationTitle(item: NotificationItem) { return item.kind === 'levelUnlocked' ? `${item.level ?? 'Ein neues Niveau'} freigeschaltet` : 'Neuigkeit von Wortwerk'; }
function notificationBody(item: NotificationItem) { return item.kind === 'levelUnlocked' ? `${item.level ?? 'Ein neues Niveau'} ist freigeschaltet – dein Lernweg geht weiter.` : 'Öffne die App, um mehr zu erfahren.'; }

const s = StyleSheet.create({ back: { alignSelf: 'flex-start', minHeight: 42, justifyContent: 'center', paddingRight: 12 }, header: { marginBottom: 21 }, eyebrow: { color: colors.streak, fontSize: 10, fontWeight: '900', letterSpacing: 1.2 }, title: { color: colors.ink, fontSize: 28, lineHeight: 34, fontWeight: '900', letterSpacing: -0.8, marginTop: 5 }, label: { color: colors.ink, fontSize: 12, fontWeight: '800', marginBottom: 8 }, input: { minHeight: 50, borderRadius: 16, backgroundColor: colors.paper, borderWidth: 1, borderColor: colors.line, paddingHorizontal: 14, color: colors.ink, fontSize: 15 }, hint: { color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 5 }, error: { color: colors.danger, fontSize: 12, lineHeight: 18, marginVertical: 12, textAlign: 'center' }, success: { color: '#245D31', fontSize: 12, lineHeight: 18, marginTop: 12 }, link: { color: colors.ink, fontSize: 13, fontWeight: '800' }, wrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 }, chip: { minHeight: 42, borderRadius: 999, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.paper, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 16 }, chipSelected: { backgroundColor: colors.ink, borderColor: colors.ink }, chipText: { color: colors.ink, fontSize: 12, fontWeight: '800' }, chipTextSelected: { color: colors.paper }, setting: { minHeight: 67, borderBottomWidth: 1, borderBottomColor: colors.line, flexDirection: 'row', alignItems: 'center', gap: 12 }, cardTitle: { color: colors.ink, fontSize: 14, fontWeight: '900' }, switch: { width: 43, height: 26, borderRadius: 999, backgroundColor: '#D6D2CB', padding: 3, justifyContent: 'center' }, switchOn: { backgroundColor: colors.ink }, switchKnob: { width: 20, height: 20, borderRadius: 10, backgroundColor: colors.card }, switchKnobOn: { alignSelf: 'flex-end' }, trailing: { color: colors.ink, fontSize: 11, fontWeight: '900' }, notification: { marginBottom: 10 }, unread: { borderColor: colors.streak, backgroundColor: '#FFF9F1' }, row: { flexDirection: 'row', alignItems: 'center', gap: 11 }, spark: { width: 40, height: 40, borderRadius: 15, backgroundColor: colors.levels.C2, alignItems: 'center', justifyContent: 'center' }, date: { color: colors.muted, fontSize: 10, marginTop: 6 }, readMark: { color: colors.streak, fontSize: 10 }, streakHero: { alignItems: 'center', backgroundColor: colors.ink, marginBottom: 24 }, streakEmoji: { color: colors.levels.C2, fontSize: 24 }, streakCount: { color: colors.paper, fontSize: 62, lineHeight: 67, fontWeight: '900' }, streakCaption: { color: colors.levels.C2, letterSpacing: 1.2, fontSize: 10, fontWeight: '900', marginBottom: 9 }, calendar: { flexDirection: 'row', flexWrap: 'wrap', gap: 5, justifyContent: 'space-between' }, calendarDay: { width: '12%', aspectRatio: 1, borderRadius: 11, backgroundColor: colors.paper, alignItems: 'center', justifyContent: 'center' }, calendarOn: { backgroundColor: colors.streak }, calendarFaded: { opacity: 0.55 }, calendarText: { color: colors.ink, fontSize: 10, fontWeight: '800' }, legendDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.streak } });
