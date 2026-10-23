import { Text, View, StyleSheet, StyleProp, ViewStyle, ActivityIndicator, SafeAreaView, ScrollView as RNScrollView } from 'react-native';
import { useSharedValue, useAnimatedStyle } from 'react-native-reanimated';
import { colors, radii, space, motionMs, type LevelId } from './theme';

export const Card = ({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) => {
  return <View style={[styles.card, style]}>{children}</View>;
};

export function AnimatedFlame({ size = 64 }: { size?: number }) {
  return <View style={[styles.card, { width: size, height: size, borderRadius: size / 2 }]} />;
}

export function SectionTitle({
  kicker,
  title,
  action,
  accent,
  textColor = colors.ink,
  actionColor = colors.inkSoft,
}: {
  kicker?: string;
  title: string;
  action?: string;
  accent?: string;
  textColor?: string;
  actionColor?: string;
}) {
  return (
    <View style={styles.sectionHead}>
      <View>
        {kicker ? (
          <Text style={[styles.kicker, accent && { color: accent }]}>{kicker}</Text>
        ) : null}
        <Text style={[styles.sectionTitle, { color: textColor }]}>{title}</Text>
      </View>
      {action ? (
        <Text style={[styles.sectionAction, { color: actionColor }]}>{action}</Text>
      ) : null}
    </View>
  );
}

export function AnimatedMeter({
  value,
  color = colors.accent,
  height = 8,
}: {
  value: number;
  color?: string;
  height?: number;
}) {
  return (
    <View
      accessibilityRole="progressbar"
      accessibilityValue={{ min: 0, max: 1, now: Math.round(value * 100) }}
      style={[styles.meter, { height, backgroundColor: colors.card, borderRadius: height / 2 }]}
    >
      <Animated.View
        style={{
          width: `${Math.max(0, Math.min(1, value)) * 100}%`,
          backgroundColor: color,
          transform: [{ scaleX: 1 }],
          borderRadius: height / 2,
        }}
      />
    </View>
  );
}

export function WeekDots({ activeDays, todayId }: { activeDays: Set<string>; todayId: string }) {
  return (
    <View style={styles.weekDots}>
      {[0, 1, 2, 3, 4].map((dayOffset, index) => {
        const label = `${index + 1}`;
        const isActive = activeDays.has(label);
        const isToday = label === todayId;
        return (
          <View key={label} style={[styles.weekDot, isActive && styles.weekDotActive, isToday && styles.weekDotToday]}>
            {isActive && <View style={styles.weekDotInner} />}
          </View>
        );
      })}
    </View>
  );
}

export function FriendlyEmpty({ title, body, onRetry }: { title: string; body?: string; onRetry?: () => void }) {
  return (
    <View style={styles.empty}>
      <Text style={styles.emptyTitle}>{title}</Text>
      {body ? <Text style={styles.emptyBody}>{body}</Text> : null}
      {onRetry ? <ActivityIndicator style={styles.emptySpinner} size="small" color={colors.streak} /> : null}
    </View>
  );
}

export const AppBar = ({ title, subtitle, action }: { title?: string; subtitle?: string; action?: string }) => (
  <View style={styles.appBar}>
    {title ? <Text style={styles.appBarTitle}>{title}</Text> : null}
    {subtitle ? <Text style={styles.appBarSubtitle}>{subtitle}</Text> : null}
    {action ? <Text style={styles.appBarAction}>{action}</Text> : null}
  </View>
);

export interface PrimaryButtonProps {
  title: string;
  onPress: () => void;
  disabled?: boolean;
  busy?: boolean;
}
export const PrimaryButton = ({ title, onPress, disabled, busy }: PrimaryButtonProps) => (
  <View style={[styles.primaryButton, disabled && styles.primaryButtonDisabled]} pointerEvents={busy || disabled ? 'none' : 'auto'}>
    {busy ? <ActivityIndicator size="small" color={colors.paper} /> : <Text style={styles.primaryButtonText}>{title}</Text>}
  </View>
);

export interface TapProps {
  children: React.ReactNode;
  onPress?: () => void;
  disabled?: boolean;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}
export const Tap = ({ children, onPress, disabled, accessibilityLabel, style }: TapProps) => {
  return (
    <View
      style={[styles.tap, disabled && styles.tapDisabled, style]}
      accessible={accessibilityLabel != null}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? undefined}
      pointerEvents={onPress ? 'auto' : 'none'}
    >
      {children}
    </View>
  );
};

export function MascotBubble({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.mascotBubble, style]}>{children}</View>;
}

export function Pingo({ value, max, label }: { value: number; max: number; label?: string }) {
  return (
    <View style={styles.pingo}>
      <Text style={styles.pingoLabel}>{label ?? 'Pingo'}</Text>
      <View style={styles.pingoMeter}>
        <View style={[styles.pingoFill, { width: `${Math.max(0, Math.min(1, value / max)) * 100}%` }]} />
      </View>
    </View>
  );
}

