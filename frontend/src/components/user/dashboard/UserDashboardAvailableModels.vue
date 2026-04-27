<template>
  <div class="card overflow-hidden">
    <div class="flex flex-col gap-3 border-b border-gray-100 px-6 py-4 dark:border-dark-700 sm:flex-row sm:items-center sm:justify-between">
      <div class="flex items-center gap-3">
        <div class="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-lg bg-sky-100 dark:bg-sky-900/30">
          <Icon name="cpu" size="md" class="text-sky-600 dark:text-sky-400" />
        </div>
        <div>
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ t('dashboard.availableModels') }}</h2>
          <p class="text-xs text-gray-500 dark:text-dark-400">
            {{ summaryText }}
          </p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <span v-if="models.length > 0" class="badge badge-gray">
          {{ t('dashboard.availableModelsCount', { count: models.length }) }}
        </span>
        <button
          class="btn btn-secondary btn-sm"
          type="button"
          :disabled="loading"
          :title="t('common.refresh')"
          @click="$emit('refresh')"
        >
          <Icon name="refresh" size="sm" :class="loading ? 'animate-spin' : ''" />
        </button>
      </div>
    </div>

    <div class="p-5">
      <div v-if="loading" class="flex flex-wrap gap-2">
        <span v-for="idx in 8" :key="idx" class="h-8 w-28 animate-pulse rounded-full bg-gray-100 dark:bg-dark-800" />
      </div>

      <div v-else-if="error || (models.length === 0 && failedKeyCount > 0)" class="flex items-center gap-3 rounded-lg border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-900/50 dark:bg-red-950/20 dark:text-red-300">
        <Icon name="exclamationCircle" size="sm" class="flex-shrink-0" />
        <span>{{ t('dashboard.availableModelsLoadFailed') }}</span>
      </div>

      <div v-else-if="activeKeyCount === 0" class="flex flex-col gap-3 rounded-lg border border-dashed border-gray-200 px-4 py-5 dark:border-dark-700 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p class="text-sm font-medium text-gray-900 dark:text-white">{{ t('dashboard.noActiveApiKeys') }}</p>
          <p class="mt-1 text-xs text-gray-500 dark:text-dark-400">{{ t('dashboard.createKeyForModels') }}</p>
        </div>
        <router-link to="/keys" class="btn btn-secondary btn-sm">
          <Icon name="key" size="sm" />
          {{ t('dashboard.createApiKey') }}
        </router-link>
      </div>

      <div v-else-if="models.length === 0" class="rounded-lg border border-dashed border-gray-200 px-4 py-5 text-sm text-gray-500 dark:border-dark-700 dark:text-dark-400">
        {{ t('dashboard.noAvailableModels') }}
      </div>

      <div v-else>
        <div class="max-h-40 overflow-y-auto pr-1">
          <div class="flex flex-wrap gap-2">
            <span
              v-for="model in models"
              :key="model.id"
              class="inline-flex max-w-full items-center rounded-full border border-gray-200 bg-gray-50 px-3 py-1.5 font-mono text-xs font-medium text-gray-700 dark:border-dark-700 dark:bg-dark-800/60 dark:text-dark-100"
              :title="model.display_name && model.display_name !== model.id ? `${model.display_name} (${model.id})` : model.id"
            >
              <span class="max-w-[260px] truncate">{{ model.id }}</span>
            </span>
          </div>
        </div>
        <p v-if="failedKeyCount > 0" class="mt-3 text-xs text-amber-600 dark:text-amber-400">
          {{ t('dashboard.availableModelsPartialFailed', { count: failedKeyCount }) }}
        </p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import Icon from '@/components/icons/Icon.vue'
import type { GatewayModel } from '@/api/models'

const props = defineProps<{
  models: GatewayModel[]
  loading: boolean
  error: boolean
  activeKeyCount: number
  queriedKeyCount: number
  failedKeyCount: number
}>()

defineEmits<{
  (e: 'refresh'): void
}>()

const { t } = useI18n()

const summaryText = computed(() => {
  if (props.loading) {
    return t('dashboard.availableModelsLoading')
  }
  if (props.activeKeyCount === 0) {
    return t('dashboard.availableModelsNoKeysSummary')
  }
  return t('dashboard.availableModelsSummary', {
    keys: props.activeKeyCount,
    groups: props.queriedKeyCount
  })
})
</script>
