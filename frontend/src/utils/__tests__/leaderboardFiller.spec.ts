import { describe, expect, it } from 'vitest'
import type { UserSpendingRankingItem } from '@/types'
import {
  buildLeaderboardRows,
  getLeaderboardRequestLimit,
  LEADERBOARD_FAKE_ROWS,
  LEADERBOARD_FILL_TARGET,
} from '@/utils/leaderboardFiller'

function actualRow(overrides: Partial<UserSpendingRankingItem> = {}): UserSpendingRankingItem {
  return {
    user_id: 1,
    email: 'real@example.com',
    actual_cost: 100,
    requests: 1000,
    tokens: 10000,
    ...overrides,
  }
}

describe('leaderboardFiller', () => {
  it('does not show fake rows on the first day of each month', () => {
    const rows = buildLeaderboardRows([], 20, new Date('2026-05-01T12:00:00'))

    expect(rows).toEqual([])
  })

  it('shows only the fixed partial fake set on the second day', () => {
    const rows = buildLeaderboardRows([], 20, new Date('2026-05-02T12:00:00'))

    expect(rows).toHaveLength(10)
    expect(rows).toEqual(LEADERBOARD_FAKE_ROWS.slice(0, 10))
  })

  it('fills to 20 with all fixed fake rows from the third day onward', () => {
    const rows = buildLeaderboardRows(
      [actualRow({ actual_cost: 30, requests: 900 })],
      20,
      new Date('2026-05-03T12:00:00')
    )

    expect(rows).toHaveLength(LEADERBOARD_FILL_TARGET)
    expect(rows.some((row) => row.user_id === 1)).toBe(true)
    expect(rows.map((row) => row.actual_cost)).toEqual(
      [...rows].map((row) => row.actual_cost).sort((a, b) => b - a)
    )
  })

  it('does not add fake rows when real rows already reach 20', () => {
    const actualRows = Array.from({ length: 20 }, (_, index) => actualRow({
      user_id: index + 1,
      email: `real-${index + 1}@example.com`,
      actual_cost: index + 1,
    }))

    const rows = buildLeaderboardRows(actualRows, 50, new Date('2026-05-03T12:00:00'))

    expect(rows).toHaveLength(20)
    expect(rows.every((row) => row.user_id > 0)).toBe(true)
  })

  it('requests at least 20 rows so the frontend can decide whether to fill', () => {
    expect(getLeaderboardRequestLimit(10)).toBe(20)
    expect(getLeaderboardRequestLimit(50)).toBe(50)
  })
})
