import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, TextInput, View, useWindowDimensions } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { EmailAuthProvider, createUserWithEmailAndPassword, linkWithCredential, sendPasswordResetEmail, signInWithEmailAndPassword } from 'firebase/auth';
import Animated, { FadeInDown, FadeInUp, useReducedMotion } from 'react-native-reanimated';
import { auth } from '../firebase';
import { colors, radii } from '../theme';
import { Pingo, MascotBubble, Tap, PrimaryButton, SecondaryButton } from '../ui';

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
      setError(screen === 'forgot' ? 'Please enter a valid email address.' : 'Please enter a valid email and a password with at least 8 characters.');
      return;
    }
    setBusy(true); setError(''); setNotice('');
    try {
      if (screen === 'forgot') {
        await sendPasswordResetEmail(auth, normalizedEmail);
        setNotice('If an account exists with this email, you will receive instructions to reset it.');
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
    <View style={s.splashBg} />
    <Animated.View entering={motion ? undefined : FadeInUp.delay(80).duration(520)} style={s.splashMascot}><Pingo size={132} mood="happy" /></Animated.View>
    <Animated.View entering={motion ? undefined : FadeInUp.delay(180).duration(520)} style={s.brandRow}><View style={s.brandMark}><Text style={s.brandMarkText}>w</Text></View><Text style={s.brand}>wortwerk</Text></Animated.View>
    <Text style={s.tagline}>German, at your own pace.</Text>
    <View style={s.splashDotRow}>
      <View style={[s.splashDotA, { opacity: motion ? 0 : 0.9, transform: [{ scale: motion ? 0 : 1 }] }]} />
      <View style={[s.splashDotB, { opacity: motion ? 0 : 0.9, transform: [{ scale: motion ? 0 : 1 }] }]} />
      <View style={[s.splashDotC, { opacity: motion ? 0 : 0.9, transform: [{ scale: motion ? 0 : 1 }] }]} />
    </View>
  </SafeAreaView>;

  const formTitle = screen === 'login' ? 'Welcome back' : screen === 'signup' ? 'Your journey starts here' : 'Reset password';
  const formCopy = screen === 'login' ? 'Sign in to continue where you left off.' : screen === 'signup' ? 'Create your account and keep your progress on every device.' : 'We will send you a secure link to reset your password.';

  return <SafeAreaView style={s.screen} edges={['top', 'bottom']}><StatusBar style="dark" /><KeyboardAvoidingView style={s.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
    <ScrollView contentContainerStyle={[s.content, { width: Math.min(width - 36, 480) }]} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
      <View style={[s.topBar, { backgroundColor: colors.surfaceLift, borderBottomColor: colors.line }]}><View style={s.brandRow}><View style={s.brandMark}><Text style={s.brandMarkText}>w</Text></View><Text style={s.brand}>wortwerk</Text></View><Text style={s.topCaption}>YOUR GERMAN. YOUR WAY.</Text></View>
      {screen === 'welcome' ? <Animated.View entering={motion ? undefined : FadeInDown.delay(60).duration(500)}>
        <Text style={s.title}>Welcome to Wortwerk.</Text>
        <Text style={s.copy}>German for everyday life. Pick a situation, practice short sentences and watch your progress grow.</Text>
        {initialError ? <Text style={s.error}>{initialError}</Text> : null}
        <PrimaryButton title="Create free account" onPress={() => changeScreen('signup')} />
        <Tap onPress={() => changeScreen('login')} style={s.secondaryButton}><Text style={s.secondaryText}>I already have an account</Text></Tap>
        <Tap onPress={() => { setBusy(true); setError(''); void onGuest().catch((reason: unknown) => setError(friendlyError(reason))).finally(() => setBusy(false)); }} disabled={busy} style={s.guestButton}><Text style={s.guestText}>{busy ? 'Preparing your learning path …' : 'Start without an account'}</Text></Tap>
        {error ? <Text style={s.error}>{error}</Text> : null}
        <Text style={s.legal}>With a guest account, your progress is saved on this device. You can secure it later.</Text>
      </Animated.View> : <Animated.View entering={motion ? undefined : FadeInDown.duration(350)} style={s.formWrap}>
        <Tap onPress={() => changeScreen('welcome')} style={s.back}><Text style={s.backText}>← Back</Text></Tap>
        <Text style={s.kicker}>{screen === 'login' ? 'WELCOME BACK' : screen === 'signup' ? 'YOUR WORTWERK ACCOUNT' : 'RESET PASSWORD'}</Text>
        <Text style={s.title}>{formTitle}</Text><Text style={s.copy}>{formCopy}</Text>
        <Text style={s.label}>Email address</Text>
        <TextInput value={email} onChangeText={setEmail} placeholder="you@example.com" placeholderTextColor="#88848E" autoCapitalize="none" autoComplete="email" keyboardType="email-address" textContentType="emailAddress" accessibilityLabel="Email address" style={s.input} returnKeyType="next" />
        {screen !== 'forgot' ? <><Text style={s.label}>Password</Text><TextInput value={password} onChangeText={setPassword} placeholder="At least 8 characters" placeholderTextColor="#88848E" autoCapitalize="none" autoComplete={screen === 'signup' ? 'new-password' : 'current-password'} textContentType={screen === 'signup' ? 'newPassword' : 'password'} secureTextEntry accessibilityLabel="Password" style={s.input} onSubmitEditing={() => void submit()} /></> : null}
        {error ? <Text accessibilityLiveRegion="polite" style={s.error}>{error}</Text> : null}
        {notice ? <Text accessibilityLiveRegion="polite" style={s.notice}>{notice}</Text> : null}
        <View style={{ height: 16 }} /><PrimaryButton title={screen === 'login' ? 'Sign in' : screen === 'signup' ? 'Create account' : 'Send link'} busy={busy} onPress={() => void submit()} />
        {screen === 'login' ? <Tap onPress={() => changeScreen('forgot')} style={s.linkButton}><Text style={s.link}>Forgot password?</Text></Tap> : null}
        {screen === 'login' || screen === 'signup' ? <Tap onPress={() => changeScreen(screen === 'login' ? 'signup' : 'login')} style={s.switchButton}><Text style={s.switchText}>{screen === 'login' ? "Don't have an account? Create account" : 'Already have an account? Sign in'}</Text></Tap> : null}
      </Animated.View>}
      <View style={s.footer}><Text style={s.footerCopy}>WORTWERK · GERMAN LEARNING</Text></View>
    </ScrollView>
  </KeyboardAvoidingView></SafeAreaView>;
}

function authError(reason: unknown) {
  const code = reason && typeof reason === 'object' && 'code' in reason ? String((reason as { code: unknown }).code) : '';
  if (code.includes('email-already-in-use') || code.includes('credential-already-in-use')) return 'An account already exists for this email. Sign in instead.';
  if (code.includes('invalid-credential') || code.includes('wrong-password') || code.includes('user-not-found')) return 'Email or password do not match. Please check your details and try again.';
  if (code.includes('weak-password')) return 'Choose a password with at least 8 characters.';
  if (code.includes('network-request-failed')) return 'No connection. Please check your network and try again.';
  if (code.includes('too-many-requests')) return 'Too many attempts. Wait a moment and try again later.';
  return 'That did not work out. Please check your details and try again.';
}

function friendlyError(reason: unknown) {
  if (reason && typeof reason === 'object' && 'code' in reason && String((reason as { code: unknown }).code).includes('network')) return 'No connection. Please check your network and try again.';
  return 'Your learning journey could not be started right now. Please try again.';
}

const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  content: { flexGrow: 1, alignSelf: 'center', paddingTop: 12, paddingBottom: 22 },
  splash: { flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center' },
  splashBg: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: colors.backgroundSoft,
    borderTopLeftRadius: 0,
    borderTopRightRadius: 0,
  },
  brandRow: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  brandMark: { width: 32, height: 32, borderRadius: 12, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center', shadowColor: colors.ink, shadowRadius: 10, shadowOpacity: 0.32, shadowOffset: { width: 0, height: 5 } },
  splashMascot: { marginBottom: 18 },
  splashDotRow: { flexDirection: 'row', gap: 5, marginTop: 26 },
  splashDotA: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.streak, shadowColor: colors.streak, shadowRadius: 6, shadowOpacity: 0.4, shadowOffset: { width: 0, height: 2 } },
  splashDotB: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.streak, shadowColor: colors.streak, shadowRadius: 6, shadowOpacity: 0.4, shadowOffset: { width: 0, height: 2 } },
  splashDotC: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.streak, shadowColor: colors.streak, shadowRadius: 6, shadowOpacity: 0.4, shadowOffset: { width: 0, height: 2 } },

  // Keep this file compileable against the legacy ui/route modules that still reference
  // removed fragments. These values are intentionally omitted from this polish pass.
  FritzFace: undefined as any,
  FritzFaceSize: 42 as any,
  FritzFaceMood: 'idle' as any,
  brandMarkText: { color: colors.background, fontSize: 20, fontWeight: '900', fontStyle: 'italic' },
  brand: { fontSize: 21, fontWeight: '900', color: colors.ink, letterSpacing: -0.9 },
  tagline: { marginTop: 9, color: colors.inkMuted, fontSize: 13, fontWeight: '600' },
  splashDots: { flexDirection: 'row', gap: 6, marginTop: 28 },
  splashDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.streak },
  topBar: { height: 48, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12, borderBottomWidth: 1, borderBottomColor: colors.line },
  topCaption: { color: colors.muted, fontSize: 9, fontWeight: '800', letterSpacing: 1.1 },
  title: { color: colors.ink, fontSize: 28, lineHeight: 33, letterSpacing: -0.9, fontWeight: '900', marginTop: 6 },
  copy: { color: colors.inkSoft, fontSize: 14.5, lineHeight: 21.5, marginTop: 9, marginBottom: 22 },
  secondaryButton: { minHeight: 50, borderRadius: radii.sm, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.surface, alignItems: 'center', justifyContent: 'center', marginTop: 12 },
  secondaryText: { color: colors.ink, fontSize: 14, fontWeight: '700' },
  guestButton: { minHeight: 46, borderRadius: radii.pill, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, alignItems: 'center', justifyContent: 'center', marginTop: 2 },
  guestText: { color: colors.inkSoft, fontSize: 13, fontWeight: '600' },
  legal: { color: colors.inkMuted, fontSize: 10.5, lineHeight: 15, textAlign: 'center', paddingHorizontal: 16, marginTop: 10, fontWeight: '600' },
  footer: { marginTop: 'auto', paddingTop: 18, flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: 8 },
  footerCopy: { color: colors.muted, fontSize: 9, fontWeight: '900', letterSpacing: 1.1 },
  formWrap: { paddingTop: 6 },
  back: { alignSelf: 'flex-start', minHeight: 42, justifyContent: 'center', paddingHorizontal: 4 },
  backText: { color: colors.muted, fontWeight: '800', fontSize: 14 },
  kicker: { color: colors.streak, fontSize: 10, fontWeight: '900', letterSpacing: 1.2, marginTop: 2 },
  label: { color: colors.ink, fontSize: 12.5, fontWeight: '700', marginTop: 18, marginBottom: 8, letterSpacing: 0.2 },
  input: { height: 54, borderRadius: radii.input, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.surface, paddingHorizontal: 15, fontSize: 15.5, color: colors.ink, shadowColor: colors.vignette, shadowRadius: 8, shadowOpacity: 0.18, shadowOffset: { width: 0, height: 2 } },
  linkButton: { minHeight: 47, alignItems: 'center', justifyContent: 'center' },
  link: { color: colors.streak, fontSize: 13, fontWeight: '800' },
  switchButton: { minHeight: 49, alignItems: 'center', justifyContent: 'center', marginTop: 4 },
  switchText: { color: colors.ink, fontSize: 13, fontWeight: '800' },
  error: { marginTop: 12, color: colors.danger, fontSize: 12.5, lineHeight: 18, fontWeight: '600' },
  notice: { marginTop: 12, color: colors.success, fontSize: 12.5, lineHeight: 18, fontWeight: '600' },
});
