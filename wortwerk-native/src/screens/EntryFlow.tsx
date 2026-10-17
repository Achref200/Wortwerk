import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, TextInput, View, useWindowDimensions } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { EmailAuthProvider, createUserWithEmailAndPassword, linkWithCredential, sendPasswordResetEmail, signInWithEmailAndPassword } from 'firebase/auth';
import Animated, { FadeInDown, FadeInUp, useReducedMotion } from 'react-native-reanimated';
import { auth } from '../firebase';
import { colors } from '../theme';
import { PrimaryButton, Tap } from '../ui';

type Screen = 'splash' | 'welcome' | 'login' | 'signup' | 'forgot';
type Props = { onGuest: () => Promise<void>; initialError?: string };

export function EntryFlow({ onGuest, initialError }: Props) {
  const [screen, setScreen] = useState<Screen>('splash');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const { width } = useWindowDimensions();
  const motion = useReducedMotion();
  useEffect(() => {
    const timer = setTimeout(() => setScreen('welcome'), 1050);
    return () => clearTimeout(timer);
  }, []);

  const changeScreen = (next: Screen) => { setError(''); setNotice(''); setScreen(next); };
  const submit = async () => {
    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.includes('@') || (screen !== 'forgot' && password.length < 8)) {
      setError(screen === 'forgot' ? 'Gib eine gültige E-Mail-Adresse ein.' : 'Gib eine gültige E-Mail und ein Passwort mit mindestens 8 Zeichen ein.');
      return;
    }
    setBusy(true); setError(''); setNotice('');
    try {
      if (screen === 'forgot') {
        await sendPasswordResetEmail(auth, normalizedEmail);
        setNotice('Wenn ein Konto mit dieser E-Mail existiert, erhältst du eine Anleitung zum Zurücksetzen.');
      } else if (screen === 'signup') {
        if (auth.currentUser?.isAnonymous) {
          await linkWithCredential(auth.currentUser, EmailAuthProvider.credential(normalizedEmail, password));
        } else {
          await createUserWithEmailAndPassword(auth, normalizedEmail, password);
        }
      } else {
        await signInWithEmailAndPassword(auth, normalizedEmail, password);
      }
    } catch (reason) {
      setError(authError(reason));
    } finally {
      setBusy(false);
    }
  };

  if (screen === 'splash') return <SafeAreaView style={s.splash}>
    <StatusBar style="dark" />
    <Animated.View entering={motion ? undefined : FadeInUp.delay(120).duration(500)} style={s.brandRow}><View style={s.brandMark}><Text style={s.brandMarkText}>w</Text></View><Text style={s.brand}>wortwerk</Text></Animated.View>
    <Text style={s.tagline}>Deutsch. In deinem Rhythmus.</Text>
    <View style={s.splashDots}><View style={s.splashDot} /><View style={[s.splashDot, { opacity: 0.58 }]} /><View style={[s.splashDot, { opacity: 0.3 }]} /></View>
  </SafeAreaView>;

  const formTitle = screen === 'login' ? 'Schön, dass du wieder da bist.' : screen === 'signup' ? 'Dein Lernweg beginnt hier.' : 'Wir helfen dir wieder hinein.';
  const formCopy = screen === 'login' ? 'Melde dich an und mach genau dort weiter, wo du aufgehört hast.' : screen === 'signup' ? 'Erstelle dein Konto und behalte deinen Lernfortschritt auf jedem Gerät.' : 'Wir senden dir einen sicheren Link zum Zurücksetzen deines Passworts.';

  return <SafeAreaView style={s.screen} edges={['top', 'bottom']}><StatusBar style="dark" /><KeyboardAvoidingView style={s.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
    <ScrollView contentContainerStyle={[s.content, { width: Math.min(width - 36, 480) }]} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
      <View style={s.topBar}><View style={s.brandRow}><View style={s.brandMark}><Text style={s.brandMarkText}>w</Text></View><Text style={s.brand}>wortwerk</Text></View><Text style={s.topCaption}>DEIN DEUTSCH. DEIN WEG.</Text></View>
      {screen === 'welcome' ? <Animated.View entering={motion ? undefined : FadeInDown.delay(60).duration(500)}>
        <Text style={s.title}>Willkommen bei Wortwerk.</Text>
        <Text style={s.copy}>Deutsch für deinen Alltag. Wähle eine Situation, übe kurze Sätze und sieh deinen Fortschritt wachsen.</Text>
        {initialError ? <Text style={s.error}>{initialError}</Text> : null}
        <PrimaryButton title="Kostenloses Konto erstellen" onPress={() => changeScreen('signup')} />
        <Tap onPress={() => changeScreen('login')} style={s.secondaryButton}><Text style={s.secondaryText}>Ich habe schon ein Konto</Text></Tap>
        <Tap onPress={() => { setBusy(true); setError(''); void onGuest().catch((reason: unknown) => setError(friendlyError(reason))).finally(() => setBusy(false)); }} disabled={busy} style={s.guestButton}><Text style={s.guestText}>{busy ? 'Dein Lernweg wird vorbereitet …' : 'Erst einmal ohne Konto starten'}</Text></Tap>
        {error ? <Text style={s.error}>{error}</Text> : null}
        <Text style={s.legal}>Mit einem Gastkonto wird dein Fortschritt auf diesem Gerät gespeichert. Du kannst es später sichern.</Text>
      </Animated.View> : <Animated.View entering={motion ? undefined : FadeInDown.duration(350)} style={s.formWrap}>
        <Tap onPress={() => changeScreen('welcome')} style={s.back}><Text style={s.backText}>‹  Zurück</Text></Tap>
        <Text style={s.kicker}>{screen === 'login' ? 'WILLKOMMEN ZURÜCK' : screen === 'signup' ? 'DEIN WORTWERK-KONTO' : 'KONTO ZURÜCKSETZEN'}</Text>
        <Text style={s.title}>{formTitle}</Text><Text style={s.copy}>{formCopy}</Text>
        <Text style={s.label}>E-Mail-Adresse</Text>
        <TextInput value={email} onChangeText={setEmail} placeholder="du@beispiel.de" placeholderTextColor="#88848E" autoCapitalize="none" autoComplete="email" keyboardType="email-address" textContentType="emailAddress" accessibilityLabel="E-Mail-Adresse" style={s.input} returnKeyType="next" />
        {screen !== 'forgot' ? <><Text style={s.label}>Passwort</Text><TextInput value={password} onChangeText={setPassword} placeholder="Mindestens 8 Zeichen" placeholderTextColor="#88848E" autoCapitalize="none" autoComplete={screen === 'signup' ? 'new-password' : 'current-password'} textContentType={screen === 'signup' ? 'newPassword' : 'password'} secureTextEntry accessibilityLabel="Passwort" style={s.input} onSubmitEditing={() => void submit()} /></> : null}
        {error ? <Text accessibilityLiveRegion="polite" style={s.error}>{error}</Text> : null}
        {notice ? <Text accessibilityLiveRegion="polite" style={s.notice}>{notice}</Text> : null}
        <View style={{ height: 16 }} /><PrimaryButton title={screen === 'login' ? 'Anmelden' : screen === 'signup' ? 'Konto erstellen' : 'Link senden'} busy={busy} onPress={() => void submit()} />
        {screen === 'login' ? <Tap onPress={() => changeScreen('forgot')} style={s.linkButton}><Text style={s.link}>Passwort vergessen?</Text></Tap> : null}
        {screen === 'login' || screen === 'signup' ? <Tap onPress={() => changeScreen(screen === 'login' ? 'signup' : 'login')} style={s.switchButton}><Text style={s.switchText}>{screen === 'login' ? 'Noch kein Konto? Konto erstellen' : 'Schon ein Konto? Anmelden'}</Text></Tap> : null}
      </Animated.View>}
      <View style={s.footer}><Text style={s.footerCopy}>WORTWERK · DEUTSCH LERNEN</Text></View>
    </ScrollView>
  </KeyboardAvoidingView></SafeAreaView>;
}

