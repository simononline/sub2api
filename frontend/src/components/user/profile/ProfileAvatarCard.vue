<template>
  <div :class="props.embedded ? 'space-y-4' : 'card'">
    <div
      v-if="!props.embedded"
      class="border-b border-gray-100 px-6 py-4 dark:border-dark-700"
    >
      <h2 class="text-lg font-medium text-gray-900 dark:text-white">
        {{ t('profile.avatar.title') }}
      </h2>
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
        {{ t('profile.avatar.description') }}
      </p>
    </div>

    <div :class="props.embedded ? 'space-y-3' : 'flex flex-col gap-5 px-6 py-6 sm:flex-row sm:items-start'">
      <div
        :class="props.embedded
          ? 'flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-2xl bg-gradient-to-br from-primary-500 to-primary-600 text-xl font-bold text-white shadow-lg shadow-primary-500/20'
          : 'flex h-24 w-24 shrink-0 items-center justify-center overflow-hidden rounded-2xl bg-gradient-to-br from-primary-500 to-primary-600 text-3xl font-bold text-white shadow-lg shadow-primary-500/20'"
      >
        <img
          v-if="currentAvatarUrl"
          data-testid="profile-avatar-preview"
          :src="currentAvatarUrl"
          :alt="displayName"
          class="h-full w-full object-cover"
        >
        <span v-else>{{ avatarInitial }}</span>
      </div>

      <div :class="props.embedded ? 'space-y-3' : 'min-w-0 flex-1 space-y-4'">
        <div class="space-y-1">
          <p v-if="props.embedded" class="text-sm font-semibold text-gray-900 dark:text-white">
            {{ t('profile.avatar.title') }}
          </p>
          <p v-else class="text-sm font-medium text-gray-900 dark:text-white">
            {{ displayName }}
          </p>
          <p class="text-sm text-gray-500 dark:text-gray-400">
            {{ hasAvatar ? t('profile.avatar.currentHint') : t('profile.avatar.emptyHint') }}
          </p>
        </div>

        <div v-if="hasAvatar" class="flex flex-wrap items-center gap-3">
          <button
            data-testid="profile-avatar-delete"
            type="button"
            class="btn btn-secondary btn-sm"
            :disabled="avatarSaving"
            @click="handleAvatarDelete"
          >
            {{ t('common.delete') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { userAPI } from '@/api'
import { useAppStore } from '@/stores/app'
import { useAuthStore } from '@/stores/auth'
import type { User } from '@/types'
import { extractApiErrorMessage } from '@/utils/apiError'
import { sanitizeUrl } from '@/utils/url'

const props = withDefaults(defineProps<{
  user: User | null
  embedded?: boolean
}>(), {
  embedded: false,
})

const { t } = useI18n()
const authStore = useAuthStore()
const appStore = useAppStore()

const avatarSaving = ref(false)

const displayName = computed(() => props.user?.username?.trim() || props.user?.email?.trim() || t('profile.user'))
const avatarInitial = computed(() => displayName.value.charAt(0).toUpperCase() || 'U')
const storedAvatarUrl = computed(() => props.user?.avatar_url?.trim() || '')
const currentAvatarUrl = computed(() => sanitizeUrl(storedAvatarUrl.value))
const hasAvatar = computed(() => Boolean(storedAvatarUrl.value))

async function handleAvatarDelete() {
  if (avatarSaving.value) {
    return
  }
  if (!hasAvatar.value) {
    appStore.showError(t('profile.avatar.emptyDeleteHint'))
    return
  }

  avatarSaving.value = true
  try {
    const updated = await userAPI.updateProfile({ avatar_url: '' })
    authStore.user = updated
    appStore.showSuccess(t('profile.avatar.deleteSuccess'))
  } catch (error: unknown) {
    appStore.showError(extractApiErrorMessage(error, t('common.error')))
  } finally {
    avatarSaving.value = false
  }
}
</script>