export function useSnackbar() {
  return { visible: false, message: '', variant: 'info' as const };
}

export function BottomNav({ active, onChange }: { active: string; onChange: (route: string) => void }) {
  return (
    <View style={styles.bottomNav}>
      {(['home', 'path', 'groups', 'profile'] as const).map((route) => (
        <View key={route} style={[styles.tabItem, active === route && styles.tabItemActive]}>
          <Text style={[styles.tabLabel, active === route && styles.tabLabelActive]}>{route}</Text>
        </View>
      ))}
    </View>
  );
}

export const ui = {
  screen: { flex: 1, backgroundColor: colors.background },
  scroll: { flexGrow: 1 },
  row: { flexDirection: 'row', alignItems: 'center' },
};

export const Chip = ({ label, active, onPress }: { label: string; active?: boolean; onPress?: () => void }) => (
  <View style={[styles.chip, active && styles.chipActive]} onTouchEnd={onPress}>
    <Text style={[styles.chipText, active && styles.chipTextActive]}>{label}</Text>
  </View>
);

export function LevelBadge({ level }: { level: LevelId }) {
  return <View style={[styles.levelBadge, { backgroundColor: colors.levels[level] }]}><Text style={styles.levelBadgeText}>{level}</Text></View>;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.line,
    borderWidth: 1,
    borderRadius: radii.card,
    padding: 16,
  },
  sectionHead: { marginBottom: 12 },
  kicker: { color: colors.muted, fontSize: 10, fontWeight: '700', letterSpacing: 1.1, textTransform: 'uppercase' },
  sectionTitle: { color: colors.ink, fontSize: 16, fontWeight: '700', marginTop: 2 },
  sectionAction: { color: colors.accent, fontSize: 12, fontWeight: '700', textAlign: 'right', marginTop: 2 },
  meter: { width: '100%', height: 8, backgroundColor: colors.card, borderRadius: 4 },
  weekDots: { flexDirection: 'row', gap: 6, marginTop: 8 },
  weekDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.line },
  weekDotActive: { backgroundColor: colors.streak },
  weekDotToday: { backgroundColor: colors.ink },
  weekDotInner: { width: 4, height: 4, borderRadius: 2, backgroundColor: colors.paper },
  empty: { padding: 24, alignItems: 'center' },
  emptyTitle: { color: colors.ink, fontSize: 14, fontWeight: '700' },
  emptyBody: { color: colors.muted, fontSize: 12, textAlign: 'center', marginTop: 6 },
  emptySpinner: { marginTop: 12 },
  appBar: { paddingHorizontal: 16, paddingTop: 8, paddingBottom: 8 },
  appBarTitle: { color: colors.ink, fontSize: 20, fontWeight: '700' },
  appBarSubtitle: { color: colors.muted, fontSize: 12, marginTop: 2 },
  appBarAction: { color: colors.accent, fontSize: 12, textAlign: 'right' },
  primaryButton: { backgroundColor: colors.ink, borderRadius: radii.card, padding: 12, alignItems: 'center' },
  primaryButtonDisabled: { opacity: 0.5 },
  primaryButtonText: { color: colors.paper, fontSize: 14, fontWeight: '700' },
  tap: { padding: 12, borderRadius: radii.card, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line },
  tapDisabled: { opacity: 0.5 },
  mascotBubble: { backgroundColor: colors.surface, borderRadius: 16, padding: 12 },
  pingo: { padding: 12, backgroundColor: colors.surface, borderRadius: radii.card },
  pingoLabel: { color: colors.ink, fontSize: 12, fontWeight: '700', marginBottom: 8 },
  pingoMeter: { height: 6, backgroundColor: colors.card, borderRadius: 3, overflow: 'hidden' },
  pingoFill: { height: '100%', backgroundColor: colors.streak },
  bottomNav: { flexDirection: 'row', borderTopWidth: 1, borderTopColor: colors.line, backgroundColor: colors.surface, paddingTop: 8 },
  tabItem: { flex: 1, alignItems: 'center', paddingVertical: 8, borderBottomWidth: 2, borderBottomColor: 'transparent' },
  tabItemActive: { borderBottomColor: colors.ink },
  tabLabel: { color: colors.muted, fontSize: 10, fontWeight: '700' },
  tabLabelActive: { color: colors.ink },
  chip: { backgroundColor: colors.surface, borderRadius: radii.pill, paddingHorizontal: 12, paddingVertical: 6, borderWidth: 1, borderColor: colors.line },
  chipActive: { backgroundColor: colors.ink, borderColor: colors.ink },
  chipText: { color: colors.ink, fontSize: 12, fontWeight: '700' },
  chipTextActive: { color: colors.paper },
  levelBadge: { borderRadius: 4, paddingHorizontal: 8, paddingVertical: 2, alignItems: 'center' },
  levelBadgeText: { color: colors.paper, fontSize: 10, fontWeight: '700' },
});
