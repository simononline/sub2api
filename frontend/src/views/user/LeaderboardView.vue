<template>
  <AppLayout>
    <div class="space-y-6">
      <section class="overflow-hidden rounded-lg border border-gray-200 bg-white dark:border-dark-800 dark:bg-dark-900/90">
        <div class="flex flex-col gap-5 border-b border-gray-100 px-6 py-5 dark:border-dark-800 lg:flex-row lg:items-start lg:justify-between">
          <div class="min-w-0">
            <div class="mb-3 inline-flex items-center gap-2 rounded-full border border-blue-200 bg-blue-50 px-3 py-1 text-xs font-medium text-blue-700 dark:border-blue-500/30 dark:bg-blue-500/10 dark:text-blue-300">
              <Icon name="trendingUp" size="sm" />
              <span>{{ t('leaderboard.badge') }}</span>
            </div>
            <h2 class="text-2xl font-semibold text-gray-950 dark:text-dark-50">
              {{ t('leaderboard.title') }}
            </h2>
            <p class="mt-2 max-w-3xl text-sm leading-6 text-gray-600 dark:text-dark-300">
              {{ viewerHint }}
            </p>
          </div>

          <form class="flex w-full flex-col gap-3 lg:w-auto" @submit.prevent="loadRanking">
            <div class="grid grid-cols-1 gap-3 sm:grid-cols-[minmax(0,150px)_minmax(0,150px)_minmax(0,110px)_auto] sm:items-end">
              <label class="block">
                <span class="mb-1.5 block text-xs font-medium text-gray-500 dark:text-dark-300">{{ t('leaderboard.startDate') }}</span>
                <input v-model="startDate" type="date" class="input h-10" />
              </label>
              <label class="block">
                <span class="mb-1.5 block text-xs font-medium text-gray-500 dark:text-dark-300">{{ t('leaderboard.endDate') }}</span>
                <input v-model="endDate" type="date" class="input h-10" />
              </label>
              <label class="block">
                <span class="mb-1.5 block text-xs font-medium text-gray-500 dark:text-dark-300">{{ t('leaderboard.limit') }}</span>
                <select v-model.number="limit" class="input h-10">
                  <option :value="10">10</option>
                  <option :value="20">20</option>
                  <option :value="50">50</option>
                </select>
              </label>
              <button type="submit" class="btn btn-primary h-10" :disabled="loading">
                <Icon name="refresh" size="sm" :class="{ 'animate-spin': loading }" />
                <span>{{ t('common.refresh', 'Refresh') }}</span>
              </button>
            </div>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="preset in presets"
                :key="preset.days"
                type="button"
                class="btn btn-secondary btn-sm"
                @click="applyPreset(preset.days)"
              >
                {{ preset.label }}
              </button>
            </div>
          </form>
        </div>
      </section>

      <div class="grid grid-cols-1 gap-4" :class="hasActiveSubscriptions ? 'lg:grid-cols-3' : 'lg:grid-cols-1'">
        <div class="stat-card">
          <div class="stat-icon stat-icon-success">
            <Icon name="creditCard" size="lg" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-gray-500 dark:text-dark-400">{{ t('leaderboard.accountBalance') }}</p>
            <p class="truncate text-2xl font-normal text-gray-950 dark:text-dark-50">{{ formatCurrency(userBalance) }}</p>
            <p class="mt-1 truncate text-xs text-gray-500 dark:text-dark-400">{{ user?.email || t('leaderboard.currentAccount') }}</p>
          </div>
        </div>

        <div v-if="hasActiveSubscriptions" class="stat-card">
          <div class="stat-icon stat-icon-primary">
            <Icon name="badge" size="lg" />
          </div>
          <div class="min-w-0 flex-1">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-xs font-medium text-gray-500 dark:text-dark-400">{{ t('leaderboard.currentPackage') }}</p>
                <p class="truncate text-2xl font-normal text-gray-950 dark:text-dark-50">{{ packageSummary }}</p>
              </div>
              <router-link to="/subscriptions" class="btn btn-secondary btn-sm shrink-0">
                <Icon name="creditCard" size="sm" />
                <span>{{ t('nav.mySubscriptions') }}</span>
              </router-link>
            </div>
            <div class="mt-2 flex flex-wrap gap-2">
              <span
                v-for="subscription in displayedSubscriptions.slice(0, 3)"
                :key="subscription.id"
                class="inline-flex max-w-full items-center gap-1.5 rounded-md border border-gray-200 bg-gray-50 px-2 py-1 text-xs text-gray-700 dark:border-dark-700 dark:bg-dark-950 dark:text-dark-200"
              >
                <span class="h-1.5 w-1.5 shrink-0 rounded-full bg-emerald-500"></span>
                <span class="truncate">{{ packageName(subscription) }}</span>
              </span>
              <span
                v-if="activeSubscriptions.length > 3"
                class="inline-flex items-center rounded-md border border-gray-200 bg-gray-50 px-2 py-1 text-xs text-gray-500 dark:border-dark-700 dark:bg-dark-950 dark:text-dark-400"
              >
                {{ t('leaderboard.morePackages', { count: activeSubscriptions.length - 3 }) }}
              </span>
            </div>
          </div>
        </div>

        <div v-if="hasActiveSubscriptions" class="stat-card">
          <div class="stat-icon stat-icon-warning">
            <Icon name="clock" size="lg" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-gray-500 dark:text-dark-400">{{ t('leaderboard.packageCountdown') }}</p>
            <p class="truncate text-2xl font-normal tabular-nums text-gray-950 dark:text-dark-50">{{ primaryCountdownText }}</p>
            <p class="mt-1 truncate text-xs text-gray-500 dark:text-dark-400">{{ primaryCountdownHint }}</p>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div class="stat-card">
          <div class="stat-icon stat-icon-primary">
            <Icon name="dollar" size="lg" />
          </div>
          <div class="min-w-0 flex-1">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-xs font-medium text-gray-500 dark:text-dark-400">{{ t('leaderboard.totalSpend') }}</p>
                <p class="truncate text-2xl font-normal text-gray-950 dark:text-dark-50">{{ formatCurrency(summary.totalSpend) }}</p>
              </div>
              <router-link to="/usage" class="btn btn-secondary btn-sm shrink-0">
                <Icon name="chart" size="sm" />
                <span>{{ t('nav.usage') }}</span>
              </router-link>
            </div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon stat-icon-success">
            <Icon name="chart" size="lg" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-gray-500 dark:text-dark-400">{{ t('leaderboard.totalRequests') }}</p>
            <p class="truncate text-2xl font-normal text-gray-950 dark:text-dark-50">{{ formatNumber(summary.totalRequests) }}</p>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon stat-icon-warning">
            <Icon name="database" size="lg" />
          </div>
          <div class="min-w-0">
            <p class="text-xs font-medium text-gray-500 dark:text-dark-400">{{ t('leaderboard.totalTokens') }}</p>
            <p class="truncate text-2xl font-normal text-gray-950 dark:text-dark-50">{{ formatNumber(summary.totalTokens) }}</p>
          </div>
        </div>
      </div>

      <section class="card overflow-hidden">
        <div class="card-header flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h3 class="text-lg font-semibold text-gray-950 dark:text-dark-50">
              {{ t('leaderboard.listTitle') }}
            </h3>
            <p class="mt-1 text-sm text-gray-500 dark:text-dark-400">
              {{ rangeLabel }}
            </p>
          </div>
          <span
            class="badge"
            :class="isMasked ? 'badge-warning' : 'badge-success'"
          >
            {{ isMasked ? t('leaderboard.maskedAccounts') : t('leaderboard.realAccounts') }}
          </span>
        </div>

        <div v-if="loading" class="flex items-center justify-center py-14">
          <LoadingSpinner />
        </div>

        <template v-else-if="rows.length">
          <div class="hidden overflow-x-auto md:block">
            <table class="w-full min-w-[800px] table-fixed text-sm">
              <colgroup>
                <col class="w-16" />
                <col class="w-56" />
                <col />
                <col class="w-28" />
                <col class="w-32" />
              </colgroup>
              <thead class="bg-gray-50 dark:bg-dark-950">
                <tr>
                  <th class="border-b border-gray-200 py-3 pl-4 pr-1 text-left text-xs font-medium text-gray-500 dark:border-dark-800 dark:text-dark-400">{{ t('leaderboard.columns.rank') }}</th>
                  <th class="border-b border-gray-200 py-3 pl-1 pr-3 text-left text-xs font-medium text-gray-500 dark:border-dark-800 dark:text-dark-400">{{ t('leaderboard.columns.account') }}</th>
                  <th class="border-b border-gray-200 px-3 py-3 text-left text-xs font-medium text-gray-500 dark:border-dark-800 dark:text-dark-400">{{ t('leaderboard.columns.spend') }}</th>
                  <th class="border-b border-gray-200 px-3 py-3 text-left text-xs font-medium text-gray-500 dark:border-dark-800 dark:text-dark-400">{{ t('leaderboard.columns.requests') }}</th>
                  <th class="border-b border-gray-200 py-3 pl-3 pr-4 text-left text-xs font-medium text-gray-500 dark:border-dark-800 dark:text-dark-400">{{ t('leaderboard.columns.tokens') }}</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100 dark:divide-dark-800">
                <tr v-for="(item, index) in rows" :key="`${index}-${item.email}`" class="transition-colors hover:bg-gray-50 dark:hover:bg-dark-800/50">
                  <td class="py-4 pl-4 pr-1">
                    <span :class="rankBadgeClass(index)">
                      #{{ index + 1 }}
                    </span>
                  </td>
                  <td class="py-4 pl-1 pr-3">
                    <div class="flex min-w-0 items-center gap-3">
                      <div class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg border border-gray-200 bg-gray-50 text-sm font-semibold text-gray-700 dark:border-dark-700 dark:bg-dark-950 dark:text-dark-100">
                        {{ accountInitial(item.email) }}
                      </div>
                      <div class="min-w-0">
                        <div class="truncate font-medium text-gray-950 dark:text-dark-50">
                          {{ item.email || '-' }}
                        </div>
                        <div v-if="!isMasked" class="mt-0.5 text-xs text-gray-500 dark:text-dark-400">
                          {{ t('leaderboard.accountRealHint') }}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td class="px-3 py-4">
                    <div class="min-w-0">
                      <div class="font-medium text-gray-950 dark:text-dark-50">
                        {{ formatCurrency(item.actual_cost) }}
                      </div>
                      <div class="mt-2 h-1.5 overflow-hidden rounded-full bg-gray-100 dark:bg-dark-800">
                        <div class="h-full rounded-full bg-primary-500" :style="{ width: progressWidth(item.actual_cost) }"></div>
                      </div>
                    </div>
                  </td>
                  <td class="px-3 py-4 text-gray-700 dark:text-dark-200">{{ formatNumber(item.requests) }}</td>
                  <td class="py-4 pl-3 pr-4 text-gray-700 dark:text-dark-200">{{ formatNumber(item.tokens) }}</td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="space-y-3 p-4 md:hidden">
            <div
              v-for="(item, index) in rows"
              :key="`mobile-${index}-${item.email}`"
              class="rounded-lg border border-gray-200 bg-white p-4 dark:border-dark-700 dark:bg-dark-900"
            >
              <div class="mb-4 flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <span :class="rankBadgeClass(index)">#{{ index + 1 }}</span>
                  <div class="mt-3 truncate font-medium text-gray-950 dark:text-dark-50">
                    {{ item.email || '-' }}
                  </div>
                </div>
                <div class="text-right text-sm font-semibold text-gray-950 dark:text-dark-50">
                  {{ formatCurrency(item.actual_cost) }}
                </div>
              </div>
              <div class="grid grid-cols-2 gap-3 text-sm">
                <div>
                  <div class="text-xs text-gray-500 dark:text-dark-400">{{ t('leaderboard.columns.requests') }}</div>
                  <div class="mt-1 font-medium text-gray-900 dark:text-dark-100">{{ formatNumber(item.requests) }}</div>
                </div>
                <div>
                  <div class="text-xs text-gray-500 dark:text-dark-400">{{ t('leaderboard.columns.tokens') }}</div>
                  <div class="mt-1 font-medium text-gray-900 dark:text-dark-100">{{ formatNumber(item.tokens) }}</div>
                </div>
              </div>
              <div class="mt-4 h-1.5 overflow-hidden rounded-full bg-gray-100 dark:bg-dark-800">
                <div class="h-full rounded-full bg-primary-500" :style="{ width: progressWidth(item.actual_cost) }"></div>
              </div>
            </div>
          </div>
        </template>

        <div v-else class="flex flex-col items-center justify-center px-6 py-14 text-center">
          <Icon name="inbox" size="xl" class="mb-4 text-gray-400 dark:text-dark-500" />
          <p class="text-base font-medium text-gray-950 dark:text-dark-50">
            {{ t('leaderboard.emptyTitle') }}
          </p>
          <p class="mt-2 max-w-md text-sm text-gray-500 dark:text-dark-400">
            {{ t('leaderboard.emptyDescription') }}
          </p>
        </div>
      </section>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppLayout from '@/components/layout/AppLayout.vue'
