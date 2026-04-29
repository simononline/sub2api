import type { SubscriptionPlan } from '@/types/payment'

export const SUBSCRIPTION_PLAN_FILTERS = [
  {
    key: 'openai',
    label: 'OpenAI',
    keywords: ['codex'],
    activeFilterClass: 'border-emerald-300 bg-emerald-500/10 text-emerald-700 shadow-sm dark:border-emerald-500/40 dark:bg-emerald-500/15 dark:text-emerald-200',
  },
  {
    key: 'claude',
    label: 'Claude',
    keywords: ['claude'],
    activeFilterClass: 'border-orange-300 bg-orange-500/10 text-orange-700 shadow-sm dark:border-orange-500/40 dark:bg-orange-500/15 dark:text-orange-200',
  },
] as const

export type SubscriptionPlanFilterKey = typeof SUBSCRIPTION_PLAN_FILTERS[number]['key']

const DEFAULT_FILTER_META = {
  label: 'Other',
  activeFilterClass: 'border-gray-300 bg-gray-100 text-gray-900 shadow-sm dark:border-dark-500 dark:bg-dark-800 dark:text-white',
}

export function getSubscriptionPlanFilterMeta(key: string) {
  return SUBSCRIPTION_PLAN_FILTERS.find(filter => filter.key === key) || {
    key,
    keywords: [] as string[],
    ...DEFAULT_FILTER_META,
  }
}

export function subscriptionPlanMatchesFilter(
  plan: Pick<SubscriptionPlan, 'name'>,
  filterKey: SubscriptionPlanFilterKey,
): boolean {
  const filter = getSubscriptionPlanFilterMeta(filterKey)
  const normalizedName = plan.name.trim().toLowerCase()
  return filter.keywords.some(keyword => normalizedName.includes(keyword.toLowerCase()))
}
