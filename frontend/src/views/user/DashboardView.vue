<template>
  <AppLayout>
    <div class="space-y-6">
      <UserDashboardAvailableModels
        :models="availableModels"
        :loading="loadingAvailableModels"
        :error="availableModelsError"
        :active-key-count="activeModelKeyCount"
        :queried-key-count="queriedModelKeyCount"
        :failed-key-count="failedModelKeyCount"
        @refresh="loadAvailableModels"
      />
      <div v-if="loading" class="flex items-center justify-center py-12"><LoadingSpinner /></div>
      <template v-else-if="stats">
        <UserDashboardStats :stats="stats" :balance="user?.balance || 0" :is-simple="authStore.isSimpleMode" />
        <UserDashboardCharts v-model:startDate="startDate" v-model:endDate="endDate" v-model:granularity="granularity" :loading="loadingCharts" :trend="trendData" :models="modelStats" @dateRangeChange="loadCharts" @granularityChange="loadCharts" @refresh="refreshAll" />
        <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div class="lg:col-span-2"><UserDashboardRecentUsage :data="recentUsage" :loading="loadingUsage" /></div>
          <div class="lg:col-span-1"><UserDashboardQuickActions /></div>
        </div>
      </template>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'; import { useAuthStore } from '@/stores/auth'; import { usageAPI, type UserDashboardStats as UserStatsType } from '@/api/usage'
import AppLayout from '@/components/layout/AppLayout.vue'; import LoadingSpinner from '@/components/common/LoadingSpinner.vue'
import UserDashboardStats from '@/components/user/dashboard/UserDashboardStats.vue'; import UserDashboardCharts from '@/components/user/dashboard/UserDashboardCharts.vue'
import UserDashboardAvailableModels from '@/components/user/dashboard/UserDashboardAvailableModels.vue'
import UserDashboardRecentUsage from '@/components/user/dashboard/UserDashboardRecentUsage.vue'; import UserDashboardQuickActions from '@/components/user/dashboard/UserDashboardQuickActions.vue'
import type { UsageLog, TrendDataPoint, ModelStat } from '@/types'
import { modelsAPI, type GatewayModel } from '@/api/models'

const authStore = useAuthStore(); const user = computed(() => authStore.user)
const stats = ref<UserStatsType | null>(null); const loading = ref(false); const loadingUsage = ref(false); const loadingCharts = ref(false)
const trendData = ref<TrendDataPoint[]>([]); const modelStats = ref<ModelStat[]>([]); const recentUsage = ref<UsageLog[]>([])
const availableModels = ref<GatewayModel[]>([]); const loadingAvailableModels = ref(true); const availableModelsError = ref(false)
const activeModelKeyCount = ref(0); const queriedModelKeyCount = ref(0); const failedModelKeyCount = ref(0)

const formatLD = (d: Date) => d.toISOString().split('T')[0]
const startDate = ref(formatLD(new Date(Date.now() - 6 * 86400000))); const endDate = ref(formatLD(new Date())); const granularity = ref('day')

const loadStats = async () => { loading.value = true; try { await authStore.refreshUser(); stats.value = await usageAPI.getDashboardStats() } catch (error) { console.error('Failed to load dashboard stats:', error) } finally { loading.value = false } }
const loadAvailableModels = async () => { loadingAvailableModels.value = true; availableModelsError.value = false; try { const res = await modelsAPI.getCurrentUserAvailableModels(); availableModels.value = res.models; activeModelKeyCount.value = res.active_key_count; queriedModelKeyCount.value = res.queried_key_count; failedModelKeyCount.value = res.failed_key_count } catch (error) { console.error('Failed to load available models:', error); availableModels.value = []; activeModelKeyCount.value = 0; queriedModelKeyCount.value = 0; failedModelKeyCount.value = 0; availableModelsError.value = true } finally { loadingAvailableModels.value = false } }
const loadCharts = async () => { loadingCharts.value = true; try { const res = await Promise.all([usageAPI.getDashboardTrend({ start_date: startDate.value, end_date: endDate.value, granularity: granularity.value as any }), usageAPI.getDashboardModels({ start_date: startDate.value, end_date: endDate.value })]); trendData.value = res[0].trend || []; modelStats.value = res[1].models || [] } catch (error) { console.error('Failed to load charts:', error) } finally { loadingCharts.value = false } }
const loadRecent = async () => { loadingUsage.value = true; try { const res = await usageAPI.getByDateRange(startDate.value, endDate.value); recentUsage.value = res.items.slice(0, 5) } catch (error) { console.error('Failed to load recent usage:', error) } finally { loadingUsage.value = false } }
const refreshAll = () => { loadStats(); loadAvailableModels(); loadCharts(); loadRecent() }

onMounted(() => { refreshAll() })
</script>