import Icon from '@/components/icons/Icon.vue'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'
import { usageAPI } from '@/api/usage'
import type { UserSpendingRankingItem, UserSpendingRankingResponse, UserSubscription } from '@/types'
import { useAppStore } from '@/stores/app'
import { useAuthStore } from '@/stores/auth'
import { useSubscriptionStore } from '@/stores/subscriptions'
import { extractApiErrorMessage } from '@/utils/apiError'
import { formatCurrency, formatDateOnly, formatNumber } from '@/utils/format'

const { t } = useI18n()
const appStore = useAppStore()
const authStore = useAuthStore()
const subscriptionStore = useSubscriptionStore()

const loading = ref(false)
const ranking = ref<UserSpendingRankingResponse | null>(null)
const limit = ref(20)
const nowTick = ref(Date.now())
let countdownTimer: ReturnType<typeof setInterval> | null = null

function formatDateInput(date: Date): string {
  return date.toISOString().slice(0, 10)
}

function daysAgo(days: number): string {
  const date = new Date()
  date.setDate(date.getDate() - days)
  return formatDateInput(date)
}

const startDate = ref(daysAgo(6))
const endDate = ref(formatDateInput(new Date()))

const presets = computed(() => [
  { days: 6, label: t('leaderboard.presets.sevenDays') },
  { days: 29, label: t('leaderboard.presets.thirtyDays') },
  { days: 89, label: t('leaderboard.presets.ninetyDays') },
])

