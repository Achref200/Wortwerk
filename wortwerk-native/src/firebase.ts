import AsyncStorage from '@react-native-async-storage/async-storage';
import { getApp, getApps, initializeApp } from 'firebase/app';
import {
  getAuth,
  getReactNativePersistence,
  initializeAuth,
  connectAuthEmulator,
} from 'firebase/auth';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import { connectFunctionsEmulator, getFunctions } from 'firebase/functions';
import { Platform } from 'react-native';

const useEmulators = process.env.EXPO_PUBLIC_USE_FIREBASE_EMULATORS !== 'false';
const projectId = process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID || 'demo-wortwerk-dev';

const config = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY || 'demo-api-key',
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN || `${projectId}.firebaseapp.com`,
  projectId,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET || `${projectId}.firebasestorage.app`,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_SENDER_ID || '1234567890',
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID || '1:1234567890:ios:wortwerk-expo',
};

export const firebaseApp = getApps().length ? getApp() : initializeApp(config);
export const auth = (() => {
  try {
    if (Platform.OS === 'web') return getAuth(firebaseApp);
    return initializeAuth(firebaseApp, {
      persistence: getReactNativePersistence(AsyncStorage),
    });
  } catch {
    return getAuth(firebaseApp);
  }
})();
export const db = getFirestore(firebaseApp);
export const functions = getFunctions(firebaseApp, 'europe-west1');

if (useEmulators) {
  const host = process.env.EXPO_PUBLIC_FIREBASE_EMULATOR_HOST ||
    (Platform.OS === 'android' ? '10.0.2.2' : '127.0.0.1');
  connectAuthEmulator(auth, `http://${host}:9099`, { disableWarnings: true });
  // The Emulator Suite host should be the machine running Firebase. A phone
  // running Expo Go must set EXPO_PUBLIC_FIREBASE_EMULATOR_HOST to its LAN IP.
  connectFirestoreEmulator(db, host, 8080);
  connectFunctionsEmulator(functions, host, 5001);
}

export const isUsingFirebaseEmulators = useEmulators;
