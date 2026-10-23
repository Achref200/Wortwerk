import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View, useWindowDimensions } from 'react-native';
import { SafeAreaProvider, SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { useLocalSearchParams, usePathname, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import * as Speech from 'expo-speech';
import Svg, { Path as SvgPath } from 'react-native-svg';
import Animated, { FadeInDown, FadeInUp, FlipInEasyY, FlipOutEasyY, LinearTransition, interpolate, useAnimatedStyle, useReducedMotion, useSharedValue, withRepeat, withSequence, withSpring, withTiming } from 'react-native-reanimated';
import {
  completeLesson, completeReview, ensureGuest, ensureProfile, finishOnboarding,
  greetingCards, listenHome, loadLearningPath, loadLesson,
  watchAuth, watchMissions,
  type DailyMission, type HomeSnapshot, type LearningLesson, type LearningPath,
  type LearnerProfile, type PathLesson,
} from './src/data';
import { colors, levelTheme, radii, space, type LevelId } from './src/theme';
import { AnimatedFlame, AnimatedMeter, Card, FriendlyEmpty, PrimaryButton, SectionTitle, Tap, WeekDots, ui } from './src/ui';
import { auth, db, functions, isUsingFirebaseEmulators } from './src/firebase';
import { answerInDemo, loadDemoTutorMessages, saveDemoTutorMessages, type TutorMessage } from './src/demoTutor';
import { collection, doc, getDocs, limit, onSnapshot, orderBy, query, where } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { AccountScreen, EditProfileScreen, NotificationsScreen, SettingsScreen, StreakScreen } from './src/screens/AccountScreens';
import { EntryFlow } from './src/screens/EntryFlow';

type Tab = 'home' | 'path' | 'groups' | 'profile';
type Route = Tab | 'lesson' | 'review' | 'tutor' | 'settings' | 'notifications' | 'streak' | 'account' | 'edit-profile';

export default function App() {
  return <SafeAreaProvider><RootApp /></SafeAreaProvider>;
}

function RootApp() {
  const [user, setUser] = useState<typeof auth.currentUser>(null);
  const [authReady, setAuthReady] = useState(false);
  const [profile, setProfile] = useState<LearnerProfile>();
  const [error, setError] = useState<string>();
  const [retry, setRetry] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const router = useRouter();
  const pathname = usePathname();
  const params = useLocalSearchParams<{ levelId?: string; unitId?: string; lessonId?: string }>();
  const route = routeFromPath(pathname);
  const lessonTarget = route === 'lesson' && params.levelId && params.unitId && params.lessonId
    ? { levelId: params.levelId, unitId: params.unitId, lessonId: params.lessonId }
    : undefined;
  const { width } = useWindowDimensions();
  const compact = width < 365;
  const contentWidth = Math.min(width - (compact ? 28 : 40), 560);

  useEffect(() => {
    setError(undefined);
    const stop = watchAuth((nextUser) => {
      setUser(nextUser);
      setAuthReady(true);
    });
    return stop;
  }, [retry]);

  useEffect(() => {
    if (!user) { setProfile(undefined); return; }
    let alive = true;
    setError(undefined);
    setProfile(undefined);
    void ensureProfile(user).then((next) => { if (alive) setProfile(next); }).catch((reason: unknown) => {
      if (alive) setError(safeError(reason));
    });
    return () => { alive = false; };
  }, [user, retry]);

  const openRoute = useCallback((destination: Route) => {
    router.push(`/${destination}` as never);
  }, [router]);
  const openLesson = useCallback((target: { levelId: string; unitId: string; lessonId: string }) => {
    router.push({ pathname: '/lesson', params: target } as never);
  }, [router]);
  const goHome = useCallback(() => { router.replace('/home' as never); }, [router]);
  const goProfile = useCallback(() => { router.replace('/profile' as never); }, [router]);
  const afterLearning = useCallback(() => { setRefresh((value) => value + 1); goHome(); }, [goHome]);

  if (!authReady) return <LoadingScreen error={error} retry={() => setRetry((value) => value + 1)} />;
  if (!user) return <EntryFlow initialError={error} onGuest={async () => { setError(undefined); await ensureGuest(); }} />;
  if (!profile) return <LoadingScreen error={error} retry={() => setRetry((value) => value + 1)} />;
  if (!profile.onboardingCompleted) {
    return <OnboardingScreen profile={profile} uid={user.uid} width={contentWidth} onComplete={async (selection) => {
      await finishOnboarding({ uid: user.uid, ...selection });
      const saved = await ensureProfile(user);
      setProfile(saved);
    }} />;
  }

  return <SafeAreaView style={ui.screen} edges={['top', 'left', 'right']}>
    <StatusBar style="dark" />
    {isUsingFirebaseEmulators ? <View style={styles.emulatorBar}><View style={styles.emulatorDot} /><Text style={styles.emulatorText}>DEV · FIREBASE EMULATOR</Text><Text style={styles.emulatorProject}>{process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID || 'demo-wortwerk-dev'}</Text></View> : null}
    <View style={{ flex: 1 }}>
      {route === 'home' && <HomeScreen uid={user.uid} refresh={refresh} width={contentWidth} profile={profile} onProfileUpdated={setProfile} onOpen={openRoute} onLesson={openLesson} />}
      {route === 'path' && <PathScreen uid={user.uid} refresh={refresh} width={contentWidth} onLesson={openLesson} />}
      {route === 'groups' && <GroupsScreen uid={user.uid} width={contentWidth} />}
      {route === 'profile' && <ProfileScreen uid={user.uid} profile={profile} width={contentWidth} onOpen={openRoute} />}
      {route === 'settings' && <SettingsScreen uid={user.uid} profile={profile} width={contentWidth} onBack={goProfile} onSaved={(value) => setProfile((current) => current ? { ...current, ...value } : current)} onOpen={openRoute} />}
      {route === 'notifications' && <NotificationsScreen uid={user.uid} profile={profile} width={contentWidth} onBack={goProfile} onSaved={(value) => setProfile((current) => current ? { ...current, ...value } : current)} onOpen={openRoute} />}
      {route === 'streak' && <StreakScreen uid={user.uid} profile={profile} width={contentWidth} onBack={goProfile} onSaved={(value) => setProfile((current) => current ? { ...current, ...value } : current)} onOpen={openRoute} />}
      {route === 'account' && <AccountScreen uid={user.uid} profile={profile} width={contentWidth} onBack={goProfile} onSaved={(value) => setProfile((current) => current ? { ...current, ...value } : current)} onOpen={openRoute} />}
      {route === 'edit-profile' && <EditProfileScreen uid={user.uid} profile={profile} width={contentWidth} onBack={goProfile} onSaved={(value) => setProfile((current) => current ? { ...current, ...value } : current)} onOpen={openRoute} />}
      {route === 'lesson' && lessonTarget && <LessonScreen target={lessonTarget} width={contentWidth} onClose={goHome} onSaved={afterLearning} />}
      {route === 'review' && <ReviewScreen width={contentWidth} onClose={goHome} onSaved={afterLearning} />}
      {route === 'tutor' && <TutorScreen uid={user.uid} profile={profile} width={contentWidth} onClose={() => { setRefresh((value) => value + 1); goHome(); }} />}
    </View>
    {(['home', 'path', 'groups', 'profile'] as Route[]).includes(route) ? <TabBar active={route as Tab} onChange={openRoute} /> : null}
  </SafeAreaView>;
}

function SafeScreen({ children }: { children: React.ReactNode }) {
  return <SafeAreaView style={[ui.screen, { padding: 20 }]}><StatusBar style="dark" /><View style={{ flex: 1, justifyContent: 'center' }}>{children}</View></SafeAreaView>;
}

function LoadingScreen({ error, retry }: { error?: string; retry: () => void }) {
  return <SafeScreen>{error ? <FriendlyEmpty title="Verbindung verloren" body={error} onRetry={retry} /> : <View style={styles.loading}>
    <AnimatedFlame size={64} /><Text style={styles.loadingTitle}>Dein Lernweg wartet</Text><Text style={styles.body}>Wortwerk verbindet sich mit deinem sicheren Lernprofil.</Text>
  </View>}</SafeScreen>;
}

type OnboardingSelection = { goals: string[]; dailyMinutes: number; targetDaysPerWeek: 3 | 5 | 7; level: 'A1' | 'A2' | 'B1'; source: 'self_assessment'; confidence: number; style: 'structured' | 'conversation' | 'visual' | 'variety'; feedback: 'gentle' | 'direct' };

function OnboardingScreen({ profile, width, onComplete }: { profile: LearnerProfile; uid: string; width: number; onComplete: (selection: OnboardingSelection) => Promise<void> }) {
  const [goals, setGoals] = useState<string[]>(profile.goals.length ? profile.goals.slice(0, 3) : ['Alltag']);
  const [minutes, setMinutes] = useState(10);
  const [days, setDays] = useState<3 | 5 | 7>(5);
  const [style, setStyle] = useState<OnboardingSelection['style']>('conversation');
  const [feedback, setFeedback] = useState<'gentle' | 'direct'>('gentle');
  const [level, setLevel] = useState<'A1' | 'A2' | 'B1'>('A1');
  const [step, setStep] = useState(0);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string>();
  const motion = useReducedMotion();
  const screens = [
    { eyebrow: '01 · ZIELE', title: 'Wofür brauchst du Deutsch?', prompt: 'Zum Beispiel für die Arbeit, ein Gespräch beim Amt oder den Alltag.', color: colors.levels.A2 },
    { eyebrow: '02 · LERNEN', title: 'Was hilft dir beim Lernen?', prompt: 'Es gibt keine richtige Antwort. Wähle, was dir liegt.', color: colors.levels.C2 },
    { eyebrow: '03 · ZEIT', title: 'Wie oft schaffst du es realistisch?', prompt: 'Wähle einen Rhythmus, der auch in einer vollen Woche klappt.', color: colors.levels.B1 },
    { eyebrow: '04 · NIVEAU', title: 'Wie sicher bist du in Deutsch?', prompt: 'Das ist eine erste Einschätzung. Du kannst später wechseln.', color: colors.levels.A1 },
    { eyebrow: 'DEIN START', title: 'So könnte deine Woche aussehen.', prompt: 'Du kannst dein Ziel später in den Einstellungen ändern.', color: colors.levels.C1 },
  ] as const;
  const current = screens[step];
  const styleOptions = [
    { id: 'conversation', title: 'Sprechen & ausprobieren', sub: 'Dialoge und echte Alltagssituationen', icon: '1' },
    { id: 'structured', title: 'Klar & Schritt für Schritt', sub: 'Regeln, Beispiele und ein roter Faden', icon: '2' },
    { id: 'visual', title: 'Bilder & Zusammenhänge', sub: 'Visuelle Merkhilfen und Kontexte', icon: '3' },
    { id: 'variety', title: 'Abwechslung bitte', sub: 'Kurze, wechselnde Übungen', icon: '4' },
  ] as const;
  const save = async () => {
    setBusy(true); setFailure(undefined);
    try { await onComplete({ goals, dailyMinutes: minutes, targetDaysPerWeek: days, level, source: 'self_assessment', confidence: 0, style, feedback }); await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success); }
    catch (reason) { setFailure(safeError(reason)); setBusy(false); }
  };
  return <SafeAreaView style={ui.screen} edges={['top', 'bottom']}>
    <View style={styles.onboardingShell}>
      <View style={[styles.onboardingTop, { width }]}><View style={styles.brandLockup}><View style={styles.brandMark}><Text style={styles.brandMarkText}>w</Text></View><Text style={styles.brandName}>wortwerk</Text></View><Text style={styles.stepCount}>{step + 1} <Text style={styles.stepCountMuted}>/ 5</Text></Text></View>
      <View style={[styles.progressTrack, { width }]}><Animated.View key={step} entering={motion ? undefined : FadeInDown.duration(300)} style={[styles.progressFill, { width: `${((step + 1) / screens.length) * 100}%` }]} /></View>
      <ScrollView key={step} contentContainerStyle={[ui.scroll, styles.onboardingScroll]} showsVerticalScrollIndicator={false}><View style={{ width }}>
        <Animated.View key={`context-${step}`} entering={motion ? undefined : FadeInDown.duration(180)} style={styles.onboardingContext}><View style={[styles.onboardingContextMark, { backgroundColor: current.color }]}><Text style={styles.onboardingContextNumber}>{String(step + 1).padStart(2, '0')}</Text></View><Text style={styles.onboardingContextCopy}>{current.prompt}</Text></Animated.View>
        <Animated.View key={`question-${step}`} entering={motion ? undefined : FadeInDown.delay(80).duration(400)} style={styles.onboardingQuestion}><Text style={styles.kicker}>{current.eyebrow}</Text><Text style={styles.onboardingTitle}>{current.title}</Text></Animated.View>
        {step === 0 ? <><Text style={styles.body}>Wähle ein bis drei Situationen. Daraus wählen wir passende Übungen.</Text><View style={styles.goalGrid}>{['Alltag', 'Arbeit', 'Studium', 'Familie & Freunde', 'Behörden', 'Kultur'].map((item, index) => { const active = goals.includes(item); return <Animated.View key={item} entering={motion ? undefined : FadeInUp.delay(index * 25).duration(200)} style={{ width: '48%' }}><Tap onPress={() => setGoals((old) => active ? old.filter((goal) => goal !== item) : old.length < 3 ? [...old, item] : old)} style={[styles.goalCard, active && styles.goalCardSelected]}><Text style={[styles.goalText, active && styles.choiceSelectedText]}>{item}</Text><View style={[styles.goalCheck, active && styles.goalCheckSelected]}>{active ? <Text style={styles.goalCheckGlyph}>✓</Text> : null}</View></Tap></Animated.View>; })}</View></> : null}
        {step === 1 ? <><Text style={styles.body}>Wähle, was dir beim Lernen hilft. Du kannst es später ändern.</Text><View style={styles.minutesList}>{styleOptions.map((item, index) => <Animated.View key={item.id} entering={motion ? undefined : FadeInUp.delay(index * 50).duration(330)}><Tap onPress={() => setStyle(item.id)} style={[styles.minutesCard, style === item.id && styles.minutesCardSelected]}><View style={[styles.minutesNumber, style === item.id && styles.minutesNumberSelected]}><Text style={[styles.minutesNumberText, style === item.id && styles.minutesNumberTextSelected]}>{item.icon}</Text></View><View style={{ flex: 1 }}><Text style={styles.minutesTitle}>{item.title}</Text><Text style={styles.minutesHint}>{item.sub}</Text></View><Text style={styles.minutesArrow}>{style === item.id ? '✓' : '›'}</Text></Tap></Animated.View>)}</View><Text style={[styles.kicker, { marginTop: 18 }]}>WIE SOLL FRITZ KORRIGIEREN?</Text><View style={styles.choiceWrap}>{(['gentle', 'direct'] as const).map((item) => <Tap key={item} onPress={() => setFeedback(item)} style={[styles.choice, feedback === item && styles.choiceSelected]}><Text style={[styles.choiceText, feedback === item && styles.choiceSelectedText]}>{item === 'gentle' ? 'Ermutigend' : 'Direkt & knapp'}</Text></Tap>)}</View></> : null}
        {step === 2 ? <><View style={styles.minutesList}>{[5, 10, 15, 20].map((value, index) => <Animated.View key={value} entering={motion ? undefined : FadeInUp.delay(index * 45).duration(320)}><Tap onPress={() => setMinutes(value)} style={[styles.minutesCard, minutes === value && styles.minutesCardSelected]}><View style={[styles.minutesNumber, minutes === value && styles.minutesNumberSelected]}><Text style={[styles.minutesNumberText, minutes === value && styles.minutesNumberTextSelected]}>{value}</Text></View><View style={{ flex: 1 }}><Text style={styles.minutesTitle}>{value} Minuten pro Lerntag</Text><Text style={styles.minutesHint}>{['Ein kleiner Start', 'Gut in den Alltag integrierbar', 'Mit etwas mehr Tiefe', 'Intensiv und fokussiert'][index]}</Text></View><Text style={styles.minutesArrow}>{minutes === value ? '✓' : '›'}</Text></Tap></Animated.View>)}</View><Text style={[styles.kicker, { marginTop: 18 }]}>DEIN WOCHENZIEL</Text><Text style={styles.body}>Dein Streak zählt echte Lerntage. Lege ein realistisches Ziel fest.</Text><View style={styles.choiceWrap}>{([3, 5, 7] as const).map((value) => <Tap key={value} onPress={() => setDays(value)} style={[styles.choice, days === value && styles.choiceSelected]}><Text style={[styles.choiceText, days === value && styles.choiceSelectedText]}>{value} Tage</Text></Tap>)}</View></> : null}
        {step === 3 ? <View style={styles.levelChoiceList}>{(['A1', 'A2', 'B1'] as const).map((item, index) => <Animated.View key={item} entering={motion ? undefined : FadeInUp.delay(index * 55).duration(330)}><Tap onPress={() => setLevel(item)} style={[styles.levelChoice, styles.levelChoicePremium, { backgroundColor: [colors.levels.A1, colors.levels.A2, colors.levels.B1][index] }, level === item && styles.levelChoiceSelected]}><View style={ui.row}><View style={styles.levelBadge}><Text style={styles.levelBadgeText}>{item}</Text></View><View><Text style={styles.levelLabel}>{['Ich starte ganz neu', 'Ich kenne Grundlagen', 'Ich kann einfache Gespräche'][index]}</Text><Text style={styles.levelDescription}>{['Keine Vorkenntnisse nötig', 'Ein paar Wörter und Sätze', 'Ich möchte sicherer werden'][index]}</Text></View></View><Text style={styles.levelRadio}>{level === item ? '●' : '○'}</Text></Tap></Animated.View>)}</View> : null}
        {step === 4 ? <><Animated.View entering={motion ? undefined : FadeInDown.duration(180)} style={[styles.levelChoice, { backgroundColor: colors.levels[level], minHeight: 94, marginTop: 12 }]}><View style={styles.levelBadge}><Text style={styles.levelBadgeText}>{level}</Text></View><View style={{ flex: 1, marginLeft: 12 }}><Text style={styles.levelLabel}>Dein Startniveau</Text><Text style={styles.levelDescription}>Eigene Einschätzung · später änderbar</Text></View></Animated.View><View style={[styles.modernMissionCard, { marginTop: 14 }]}><Text style={styles.missionTitle}>Deine erste Lernwoche</Text><Text style={styles.body}>{minutes} Minuten · {days} Lerntage pro Woche</Text><Text style={[styles.body, { marginTop: 8 }]}>Fokus: {goals.join(' · ')}</Text><Text style={[styles.body, { marginTop: 8 }]}>Lernstil: {styleOptions.find((item) => item.id === style)?.title} · Korrekturen: {feedback === 'gentle' ? 'ermutigend' : 'direkt'}.</Text><Text style={[styles.body, { marginTop: 10 }]}>Dein Wochenziel ist flexibel und setzt deinen echten Streak nicht künstlich zurück.</Text></View></> : null}
        {failure ? <Text accessibilityLiveRegion="polite" style={styles.errorCopy}>{failure}</Text> : null}
        <View style={styles.onboardingFooter}>{step > 0 ? <Tap onPress={() => setStep(step - 1)} style={styles.backButton}><Text style={styles.backButtonText}>← Zurück</Text></Tap> : <Text style={styles.privacyNote}>Nur für deinen persönlichen Lernplan gespeichert.</Text>}<Tap onPress={() => step < 4 ? setStep(step + 1) : void save()} disabled={busy || (step === 0 && goals.length === 0)} style={[styles.onboardingContinue, busy && { opacity: 0.55 }]}><Text style={styles.onboardingContinueText}>{busy ? 'Einen Moment …' : step === 4 ? 'Lernweg starten' : 'Weiter'}</Text><Text style={styles.onboardingContinueArrow}>→</Text></Tap></View>
      </View></ScrollView>
    </View>
  </SafeAreaView>;
}

function HomeScreen({ uid, refresh, width, profile, onProfileUpdated, onOpen, onLesson }: { uid: string; refresh: number; width: number; profile: LearnerProfile; onProfileUpdated: (value: LearnerProfile) => void; onOpen: (route: Route) => void; onLesson: (target: { levelId: string; unitId: string; lessonId: string }) => void }) {
  const [home, setHome] = useState<HomeSnapshot>();
  const [missions, setMissions] = useState<{ date: string; focusGoal: string; earnedXp: number; tasks: DailyMission[] }>();
  const [error, setError] = useState<string>();
  const [retry, setRetry] = useState(0);
  const [leveledUp, setLeveledUp] = useState(false);
  const previousLevel = useRef(profile.level);
  const handleHome = useCallback((value: HomeSnapshot) => {
    setHome(value);
    onProfileUpdated(value.profile);
  }, [onProfileUpdated]);
  useEffect(() => {
    const level = home?.profile.level;
    if (!level) return;
    const levelOrder: LevelId[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    if (levelOrder.indexOf(level) > levelOrder.indexOf(previousLevel.current)) {
      setLeveledUp(true);
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    }
    previousLevel.current = level;
  }, [home?.profile.level]);
  useEffect(() => {
    setError(undefined); setHome(undefined); setMissions(undefined);
    const stopHome = listenHome(uid, handleHome, () => setError('Tagesfortschritt konnte nicht geladen werden.'));
    const stopMissions = watchMissions(uid, setMissions, () => setError('Tagesmissionen konnten nicht geladen werden.'));
    return () => { stopHome(); stopMissions(); };
  }, [uid, retry, refresh, handleHome]);
  const [path, setPath] = useState<LearningPath>();
  const [pathError, setPathError] = useState(false);
  const [pathRetry, setPathRetry] = useState(0);
  useEffect(() => {
    let alive = true;
    setPath(undefined); setPathError(false);
    void loadLearningPath(uid).then((value) => { if (alive) setPath(value); }).catch(() => { if (alive) setPathError(true); });
    return () => { alive = false; };
  }, [uid, refresh, pathRetry]);
  const nextLesson = findNextLesson(path);
  const today = missions?.date ?? localDayId();
  const completedMissions = missions?.tasks.filter((task) => task.completed).length ?? 0;
  const wide = width > 560;
  const motion = useReducedMotion();
  const profileName = home?.profile.displayName ?? 'Deutschlernende Person';
  const firstName = profileName.split(/\s+/)[0] ?? 'Lernende Person';
  const greeting = profileName === 'Deutschlernende Person' ? 'Schön, dass du da bist.' : `Hallo, ${firstName}.`;

  const activeTheme = levelTheme(profile.level);
  return <ScrollView key="home-scroll" contentContainerStyle={ui.scroll} showsVerticalScrollIndicator={false}>
    <View style={{ width }}>
      <Animated.View entering={motion ? undefined : FadeInDown.duration(360)} style={styles.modernTopbar}>
        <View><Text style={styles.modernWordmark}>WORTWERK <Text style={styles.modernWordmarkDot}>/</Text> DEUTSCH LERNEN</Text><Text style={styles.modernGreeting}>{greeting}</Text></View>
        <Tap onPress={() => onOpen('profile')} accessibilityLabel="Profil öffnen" style={[styles.modernProfile, { backgroundColor: activeTheme.surface }]}><Text style={[styles.modernProfileText, { color: activeTheme.deep }]}>{firstName.slice(0, 1).toLocaleUpperCase('de-DE')}</Text></Tap>
      </Animated.View>

      <Animated.View entering={motion ? undefined : FadeInDown.duration(220)} style={[styles.homeFocusCard, { borderLeftColor: activeTheme.accent }]}>
        <View style={styles.homeFocusTop}><Text style={styles.homeFocusEyebrow}>WEITERLERNEN</Text><View style={[styles.homeFocusLevel, { backgroundColor: activeTheme.surface }]}><Text style={[styles.homeFocusLevelText, { color: activeTheme.deep }]}>{profile.level}</Text></View></View>
        <Text style={styles.homeFocusTitle}>{nextLesson?.lessonTitle ?? 'Dein Lernpfad'}</Text>
        <Text style={styles.homeFocusCopy}>{nextLesson?.unitTitle ?? `${profile.goals[0] ?? 'Deutsch'} · Dein Niveau ${profile.level}`}</Text>
        <Tap onPress={() => nextLesson ? onLesson(nextLesson) : onOpen('path')} style={styles.homeFocusAction}><Text style={styles.homeFocusActionText}>{nextLesson ? 'Lektion öffnen' : 'Lernpfad öffnen'}</Text><Text style={styles.homeFocusActionArrow}>→</Text></Tap>
      </Animated.View>

      {leveledUp ? <Animated.View entering={motion ? undefined : FadeInUp.springify().damping(18)}><Card style={[styles.levelUpNotice, { backgroundColor: levelTheme(home?.profile.level ?? profile.level).surface }]}><View style={[styles.levelUpBadge, { backgroundColor: levelTheme(home?.profile.level ?? profile.level).deep }]}><Text style={styles.levelUpBadgeText}>{home?.profile.level}</Text></View><View style={{ flex: 1 }}><Text style={styles.levelUpTitle}>Neues Niveau freigeschaltet</Text><Text style={styles.levelUpCopy}>Du lernst jetzt auf {home?.profile.level}. Dein bisheriges Wissen bleibt Teil deines Lernwegs.</Text><Tap onPress={() => { setLeveledUp(false); onOpen('path'); }} style={styles.levelUpAction}><Text style={styles.levelUpActionText}>Neuen Abschnitt ansehen →</Text></Tap></View><Tap onPress={() => setLeveledUp(false)} accessibilityLabel="Hinweis schließen" style={styles.levelUpClose}><Text style={styles.levelUpCloseText}>×</Text></Tap></Card></Animated.View> : null}

      {error && (!home || !missions) ? <FriendlyEmpty title="Dein Tag lädt gerade nicht" body={error} onRetry={() => setRetry((value) => value + 1)} /> : !home || !missions ? <LoadingCard label="Dein Tagesfortschritt wird geladen …" /> : <>
        <Animated.View entering={motion ? undefined : FadeInUp.delay(100).duration(420)} style={styles.modernStats}>
          <Tap onPress={() => onOpen('streak')} style={styles.modernStatCard}><Text style={styles.modernStatCaption}>LERNTAGE IN FOLGE</Text><View style={styles.modernStatValueRow}><Text style={styles.modernStatValue}>{home.profile.streak.current}</Text><Text style={styles.modernStatIcon}>✳</Text></View><Text style={styles.modernStatFoot}>Bester Lauf: {home.profile.streak.longest} Tage</Text></Tap>
        <View style={[styles.modernStatCard, styles.modernXpCard]}><Text style={styles.modernStatCaption}>XP · HEUTE</Text><View style={styles.modernStatValueRow}><Text style={styles.modernStatValue}>{home.xpEarnedToday}</Text><Text style={styles.modernStatIcon}>XP</Text></View><Text style={styles.modernStatFoot}>Für Üben und Wiederholen.</Text></View>
        </Animated.View>
        <View style={styles.modernWeek}><WeekDots activeDays={home.activeDayIds} todayId={today} /><Text style={styles.modernWeekGoal}>{home.activeDayIds.size} / {home.profile.learningPlan?.targetDaysPerWeek ?? 5} Lerntage diese Woche</Text></View>

        <Animated.View entering={motion ? undefined : FadeInUp.delay(150).duration(420)} style={styles.modernMissionCard}>
          <View style={styles.modernSectionHead}><View><Text style={styles.modernEyebrow}>DEIN TAGESPLAN</Text><Text style={styles.modernSectionTitle}>{goalName(missions.focusGoal)}</Text></View><Text style={styles.modernMissionCount}>{completedMissions} <Text style={styles.modernMissionTotal}>/ {missions.tasks.length}</Text></Text></View>
          <AnimatedMeter value={completedMissions / Math.max(missions.tasks.length, 1)} height={5} />
          <View style={{ gap: 3, marginTop: 10 }}>{missions.tasks.map((task) => <MissionRow key={task.kind} task={task} onPress={() => {
            if (task.completed) return;
            if (task.kind === 'lesson_complete' && nextLesson) onLesson(nextLesson);
            else if (task.kind === 'review_session') onOpen('review');
            else onOpen('tutor');
          }} />)}</View>
          {missions.tasks.every((task) => task.completed) ? <Animated.View entering={motion ? undefined : FadeInUp.springify()} style={styles.doneMessage}><Text style={styles.doneEmoji}>✺</Text><Text style={styles.doneText}>Dein Tagesplan ist geschafft · +{missions.earnedXp} XP</Text></Animated.View> : null}
        </Animated.View>
        {error ? <Text accessibilityLiveRegion="polite" style={styles.softError}>{error} · <Text onPress={() => setRetry((value) => value + 1)}>Erneut laden</Text></Text> : null}

        <View style={styles.modernSectionHeader}><Text style={styles.modernEyebrow}>WEITER AUF DEINEM WEG</Text><Text style={styles.modernSectionTitle}>Deine nächste Lektion</Text></View>
        {nextLesson ? <Animated.View entering={motion ? undefined : FadeInUp.delay(210).duration(420)} style={styles.modernLessonCard}>
          <View style={styles.modernLessonTop}><View style={styles.modernLessonBadge}><Text style={styles.modernLessonBadgeText}>{nextLesson.levelId}</Text></View><Text style={styles.modernLessonMeta}>{nextLesson.questionCount} Fragen · ca. {profile.dailyMinutes} Min.</Text></View>
          <Text style={styles.modernLessonTitle}>{nextLesson.lessonTitle}</Text><Text style={styles.modernLessonUnit}>{nextLesson.unitTitle}</Text>
          <Tap onPress={() => onLesson(nextLesson)} style={styles.modernLessonAction}><Text style={styles.modernLessonActionText}>Lektion starten</Text><Text style={styles.modernLessonActionArrow}>→</Text></Tap>
        </Animated.View> : pathError ? <FriendlyEmpty title="Der Lernweg lädt gerade nicht" body="Dein Tagesplan bleibt verfügbar. Prüfe die Verbindung und lade den Lernweg neu." onRetry={() => setPathRetry((value) => value + 1)} /> : path && path.levels.every((level) => level.units.every((unit) => unit.lessons.length === 0)) ? <FriendlyEmpty title="Dein Lernweg wird vorbereitet" body="Veröffentlichte Lektionen erscheinen hier, sobald sie bereit sind." /> : path && !findNextLesson(path) ? <Card style={styles.doneMessage}><Text style={styles.doneText}>Du bist für heute gut vorangekommen.</Text><PrimaryButton title="Wörter wiederholen" onPress={() => onOpen('review')} /></Card> : <LoadingCard label="Deine nächste Lektion wird geladen …" />}

        <Tap onPress={() => onOpen('review')} style={styles.modernReviewLink}><View><Text style={styles.modernEyebrow}>FÜNF MINUTEN FREI?</Text><Text style={styles.modernReviewTitle}>Wörter wiederholen</Text></View><Text style={styles.modernReviewArrow}>↗</Text></Tap>
        <View style={{ height: 34 }} />
      </>}
    </View>
  </ScrollView>;
}

function LoadingCard({ label }: { label: string }) {
  return <Card style={styles.loadingCard}><AnimatedFlame size={30} /><Text style={styles.body}>{label}</Text></Card>;
}

function MissionRow({ task, onPress }: { task: DailyMission; onPress: () => void }) {
  const completed = task.completed;
  return <Tap onPress={onPress} disabled={completed} style={styles.missionRow} accessibilityLabel={`${task.title}, ${completed ? 'abgeschlossen' : 'offen'}, ${task.xp} XP`}>
    <View style={[styles.missionIcon, completed && styles.missionIconDone]}><Text style={styles.missionIconText}>{completed ? '✓' : task.kind === 'lesson_complete' ? '↗' : task.kind === 'review_session' ? '▤' : '☻'}</Text></View>
    <View style={{ flex: 1 }}><Text style={[styles.missionRowTitle, completed && styles.completedText]}>{task.title}</Text><View style={ui.row}><View style={styles.miniMeter}><View style={[styles.miniMeterFill, { width: `${Math.round(task.progress / Math.max(task.target, 1) * 100)}%`, backgroundColor: completed ? colors.success : colors.streak }]} /></View><Text style={styles.missionProgress}>{task.progress}/{task.target}</Text></View></View>
    <Text style={styles.missionXp}>+{task.xp}</Text>
  </Tap>;
}

function PathScreen({ uid, refresh, width, onLesson }: { uid: string; refresh: number; width: number; onLesson: (target: { levelId: string; unitId: string; lessonId: string }) => void }) {
  const [path, setPath] = useState<LearningPath>();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const motion = useReducedMotion();
  useEffect(() => {
    let alive = true; setLoading(true); setError(false);
    void loadLearningPath(uid).then((value) => { if (alive) setPath(value); }).catch(() => { if (alive) { setPath(undefined); setError(true); } }).finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [uid, refresh, attempt]);
  if (loading) return <ScrollView contentContainerStyle={ui.scroll}><View style={{ width }}><PathHeader /><LoadingCard label="Dein Lernpfad wird geladen …" /></View></ScrollView>;
  if (error) return <ScrollView contentContainerStyle={ui.scroll}><View style={{ width }}><PathHeader /><FriendlyEmpty title="Der Lernpfad ist gerade nicht erreichbar" body="Dein gespeicherter Fortschritt bleibt erhalten. Prüfe deine Verbindung und versuche es erneut." onRetry={() => setAttempt((value) => value + 1)} /></View></ScrollView>;
  if (!path || path.levels.every((level) => level.units.length === 0)) return <ScrollView contentContainerStyle={ui.scroll}><View style={{ width }}><PathHeader /><FriendlyEmpty title="Hier wächst dein Lernweg" body="Veröffentlichte Lektionen erscheinen hier direkt aus deinem Lernkonto." /></View></ScrollView>;

  const currentProgress = path.progressByLevel[path.currentLevel];
  return <ScrollView contentContainerStyle={ui.scroll} showsVerticalScrollIndicator={false}>
    <View style={{ width }}><PathHeader />
      <Animated.View entering={motion ? undefined : FadeInDown.duration(350)} style={[styles.pathIntro, { backgroundColor: levelTheme(path.currentLevel as LevelId).deep }]}>
        <View style={{ flex: 1 }}><Text style={[styles.kicker, { color: '#D8E2DC' }]}>DEIN DEUTSCHER LERNPFAD</Text><Text style={styles.pathTitle}>Schritt für Schritt.</Text><Text style={[styles.body, { color: '#E3EAE5' }]}>Jeder Knoten ist eine veröffentlichte Lektion. Dein Weg verändert sich mit deinem Fortschritt.</Text></View>
        <View style={[styles.pathBadge, { backgroundColor: levelTheme(path.currentLevel as LevelId).surface }]}><Text style={[styles.pathBadgeText, { color: levelTheme(path.currentLevel as LevelId).deep }]}>{path.currentLevel}</Text></View>
      </Animated.View>

      {currentProgress ? <Card style={{ marginTop: 16 }}>
        <Text style={styles.missionTitle}>Dein Stand in {path.currentLevel}</Text><Text style={[styles.body, { textAlign: 'left', marginTop: 4 }]}>XP zeigen dein tägliches Üben. Für den nächsten Abschnitt müssen diese Lernziele sitzen:</Text>
        <CriteriaRow title="Wörter behalten" value={`${currentProgress.retainedWords}/${currentProgress.coreVocabularyCount}`} ratio={currentProgress.coreVocabularyCount ? currentProgress.retainedWords / currentProgress.coreVocabularyCount : 0} detail="70 % nötig" color={levelTheme(path.currentLevel as LevelId).accent} />
        <CriteriaRow title="Mit Fritz gesprochen" value={`${currentProgress.fritzConversations}/3`} ratio={currentProgress.fritzConversations / 3} detail="3 Gespräche" color={levelTheme(path.currentLevel as LevelId).accent} />
        <CriteriaRow title="Wiederholung bestanden" value={`${currentProgress.reviewRoundsPassed}/1`} ratio={currentProgress.reviewRoundsPassed > 0 ? 1 : 0} detail="70 % richtig" color={levelTheme(path.currentLevel as LevelId).accent} />
      </Card> : null}

      {path.levels.map((level, levelIndex) => <View key={level.id} style={{ marginTop: 26 }}>
        <View style={styles.levelHeader}><View style={[styles.levelMark, { backgroundColor: levelTheme(level.id).surface }]}><Text style={[styles.levelMarkText, { color: levelTheme(level.id).deep }]}>{level.id}</Text></View><View style={{ flex: 1 }}><Text style={styles.levelTitle}>{level.title}</Text><Text style={styles.body}>{level.units.reduce((sum, unit) => sum + unit.lessons.length, 0)} veröffentlichte Lektionen</Text></View>{level.id === path.currentLevel ? <View style={[styles.nowPill, { backgroundColor: levelTheme(level.id).deep }]}><Text style={styles.nowPillText}>DU BIST HIER</Text></View> : null}</View>
        {level.units.map((unit) => <View key={unit.id} style={styles.unitBlock}>
          <View style={styles.unitLabel}><Text style={styles.unitTitle}>{unit.title}</Text><Text style={styles.unitCount}>{unit.lessons.filter((lesson) => lesson.completed).length}/{unit.lessons.length}</Text></View>
          {unit.lessons.length ? <LessonRoad levelId={level.id} unitId={unit.id} lessons={unit.lessons} width={width} onLesson={onLesson} motion={motion} /> : <FriendlyEmpty title="Diese Einheit ist noch leer" body="Der Lernpfad zeigt nur Inhalte, die bereits veröffentlicht wurden." />}
        </View>)}
        {levelIndex < path.levels.length - 1 ? <View style={styles.levelConnector}><View style={styles.connectorLine} /><Text style={styles.connectorCopy}>WEITER GEHT'S, WENN DU BEREIT BIST</Text><View style={styles.connectorLine} /></View> : null}
      </View>)}
      <View style={{ height: 100 }} />
    </View>
  </ScrollView>;
}

function PathHeader() {
  return <View style={styles.screenHeader}><View style={styles.headerGlyph}><Text style={{ color: colors.ink, fontSize: 19 }}>↝</Text></View><View><Text style={styles.kicker}>DEIN FORTSCHRITT</Text><Text style={styles.screenTitle}>Der Lernweg</Text></View></View>;
}

function CriteriaRow({ title, value, ratio, detail, color }: { title: string; value: string; ratio: number; detail: string; color?: string }) {
  const met = ratio >= (title === 'Wörter behalten' ? 0.7 : 1);
  return <View style={styles.criteriaRow}><View style={styles.criteriaHeading}><Text style={styles.criteriaTitle}>{title}</Text><Text style={styles.criteriaValue}>{value} · {detail}</Text></View><AnimatedMeter value={ratio} color={met ? colors.success : color ?? colors.streak} height={6} /></View>;
}

function LessonRoad({ levelId, unitId, lessons, width, onLesson, motion }: { levelId: LevelId; unitId: string; lessons: PathLesson[]; width: number; onLesson: (target: { levelId: string; unitId: string; lessonId: string }) => void; motion: boolean }) {
  const boardWidth = Math.max(270, width - 16);
  const height = Math.max(132, 54 + lessons.length * 132);
  const points = lessons.map((_, index) => ({ x: index % 2 === 0 ? boardWidth * 0.3 : boardWidth * 0.7, y: 48 + index * 132 }));
  const pathData = points.length < 2 ? '' : points.slice(1).reduce((path, point, index) => {
    const previous = points[index]; const middleY = (previous.y + point.y) / 2;
    return `${path} C ${previous.x} ${middleY}, ${point.x} ${middleY}, ${point.x} ${point.y}`;
  }, `M ${points[0].x} ${points[0].y}`);
  const completeCount = lessons.filter((lesson) => lesson.completed).length;
  return <View style={[styles.roadBoard, { height }]}>
    <Svg pointerEvents="none" width={boardWidth} height={height} style={StyleSheet.absoluteFill}>
      {pathData ? <>
        <SvgPath d={pathData} fill="none" stroke={colors.line} strokeWidth={15} strokeDasharray="2 17" strokeLinecap="round" />
        {completeCount > 0 ? <SvgPath d={points.slice(0, completeCount + 1).length > 1 ? points.slice(0, completeCount + 1).slice(1).reduce((path, point, index, subset) => {
          const start = points[index]; const middle = (start.y + point.y) / 2; return `${path} C ${start.x} ${middle}, ${point.x} ${middle}, ${point.x} ${point.y}`;
        }, `M ${points[0].x} ${points[0].y}`) : ''} fill="none" stroke={colors.success} strokeWidth={5} strokeLinecap="round" /> : null}
      </> : null}
    </Svg>
    {lessons.map((lesson, index) => {
      const point = points[index]; const current = !lesson.completed && lessons.slice(0, index).every((item) => item.completed);
      const locked = !lesson.completed && !current;
      return <Animated.View key={lesson.id} entering={motion ? undefined : FadeInUp.delay(index * 90).duration(380)} style={[styles.pathNodePosition, { left: point.x - 38, top: point.y - 38 }]}>
        <Tap onPress={() => {
          if (locked) { Alert.alert('Ein Schritt nach dem anderen', 'Schließe zuerst die Lektionen davor mit mindestens 60 % ab.'); return; }
          onLesson({ levelId, unitId, lessonId: lesson.id });
        }} style={[styles.pathNode, lesson.completed ? styles.pathNodeDone : current ? { backgroundColor: levelTheme(levelId as LevelId).surface, borderColor: levelTheme(levelId as LevelId).accent } : styles.pathNodeLocked]} accessibilityLabel={`${lesson.title}, ${lesson.completed ? 'abgeschlossen' : locked ? 'gesperrt' : 'jetzt verfügbar'}`}>
          <Text style={styles.pathNodeSymbol}>{lesson.completed ? '✓' : current ? '›' : '·'}</Text>
        </Tap>
        <Text numberOfLines={2} style={styles.pathNodeCaption}>{lesson.title}</Text>
      </Animated.View>;
    })}
  </View>;
}

function LessonScreen({ target, width, onClose, onSaved }: { target: { levelId: string; unitId: string; lessonId: string }; width: number; onClose: () => void; onSaved: () => void }) {
  const [lesson, setLesson] = useState<LearningLesson>();
  const [error, setError] = useState<string>();
  const [attempt, setAttempt] = useState(0);
  const [index, setIndex] = useState(0);
  const [selected, setSelected] = useState<string>();
  const [answers, setAnswers] = useState<{ questionId: string; choiceId: string }[]>([]);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState(false);
  const [result, setResult] = useState<{ accuracy: number; xpAwarded: number; correctCount: number }>();
  const requestId = useRef(`lesson_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`);
  const reduced = useReducedMotion();
  useEffect(() => { let alive = true; setLesson(undefined); setError(undefined); void loadLesson(target.levelId, target.unitId, target.lessonId).then((value) => { if (alive) setLesson(value); }).catch(() => { if (alive) setError('Diese Lektion konnte nicht geladen werden. Prüfe deine Verbindung und versuche es erneut.'); }); return () => { alive = false; }; }, [target.levelId, target.unitId, target.lessonId, attempt]);

  const question = lesson?.questions[index];
  const chosen = question?.choices.find((choice) => choice.id === selected);
  const isCorrect = Boolean(question && selected && selected === question.correctChoiceId);
  const animatedProgress = useMemo(() => lesson?.questions.length ? (index + (selected ? 1 : 0)) / lesson.questions.length : 0, [index, lesson?.questions.length, selected]);

  const submit = async (finalAnswers: { questionId: string; choiceId: string }[]) => {
    if (!lesson || saving) return;
    setSaving(true); setSaveError(false);
    try {
      const saved = await completeLesson({ lesson, answers: finalAnswers, requestId: requestId.current });
      setResult(saved); await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch {
      setSaveError(true); await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    } finally { setSaving(false); }
  };
  const advance = () => {
    if (!lesson || !question || !selected) return;
    const nextAnswers = [...answers, { questionId: question.id, choiceId: selected }];
    if (index >= lesson.questions.length - 1) { setAnswers(nextAnswers); void submit(nextAnswers); return; }
    setAnswers(nextAnswers); setIndex((value) => value + 1); setSelected(undefined);
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  return <SafeAreaView style={styles.fullScreen} edges={['top', 'bottom']}>
    <View style={[styles.lessonHeader, { maxWidth: width, alignSelf: 'center' }]}><Tap onPress={onClose} style={styles.closeCircle} accessibilityLabel="Lektion schließen"><Text style={styles.closeMark}>×</Text></Tap><View style={styles.lessonHeaderCenter}><Text style={styles.kicker}>{lesson ? `${lesson.levelId} · ${index + 1} / ${lesson.questions.length}` : 'DEUTSCH LERNEN'}</Text><AnimatedMeter value={animatedProgress} height={7} /></View><View style={{ width: 44 }} /></View>
    {result ? <ScrollView contentContainerStyle={[ui.scroll, { justifyContent: 'center' }]}><View style={{ width }}>
      <Animated.View entering={reduced ? undefined : FlipInEasyY.duration(600)} style={[styles.resultSeal, { backgroundColor: colors.success }]}><Text style={styles.resultSealText}>✓</Text></Animated.View>
      <Text style={[styles.kicker, { textAlign: 'center', marginTop: 25 }]}>LEKTION ABGESCHLOSSEN</Text><Text style={styles.resultTitle}>{result.correctCount} von {lesson?.questions.length} richtig</Text><Text style={[styles.body, { marginTop: 8 }]}>Deine Antworten sind gespeichert. Wiederhole schwierige Wörter später noch einmal.</Text>
      <Animated.View entering={reduced ? undefined : FadeInDown.duration(180)} style={styles.rewardCard}><Text style={styles.rewardValue}>+{result.xpAwarded} XP</Text><Text style={styles.rewardCaption}>{result.accuracy >= 0.9 ? 'BONUS FÜR 90 % ODER MEHR' : 'ZUM LERNSTAND HINZUGEFÜGT'}</Text></Animated.View>
      <PrimaryButton title="Weiter auf meinem Lernweg" onPress={onSaved} />
    </View></ScrollView> : error ? <View style={[ui.scroll, { justifyContent: 'center' }]}><View style={{ width }}><FriendlyEmpty title="Die Lektion wartet auf Verbindung" body={error} onRetry={() => setAttempt((value) => value + 1)} /></View></View> : !lesson || !question ? <LoadingCard label="Lektionsinhalt wird geladen …" /> : saveError ? <View style={[ui.scroll, { justifyContent: 'center' }]}><View style={{ width }}><FriendlyEmpty title="Fortschritt noch nicht gespeichert" body="Deine Antworten sind da. Sende sie erneut, sobald die Verbindung bereit ist." onRetry={() => void submit(answers)} /></View></View> : <ScrollView contentContainerStyle={[ui.scroll, { paddingTop: 25, justifyContent: 'center' }]}><View style={{ width }}>
      <Animated.View key={question.id} entering={reduced ? undefined : FadeInDown.duration(300)} exiting={reduced ? undefined : FlipOutEasyY.duration(160)}>
        <Text style={[styles.kicker, { marginBottom: 9 }]}>{question.instruction ?? `${lesson.title} · Frage ${index + 1} von ${lesson.questions.length}`}</Text><Text style={styles.questionTitle}>{question.prompt}</Text>
        <View style={styles.choiceList}>{question.choices.map((choice) => {
          const active = selected === choice.id; const correct = active && choice.id === question.correctChoiceId; const wrong = active && !correct;
          return <Tap key={choice.id} onPress={() => { if (selected) return; setSelected(choice.id); void Haptics.selectionAsync(); }} style={[styles.answerChoice, active && styles.answerSelected, correct && styles.answerCorrect, wrong && styles.answerWrong]}>
            <Text style={[styles.answerLetter, active && { backgroundColor: correct ? colors.success : wrong ? colors.danger : colors.ink, color: colors.card }]}>{String.fromCharCode(65 + question.choices.indexOf(choice))}</Text><Text style={styles.answerText}>{choice.text}</Text>{correct ? <Text style={styles.feedbackIcon}>✓</Text> : wrong ? <Text style={styles.feedbackIcon}>↺</Text> : null}
          </Tap>;
        })}</View>
      </Animated.View>
      {selected ? <Animated.View entering={reduced ? undefined : FadeInUp.springify()} style={[styles.explanation, { backgroundColor: isCorrect ? '#E5F3E7' : '#F9E8E6' }]}><Text style={[styles.explanationTitle, { color: isCorrect ? '#245D31' : colors.danger }]}>{isCorrect ? 'Genau! Gut gesehen.' : 'Fast da — so klingt es richtig:'}</Text><Text style={styles.explanationCopy}>{question.explanation}</Text></Animated.View> : <Text style={styles.encouragement}>Einfach ausprobieren. Du kannst hier nichts verlieren.</Text>}
      <View style={{ marginTop: 22 }}><PrimaryButton title={index === lesson.questions.length - 1 ? 'Lektion abschließen' : 'Weiter'} disabled={!selected} busy={saving} onPress={advance} /></View>
    </View></ScrollView>}
  </SafeAreaView>;
}

function ReviewScreen({ width, onClose, onSaved }: { width: number; onClose: () => void; onSaved: () => void }) {
  const [index, setIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [answers, setAnswers] = useState<{ cardId: string; remembered: boolean }[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(false);
  const [result, setResult] = useState<{ reviewedCount: number; rememberedCount: number; xpAwarded: number }>();
  const flip = useSharedValue(0); const reduced = useReducedMotion();
  const requestId = useRef(`review_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`);
  const card = greetingCards[index];
  const flipStyle = useAnimatedStyle(() => ({ transform: [{ perspective: 900 }, { rotateY: `${interpolate(flip.value, [0, 1], [0, 180])}deg` }] }));
  const send = async (finalAnswers: { cardId: string; remembered: boolean }[]) => {
    setBusy(true); setError(false);
    try { const saved = await completeReview(finalAnswers, requestId.current); setResult(saved); await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success); }
    catch { setError(true); await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error); }
    finally { setBusy(false); }
  };
  const reveal = () => { if (!revealed) flip.value = reduced ? 1 : withTiming(1, { duration: 340 }); setRevealed(true); void Haptics.selectionAsync(); };
  const rate = (remembered: boolean) => {
    const next = [...answers, { cardId: card[0], remembered }];
    if (index === greetingCards.length - 1) { setAnswers(next); void send(next); return; }
    setAnswers(next); setIndex((value) => value + 1); setRevealed(false); flip.value = 0;
    void Haptics.impactAsync(remembered ? Haptics.ImpactFeedbackStyle.Medium : Haptics.ImpactFeedbackStyle.Light);
  };
  return <SafeAreaView style={styles.fullScreen} edges={['top', 'bottom']}>
    <View style={[styles.lessonHeader, { maxWidth: width, alignSelf: 'center' }]}><Tap onPress={onClose} style={styles.closeCircle}><Text style={styles.closeMark}>×</Text></Tap><View style={styles.lessonHeaderCenter}><Text style={styles.kicker}>WORTSCHATZ · {Math.min(index + 1, 10)} / 10</Text><AnimatedMeter value={result ? 1 : (index + (revealed ? 0.5 : 0)) / greetingCards.length} /></View><View style={{ width: 44 }} /></View>
    {result ? <ScrollView contentContainerStyle={[ui.scroll, { justifyContent: 'center' }]}><View style={{ width }}><Text style={[styles.kicker, { textAlign: 'center' }]}>WIEDERHOLUNG ABGESCHLOSSEN</Text><Text style={[styles.resultTitle, { textAlign: 'center', marginTop: 12 }]}>{result.rememberedCount} von {result.reviewedCount} Wörtern gewusst</Text><Text style={[styles.body, { marginTop: 10 }]}>Die Karten, die noch schwer waren, kommen bald wieder.</Text><View style={[styles.rewardCard, { width: '100%' }]}><Text style={styles.rewardValue}>+{result.xpAwarded} XP</Text></View><PrimaryButton title="Zurück zum Start" onPress={onSaved} /></View></ScrollView> : error ? <View style={[ui.scroll, { justifyContent: 'center' }]}><View style={{ width }}><FriendlyEmpty title="Wiederholung noch nicht gespeichert" body="Deine zehn Antworten sind sicher auf diesem Bildschirm. Versuche es noch einmal." onRetry={() => void send(answers)} /></View></View> : <ScrollView contentContainerStyle={[ui.scroll, { justifyContent: 'center' }]}><View style={{ width }}>
      <View style={[ui.row, { gap: 10, marginBottom: 7 }]}><Text style={[styles.kicker, { flex: 1 }]}>WIEDERHOLUNG · {index + 1} / 10</Text></View><Text style={styles.reviewTitle}>{index + 1 === 10 ? 'Letzte Karte' : 'Was bedeutet dieses Wort?'}</Text>
      <Pressable onPress={reveal} accessibilityRole="button" accessibilityLabel={revealed ? 'Übersetzung anzeigen' : 'Karte umdrehen'} style={styles.flashcardShell}>
        <Animated.View style={[styles.flashcardShellInner, flipStyle]}>
          <View style={[styles.flashcard, styles.flashcardFront]}>
            <Text style={styles.flashcardTag}>{card[3].toUpperCase()}</Text><Text style={styles.flashcardWord}>{card[1]}</Text><Text style={styles.flashcardHint}>TIPPE, UM DIE KARTE ZU WENDEN</Text>
          </View>
          <View style={[styles.flashcard, styles.flashcardBack]}>
            <Text style={styles.flashcardTag}>{card[3].toUpperCase()}</Text><Text style={styles.flashcardWord}>{card[2]}</Text><Text style={styles.flashcardHint}>ENGLISCHE BEDEUTUNG</Text>
          </View>
        </Animated.View>
      </Pressable>
      {revealed ? <Animated.View entering={reduced ? undefined : FadeInUp.springify()} style={styles.reviewActions}><Tap onPress={() => rate(false)} style={styles.hardButton}><Text style={styles.hardText}>Noch üben</Text><Text style={styles.actionHint}>kommt bald wieder</Text></Tap><Tap onPress={() => rate(true)} style={styles.easyButton}><Text style={styles.easyText}>Gewusst!</Text><Text style={styles.actionHint}>gut gemerkt</Text></Tap></Animated.View> : <Text style={styles.encouragement}>Du bestimmst selbst, was du schon sicher kannst.</Text>}
      {busy ? <Text style={styles.encouragement}>Deine Wiederholung wird sicher gespeichert …</Text> : null}
    </View></ScrollView>}
  </SafeAreaView>;
}

function GroupsScreen({ uid, width }: { uid: string; width: number }) {
  const [groups, setGroups] = useState<{ id: string; name: string; topic: string; levelTag: string; memberCount: number; lastMessage: string }[]>();
  const [joined, setJoined] = useState<Set<string>>(new Set());
  const [ageConfirmed, setAgeConfirmed] = useState(false);
  const [rulesAccepted, setRulesAccepted] = useState(false);
  const [busyId, setBusyId] = useState<string>();
  const [error, setError] = useState<string>();
  const [retry, setRetry] = useState(0);
  const [selectedGroupId, setSelectedGroupId] = useState<string>();
  const motion = useReducedMotion();
  useEffect(() => {
    setError(undefined); setGroups(undefined);
    const stopGroups = onSnapshot(query(collection(db, 'groups'), where('published', '==', true), where('isPublic', '==', true)), (snapshot) => {
      setGroups(snapshot.docs.map((item) => {
        const data = item.data(); const last = data.lastMessage && typeof data.lastMessage === 'object' ? data.lastMessage as Record<string, unknown> : {};
        return { id: item.id, name: String(data.name ?? item.id), topic: String(data.topic ?? ''), levelTag: String(data.levelTag ?? 'A1'), memberCount: typeof data.memberCount === 'number' ? data.memberCount : 0, lastMessage: typeof last.body === 'string' ? last.body : '' };
      }).sort((a, b) => a.levelTag.localeCompare(b.levelTag) || a.name.localeCompare(b.name)));
    }, () => setError('Lerngruppen konnten nicht geladen werden.'));
    const stopProfile = onSnapshot(doc(db, 'users', uid), (snapshot) => {
      const value = snapshot.data()?.joinedCommunityGroupIds;
      setJoined(new Set(Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : []));
    }, () => setError('Deine Gruppenmitgliedschaften konnten nicht geladen werden.'));
    return () => { stopGroups(); stopProfile(); };
  }, [uid, retry]);
  const join = async (groupId: string) => {
    if (!ageConfirmed || !rulesAccepted || busyId) return;
    setBusyId(groupId); setError(undefined);
    try {
      const action = httpsCallable(functions, 'joinLearningGroup');
      await action({ groupId, confirmAge16: true, acceptRulesVersion: 1 });
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch { setError('Der Beitritt konnte nicht bestätigt werden. Deine Auswahl bleibt erhalten.'); await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error); }
    finally { setBusyId(undefined); }
  };
  const selectedGroup = groups?.find((group) => group.id === selectedGroupId);
  if (selectedGroup && joined.has(selectedGroup.id)) return <GroupConversationScreen uid={uid} width={width} group={selectedGroup} onBack={() => setSelectedGroupId(undefined)} onLeave={() => setSelectedGroupId(undefined)} />;
  return <ScrollView contentContainerStyle={ui.scroll} showsVerticalScrollIndicator={false}><View style={{ width }}>
    <View style={styles.screenHeader}><View style={styles.headerGlyph}><Text style={{ color: colors.ink, fontSize: 17 }}>☻</Text></View><View><Text style={styles.kicker}>GEMEINSAM LERNEN</Text><Text style={styles.screenTitle}>Deine Gruppe</Text></View></View>
    <Animated.View entering={motion ? undefined : FadeInDown} style={styles.groupWelcome}><Text style={styles.groupWelcomeTitle}>Zusammen klingt Deutsch leichter.</Text><Text style={[styles.body, { textAlign: 'left', marginTop: 8 }]}>Finde Lernende auf deinem Niveau. Du entscheidest, wann du mitmachen möchtest.</Text></Animated.View>
    <Card style={{ marginTop: 14 }}><Text style={styles.missionTitle}>Bevor du beitrittst</Text><Text style={[styles.body, { textAlign: 'left', marginTop: 4 }]}>Die Lerngruppen sind für Menschen ab 16 und folgen den Wortwerk-Gruppenregeln.</Text>
      <ConsentRow selected={ageConfirmed} title="Ich bestätige, dass ich mindestens 16 Jahre alt bin." onPress={() => setAgeConfirmed((value) => !value)} />
      <ConsentRow selected={rulesAccepted} title="Ich akzeptiere die Gruppenregeln und respektiere andere Lernende." onPress={() => setRulesAccepted((value) => !value)} />
    </Card>
    <View style={{ marginTop: 24 }}><SectionTitle kicker="AUS FIRESTORE" title="Offene Lerngruppen" action={groups ? `${groups.length} Gruppen` : undefined} /></View>
    {error ? <FriendlyEmpty title="Gruppen gerade nicht erreichbar" body={error} onRetry={() => setRetry((value) => value + 1)} /> : !groups ? <LoadingCard label="Lerngruppen werden geladen …" /> : groups.length === 0 ? <FriendlyEmpty title="Noch keine Gruppe veröffentlicht" body="Neue Lerngruppen erscheinen hier, sobald sie im Lernbereich veröffentlicht wurden." /> : <View style={{ gap: 12 }}>{groups.map((group, index) => <Animated.View key={group.id} entering={motion ? undefined : FadeInUp.delay(index * 70).duration(360)}><Card style={styles.groupCard}>
      <View style={styles.groupCardHead}><View style={[styles.groupMark, { backgroundColor: colors.levels[(group.levelTag in colors.levels ? group.levelTag : 'A1') as LevelId] }]}><Text style={styles.groupMarkText}>{group.levelTag}</Text></View><View style={{ flex: 1 }}><Text style={styles.groupName}>{group.name}</Text><Text style={styles.body}>{group.topic}</Text></View><Text style={styles.groupMembers}>♧ {group.memberCount}</Text></View>
      {group.lastMessage ? <Text numberOfLines={2} style={styles.groupPreview}>„{group.lastMessage}“</Text> : <Text style={styles.groupPreview}>Ein ruhiger Platz für deine nächste Frage.</Text>}
      {joined.has(group.id) ? <View style={{ gap: 9 }}><View style={styles.joinedBadge}><Text style={styles.joinedText}>✓ Du bist dabei</Text></View><PrimaryButton title="Gruppengespräch öffnen" onPress={() => setSelectedGroupId(group.id)} /></View> : <PrimaryButton title={busyId === group.id ? 'Beitritt wird gespeichert …' : 'Gruppe ansehen & beitreten'} disabled={!ageConfirmed || !rulesAccepted || Boolean(busyId)} busy={busyId === group.id} onPress={() => void join(group.id)} />}
    </Card></Animated.View>)}</View>}
    <View style={{ height: 110 }} />
  </View></ScrollView>;
}

function GroupConversationScreen({ uid, width, group, onBack, onLeave }: { uid: string; width: number; group: { id: string; name: string; topic: string; levelTag: string; memberCount: number }; onBack: () => void; onLeave: () => void }) {
  const [messages, setMessages] = useState<{ id: string; uid: string; displayName: string; body: string; createdAt?: Date }[]>();
  const [blocked, setBlocked] = useState<Set<string>>();
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);
  const motion = useReducedMotion();
  useEffect(() => {
    let active = true;
    void getDocs(collection(db, 'users', uid, 'blocks')).then((snapshot) => { if (active) setBlocked(new Set(snapshot.docs.map((item) => item.id))); }).catch(() => { if (active) setError('Deine ausgeblendeten Kontakte konnten nicht geladen werden.'); });
    const stop = onSnapshot(query(collection(db, 'groups', group.id, 'messages'), where('status', '==', 'visible'), orderBy('createdAt', 'desc'), limit(50)), (snapshot) => {
      if (!active) return;
      setMessages(snapshot.docs.map((item) => { const data = item.data(); const createdAt = data.createdAt?.toDate?.(); return { id: item.id, uid: String(data.uid ?? ''), displayName: String(data.displayName ?? 'Lernende Person'), body: String(data.body ?? ''), ...(createdAt instanceof Date ? { createdAt } : {}) }; }).reverse());
    }, () => { if (active) setError('Das Gruppengespräch ist gerade nicht erreichbar. Prüfe zuerst deine Mitgliedschaft.'); });
    return () => { active = false; stop(); };
  }, [uid, group.id, reload]);
  const send = async () => {
    const body = input.trim(); if (!body || busy) return;
    setBusy(true); setError('');
    try { await httpsCallable(functions, 'sendGroupMessage')({ groupId: group.id, clientRequestId: `msg_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`, body }); setInput(''); }
    catch (reason) { const code = errorCode(reason); setError(code.includes('permission-denied') ? 'Du bist nicht mehr Mitglied dieser Gruppe.' : code.includes('resource-exhausted') ? 'Du hast gerade viele Nachrichten gesendet. Mach kurz Pause.' : 'Nachricht konnte nicht gesendet werden. Bitte prüfe sie und versuche es erneut.'); }
    finally { setBusy(false); }
  };
  const report = (messageId: string) => Alert.alert('Nachricht melden', 'Wähle den Grund für deine Meldung.', [
    { text: 'Abbrechen', style: 'cancel' },
    ...([['Belästigung', 'harassment'], ['Spam', 'spam'], ['Unsicherer Inhalt', 'unsafe'], ['Sonstiges', 'other']] as const).map(([label, reason]) => ({ text: label, onPress: () => { void httpsCallable(functions, 'reportGroupMessage')({ groupId: group.id, messageId, reason }).then(() => setError('Danke. Deine Meldung wurde vertraulich übermittelt.')).catch(() => setError('Die Meldung konnte gerade nicht übermittelt werden.')); } })),
  ]);
  const block = (otherUid: string) => Alert.alert('Mitglied ausblenden?', 'Nachrichten dieses Kontos werden für dich ausgeblendet.', [{ text: 'Abbrechen', style: 'cancel' }, { text: 'Ausblenden', style: 'destructive', onPress: () => { void httpsCallable(functions, 'blockCommunityMember')({ otherUid }).then(() => setBlocked((old) => old ? new Set(old).add(otherUid) : new Set([otherUid]))).catch(() => setError('Das Mitglied konnte nicht ausgeblendet werden.')); } }]);
  const leave = () => Alert.alert('Gruppe verlassen?', 'Du kannst die Gruppe später erneut entdecken und beitreten.', [{ text: 'Abbrechen', style: 'cancel' }, { text: 'Gruppe verlassen', style: 'destructive', onPress: () => { void httpsCallable(functions, 'leaveLearningGroup')({ groupId: group.id }).then(onLeave).catch(() => setError('Die Gruppe konnte nicht verlassen werden.')); } }]);
  return <SafeAreaView style={styles.fullScreen} edges={['top', 'bottom']}>
    <View style={[styles.tutorHeader, { maxWidth: width, alignSelf: 'center' }]}><Tap onPress={onClose} style={styles.closeCircle}><Text style={styles.closeMark}>×</Text></Tap><View style={styles.tutorAvatar}><Text style={styles.tutorAvatarLetter}>F</Text></View><View style={{ flex: 1 }}><Text style={styles.tutorTitle}>Lern mit Fritz</Text><View style={styles.tutorStatusLine}><View style={[styles.onlineDot, busy && styles.onlineDotBusy]} /><Text style={styles.tutorStatus}>{status} · {profile.level}</Text></View></View>{profile.speechOutputEnabled ? <Tap onPress={() => { activeSpeechRef.current = undefined; void Speech.stop(); setSpeakingMessageId(undefined); }} style={styles.voiceToggle} accessibilityLabel="Sprachausgabe stoppen"><Text style={styles.voiceToggleGlyph}>{speakingMessageId ? 'Ⅱ' : '♫'}</Text></Tap> : <View style={{ width: 38 }} />}</View>
    {error ? <Tap onPress={() => { setError(''); setReload((n) => n + 1); }} style={styles.communityNotice}><Text style={styles.tutorFailureText}>{error} · Erneut laden</Text></Tap> : null}
    <ScrollView contentContainerStyle={[ui.scroll, { flexGrow: 1, paddingTop: 14, paddingBottom: 25 }]}><View style={{ width, flex: 1 }}>
      {!messages || !blocked ? <LoadingCard label="Gespräch und deine ausgeblendeten Kontakte werden geladen …" /> : messages.filter((item) => !blocked.has(item.uid)).length === 0 ? <Card><Text style={[styles.missionTitle, { marginTop: 12 }]}>Der Anfang gehört dir.</Text><Text style={[styles.body, { textAlign: 'left', marginTop: 5 }]}>Teile einen freundlichen Satz auf Deutsch. Links und Kontaktdaten werden zum Schutz nicht zugelassen.</Text></Card> : messages.filter((item) => !blocked.has(item.uid)).map((message, index) => <Animated.View key={message.id} entering={motion ? undefined : FadeInDown.delay(Math.min(index * 35, 210))} style={{ marginBottom: 10 }}>
        <Card style={message.uid === uid ? styles.communityOwn : styles.communityMessage}><View style={styles.rowBetween}><Text style={styles.communityName}>{message.uid === uid ? 'Du' : message.displayName}</Text>{message.uid !== uid ? <Tap onPress={() => report(message.id)} accessibilityLabel="Nachricht melden" style={styles.communityAction}><Text style={styles.communityActionText}>Melden</Text></Tap> : null}{message.uid !== uid && !blocked.has(message.uid) ? <Tap onPress={() => block(message.uid)} accessibilityLabel="Mitglied ausblenden" style={styles.communityAction}><Text style={styles.communityActionText}>Ausblenden</Text></Tap> : null}</View><Text style={styles.communityBody}>{message.body}</Text>{message.createdAt ? <Text style={styles.communityTime}>{new Intl.DateTimeFormat('de-DE', { hour: '2-digit', minute: '2-digit' }).format(message.createdAt)}</Text> : null}</Card>
      </Animated.View>)}
    </View></ScrollView>
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={10}><View style={[styles.composerShell, { maxWidth: width, alignSelf: 'center' }]}><View style={styles.composer}><TextInput value={input} onChangeText={setInput} placeholder="Schreib einen Satz auf Deutsch …" placeholderTextColor={colors.muted} maxLength={2000} multiline style={styles.composerInput} accessibilityLabel="Nachricht an Gruppe"/><Tap onPress={() => void send()} disabled={!input.trim() || busy} style={[styles.sendButton, (!input.trim() || busy) && styles.sendButtonDisabled]} accessibilityLabel="Nachricht senden"><Text style={styles.sendGlyph}>{busy ? '…' : '↑'}</Text></Tap></View><Text style={styles.composerFootnote}>Respektvoll · keine Links · freundlich miteinander üben</Text></View></KeyboardAvoidingView>
  </SafeAreaView>;
}

function ConsentRow({ selected, title, onPress }: { selected: boolean; title: string; onPress: () => void }) {
  return <Tap onPress={onPress} style={styles.consentRow} accessibilityLabel={title}>
    <View style={[styles.checkBox, selected && styles.checkBoxSelected]}><Text style={styles.checkMark}>{selected ? '✓' : ''}</Text></View><Text style={styles.consentText}>{title}</Text>
  </Tap>;
}

function ProfileScreen({ uid, profile, width, onOpen }: { uid: string; profile: LearnerProfile; width: number; onOpen: (route: Route) => void }) {
  const motion = useReducedMotion();
  return <ScrollView contentContainerStyle={ui.scroll}><View style={{ width }}>
    <View style={styles.screenHeader}><View style={styles.headerGlyph}><Text style={{ color: colors.ink, fontSize: 17 }}>✿</Text></View><View><Text style={styles.kicker}>DEIN LERNKONTO</Text><Text style={styles.screenTitle}>Dein Profil</Text></View></View>
    <Animated.View entering={motion ? undefined : FadeInDown.duration(180)} style={[styles.profileHero, { backgroundColor: levelTheme(profile.level).surface }]}><View style={[styles.profileInitial, { backgroundColor: levelTheme(profile.level).deep }]}><Text style={styles.profileInitialText}>{profile.displayName.trim().slice(0, 1).toLocaleUpperCase('de-DE')}</Text></View><Text style={styles.profileName}>{profile.displayName}</Text><View style={[styles.profileLevelPill, { backgroundColor: colors.card }]}><Text style={[styles.profileLevelText, { color: levelTheme(profile.level).deep }]}>LERNSTUFE {profile.level}</Text></View></Animated.View>
    <View style={styles.statGrid}><StatCard value={`${profile.xpTotal}`} label="XP GESAMT" color={colors.levels.A2} /><StatCard value={`${profile.streak.longest}`} label="LÄNGSTE SERIE" color={colors.levels.C2} /><StatCard value={`${profile.streak.shields}`} label="LERN-SCHUTZ" color={colors.levels.B1} /></View>
    <Card style={{ marginTop: 14 }}><Text style={styles.kicker}>DEIN LERNPLAN</Text><Text style={[styles.profileGoal, { marginTop: 4 }]}>{profile.goals.join(' · ') || 'Dein Lernziel wächst mit dir.'}</Text><View style={styles.profileDivider} /><Text style={styles.body}>Lernzeit · {profile.dailyMinutes} Minuten am Lerntag</Text><Text style={styles.body}>Wochenziel · {profile.learningPlan?.targetDaysPerWeek ?? 5} Lerntage</Text><Text style={styles.body}>Lernstil · {profile.learningPreferences?.style ?? 'variety'}</Text><Text style={styles.body}>Zeitzone · {profile.timezone}</Text><Text style={styles.body}>Wöchentlicher Ruhetag · {['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'][profile.restWeekday % 7]}</Text></Card>
    <Card style={{ marginTop: 14 }}><Text style={styles.missionTitle}>Dein Fortschritt gehört dir.</Text><Text style={[styles.body, { textAlign: 'left', marginTop: 6 }]}>Lernstand, tägliche Missionen und dein Weg werden mit deinem Firebase-Lernkonto synchronisiert.</Text><Text style={styles.profileUid}>Lernkonto {uid.slice(0, 8)}</Text></Card>
    <View style={{ gap: 9, marginTop: 14 }}>
      <PrimaryButton title="Profil bearbeiten" onPress={() => onOpen('edit-profile')} />
      <Tap onPress={() => onOpen('settings')} style={styles.profileAction}><Text style={styles.profileActionTitle}>Lern-Einstellungen</Text><Text style={styles.profileActionCopy}>Ziel · Ruhetag · Sprache · Lernhilfe</Text><Text style={styles.profileActionArrow}>↗</Text></Tap>
      <Tap onPress={() => onOpen('notifications')} style={styles.profileAction}><Text style={styles.profileActionTitle}>Mitteilungen</Text><Text style={styles.profileActionCopy}>Dein persönliches Wortwerk-Postfach</Text><Text style={styles.profileActionArrow}>↗</Text></Tap>
      <Tap onPress={() => onOpen('streak')} style={styles.profileAction}><Text style={styles.profileActionTitle}>Lernrhythmus</Text><Text style={styles.profileActionCopy}>Deine aktiven Tage im Kalender</Text><Text style={styles.profileActionArrow}>↗</Text></Tap>
      <Tap onPress={() => onOpen('account')} style={styles.profileAction}><Text style={styles.profileActionTitle}>Konto & Sicherheit</Text><Text style={styles.profileActionCopy}>{auth.currentUser?.isAnonymous ? 'Gastkonto sichern' : 'E-Mail & Anmeldedaten'}</Text><Text style={styles.profileActionArrow}>↗</Text></Tap>
    </View>
    {auth.currentUser?.isAnonymous ? <View style={styles.guestBadge}><Text style={styles.guestBadgeText}>GASTPROFIL · FORTSCHRITT WIRD GESPEICHERT</Text></View> : null}
    <View style={{ height: 110 }} />
  </View></ScrollView>;
}

function StatCard({ value, label, color }: { value: string; label: string; color: string }) {
  const motion = useReducedMotion();
  return <Animated.View layout={motion ? undefined : LinearTransition.springify()} style={[styles.statCard, { backgroundColor: color }]}><Text style={styles.statValue}>{value}</Text><Text style={styles.statLabel}>{label}</Text></Animated.View>;
}

function TutorScreen({ uid, profile, width, onClose }: { uid: string; profile: LearnerProfile; width: number; onClose: () => void }) {
  const [messages, setMessages] = useState<TutorMessage[]>([]);
  const [demoHistoryReady, setDemoHistoryReady] = useState(!isUsingFirebaseEmulators);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string>();
  const [speakingMessageId, setSpeakingMessageId] = useState<string>();
  const activeSpeechRef = useRef<string | undefined>(undefined);
  const [retryPayload, setRetryPayload] = useState<{ text: string; requestId: string }>();
  const motion = useReducedMotion();
  useEffect(() => {
    if (isUsingFirebaseEmulators) {
      let alive = true;
      void loadDemoTutorMessages(uid).then((saved) => { if (alive) setMessages(saved); }).catch(() => { if (alive) setFailure('Die lokale Übung konnte nicht geladen werden.'); }).finally(() => { if (alive) setDemoHistoryReady(true); });
      return () => { alive = false; };
    }
    const messageCollection = collection(db, 'users', uid, 'aiThreads', 'main', 'messages');
    return onSnapshot(query(messageCollection, orderBy('createdAt'), limit(100)), (snapshot) => {
      setMessages(snapshot.docs.flatMap((item) => { const data = item.data(); return (data.role === 'user' || data.role === 'assistant') && typeof data.text === 'string' ? [{ id: item.id, role: data.role, text: data.text }] : []; }));
    }, () => setFailure('Fritz’ Gespräch konnte nicht geladen werden.'));
  }, [uid]);
  useEffect(() => () => { activeSpeechRef.current = undefined; void Speech.stop(); }, []);
  const send = async (retrying = false, starterText?: string, starterTitle?: string) => {
    const text = retrying ? retryPayload?.text : (starterText ?? input).trim();
    if (!text || busy) return;
    const payload = retrying && retryPayload ? retryPayload : { text, requestId: `fritz_${Date.now()}_${Math.random().toString(36).slice(2, 8)}` };
    setRetryPayload(payload); setBusy(true); setFailure(undefined);
    try {
      if (isUsingFirebaseEmulators) {
        const userMessage: TutorMessage = { id: `demo_user_${payload.requestId}`, role: 'user', text: starterTitle ? `${starterTitle} üben` : payload.text };
        const firstMessages = [...messages, userMessage].slice(-80);
        setMessages(firstMessages);
        await new Promise((resolve) => setTimeout(resolve, 420));
        const assistantMessage: TutorMessage = { id: `demo_assistant_${payload.requestId}`, role: 'assistant', text: answerInDemo(payload.text, profile.level) };
        const nextMessages = [...firstMessages, assistantMessage].slice(-80);
        setMessages(nextMessages);
        await saveDemoTutorMessages(uid, nextMessages);
        setInput(''); setRetryPayload(undefined); await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        return;
      }
      const call = httpsCallable(functions, 'fritzChat');
      await call({ message: payload.text, mode: 'practice', threadId: 'main', clientRequestId: payload.requestId });
      setInput(''); setRetryPayload(undefined); await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch (reason) {
      const code = errorCode(reason);
      setFailure(code.includes('failed-precondition')
        ? 'Der sichere KI-Zugang für Fritz ist auf diesem Server noch nicht eingerichtet. Du kannst es später erneut versuchen.'
        : 'Fritz konnte gerade keine Antwort erstellen. Deine Nachricht bleibt hier; du kannst es gleich noch einmal versuchen.');
    } finally { setBusy(false); }
  };
  const speak = (message: { id: string; text: string }) => {
    if (activeSpeechRef.current === message.id) { activeSpeechRef.current = undefined; setSpeakingMessageId(undefined); void Speech.stop(); return; }
    const isCurrentSpeech = () => activeSpeechRef.current === message.id;
    activeSpeechRef.current = message.id; setSpeakingMessageId(message.id);
    void Speech.stop().then(() => {
      if (!isCurrentSpeech()) return;
      Speech.speak(message.text, { language: 'de-DE', rate: 0.92, onDone: () => { if (isCurrentSpeech()) { activeSpeechRef.current = undefined; setSpeakingMessageId(undefined); } }, onStopped: () => { if (isCurrentSpeech()) { activeSpeechRef.current = undefined; setSpeakingMessageId(undefined); } }, onError: () => { if (isCurrentSpeech()) { activeSpeechRef.current = undefined; setSpeakingMessageId(undefined); } } });
    });
  };
  const starters = [
    { emoji: '01', title: 'Im Café', hint: 'Bestellen und bezahlen', prompt: 'Lass uns ein Rollenspiel im Café machen. Du bist der Barista und ich bestelle. Sprich auf Deutsch auf meinem Niveau und stelle immer nur eine Frage.' },
    { emoji: '02', title: 'Mich vorstellen', hint: 'Ein Gespräch beginnen', prompt: 'Übe mit mir, mich auf Deutsch vorzustellen. Stelle mir eine kurze Frage nach der anderen und passe die Sprache an mein Niveau an.' },
    { emoji: '03', title: 'Auf Reisen', hint: 'Am Bahnhof ankommen', prompt: 'Lass uns eine Reisesituation auf Deutsch üben. Du bist am Bahnhof und hilfst mir, ein Ticket zu kaufen. Frage mich Schritt für Schritt.' },
    { emoji: '04', title: 'Freies Gespräch', hint: 'Erzähl mir von deinem Tag', prompt: 'Führe ein lockeres deutsches Gespräch mit mir über meinen Tag. Stelle eine einfache, offene Frage und passe dich meinem Niveau an.' },
  ];
  const status = busy ? 'Fritz denkt nach …' : speakingMessageId ? 'Fritz spricht gerade' : 'Dein Coach ist bereit';
  return <SafeAreaView style={styles.fullScreen} edges={['top', 'bottom']}>
    <View style={[styles.tutorHeader, { maxWidth: width, alignSelf: 'center' }]}><Tap onPress={onClose} style={styles.closeCircle}><Text style={styles.closeMark}>×</Text></Tap><Animated.View style={styles.tutorAvatar}><FritzFace size={42} mood={busy ? 'thinking' : speakingMessageId ? 'speaking' : 'listening'} /></Animated.View><View style={{ flex: 1 }}><Text style={styles.tutorTitle}>Lern mit Fritz</Text><View style={styles.tutorStatusLine}><View style={[styles.onlineDot, busy && styles.onlineDotBusy]} /><Text style={styles.tutorStatus}>{status} · {profile.level}</Text></View></View>{profile.speechOutputEnabled ? <Tap onPress={() => { activeSpeechRef.current = undefined; void Speech.stop(); setSpeakingMessageId(undefined); }} style={styles.voiceToggle} accessibilityLabel="Sprachausgabe stoppen"><Text style={styles.voiceToggleGlyph}>{speakingMessageId ? 'Ⅱ' : '♫'}</Text></Tap> : <View style={{ width: 38 }} />}</View>
    <ScrollView contentContainerStyle={[ui.scroll, { flexGrow: 1, paddingTop: 15, paddingBottom: 22 }]}><View style={{ width, flex: 1 }}>
    {isUsingFirebaseEmulators ? <View style={styles.demoCoachNotice}><Text style={styles.demoCoachLabel}>DEMO-ÜBUNG</Text><Text style={styles.demoCoachCopy}>Vorbereitete Antworten ohne KI-Modell. Der Verlauf bleibt lokal und zählt noch nicht zu XP.</Text></View> : null}
    {messages.length === 0 ? <>
        <Animated.View entering={motion ? undefined : FadeInDown.duration(180)} style={styles.tutorWelcome}>
          <View style={styles.tutorWelcomeCopy}><Text style={styles.tutorEyebrow}>DEUTSCH SPRECHEN</Text><Text style={styles.tutorWelcomeTitle}>Übe eine Situation.</Text><Text style={styles.tutorWelcomeBody}>Wähle ein Thema. Fritz spricht mit dir auf {profile.level}-Niveau und wartet auf deine Antwort.</Text><Text style={styles.tutorPromiseText}>Du kannst jederzeit um eine langsamere Erklärung bitten.</Text></View>
        </Animated.View>
        <View style={styles.starterHeading}><View><Text style={styles.tutorSectionTitle}>Was möchtest du üben?</Text><Text style={styles.tutorSectionHint}>Wähle eine Situation und starte direkt.</Text></View><Text style={styles.starterCount}>4 IDEEN</Text></View>
        <View style={styles.starterGrid}>{starters.map((item, index) => <Animated.View key={item.title} entering={motion ? undefined : FadeInUp.delay(index * 70).duration(350)} style={{ width: '48%' }}><Tap disabled={busy || !demoHistoryReady} onPress={() => void send(false, item.prompt, item.title)} style={styles.starterCard}><View style={styles.starterTop}><View style={styles.starterEmoji}><Text style={styles.starterEmojiText}>{item.emoji}</Text></View><Text style={styles.starterArrow}>↗</Text></View><Text style={styles.starterTitle}>{item.title}</Text><Text style={styles.starterHint}>{item.hint}</Text></Tap></Animated.View>)}</View>
        <View style={styles.scopeNote}><Text style={styles.scopeTitle}>Klein anfangen ist perfekt.</Text><Text style={styles.body}>{isUsingFirebaseEmulators ? 'Probier eine Café-, Reise- oder Vorstellungsübung. Die Demo verwendet feste Lernantworten statt eines verbundenen KI-Modells.' : 'Schreibe eine Frage oder starte ein Rollenspiel. Fritz antwortet auf Deutsch und hilft dir, dranzubleiben.'}</Text></View>
      </> : <>
        <Animated.View entering={motion ? undefined : FadeInDown} style={styles.chatDay}><View style={styles.chatDayLine} /><Text style={styles.chatDayLabel}>DEIN GESPRÄCH</Text><View style={styles.chatDayLine} /></Animated.View>
        {messages.map((message) => <Animated.View key={message.id} entering={motion ? undefined : FadeInUp.duration(180)} style={[styles.chatRow, message.role === 'user' && styles.chatRowUser]}><View style={[styles.chatBubble, message.role === 'user' ? styles.userBubble : styles.coachBubble]}><Text style={[styles.chatCopy, message.role === 'user' && styles.userChatCopy]}>{message.text}</Text>{message.role !== 'user' && profile.speechOutputEnabled ? <Tap onPress={() => speak(message)} style={styles.speakReply}><Text style={styles.speakReplyGlyph}>{speakingMessageId === message.id ? 'Ⅱ' : '▶'}</Text><Text style={styles.speakReplyText}>{speakingMessageId === message.id ? 'Stoppen' : 'Anhören'}</Text></Tap> : null}</View></Animated.View>)}
      </>}
      {failure ? <Animated.View entering={motion ? undefined : FadeInDown} style={styles.tutorFailure}><Text style={styles.tutorFailureText}>{failure}</Text>{retryPayload ? <Tap onPress={() => void send(true)} style={styles.retryInline}><Text style={styles.retryInlineText}>Erneut versuchen</Text></Tap> : null}</Animated.View> : null}
      {busy ? <Animated.View entering={motion ? undefined : FadeInUp.duration(120)} style={styles.typingRow}><View style={styles.typingBubble}><View style={styles.typingDot} /><View style={[styles.typingDot, { opacity: 0.65 }]} /><View style={[styles.typingDot, { opacity: 0.35 }]} /></View><Text style={styles.typingLabel}>Fritz schreibt …</Text></Animated.View> : null}
    </View></ScrollView>
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={10}>
      <View style={[styles.composerShell, { maxWidth: width, alignSelf: 'center' }]}><View style={styles.composer}><TextInput value={input} onChangeText={setInput} placeholder="Schreib Fritz eine Nachricht …" placeholderTextColor={colors.muted} maxLength={1000} multiline style={styles.composerInput} accessibilityLabel="Nachricht an Fritz" onSubmitEditing={() => void send()}/><Tap onPress={() => void send()} disabled={!input.trim() || busy || !demoHistoryReady} style={[styles.sendButton, (!input.trim() || busy || !demoHistoryReady) && styles.sendButtonDisabled]} accessibilityLabel="Nachricht senden"><Text style={styles.sendGlyph}>{busy ? '…' : '↑'}</Text></Tap></View><Text style={styles.composerFootnote}>Dein Lerncoach · freundlich, geduldig, auf Deutsch</Text></View>
    </KeyboardAvoidingView>
  </SafeAreaView>;
}

function TabBar({ active, onChange }: { active: Tab; onChange: (tab: Tab) => void }) {
  const items: { id: Tab; label: string }[] = [
    { id: 'home', label: 'Start' }, { id: 'path', label: 'Lernweg' }, { id: 'groups', label: 'Gruppen' }, { id: 'profile', label: 'Profil' },
  ];
  const insets = useSafeAreaInsets();
  return <View style={[styles.tabBar, { paddingBottom: Math.max(insets.bottom, 8) }]}>{items.map((item) => {
    const selected = active === item.id;
    return <Tap key={item.id} onPress={() => onChange(item.id)} style={styles.tabItem} accessibilityLabel={`${item.label} öffnen`}>
      <View style={[styles.tabIndicator, selected && styles.tabIndicatorActive]} /><Text style={[styles.tabLabel, selected && styles.tabLabelActive]}>{item.label}</Text>
    </Tap>;
  })}</View>;
}

function findNextLesson(path?: LearningPath): { levelId: string; unitId: string; lessonId: string; lessonTitle: string; unitTitle: string; questionCount: number } | undefined {
  if (!path) return undefined;
  const levels = [...path.levels].sort((a, b) => a.order - b.order);
  for (const level of levels) {
    const units = [...level.units].sort((a, b) => a.order - b.order);
    for (const unit of units) {
      if (!unit.available) continue;
      const lesson = unit.lessons.find((item) => !item.completed);
      if (!lesson) continue;
      return { levelId: level.id, unitId: unit.id, lessonId: lesson.id, lessonTitle: lesson.title, unitTitle: unit.title, questionCount: lesson.questionCount };
    }
  }
  return undefined;
}

function routeFromPath(pathname: string): Route {
  const name = pathname.split('/').filter(Boolean).at(-1);
  return name && ['home', 'path', 'groups', 'profile', 'lesson', 'review', 'tutor', 'settings', 'notifications', 'streak', 'account', 'edit-profile'].includes(name)
    ? name as Route
    : 'home';
}

function goalName(goal: string) {
  const names: Record<string, string> = { reisen: 'Reisen', arbeit: 'Arbeit', alltag: 'Alltag', kultur: 'Kultur', neugier: 'Neugier', 'familie & freunde': 'Familie & Freunde' };
  return names[goal.toLocaleLowerCase('de-DE')] ?? goal;
}

function localDayId() {
  const date = new Date();
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function safeError(reason: unknown) {
  const code = reason && typeof reason === 'object' && 'code' in reason ? String((reason as { code: unknown }).code) : '';
  if (code.includes('network') || code.includes('unavailable') || code.includes('deadline')) return 'Keine Verbindung. Prüfe dein Netzwerk und versuche es erneut.';
  if (code.includes('permission-denied')) return 'Dein Lernkonto hat für diesen Schritt gerade keine Freigabe.';
  if (code.includes('failed-precondition')) return 'Dein Lernprofil ist noch nicht bereit für diesen Schritt.';
  return 'Es ist etwas dazwischengekommen. Dein Lernfortschritt bleibt sicher.';
}

function errorCode(reason: unknown) {
  return reason && typeof reason === 'object' && 'code' in reason
    ? String((reason as { code: unknown }).code)
    : '';
}

const styles = StyleSheet.create({
  emulatorBar: { flexDirection: 'row' as const, alignItems: 'center' as const, gap: 7, minHeight: 29, paddingHorizontal: 15, backgroundColor: colors.ink },
  emulatorDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: colors.success },
  emulatorText: { color: colors.paper, fontSize: 9, fontWeight: '900', letterSpacing: 1 },
  emulatorProject: { marginLeft: 'auto', color: '#D4BDEE', fontSize: 9, fontWeight: '700' },
  loading: { alignItems: 'center', justifyContent: 'center', gap: 12, paddingHorizontal: 20 },
  loadingTitle: { color: colors.ink, fontSize: 24, fontWeight: '900', marginTop: 10 },
  body: { color: colors.muted, fontSize: 14, lineHeight: 21 },
  kicker: { color: colors.muted, fontSize: 10, fontWeight: '900', letterSpacing: 1.15 },
  heroTitle: { color: colors.ink, fontSize: 31, lineHeight: 35, fontWeight: '900', letterSpacing: -1.1, marginTop: 5 },
  levelUpNotice: { flexDirection: 'row' as const, alignItems: 'flex-start' as const, gap: 11, backgroundColor: colors.levels.C2, borderColor: 'transparent', marginBottom: 17, padding: 16 },
  levelUpBadge: { width: 48, height: 48, borderRadius: 15, alignItems: 'center', justifyContent: 'center' },
  levelUpBadgeText: { color: '#FFFFFF', fontSize: 12, fontWeight: '900' },
  levelUpTitle: { color: colors.ink, fontSize: 15, fontWeight: '900' },
  levelUpCopy: { color: colors.ink, opacity: 0.75, fontSize: 11, lineHeight: 16, marginTop: 3 },
  levelUpAction: { alignSelf: 'flex-start', minHeight: 36, justifyContent: 'center' },
  levelUpActionText: { color: colors.ink, fontSize: 11, fontWeight: '900' },
  levelUpClose: { width: 28, height: 28, alignItems: 'center', justifyContent: 'center' },
  levelUpCloseText: { color: colors.ink, fontSize: 22, lineHeight: 24 },
  welcomeMascot: { alignItems: 'center', justifyContent: 'center', marginTop: 6, marginBottom: 22 },
  sparkle: { position: 'absolute', top: 0, right: '31%' },
  onboardingShell: { flex: 1, alignItems: 'center' },
  onboardingTop: { flexDirection: 'row' as const, alignItems: 'center' as const, justifyContent: 'space-between' as const, paddingTop: 9, paddingBottom: 13 },
  brandLockup: { flexDirection: 'row' as const, alignItems: 'center' as const, gap: 8 },
  brandMark: { width: 28, height: 28, borderRadius: 10, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center', transform: [{ rotate: '-8deg' }] },
  brandMarkText: { color: colors.paper, fontSize: 19, lineHeight: 22, fontWeight: '900' },
  brandName: { color: colors.ink, fontSize: 17, fontWeight: '900', letterSpacing: -0.6 },
  stepCount: { color: colors.ink, fontSize: 12, fontWeight: '900' },
  stepCountMuted: { color: colors.muted, fontWeight: '700' },
  progressTrack: { height: 5, backgroundColor: '#E3DED5', borderRadius: 99, overflow: 'hidden' },
  progressFill: { height: '100%', backgroundColor: colors.streak, borderRadius: 99 },
  onboardingScroll: { paddingTop: 18, paddingBottom: 30 },
  onboardingContext: { minHeight: 72, flexDirection: 'row' as const, alignItems: 'center' as const, gap: 12, paddingVertical: 12, marginBottom: 24, borderBottomWidth: 1, borderBottomColor: colors.line },
  onboardingContextMark: { width: 40, height: 40, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  onboardingContextNumber: { color: colors.ink, fontSize: 12, fontWeight: '800' },
  onboardingContextCopy: { flex: 1, color: colors.muted, fontSize: 13, lineHeight: 19 },
  onboardingQuestion: { marginBottom: 15 },
  onboardingTitle: { color: colors.ink, fontSize: 27, lineHeight: 32, fontWeight: '900', letterSpacing: -0.8, marginTop: 6 },
  goalGrid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 10, marginBottom: 18 },
  goalCard: { minHeight: 68, width: '100%', borderRadius: 14, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card, padding: 13, justifyContent: 'center', position: 'relative' },
  goalCardSelected: { backgroundColor: colors.ink, borderColor: colors.ink },
  goalText: { color: colors.ink, fontSize: 13, fontWeight: '600', marginRight: 20 },
  goalCheck: { position: 'absolute', top: 12, right: 12, width: 18, height: 18, borderRadius: 9, borderWidth: 1, borderColor: colors.line, alignItems: 'center', justifyContent: 'center' },
  goalCheckSelected: { backgroundColor: colors.levels.C2, borderColor: colors.levels.C2 },
  goalCheckGlyph: { color: colors.ink, fontSize: 11, fontWeight: '900' },
  minutesList: { gap: 9, marginBottom: 18 },
  minutesCard: { minHeight: 66, flexDirection: 'row', alignItems: 'center', gap: 13, padding: 10, paddingHorizontal: 12, borderRadius: 14, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card },
  minutesCardSelected: { borderColor: colors.ink, borderWidth: 1.5, backgroundColor: '#F7F1E8' },
  minutesNumber: { width: 46, height: 46, borderRadius: 16, backgroundColor: colors.paper, alignItems: 'center', justifyContent: 'center' },
  minutesNumberSelected: { backgroundColor: colors.ink },
  minutesNumberText: { color: colors.ink, fontSize: 18, fontWeight: '900' },
  minutesNumberTextSelected: { color: colors.paper },
  minutesTitle: { color: colors.ink, fontSize: 13, fontWeight: '900' },
  minutesHint: { color: colors.muted, fontSize: 10, marginTop: 3 },
  minutesArrow: { color: colors.ink, fontSize: 19, fontWeight: '900', paddingHorizontal: 4 },
  levelChoicePremium: { minHeight: 75, borderRadius: 21, paddingHorizontal: 13, marginBottom: 9 },
  levelDescription: { color: colors.ink, opacity: 0.7, fontSize: 10, marginLeft: 11, marginTop: 3 },
  onboardingFooter: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginTop: 4 },
  onboardingContinue: { minHeight: 55, flex: 1, backgroundColor: colors.ink, borderRadius: 19, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12, shadowColor: colors.ink, shadowOpacity: 0.15, shadowRadius: 12, shadowOffset: { width: 0, height: 6 }, elevation: 3 },
  onboardingContinueText: { color: colors.paper, fontSize: 14, fontWeight: '900' },
  onboardingContinueArrow: { color: colors.levels.C2, fontSize: 17, fontWeight: '900' },
  backButton: { minHeight: 48, paddingHorizontal: 8, justifyContent: 'center' },
  backButtonText: { color: colors.ink, fontSize: 12, fontWeight: '800' },
  choiceWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 9, marginTop: 12, marginBottom: 27 },
  choice: { minHeight: 46, borderRadius: 999, paddingHorizontal: 16, justifyContent: 'center', borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card },
  choiceSelected: { backgroundColor: colors.ink, borderColor: colors.ink },
  choiceText: { color: colors.ink, fontSize: 13, fontWeight: '700' },
  choiceSelectedText: { color: colors.paper },
  levelChoiceList: { gap: 9, marginVertical: 12 },
  levelChoice: { minHeight: 62, borderRadius: 19, borderWidth: 1, borderColor: 'transparent', paddingHorizontal: 14, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  levelChoiceSelected: { borderColor: colors.ink, borderWidth: 2 },
  levelBadge: { width: 38, height: 38, borderRadius: 14, backgroundColor: 'rgba(255,255,255,0.58)', alignItems: 'center', justifyContent: 'center' },
  levelBadgeText: { color: colors.ink, fontSize: 11, fontWeight: '900' },
  levelLabel: { marginLeft: 11, color: colors.ink, fontSize: 14, fontWeight: '700' },
  levelRadio: { fontSize: 18, color: colors.ink },
  errorCopy: { color: colors.danger, fontWeight: '700', lineHeight: 20, marginVertical: 10 },
  privacyNote: { color: colors.muted, textAlign: 'center', fontSize: 11, lineHeight: 16, marginTop: 12 },
  homeHeader: { minHeight: 82, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 },
  modernTopbar: { minHeight: 75, flexDirection: 'row' as const, alignItems: 'center' as const, justifyContent: 'space-between' as const, marginBottom: 16 },
  modernWordmark: { color: colors.muted, fontSize: 9, fontWeight: '900', letterSpacing: 1.25 },
  modernWordmarkDot: { color: colors.success },
  modernGreeting: { color: colors.ink, fontSize: 25, fontWeight: '800', letterSpacing: -0.7, marginTop: 5 },
  modernProfile: { width: 43, height: 43, borderRadius: 22, backgroundColor: colors.levels.A2, alignItems: 'center' as const, justifyContent: 'center' as const },
  modernProfileText: { color: colors.ink, fontSize: 16, fontWeight: '800' },
  homeFocusCard: { backgroundColor: colors.card, borderColor: colors.line, borderWidth: 1, borderLeftWidth: 4, borderRadius: 18, padding: 17, marginBottom: 15 },
  homeFocusTop: { flexDirection: 'row' as const, alignItems: 'center' as const, justifyContent: 'space-between' as const },
  homeFocusEyebrow: { color: colors.muted, fontSize: 10, fontWeight: '800', letterSpacing: 0.7 },
  homeFocusLevel: { minWidth: 38, minHeight: 28, alignItems: 'center' as const, justifyContent: 'center' as const, borderRadius: 8, paddingHorizontal: 8 },
  homeFocusLevelText: { fontSize: 11, fontWeight: '800' },
  homeFocusTitle: { color: colors.ink, fontSize: 20, fontWeight: '700', marginTop: 13 },
  homeFocusCopy: { color: colors.muted, fontSize: 13, marginTop: 4 },
  homeFocusAction: { minHeight: 44, borderTopWidth: 1, borderTopColor: colors.line, marginTop: 14, flexDirection: 'row' as const, alignItems: 'center' as const, justifyContent: 'space-between' as const },
  homeFocusActionText: { color: colors.ink, fontSize: 13, fontWeight: '700' },
  homeFocusActionArrow: { color: colors.ink, fontSize: 17 },
  modernStats: { flexDirection: 'row' as const, gap: 10, marginBottom: 10 },
  modernStatCard: { flex: 1, minHeight: 104, borderRadius: 19, backgroundColor: '#FFFFFF', borderWidth: 1, borderColor: colors.line, paddingHorizontal: 14, paddingVertical: 13, flexDirection: 'column' as const, alignItems: 'flex-start' as const },
  modernXpCard: { backgroundColor: '#E7F1DF', borderColor: '#E7F1DF', paddingVertical: 13 },
  modernStatCaption: { color: colors.muted, fontSize: 8, fontWeight: '900', letterSpacing: 0.65 },
  modernStatValueRow: { flexDirection: 'row' as const, alignItems: 'center' as const, gap: 7, marginTop: 6 },
  modernStatValue: { color: colors.ink, fontSize: 26, fontWeight: '800', letterSpacing: -0.8 },
  modernStatIcon: { color: '#6B8C50', fontSize: 11, fontWeight: '900' },
  modernStatFoot: { color: colors.muted, fontSize: 9, marginTop: 1 },
  modernWeek: { marginBottom: 20, paddingHorizontal: 4 },
  modernWeekGoal: { color: colors.muted, fontSize: 10, fontWeight: '800', textAlign: 'right', marginTop: 4 },
  modernMissionCard: { padding: 16, borderRadius: 21, backgroundColor: '#FFFFFF', borderWidth: 1, borderColor: colors.line, flexDirection: 'column' as const, alignItems: 'stretch' as const },
  modernSectionHead: { flexDirection: 'row' as const, justifyContent: 'space-between' as const, alignItems: 'center' as const, marginBottom: 12 },
  modernEyebrow: { color: colors.muted, fontSize: 8, fontWeight: '900', letterSpacing: 0.9 },
  modernSectionTitle: { color: colors.ink, fontSize: 18, fontWeight: '800', letterSpacing: -0.35, marginTop: 4 },
  modernMissionCount: { color: colors.ink, fontSize: 16, fontWeight: '900' },
  modernMissionTotal: { color: colors.muted, fontSize: 12, fontWeight: '700' },
  modernSectionHeader: { marginTop: 24, marginBottom: 12 },
  modernLessonCard: { backgroundColor: '#FFFFFF', borderRadius: 21, borderWidth: 1, borderColor: colors.line, padding: 16, flexDirection: 'column' as const, alignItems: 'stretch' as const },
  modernLessonTop: { minHeight: 46, flexDirection: 'row' as const, alignItems: 'center' as const, gap: 9 },
  modernLessonBadge: { minWidth: 42, height: 33, alignItems: 'center', justifyContent: 'center', borderRadius: 12, backgroundColor: colors.levels.A1, paddingHorizontal: 8 },
  modernLessonBadgeText: { color: colors.ink, fontSize: 10, fontWeight: '900' },
  modernLessonMeta: { color: colors.muted, fontSize: 10, fontWeight: '700', flex: 1 },
  modernLessonTitle: { color: colors.ink, fontSize: 18, lineHeight: 22, fontWeight: '800', marginTop: 11 },
  modernLessonUnit: { color: colors.muted, fontSize: 11, marginTop: 3 },
  modernLessonAction: { minHeight: 45, flexDirection: 'row' as const, alignItems: 'center' as const, justifyContent: 'space-between' as const, paddingHorizontal: 14, marginTop: 15, borderRadius: 14, backgroundColor: '#173B31' },
  modernLessonActionText: { color: '#FFFFFF', fontSize: 11, fontWeight: '800' },
  modernLessonActionArrow: { color: '#D4EE9A', fontSize: 17, fontWeight: '700' },
  modernReviewLink: { minHeight: 70, flexDirection: 'row' as const, alignItems: 'center' as const, justifyContent: 'space-between' as const, borderBottomWidth: 1, borderBottomColor: colors.line, marginTop: 7, paddingHorizontal: 4 },
  modernReviewTitle: { color: colors.ink, fontSize: 15, fontWeight: '800', marginTop: 4 },
  modernReviewArrow: { color: colors.ink, fontSize: 21, fontWeight: '700' },
  homeHero: { minHeight: 178, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', overflow: 'hidden', position: 'relative', backgroundColor: colors.levels.A2, borderRadius: 31, paddingHorizontal: 19, paddingVertical: 18, marginBottom: 19 },
  homeHeroOrbit: { position: 'absolute', width: 190, height: 190, borderRadius: 100, borderWidth: 1, borderColor: 'rgba(30,29,34,0.09)', right: -64, top: -95 },
  homeHeroOrbitSmall: { position: 'absolute', width: 130, height: 130, borderRadius: 70, borderWidth: 1, borderColor: 'rgba(30,29,34,0.09)', right: -29, bottom: -80 },
  homeHeroCopy: { flex: 1, zIndex: 1 },
  homeHeroEyebrow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  homeHeroEyebrowText: { color: colors.ink, fontSize: 8, fontWeight: '900', letterSpacing: 0.75 },
  homeHeroTitle: { color: colors.ink, fontSize: 29, lineHeight: 31, fontWeight: '900', letterSpacing: -1.1, marginTop: 10 },
  homeHeroBody: { color: colors.ink, opacity: 0.7, fontSize: 11, fontWeight: '600', marginTop: 7 },
  homeHeroMascot: { width: 96, alignItems: 'center', justifyContent: 'center', zIndex: 1 },
  homeHeroBubble: { backgroundColor: colors.card, borderRadius: 999, paddingHorizontal: 9, paddingVertical: 6, marginTop: -1, shadowColor: colors.ink, shadowOpacity: 0.1, shadowRadius: 7, shadowOffset: { width: 0, height: 3 }, elevation: 2 },
  homeHeroBubbleText: { color: colors.ink, fontSize: 9, fontWeight: '900' },
  homeColumns: { gap: 12 },
  homeColumnsWide: { flexDirection: 'row', alignItems: 'stretch' },
  streakCard: { backgroundColor: colors.ink, borderRadius: radii.card, padding: 20, minHeight: 185 },
  streakTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  streakValue: { color: colors.paper, fontSize: 35, lineHeight: 38, fontWeight: '900', letterSpacing: -1 },
  streakLabel: { color: '#E8D9C7', fontSize: 9, fontWeight: '900', letterSpacing: 0.9, marginTop: 3 },
  xpPill: { backgroundColor: '#34323A', borderRadius: 999, paddingVertical: 8, paddingHorizontal: 11 },
  xpText: { color: colors.levels.C2, fontSize: 12, fontWeight: '900' },
  streakFoot: { flexDirection: 'row', justifyContent: 'space-between', borderTopColor: 'rgba(255,255,255,0.16)', borderTopWidth: 1, marginTop: 14, paddingTop: 10 },
  streakFootText: { color: '#DDD9D2', fontSize: 9, fontWeight: '700' },
  missionsCard: { backgroundColor: colors.card, borderColor: colors.line, borderWidth: 1, borderRadius: radii.card, padding: 18, minHeight: 185, justifyContent: 'center' },
  missionHeading: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 11 },
  missionTitle: { color: colors.ink, fontSize: 17, fontWeight: '900', letterSpacing: -0.25 },
  missionCount: { color: colors.ink, fontSize: 13, fontWeight: '900', backgroundColor: colors.paper, borderRadius: 999, paddingHorizontal: 9, paddingVertical: 6, overflow: 'hidden' },
  missionRow: { flexDirection: 'row', alignItems: 'center', gap: 10, minHeight: 48, paddingVertical: 5 },
  missionIcon: { width: 31, height: 31, borderRadius: 11, backgroundColor: '#FCE3C5', alignItems: 'center', justifyContent: 'center' },
  missionIconDone: { backgroundColor: '#E2F2E5' },
  missionIconText: { color: colors.ink, fontWeight: '900', fontSize: 15 },
  missionRowTitle: { color: colors.ink, fontSize: 11, fontWeight: '800', marginBottom: 5 },
  completedText: { color: '#3E7350' },
  miniMeter: { width: 50, height: 4, overflow: 'hidden', backgroundColor: colors.paper, borderRadius: 99 },
  miniMeterFill: { height: 4, borderRadius: 99 },
  missionProgress: { color: colors.muted, fontSize: 9, fontWeight: '700', marginLeft: 5 },
  missionXp: { color: colors.streak, fontSize: 10, fontWeight: '900' },
  doneMessage: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7, backgroundColor: '#E2F2E5', borderRadius: 13, padding: 10, marginTop: 10 },
  doneEmoji: { color: '#397447', fontSize: 17 },
  doneText: { color: '#397447', fontSize: 11, fontWeight: '900' },
  softError: { color: colors.danger, fontSize: 12, fontWeight: '700', marginTop: 8 },
  nextLesson: { overflow: 'hidden', backgroundColor: colors.card, borderColor: colors.line, borderWidth: 1, borderRadius: radii.card },
  nextLessonArt: { minHeight: 125, backgroundColor: colors.levels.A1, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 22 },
  lessonTag: { color: colors.ink, fontSize: 9, fontWeight: '900', letterSpacing: 0.8, backgroundColor: 'rgba(255,255,255,0.55)', padding: 8, borderRadius: 999, overflow: 'hidden' },
  nextLessonTitle: { color: colors.ink, fontSize: 20, fontWeight: '900', marginBottom: 4 },
  warmupCard: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16 },
  warmupIcon: { width: 48, height: 48, borderRadius: 16, backgroundColor: colors.levels.A2, alignItems: 'center', justifyContent: 'center' },
  warmupWord: { color: colors.ink, fontSize: 16, fontWeight: '900', marginBottom: 2 },
  roundArrow: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center' },
  roundArrowText: { color: colors.paper, fontSize: 18, fontWeight: '900' },
  loadingCard: { flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 14 },
  screenHeader: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 25, paddingTop: 5 },
  headerGlyph: { width: 42, height: 42, borderRadius: 15, backgroundColor: colors.levels.A2, alignItems: 'center', justifyContent: 'center' },
  screenTitle: { color: colors.ink, fontSize: 22, fontWeight: '900', letterSpacing: -0.5 },
  pathIntro: { backgroundColor: colors.ink, borderRadius: radii.card, padding: 21, flexDirection: 'row', alignItems: 'center', gap: 12 },
  pathTitle: { color: colors.paper, fontSize: 24, fontWeight: '900', marginTop: 5 },
  pathBadge: { width: 58, height: 58, borderRadius: 20, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.levels.A1 },
  pathBadgeText: { color: colors.ink, fontSize: 15, fontWeight: '900' },
  levelHeader: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 12 },
  levelMark: { width: 48, height: 48, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
  levelMarkText: { color: colors.ink, fontSize: 12, fontWeight: '900' },
  levelTitle: { color: colors.ink, fontSize: 18, fontWeight: '900' },
  nowPill: { backgroundColor: colors.ink, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 7 },
  nowPillText: { color: colors.paper, fontSize: 8, fontWeight: '900', letterSpacing: 0.6 },
  unitBlock: { backgroundColor: 'rgba(255,255,255,0.28)', borderRadius: 25, padding: 12, paddingTop: 15, marginBottom: 10 },
  unitLabel: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginHorizontal: 5, marginBottom: 4 },
  unitTitle: { color: colors.ink, fontSize: 14, fontWeight: '900' },
  unitCount: { color: colors.muted, fontSize: 10, fontWeight: '800' },
  roadBoard: { width: '100%', position: 'relative', overflow: 'hidden' },
  pathNodePosition: { position: 'absolute', width: 76, alignItems: 'center' },
  pathNode: { width: 66, height: 66, borderRadius: 25, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
  pathNodeDone: { backgroundColor: colors.success, borderColor: colors.success },
  pathNodeLocked: { backgroundColor: colors.paper, borderColor: colors.line },
  pathNodeSymbol: { color: colors.ink, fontSize: 23, fontWeight: '900' },
  pathNodeCaption: { color: colors.ink, fontSize: 10, lineHeight: 13, fontWeight: '800', textAlign: 'center', width: 92, marginTop: 3 },
  levelConnector: { flexDirection: 'row', alignItems: 'center', gap: 9, marginTop: 18 },
  connectorLine: { flex: 1, height: 1, backgroundColor: colors.line },
  connectorCopy: { color: colors.muted, fontSize: 8, fontWeight: '900', letterSpacing: 0.6 },
  criteriaRow: { marginTop: 16, gap: 7 },
  criteriaHeading: { flexDirection: 'row', justifyContent: 'space-between', gap: 8 },
  criteriaTitle: { color: colors.ink, fontSize: 12, fontWeight: '800' },
  criteriaValue: { color: colors.muted, fontSize: 10, fontWeight: '700' },
  fullScreen: { flex: 1, backgroundColor: colors.paper },
  lessonHeader: { width: '100%', flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 20, paddingVertical: 10 },
  closeCircle: { width: 42, height: 42, borderRadius: 21, borderWidth: 1, borderColor: colors.line, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.card },
  closeMark: { color: colors.ink, fontSize: 25, lineHeight: 27, fontWeight: '500' },
  lessonHeaderCenter: { flex: 1, gap: 7 },
  resultSeal: { width: 100, height: 100, borderRadius: 36, alignSelf: 'center', alignItems: 'center', justifyContent: 'center' },
  resultSealText: { color: colors.ink, fontSize: 48, fontWeight: '900' },
  resultTitle: { color: colors.ink, fontSize: 29, fontWeight: '900', textAlign: 'center', letterSpacing: -0.8, marginTop: 17, marginBottom: 5 },
  rewardCard: { backgroundColor: colors.ink, borderRadius: 25, alignItems: 'center', justifyContent: 'center', padding: 22, marginVertical: 25 },
  rewardValue: { color: colors.paper, fontSize: 27, fontWeight: '900', marginTop: 4 },
  rewardCaption: { color: '#D4BDEE', fontSize: 9, fontWeight: '900', letterSpacing: 1.2, marginTop: 4 },
  questionTitle: { color: colors.ink, fontSize: 25, lineHeight: 31, fontWeight: '900', letterSpacing: -0.5, marginTop: 11, marginBottom: 21 },
  choiceList: { gap: 10 },
  answerChoice: { minHeight: 62, borderRadius: 19, borderWidth: 1.2, borderColor: colors.line, backgroundColor: colors.card, alignItems: 'center', flexDirection: 'row', paddingHorizontal: 12, gap: 12 },
  answerSelected: { borderColor: colors.ink },
  answerCorrect: { backgroundColor: '#E5F3E7', borderColor: colors.success },
  answerWrong: { backgroundColor: '#F9E8E6', borderColor: colors.danger },
  answerLetter: { width: 33, height: 33, borderRadius: 12, backgroundColor: colors.paper, alignItems: 'center', textAlign: 'center', textAlignVertical: 'center', color: colors.ink, overflow: 'hidden', fontSize: 12, lineHeight: 33, fontWeight: '900' },
  answerText: { flex: 1, color: colors.ink, fontSize: 14, fontWeight: '700' },
  feedbackIcon: { color: colors.ink, fontSize: 17, fontWeight: '900' },
  explanation: { borderRadius: 17, padding: 14, marginTop: 15 },
  explanationTitle: { fontSize: 13, fontWeight: '900', marginBottom: 3 },
  explanationCopy: { color: colors.ink, fontSize: 13, lineHeight: 19 },
  encouragement: { color: colors.muted, fontSize: 12, lineHeight: 18, textAlign: 'center', marginTop: 18 },
  reviewTitle: { color: colors.ink, fontSize: 27, fontWeight: '900', letterSpacing: -0.6, marginTop: 7, marginBottom: 21 },
  flashcardShell: { height: 290, width: '100%' },
  flashcardShellInner: { flex: 1, transform: [{ perspective: 900 }] },
  flashcard: { flex: 1, borderRadius: 35, borderColor: colors.ink, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center', padding: 24, backfaceVisibility: 'hidden' },
  flashcardFront: { backgroundColor: colors.levels.A1 },
  flashcardBack: { position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: colors.levels.B1, transform: [{ rotateY: '180deg' }] },
  flashcardTag: { position: 'absolute', top: 25, color: colors.ink, fontSize: 9, fontWeight: '900', letterSpacing: 1.1 },
  flashcardWord: { color: colors.ink, fontSize: 34, fontWeight: '900', textAlign: 'center', letterSpacing: -0.7 },
  flashcardHint: { position: 'absolute', bottom: 24, color: colors.muted, fontSize: 9, fontWeight: '800', letterSpacing: 0.6 },
  reviewActions: { flexDirection: 'row', gap: 10, marginTop: 17 },
  hardButton: { flex: 1, minHeight: 68, alignItems: 'center', justifyContent: 'center', borderRadius: 19, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card },
  hardText: { color: colors.ink, fontWeight: '900', fontSize: 13 },
  easyButton: { flex: 1, minHeight: 68, alignItems: 'center', justifyContent: 'center', borderRadius: 19, backgroundColor: colors.ink },
  easyText: { color: colors.paper, fontWeight: '900', fontSize: 13 },
  actionHint: { color: colors.muted, fontSize: 9, marginTop: 4 },
  groupWelcome: { backgroundColor: colors.levels.B1, borderRadius: radii.card, padding: 21 },
  groupWelcomeTitle: { color: colors.ink, fontSize: 21, lineHeight: 26, fontWeight: '900' },
  consentRow: { flexDirection: 'row', alignItems: 'center', gap: 10, minHeight: 48, marginTop: 8 },
  checkBox: { width: 25, height: 25, borderRadius: 8, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card, alignItems: 'center', justifyContent: 'center' },
  checkBoxSelected: { backgroundColor: colors.ink, borderColor: colors.ink },
  checkMark: { color: colors.paper, fontWeight: '900' },
  consentText: { flex: 1, color: colors.ink, fontSize: 11, lineHeight: 16, fontWeight: '600' },
  groupCard: { padding: 16 },
  groupCardHead: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  groupMark: { width: 44, height: 44, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  groupMarkText: { color: colors.ink, fontSize: 11, fontWeight: '900' },
  groupName: { color: colors.ink, fontSize: 15, fontWeight: '900' },
  groupMembers: { color: colors.muted, fontSize: 10, fontWeight: '800' },
  groupPreview: { color: colors.muted, fontSize: 12, lineHeight: 17, marginTop: 15, marginBottom: 14 },
  joinedBadge: { minHeight: 46, backgroundColor: '#E5F3E7', borderRadius: 999, alignItems: 'center', justifyContent: 'center' },
  joinedText: { color: '#245D31', fontSize: 12, fontWeight: '900' },
  profileHero: { backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line, borderRadius: 18, minHeight: 168, alignItems: 'center', justifyContent: 'center', padding: 20 },
  profileInitial: { width: 56, height: 56, borderRadius: 17, alignItems: 'center', justifyContent: 'center', marginBottom: 12 },
  profileInitialText: { color: colors.paper, fontSize: 24, fontWeight: '600' },
  profileName: { color: colors.ink, fontSize: 21, fontWeight: '900', marginTop: 10 },
  profileLevelPill: { backgroundColor: 'rgba(255,255,255,0.65)', borderRadius: 999, paddingHorizontal: 11, paddingVertical: 7, marginTop: 7 },
  profileLevelText: { color: colors.ink, fontSize: 9, fontWeight: '900', letterSpacing: 0.9 },
  statGrid: { flexDirection: 'row', gap: 8, marginTop: 13 },
  statCard: { flex: 1, minHeight: 86, borderRadius: 20, padding: 12, justifyContent: 'center' },
  statValue: { color: colors.ink, fontSize: 22, fontWeight: '900' },
  statLabel: { color: colors.ink, fontSize: 8, fontWeight: '900', marginTop: 4, letterSpacing: 0.3 },
  profileGoal: { color: colors.ink, fontSize: 17, lineHeight: 23, fontWeight: '900' },
  profileDivider: { height: 1, backgroundColor: colors.line, marginVertical: 14 },
  profileUid: { color: colors.muted, fontSize: 9, letterSpacing: 0.4, marginTop: 14 },
  guestBadge: { minHeight: 42, marginTop: 14, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.levels.C2, borderRadius: 999 },
  guestBadgeText: { color: colors.ink, fontSize: 8, letterSpacing: 0.7, fontWeight: '900' },
  profileAction: { minHeight: 70, paddingHorizontal: 16, paddingVertical: 11, borderRadius: 20, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card, justifyContent: 'center' },
  profileActionTitle: { color: colors.ink, fontSize: 14, fontWeight: '900' },
  profileActionCopy: { color: colors.muted, fontSize: 10, marginTop: 4 },
  profileActionArrow: { color: colors.streak, position: 'absolute', right: 16, top: 24, fontSize: 18, fontWeight: '900' },
  rowBetween: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  communityMessage: { padding: 14, borderTopLeftRadius: 8 },
  communityOwn: { padding: 14, backgroundColor: colors.levels.A1, borderColor: colors.levels.A1, borderTopRightRadius: 8 },
  communityName: { color: colors.ink, fontSize: 10, fontWeight: '900', flex: 1 },
  communityAction: { minHeight: 33, paddingHorizontal: 8, alignItems: 'center', justifyContent: 'center' },
  communityActionText: { color: colors.muted, fontSize: 9, fontWeight: '800' },
  communityBody: { color: colors.ink, fontSize: 13, lineHeight: 19, marginTop: 7 },
  communityTime: { color: colors.muted, fontSize: 9, textAlign: 'right', marginTop: 6 },
  communityNotice: { padding: 12, backgroundColor: '#FFF3D7' },
  tutorHeader: { width: '100%', minHeight: 66, flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 16, borderBottomWidth: 1, borderBottomColor: colors.line },
  tutorTitle: { color: colors.ink, fontSize: 16, fontWeight: '900' },
  onlineDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.streak },
  onlineDotBusy: { backgroundColor: colors.levels.B1 },
  tutorStatusLine: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 4 },
  tutorStatus: { color: colors.muted, fontSize: 10, fontWeight: '700' },
  tutorAvatar: { width: 46, height: 46, alignItems: 'center', justifyContent: 'center', borderRadius: 17, backgroundColor: colors.levels.A2 },
  demoCoachNotice: { flexDirection: 'row', alignItems: 'center', gap: 9, width: '100%', padding: 12, marginBottom: 14, borderRadius: 14, backgroundColor: colors.levels.B2 },
  demoCoachLabel: { color: colors.ink, fontSize: 9, fontWeight: '900', letterSpacing: 0.8 },
  demoCoachCopy: { flex: 1, color: colors.ink, fontSize: 10, lineHeight: 14 },
  voiceToggle: { width: 38, height: 38, borderRadius: 14, backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line, alignItems: 'center', justifyContent: 'center' },
  voiceToggleGlyph: { color: colors.ink, fontSize: 16, fontWeight: '900' },
  tutorWelcome: { width: '100%', overflow: 'hidden', borderRadius: 28, backgroundColor: colors.ink, marginBottom: 24 },
  tutorWelcomeArt: { height: 173, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.levels.A2, overflow: 'hidden' },
  tutorOrbit: { position: 'absolute', width: 210, height: 210, borderRadius: 110, borderWidth: 1, borderColor: 'rgba(30,29,34,0.13)' },
  tutorOrbitInner: { position: 'absolute', width: 148, height: 148, borderRadius: 80, borderWidth: 1, borderColor: 'rgba(30,29,34,0.10)' },
  tutorMascot: { zIndex: 2 },
  tutorWelcomeSpark: { position: 'absolute', top: 31, right: '28%', width: 34, height: 34, borderRadius: 12, backgroundColor: colors.card, alignItems: 'center', justifyContent: 'center', transform: [{ rotate: '12deg' }] },
  tutorWelcomeSparkText: { color: colors.streak, fontSize: 21, fontWeight: '900' },
  tutorWelcomeCopy: { paddingHorizontal: 20, paddingTop: 19, paddingBottom: 20 },
  tutorEyebrow: { color: colors.levels.C2, fontSize: 8, fontWeight: '900', letterSpacing: 1.1 },
  tutorWelcomeTitle: { color: colors.paper, fontSize: 27, fontWeight: '900', letterSpacing: -0.7, marginTop: 7 },
  tutorWelcomeBody: { color: '#E3DFD8', fontSize: 12, lineHeight: 18, marginTop: 6 },
  tutorPromise: { flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: '#34323A', borderRadius: 14, paddingHorizontal: 11, paddingVertical: 9, marginTop: 14 },
  tutorPromiseGlyph: { color: colors.levels.C2, fontSize: 14 },
  tutorPromiseText: { flex: 1, color: colors.paper, fontSize: 9, lineHeight: 13, fontWeight: '700' },
  starterHeading: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  tutorSectionTitle: { color: colors.ink, fontSize: 17, fontWeight: '900' },
  tutorSectionHint: { color: colors.muted, fontSize: 10, marginTop: 3 },
  starterCount: { color: colors.muted, fontSize: 8, fontWeight: '900', letterSpacing: 0.8 },
  starterGrid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 10, marginBottom: 18 },
  starterCard: { minHeight: 124, borderRadius: 20, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card, padding: 13, justifyContent: 'space-between' },
  starterTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  starterEmoji: { width: 35, height: 35, borderRadius: 13, backgroundColor: colors.levels.A1, alignItems: 'center', justifyContent: 'center' },
  starterEmojiText: { fontSize: 17 },
  starterArrow: { color: colors.muted, fontSize: 16, fontWeight: '800' },
  starterTitle: { color: colors.ink, fontSize: 13, fontWeight: '900', marginTop: 9 },
  starterHint: { color: colors.muted, fontSize: 9, marginTop: 3 },
  scopeNote: { width: '100%', backgroundColor: '#FFF3D7', borderRadius: 17, padding: 15, marginBottom: 18 },
  scopeTitle: { color: colors.ink, fontSize: 12, lineHeight: 17, fontWeight: '900', marginBottom: 3 },
  chatDay: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 16 },
  chatDayLine: { flex: 1, height: 1, backgroundColor: colors.line },
  chatDayLabel: { color: colors.muted, fontSize: 8, fontWeight: '900', letterSpacing: 1 },
  chatRow: { flexDirection: 'row', alignItems: 'flex-end', gap: 8, marginBottom: 9 },
  chatRowUser: { justifyContent: 'flex-end' },
  chatBubble: { maxWidth: '84%', borderRadius: 19, paddingHorizontal: 14, paddingVertical: 11, marginBottom: 2 },
  coachBubble: { alignSelf: 'flex-start', backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line },
  userBubble: { alignSelf: 'flex-end', backgroundColor: colors.ink },
  chatCopy: { color: colors.ink, fontSize: 13, lineHeight: 19 },
  userChatCopy: { color: colors.paper },
  speakReply: { minHeight: 31, flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start', gap: 6, marginTop: 7, paddingHorizontal: 9, borderRadius: 10, backgroundColor: colors.paper },
  speakReplyGlyph: { color: colors.streak, fontSize: 10, fontWeight: '900' },
  speakReplyText: { color: colors.ink, fontSize: 9, fontWeight: '800' },
  typingRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 5, marginBottom: 8 },
  typingBubble: { height: 34, flexDirection: 'row', alignItems: 'center', gap: 5, borderRadius: 15, paddingHorizontal: 13, backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line },
  typingDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.streak },
  typingLabel: { color: colors.muted, fontSize: 9, fontWeight: '700' },
  tutorFailure: { alignSelf: 'stretch', backgroundColor: '#F9E8E6', borderRadius: 16, padding: 13, marginTop: 8 },
  tutorFailureText: { color: colors.ink, fontSize: 12, lineHeight: 18 },
  retryInline: { minHeight: 40, justifyContent: 'center' },
  retryInlineText: { color: colors.danger, fontWeight: '900', fontSize: 12 },
  composerShell: { width: '100%', backgroundColor: colors.card, borderTopWidth: 1, borderTopColor: colors.line, paddingHorizontal: 14, paddingTop: 9, paddingBottom: 5 },
  composer: { width: '100%', minHeight: 53, flexDirection: 'row', alignItems: 'flex-end', gap: 8, backgroundColor: colors.paper, paddingHorizontal: 10, paddingVertical: 5, borderRadius: 19 },
  composerInput: { flex: 1, maxHeight: 110, minHeight: 42, color: colors.ink, fontSize: 14, paddingTop: 11, paddingBottom: 7 },
  sendButton: { width: 44, height: 44, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.ink },
  sendButtonDisabled: { opacity: 0.42 },
  sendGlyph: { color: colors.paper, fontSize: 23, fontWeight: '900' },
  composerFootnote: { color: colors.muted, fontSize: 8, textAlign: 'center', marginTop: 6, marginBottom: 2 },
  tabBar: { flexDirection: 'row', alignItems: 'stretch', justifyContent: 'space-around', minHeight: 58, backgroundColor: colors.card, borderTopWidth: 1, borderTopColor: colors.line, paddingHorizontal: 8, paddingTop: 5 },
  tabItem: { flex: 1, minHeight: 48, alignItems: 'center', justifyContent: 'flex-start', paddingHorizontal: 6 },
  tabIndicator: { width: 20, height: 2, borderRadius: 1, backgroundColor: 'transparent', marginBottom: 9 },
  tabIndicatorActive: { backgroundColor: colors.ink },
  tabLabel: { color: colors.muted, fontSize: 12, fontWeight: '500' },
  tabLabelActive: { color: colors.ink, fontWeight: '700' },
});