const rows = computed<UserSpendingRankingItem[]>(() => ranking.value?.ranking || [])
const isMasked = computed(() => ranking.value?.masked_accounts ?? !authStore.isAdmin)
const viewerHint = computed(() => isMasked.value ? t('leaderboard.descriptionMasked') : t('leaderboard.descriptionAdmin'))
const user = computed(() => authStore.user)
const userBalance = computed(() => user.value?.balance ?? 0)
const activeSubscriptions = computed(() => subscriptionStore.activeSubscriptions.filter((subscription) => subscription.status === 'active'))
const hasActiveSubscriptions = computed(() => activeSubscriptions.value.length > 0)
const displayedSubscriptions = computed(() => [...activeSubscriptions.value].sort(compareSubscriptionExpiry))
const primarySubscription = computed(() => {
  return displayedSubscriptions.value.find((subscription) => subscription.expires_at) || displayedSubscriptions.value[0] || null
})
const packageSummary = computed(() => {
  if (activeSubscriptions.value.length === 1) return packageName(activeSubscriptions.value[0])
  return t('leaderboard.activePackageCount', { count: activeSubscriptions.value.length })
})
const primaryCountdownText = computed(() => {
  const subscription = primarySubscription.value
  if (!subscription) return t('leaderboard.noActivePackage')
  if (!subscription.expires_at) return t('leaderboard.noExpiration')
  return formatCountdown(subscription.expires_at)
})
const primaryCountdownHint = computed(() => {
  const subscription = primarySubscription.value
  if (!subscription) return t('leaderboard.noActivePackageHint')
  if (!subscription.expires_at) return packageName(subscription)
  return t('leaderboard.expiresOn', {
    plan: packageName(subscription),
    date: formatDateOnly(subscription.expires_at),
  })
})

