import type { UserSpendingRankingItem } from '@/types'

export const LEADERBOARD_FILL_TARGET = 20

const LEADERBOARD_DAY_TWO_FAKE_COUNT = 10

export const LEADERBOARD_FAKE_ROWS: UserSpendingRankingItem[] = [
  { user_id: -1001, email: 'ch****ai@***.com', actual_cost: 68.42, requests: 942, tokens: 18_840_000 },
  { user_id: -1002, email: 'li****en@***.com', actual_cost: 61.35, requests: 887, tokens: 16_930_000 },
  { user_id: -1003, email: 'mo****xi@***.com', actual_cost: 55.86, requests: 816, tokens: 15_410_000 },
  { user_id: -1004, email: 'su****ng@***.com', actual_cost: 49.73, requests: 754, tokens: 13_980_000 },
  { user_id: -1005, email: 'yu****ao@***.com', actual_cost: 44.29, requests: 698, tokens: 12_760_000 },
  { user_id: -1006, email: 'ha****uo@***.com', actual_cost: 39.64, requests: 641, tokens: 11_620_000 },
  { user_id: -1007, email: 'ze****in@***.com', actual_cost: 35.18, requests: 603, tokens: 10_870_000 },
  { user_id: -1008, email: 'qi****an@***.com', actual_cost: 31.92, requests: 557, tokens: 9_940_000 },
  { user_id: -1009, email: 'ka****un@***.com', actual_cost: 28.57, requests: 519, tokens: 9_180_000 },
  { user_id: -1010, email: 'mi****er@***.com', actual_cost: 25.41, requests: 481, tokens: 8_530_000 },
  { user_id: -1011, email: 'no****va@***.com', actual_cost: 22.74, requests: 446, tokens: 7_960_000 },
  { user_id: -1012, email: 'ra****in@***.com', actual_cost: 20.33, requests: 412, tokens: 7_340_000 },
  { user_id: -1013, email: 'ta****ng@***.com', actual_cost: 18.26, requests: 389, tokens: 6_890_000 },
  { user_id: -1014, email: 'ev****ee@***.com', actual_cost: 16.47, requests: 351, tokens: 6_260_000 },
  { user_id: -1015, email: 'jo****ia@***.com', actual_cost: 14.93, requests: 327, tokens: 5_810_000 },
  { user_id: -1016, email: 'an****ol@***.com', actual_cost: 13.58, requests: 304, tokens: 5_320_000 },
  { user_id: -1017, email: 'vi****or@***.com', actual_cost: 12.36, requests: 281, tokens: 4_960_000 },
  { user_id: -1018, email: 'pe****al@***.com', actual_cost: 11.14, requests: 263, tokens: 4_520_000 },
  { user_id: -1019, email: 'os****ir@***.com', actual_cost: 10.06, requests: 244, tokens: 4_130_000 },
  { user_id: -1020, email: 'lu****me@***.com', actual_cost: 9.18, requests: 229, tokens: 3_780_000 },
]

export function getLeaderboardRequestLimit(displayLimit: number): number {
  return Math.max(normalizeDisplayLimit(displayLimit), LEADERBOARD_FILL_TARGET)
}

export function buildLeaderboardRows(
  actualRows: UserSpendingRankingItem[],
  displayLimit: number,
  currentDate = new Date()
): UserSpendingRankingItem[] {
  const safeActualRows = Array.isArray(actualRows) ? actualRows : []
  const missingCount = Math.max(0, LEADERBOARD_FILL_TARGET - safeActualRows.length)
  const fakeRows = missingCount > 0
    ? getAvailableFakeRows(currentDate).slice(0, missingCount)
    : []

  return [...safeActualRows, ...fakeRows]
    .sort(compareRankingRows)
    .slice(0, normalizeDisplayLimit(displayLimit))
}

function getAvailableFakeRows(currentDate: Date): UserSpendingRankingItem[] {
  const dayOfMonth = currentDate.getDate()
  if (dayOfMonth <= 1) return []
  if (dayOfMonth === 2) return LEADERBOARD_FAKE_ROWS.slice(0, LEADERBOARD_DAY_TWO_FAKE_COUNT)
  return LEADERBOARD_FAKE_ROWS
}

function compareRankingRows(a: UserSpendingRankingItem, b: UserSpendingRankingItem): number {
  return b.actual_cost - a.actual_cost || b.requests - a.requests || b.tokens - a.tokens
}

function normalizeDisplayLimit(displayLimit: number): number {
  if (!Number.isFinite(displayLimit)) return LEADERBOARD_FILL_TARGET
  return Math.max(1, Math.trunc(displayLimit))
}
