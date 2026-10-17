import { useEffect } from 'react';
import { Pressable, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import Animated, { useAnimatedStyle, useReducedMotion, useSharedValue, withRepeat, withSequence, withTiming } from 'react-native-reanimated';
import { colors, radii, space } from './theme';

export function Tap({ children, onPress, style, accessibilityLabel, disabled = false, testID }: {
  children: React.ReactNode; onPress: () => void; style?: StyleProp<ViewStyle>; accessibilityLabel?: string; disabled?: boolean; testID?: string;
}) {
  return <Pressable
    testID={testID}
    accessibilityRole="button"
    accessibilityLabel={accessibilityLabel}
    disabled={disabled}
    onPress={onPress}
    style={({ pressed }) => [style, pressed && !disabled && styles.pressed, disabled && { opacity: 0.5 }]}
  >{children}</Pressable>;
}

export function Card({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function SectionTitle({ kicker, title, action }: { kicker?: string; title: string; action?: string }) {
  return <View style={styles.sectionHead}>
    <View>{kicker ? <Text style={styles.kicker}>{kicker}</Text> : null}<Text style={styles.sectionTitle}>{title}</Text></View>
    {action ? <Text style={styles.sectionAction}>{action}</Text> : null}
  </View>;
}

export function AnimatedFlame({ size = 36 }: { size?: number }) {
  const wobble = useSharedValue(0);
  const motion = useReducedMotion();
  useEffect(() => {
    if (motion) { wobble.value = 0; return; }
    wobble.value = withRepeat(withSequence(withTiming(1, { duration: 520 }), withTiming(-1, { duration: 700 }), withTiming(0, { duration: 420 })), -1, false);
  }, [motion, wobble]);
  const animated = useAnimatedStyle(() => ({
    transform: [{ rotate: `${wobble.value * 7}deg` }, { scale: 1 + Math.abs(wobble.value) * 0.06 }],
  }));
  return <Animated.View accessibilityLabel="Streak-Flamme" style={[animated, styles.flame, { width: size, height: size, borderRadius: size * 0.39 }]}>
    <Text style={{ fontSize: size * 0.72, lineHeight: size * 0.94 }}>🔥</Text>
  </Animated.View>;
}

export function AnimatedMeter({ value, color = colors.streak, height = 8 }: { value: number; color?: string; height?: number }) {
  const progress = useSharedValue(0);
  const motion = useReducedMotion();
  useEffect(() => {
    const target = Math.max(0, Math.min(1, value));
    progress.value = motion ? target : withTiming(target, { duration: 520 });
  }, [motion, progress, value]);
  const fill = useAnimatedStyle(() => ({ width: `${progress.value * 100}%` }));
  return <View accessibilityRole="progressbar" accessibilityValue={{ min: 0, max: 100, now: Math.round(value * 100) }} style={[styles.meter, { height }]}>
    <Animated.View style={[styles.meterFill, { backgroundColor: color }, fill]} />
  </View>;
}

export function WeekDots({ activeDays, todayId }: { activeDays: Set<string>; todayId: string }) {
  const today = new Date(`${todayId}T00:00:00.000Z`);
  const day = today.getUTCDay();
  const mondayOffset = (day + 6) % 7;
  const monday = new Date(today); monday.setUTCDate(today.getUTCDate() - mondayOffset);
  const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  return <View style={styles.weekRow}>{names.map((name, index) => {
    const date = new Date(monday); date.setUTCDate(monday.getUTCDate() + index);
    const key = date.toISOString().slice(0, 10);
    const active = activeDays.has(key); const isToday = key === todayId;
    return <View key={`${key}-${index}`} style={styles.weekItem}>
      <Text style={styles.weekName}>{name}</Text>
      <View style={[styles.weekDot, active && styles.weekDotActive, isToday && styles.weekDotToday]}>
        <Text style={[styles.weekCheck, active && { color: colors.card }]}>{active ? '✓' : isToday ? '·' : ''}</Text>
      </View>
    </View>;
  })}</View>;
}

export function FriendlyEmpty({ title, body, onRetry }: { title: string; body: string; onRetry?: () => void }) {
  return <Card style={styles.emptyCard}>
    <Text style={styles.emptyTitle}>{title}</Text>
    <Text style={styles.body}>{body}</Text>
    {onRetry ? <Tap onPress={onRetry} style={styles.retryButton}><Text style={styles.retryText}>Nochmal versuchen</Text></Tap> : null}
  </Card>;
}

export function PrimaryButton({ title, onPress, disabled = false, busy = false }: { title: string; onPress: () => void; disabled?: boolean; busy?: boolean }) {
  return <Tap onPress={onPress} disabled={disabled || busy} style={styles.primary}>
    <Text style={styles.primaryText}>{busy ? 'Einen Moment …' : title}</Text>
    {!busy ? <Text style={styles.primaryArrow}>↗</Text> : null}
  </Tap>;
}

export const ui = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.paper },
  scroll: { flexGrow: 1, alignItems: 'center', paddingHorizontal: 20, paddingTop: 14, paddingBottom: 44 },
  content: { width: '100%', maxWidth: 560 },
  row: { flexDirection: 'row', alignItems: 'center' },
  body: { color: colors.muted, fontSize: 14, lineHeight: 21 },
  ink: { color: colors.ink },
});

const styles = StyleSheet.create({
  card: { backgroundColor: colors.card, borderColor: colors.line, borderWidth: 1, borderRadius: radii.card, padding: space.xl },
  pressed: { opacity: 0.78 },
  sectionHead: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 14 },
  kicker: { color: colors.muted, fontSize: 11, fontWeight: '800', letterSpacing: 1.1, textTransform: 'uppercase', marginBottom: 4 },
  sectionTitle: { color: colors.ink, fontSize: 21, fontWeight: '800', letterSpacing: -0.5 },
  sectionAction: { color: colors.muted, fontSize: 12, fontWeight: '700' },
  flame: { backgroundColor: '#FCE3C5', alignItems: 'center', justifyContent: 'center' },
  meter: { width: '100%', borderRadius: 999, overflow: 'hidden', backgroundColor: 'rgba(30,29,34,0.1)' },
  meterFill: { height: '100%', borderRadius: 999 },
  weekRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 16 },
  weekItem: { alignItems: 'center', gap: 7 },
  weekName: { fontSize: 10, fontWeight: '700', color: colors.muted },
  weekDot: { width: 30, height: 30, borderRadius: 15, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.paper, borderWidth: 1, borderColor: colors.line },
  weekDotActive: { backgroundColor: colors.success, borderColor: colors.success },
  weekDotToday: { borderColor: colors.streak, borderWidth: 2 },
  weekCheck: { color: colors.muted, fontWeight: '900', fontSize: 13 },
  emptyCard: { alignItems: 'center', paddingVertical: 30, marginTop: 20 },
  emptyTitle: { color: colors.ink, fontSize: 17, fontWeight: '800', textAlign: 'center', marginBottom: 6 },
  body: { color: colors.muted, fontSize: 14, lineHeight: 21, textAlign: 'center' },
  retryButton: { marginTop: 18, minHeight: 48, borderRadius: 999, paddingHorizontal: 22, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center' },
  retryText: { color: colors.paper, fontWeight: '800', fontSize: 14 },
  primary: { minHeight: 54, borderRadius: 999, backgroundColor: colors.ink, paddingHorizontal: 22, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 12 },
  primaryText: { color: colors.paper, fontSize: 15, fontWeight: '800' },
  primaryArrow: { color: colors.paper, fontSize: 17, fontWeight: '800' },
});