const summary = computed(() => ({
  totalSpend: ranking.value?.total_actual_cost || 0,
  totalRequests: ranking.value?.total_requests || 0,
  totalTokens: ranking.value?.total_tokens || 0,
}))

const rangeLabel = computed(() => {
  const start = ranking.value?.start_date || startDate.value
  const end = ranking.value?.end_date || endDate.value
  return t('leaderboard.rangeLabel', { start, end, limit: limit.value })
})

const maxCost = computed(() => Math.max(...rows.value.map((row) => row.actual_cost), 0))

function applyPreset(days: number) {
  startDate.value = daysAgo(days)
  endDate.value = formatDateInput(new Date())
  void loadRanking()
}

async function loadRanking() {
  if (startDate.value && endDate.value && startDate.value > endDate.value) {
    appStore.showError(t('leaderboard.invalidRange'))
    return
  }

  loading.value = true
  try {
    ranking.value = await usageAPI.getDashboardUsersRanking({
      start_date: startDate.value,
      end_date: endDate.value,
      limit: limit.value,
    })
  } catch (err: unknown) {
    appStore.showError(extractApiErrorMessage(err, t('leaderboard.loadError')))
    ranking.value = null
  } finally {
    loading.value = false
  }
}

function rankBadgeClass(index: number): string {
  const base = 'inline-flex h-8 min-w-8 items-center justify-center rounded-full border px-2 text-xs font-semibold'
  if (index === 0) return `${base} border-amber-300 bg-amber-50 text-amber-700 dark:border-amber-500/40 dark:bg-amber-500/10 dark:text-amber-300`
  if (index === 1) return `${base} border-slate-300 bg-slate-50 text-slate-700 dark:border-slate-500/40 dark:bg-slate-500/10 dark:text-slate-300`
  if (index === 2) return `${base} border-orange-300 bg-orange-50 text-orange-700 dark:border-orange-500/40 dark:bg-orange-500/10 dark:text-orange-300`
  return `${base} border-gray-200 bg-gray-50 text-gray-600 dark:border-dark-700 dark:bg-dark-950 dark:text-dark-300`
}

