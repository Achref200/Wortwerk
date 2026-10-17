export const colors = {
  paper: '#F4F7F3',
  card: '#FFFFFF',
  ink: '#182620',
  muted: '#65746D',
  line: 'rgba(24,38,32,0.11)',
  streak: '#A5CF67',
  success: '#3BA77A',
  danger: '#C64D4D',
  levels: {
    A1: '#D8F0E4',
    A2: '#E3DFFD',
    B1: '#DCEBFA',
    B2: '#E1EFCE',
    C1: '#F7E0D0',
    C2: '#F8EDC6',
  },
  levelThemes: {
    A1: { surface: '#E7F1EB', accent: '#6C9D82', deep: '#274C3C', label: 'Grün · Ankommen' },
    A2: { surface: '#ECEAF6', accent: '#8275B8', deep: '#403961', label: 'Indigo · Alltag' },
    B1: { surface: '#E7EFF6', accent: '#6F95B7', deep: '#29455F', label: 'Blau · Selbstständig' },
    B2: { surface: '#EDF1E4', accent: '#829A56', deep: '#43552E', label: 'Olive · Vertiefen' },
    C1: { surface: '#F5EBE5', accent: '#BD8062', deep: '#684435', label: 'Terrakotta · Präzision' },
    C2: { surface: '#F3EFDf', accent: '#AA8B42', deep: '#5E4C20', label: 'Ocker · Meisterschaft' },
  },
} as const;

export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, hero: 48 } as const;
export const radii = { card: 20, sheet: 26, pill: 999 } as const;
export const motionMs = { quick: 160, standard: 240, reward: 520 } as const;

export type LevelId = keyof typeof colors.levels;
export type LevelTheme = (typeof colors.levelThemes)[LevelId];

export function levelTheme(level: LevelId): LevelTheme {
  return colors.levelThemes[level];
}