function authError(reason: unknown) {
  const code = reason && typeof reason === 'object' && 'code' in reason ? String((reason as { code: unknown }).code) : '';
  if (code.includes('email-already-in-use') || code.includes('credential-already-in-use')) return 'Für diese E-Mail gibt es bereits ein Konto. Melde dich stattdessen an.';
  if (code.includes('invalid-credential') || code.includes('wrong-password') || code.includes('user-not-found')) return 'E-Mail oder Passwort stimmen nicht. Prüfe deine Angaben und versuche es erneut.';
  if (code.includes('weak-password')) return 'Wähle ein Passwort mit mindestens 8 Zeichen.';
  if (code.includes('network-request-failed')) return 'Keine Verbindung. Prüfe dein Netzwerk und versuche es erneut.';
  if (code.includes('too-many-requests')) return 'Zu viele Versuche. Warte kurz und versuche es später erneut.';
  return 'Das hat gerade nicht geklappt. Prüfe deine Angaben und versuche es erneut.';
}

function friendlyError(reason: unknown) {
  if (reason && typeof reason === 'object' && 'code' in reason && String((reason as { code: unknown }).code).includes('network')) return 'Keine Verbindung. Prüfe dein Netzwerk und versuche es erneut.';
  return 'Dein Lernweg konnte gerade nicht gestartet werden. Versuche es bitte erneut.';
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.paper },
  content: { flexGrow: 1, alignSelf: 'center', paddingTop: 14, paddingBottom: 22 },
  splash: { flex: 1, backgroundColor: colors.paper, alignItems: 'center', justifyContent: 'center' },
  brandRow: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  brandMark: { width: 30, height: 30, borderRadius: 11, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center' },
  brandMarkText: { color: colors.paper, fontSize: 20, fontWeight: '900', fontStyle: 'italic' },
  brand: { fontSize: 21, fontWeight: '900', color: colors.ink, letterSpacing: -0.8 },
  tagline: { marginTop: 9, color: colors.muted, fontSize: 13 },
  splashDots: { flexDirection: 'row', gap: 6, marginTop: 28 },
  splashDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.streak },
  topBar: { height: 46, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 },
  topCaption: { color: colors.muted, fontSize: 9, fontWeight: '800', letterSpacing: 1.1 },
  title: { color: colors.ink, fontSize: 29, lineHeight: 34, letterSpacing: -0.8, fontWeight: '900', marginTop: 7 },
  copy: { color: colors.muted, fontSize: 14, lineHeight: 21, marginTop: 9, marginBottom: 20 },
  secondaryButton: { minHeight: 52, borderRadius: 18, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card, alignItems: 'center', justifyContent: 'center', marginTop: 10 },
  secondaryText: { color: colors.ink, fontSize: 14, fontWeight: '800' },
  guestButton: { minHeight: 47, alignItems: 'center', justifyContent: 'center', marginTop: 2 },
  guestText: { color: colors.muted, fontSize: 13, fontWeight: '700' },
  legal: { color: colors.muted, fontSize: 10, lineHeight: 15, textAlign: 'center', paddingHorizontal: 16, marginTop: 8 },
  footer: { marginTop: 'auto', paddingTop: 18, flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: 8 },
  footerCopy: { color: colors.muted, fontSize: 9, fontWeight: '900', letterSpacing: 1.1 },
  formWrap: { paddingTop: 6 },
  back: { alignSelf: 'flex-start', minHeight: 42, justifyContent: 'center', paddingHorizontal: 4 },
  backText: { color: colors.muted, fontWeight: '800', fontSize: 14 },
  kicker: { color: colors.streak, fontSize: 10, fontWeight: '900', letterSpacing: 1.2, marginTop: 2 },
  label: { color: colors.ink, fontSize: 12, fontWeight: '800', marginTop: 16, marginBottom: 7 },
  input: { height: 54, borderRadius: 16, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card, paddingHorizontal: 15, fontSize: 15, color: colors.ink },
  linkButton: { minHeight: 47, alignItems: 'center', justifyContent: 'center' },
  link: { color: colors.streak, fontSize: 13, fontWeight: '800' },
  switchButton: { minHeight: 49, alignItems: 'center', justifyContent: 'center', marginTop: 4 },
  switchText: { color: colors.ink, fontSize: 13, fontWeight: '800' },
  error: { marginTop: 10, color: colors.danger, fontSize: 12, lineHeight: 17, fontWeight: '700' },
  notice: { marginTop: 10, color: '#39744B', fontSize: 12, lineHeight: 17, fontWeight: '700' },
});