function progressWidth(cost: number): string {
  if (maxCost.value <= 0 || cost <= 0) return '0%'
  return `${Math.max(8, Math.round((cost / maxCost.value) * 100))}%`
}

function compareSubscriptionExpiry(a: UserSubscription, b: UserSubscription): number {
  const aTime = a.expires_at ? new Date(a.expires_at).getTime() : Number.POSITIVE_INFINITY
  const bTime = b.expires_at ? new Date(b.expires_at).getTime() : Number.POSITIVE_INFINITY
  return aTime - bTime
}

function packageName(subscription: UserSubscription): string {
  return subscription.group?.name || `Group #${subscription.group_id}`
}

function formatCountdown(expiresAt: string): string {
  const expires = new Date(expiresAt).getTime()
  if (!Number.isFinite(expires)) return t('leaderboard.noExpiration')

  const diffMs = expires - nowTick.value
  if (diffMs <= 0) return t('leaderboard.countdownExpired')

  const totalMinutes = Math.ceil(diffMs / 60_000)
  const days = Math.floor(totalMinutes / 1440)
  const hours = Math.floor((totalMinutes % 1440) / 60)
  const minutes = totalMinutes % 60

  if (days > 0) return t('leaderboard.countdownDaysHours', { days, hours })
  if (hours > 0) return t('leaderboard.countdownHoursMinutes', { hours, minutes })
  if (minutes > 0) return t('leaderboard.countdownMinutes', { minutes })
  return t('leaderboard.countdownLessThanMinute')
}

function accountInitial(account: string): string {
  const normalized = account.trim()
  if (!normalized) return '?'
  return normalized[0].toUpperCase()
}

onMounted(() => {
  void loadRanking()
  void subscriptionStore.fetchActiveSubscriptions().catch((error) => {
    console.error('Failed to load active subscriptions on leaderboard:', error)
  })
  countdownTimer = setInterval(() => {
    nowTick.value = Date.now()
  }, 60_000)
})

onBeforeUnmount(() => {
  if (countdownTimer) {
    clearInterval(countdownTimer)
    countdownTimer = null
  }
})
</script>
