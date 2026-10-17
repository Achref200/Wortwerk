import { Stack } from 'expo-router';
import { useReducedMotion } from 'react-native-reanimated';

export default function RootLayout() {
  const reducedMotion = useReducedMotion();
  return <Stack screenOptions={{ headerShown: false, animation: reducedMotion ? 'none' : 'fade_from_bottom', gestureEnabled: true }} />;
}
