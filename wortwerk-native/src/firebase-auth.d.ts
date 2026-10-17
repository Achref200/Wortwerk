export {};

declare module 'firebase/auth' {
  export { getReactNativePersistence } from '@firebase/auth';
}
