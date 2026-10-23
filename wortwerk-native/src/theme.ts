/**
 * Pingo-inspired design system for Wortwerk Native.
 * Dark, clean, modern, insightful — with a friendly mascot accent.
 * iOS-leaning refinements: softer hairlines, warmer depth, glass edges,
 * and motion that feels quiet and inhabited rather than manufactured.
 */

// Pingo palette — deep dark base with soft gradient accents
export const colors = {
  // Backgrounds
  background: '#0B0B0F',   // deep near-black (soft violet-tinted)
  backgroundElevated: '#101016',
  backgroundSoft: '#0E0E14',
  surface: '#15151A',      // card surface
  surfaceLift: '#1B1B21',  // slightly lifted surface
  surfaceGlass: 'rgba(24, 24, 30, 0.78)',
  surfaceGlassStrong: 'rgba(28, 28, 34, 0.86)',

  // Warmth / depth (iOS-leaning subtle warmth on top of the cool base)
  warmth: 'rgba(255, 240, 228, 0.05)',
  warmthLine: 'rgba(255, 240, 228, 0.10)',

  // Text
  ink: '#FFFFFF',          // primary text
  inkSoft: '#D8D8E0',      // secondary text
  inkMuted: '#7A7A86',     // tertiary text
  streak: '#5BE89C',
  card: '#1B1B21',
  paper: '#FFFFFF',
  muted: '#7A7A86',

  // Borders & lines (softer hairlines, iOS-leaning)
  line: 'rgba(255, 255, 255, 0.10)',
  lineSoft: 'rgba(255, 255, 255, 0.05)',
  lineWarm: 'rgba(255, 245, 236, 0.12)',

  // Mascot / accent (Pingo-inspired soft gradients)
  mascot: '#B793E0',       // soft violet mascot

  mascotSoft: 'rgba(183, 147, 224, 0.18)',
  mascot2: '#66F0CC',      // soft mint partner
  mascotSoft2: 'rgba(102, 240, 204, 0.16)',
  accent: '#7F5AFE',       // vivid violet
  accentSoft: 'rgba(127, 90, 254, 0.18)',
  accentLine: 'rgba(127, 90, 254, 0.34)',
  accentWarm: 'rgba(255, 185, 140, 0.18)',

  // Gradients (used sparingly for depth, never as carpet)
  vignette: 'rgba(0,0,0,0.22)',

  // Grid/brushed texture
  gridLine: 'rgba(255, 255, 255, 0.045)',
  gridVertical: 'rgba(255, 255, 255, 0.028)',

  // Status colors
  success: '#5BE89C',
  successSoft: 'rgba(91, 232, 156, 0.16)',
  danger: '#FB7185',
  dangerSoft: 'rgba(251, 113, 133, 0.16)',
  warning: '#FBBF24',
  warningSoft: 'rgba(251, 191, 36, 0.16)',
  info: '#9AA7FF',
  infoSoft: 'rgba(154, 167, 255, 0.16)',


  levelThemes: {
    A1: { surface: '#1C3A34', accent: '#5BE89C', deep: '#0E2A24', label: 'Green · Arrive' },
    A2: { surface: '#2C2B4A', accent: '#9B7CF7', deep: '#1C1A36', label: 'Indigo · Daily' },
    B1: { surface: '#2A3A4C', accent: '#7BA7F7', deep: '#122232', label: 'Blue · Independent' },
    B2: { surface: '#3A4A2E', accent: '#9AA862', deep: '#202C18', label: 'Olive · Deepen' },
    C1: { surface: '#4C342E', accent: '#D08A6A', deep: '#2A1C18', label: 'Terracotta · Precision' },
    C2: { surface: '#4A4428', accent: '#C09A4E', deep: '#2E2614', label: 'Ochre · Mastery' },
  },
  levels: {
    A1: '#5BE89C', A2: '#9B7CF7', B1: '#7BA7F7',
    B2: '#9AA862', C1: '#D08A6A', C2: '#C09A4E',
  },

} as const;

// Legacy aliases kept for existing consumers that imported these from ../theme.
export const legacyColors = {
  streak: '#5BE89C',
  card: '#1B1B21',
  paper: '#FFFFFF',
  muted: '#7A7A86',
  ink: '#FFFFFF',
  mascot: '#B793E0',
} as const;


export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 36, hero: 52, nav: 78 } as const;
export const radii = { card: 22, sheet: 28, pill: 999, sm: 14, input: 16, grid: 16, avatar: 14 } as const;
export const motionMs = { quick: 160, standard: 300, reward: 560, soft: { short: 200, medium: 360, long: 520 } } as const;

export type LevelId = keyof typeof colors.levelThemes;
export type LevelTheme = (typeof colors.levelThemes)[LevelId];

export function levelTheme(level: LevelId): LevelTheme {
  return colors.levelThemes[level];
}
