import { useEffect, useId } from 'react';
import Animated, { useAnimatedStyle, useReducedMotion, useSharedValue, withDelay, withRepeat, withSequence, withSpring, withTiming } from 'react-native-reanimated';
import Svg, { Circle, Defs, Ellipse, Path, RadialGradient, Stop } from 'react-native-svg';

export type FritzMood = 'idle' | 'happy' | 'thinking' | 'confused' | 'speaking' | 'listening' | 'encouraging' | 'celebrating';

/** Fritz is a soft glass-like study companion, with restrained motion and a calm palette. */
export function Fritz({ size = 56, mood = 'idle' }: { size?: number; mood?: FritzMood }) {
  const gradientId = `fritz-${useId().replace(/:/g, '')}`;
  const reducedMotion = useReducedMotion();
  const bob = useSharedValue(0);
  const blink = useSharedValue(1);
  const reaction = useSharedValue(1);
  useEffect(() => {
    bob.value = reducedMotion ? 0 : withRepeat(withSequence(withTiming(-2.2, { duration: 1800 }), withTiming(0, { duration: 1800 })), -1, false);
    blink.value = reducedMotion ? 1 : withRepeat(withSequence(withTiming(1, { duration: 2800 }), withTiming(0.08, { duration: 70 }), withTiming(1, { duration: 100 }), withDelay(3300, withTiming(1, { duration: 1 }))), -1, false);
  }, [blink, bob, reducedMotion]);
  useEffect(() => {
    reaction.value = reducedMotion ? 1 : withSpring(mood === 'celebrating' ? 1.07 : mood === 'confused' ? 0.985 : 1, { damping: 15, stiffness: 150 });
  }, [mood, reaction, reducedMotion]);
  const bodyStyle = useAnimatedStyle(() => ({ transform: [{ translateY: bob.value }, { scale: reaction.value }] }));
  const eyesStyle = useAnimatedStyle(() => ({ transform: [{ scaleY: blink.value }] }));
  const happy = mood === 'happy' || mood === 'celebrating' || mood === 'encouraging';
  const speaking = mood === 'speaking';

  return <Animated.View accessibilityRole="image" accessibilityLabel={`Fritz, ${moodLabel(mood)}`} style={[{ width: size, height: size }, bodyStyle]}>
    <Svg width={size} height={size} viewBox="0 0 100 100">
      <Defs><RadialGradient id={gradientId} cx="31%" cy="22%" r="83%"><Stop offset="0" stopColor="#FFFFFF"/><Stop offset="0.42" stopColor="#E8F7F0"/><Stop offset="0.78" stopColor="#B8E2D0"/><Stop offset="1" stopColor="#8ECBB2"/></RadialGradient></Defs>
      {mood === 'celebrating' ? <><Path d="M13 20l2.6 6.4L22 29l-6.4 2.6L13 38l-2.6-6.4L4 29l6.4-2.6z" fill="#B8D96F"/><Path d="M88 35l2 5 5 2-5 2-2 5-2-5-5-2 5-2z" fill="#A99BE8"/></> : null}
      <Ellipse cx="50" cy="86" rx="26" ry="5" fill="#345E50" opacity="0.1" />
      <Path d="M24 59q-12 0-12 10 0 6 8 6h9M76 59q12 0 12 10 0 6-8 6h-9" fill="none" stroke="#8ECBB2" strokeWidth="8" strokeLinecap="round" />
      <Path d="M35 80q-4 8 2 9h9M65 80q4 8-2 9h-9" fill="none" stroke="#9BD5BD" strokeWidth="7" strokeLinecap="round" />
      <Path d="M50 12c-22 0-37 17-37 39 0 21 15 36 37 36s37-15 37-36C87 29 72 12 50 12Z" fill={`url(#${gradientId})`} stroke="#5C9F83" strokeWidth="1.8" />
      <Ellipse cx="36" cy="29" rx="12" ry="7" transform="rotate(-38 36 29)" fill="#FFFFFF" opacity="0.72" />
      <Path d="M25 46c2-12 10-20 19-23" fill="none" stroke="#FFFFFF" strokeWidth="2" opacity="0.58" strokeLinecap="round" />
      <Circle cx="72" cy="59" r="9" fill="#D6F0E5" opacity="0.78" />
      {mood === 'thinking' ? <Circle cx="78" cy="33" r="3" fill="#A99BE8" /> : null}
      <AnimatedEyes style={eyesStyle} mood={mood} />
      {happy ? <Path d="M43 66q7 7 14 0" fill="none" stroke="#275544" strokeWidth="2.3" strokeLinecap="round" /> : speaking ? <Ellipse cx="50" cy="66" rx="3.4" ry="4.3" fill="#275544" /> : mood === 'confused' ? <Path d="M44 68q6-4 12 0" fill="none" stroke="#275544" strokeWidth="2" strokeLinecap="round" /> : <Path d="M44 66q6 4 12 0" fill="none" stroke="#275544" strokeWidth="1.8" strokeLinecap="round" />}
      <Ellipse cx="32" cy="63" rx="4.2" ry="2.3" fill="#E3A6A1" opacity="0.52" /><Ellipse cx="68" cy="63" rx="4.2" ry="2.3" fill="#E3A6A1" opacity="0.52" />
    </Svg>
  </Animated.View>;
}

function AnimatedEyes({ style, mood }: { style: ReturnType<typeof useAnimatedStyle>; mood: FritzMood }) {
  return <Animated.View style={[{ position: 'absolute', inset: 0 }, style]} pointerEvents="none">
    <Svg width="100%" height="100%" viewBox="0 0 100 100">
      {mood === 'listening' ? <><Ellipse cx="39" cy="53" rx="3.5" ry="5" fill="#1B332A"/><Ellipse cx="61" cy="53" rx="3.5" ry="5" fill="#1B332A"/></> : <><Circle cx="39" cy="53" r="3.5" fill="#1B332A"/><Circle cx="61" cy="53" r="3.5" fill="#1B332A"/></>}
    </Svg>
  </Animated.View>;
}

function moodLabel(mood: FritzMood) {
  const names: Record<FritzMood, string> = { idle: 'bereit zum Lernen', happy: 'freut sich mit dir', thinking: 'denkt nach', confused: 'überlegt mit dir', speaking: 'spricht', listening: 'hört dir zu', encouraging: 'macht dir Mut', celebrating: 'feiert deinen Erfolg' };
  return names[mood];
}
