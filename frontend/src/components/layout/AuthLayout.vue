<template>
  <div class="relative flex min-h-screen items-center justify-center overflow-hidden bg-gray-50 p-4 dark:bg-dark-900">
    <!-- Background -->
    <div
      class="absolute inset-0 bg-mesh-gradient bg-[size:72px_72px] opacity-80"
    ></div>

    <!-- Grid fade -->
    <div class="pointer-events-none absolute inset-0 overflow-hidden">
      <div
        class="absolute inset-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.86),rgba(255,255,255,0.56)_38%,rgba(255,255,255,0.9))] dark:bg-[linear-gradient(180deg,rgba(23,23,23,0.42),rgba(23,23,23,0.18)_42%,rgba(15,15,15,0.78))]"
      ></div>
    </div>

    <div v-if="$slots.topRight" class="absolute right-4 top-4 z-20 sm:right-6 sm:top-6">
      <slot name="topRight" />
    </div>

    <!-- Content Container -->
    <div class="relative z-10 w-full max-w-md">
      <!-- Logo/Brand -->
      <div class="mb-8 text-center">
        <!-- Custom Logo or Default Logo -->
        <template v-if="settingsLoaded">
          <div
            class="mb-4 inline-flex h-16 w-16 items-center justify-center overflow-hidden rounded-lg border border-primary-400/30 bg-dark-950/5 dark:bg-dark-950"
          >
            <img :src="siteLogo || '/logo.png'" alt="Logo" class="h-full w-full object-contain" />
          </div>
          <h1 class="mb-2 text-3xl font-normal leading-none text-gray-950 dark:text-dark-50">
            {{ siteName }}
          </h1>
          <p class="text-sm text-gray-500 dark:text-dark-400">
            {{ siteSubtitle }}
          </p>
        </template>
      </div>

      <!-- Card Container -->
      <div class="card-glass p-8">
        <slot />
      </div>

      <!-- Footer Links -->
      <div class="mt-6 text-center text-sm">
        <slot name="footer" />
      </div>

      <!-- Copyright -->
      <div class="mt-8 text-center text-xs text-gray-400 dark:text-dark-500">
        &copy; {{ currentYear }} {{ siteName }}. All rights reserved.
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useAppStore } from '@/stores'
import { sanitizeUrl } from '@/utils/url'

const appStore = useAppStore()

const siteName = computed(() => appStore.siteName || 'WeShare')
const siteLogo = computed(() => sanitizeUrl(appStore.siteLogo || '', { allowRelative: true, allowDataUrl: true }))
const siteSubtitle = computed(() => appStore.cachedPublicSettings?.site_subtitle || 'Subscription to API Conversion Platform')
const settingsLoaded = computed(() => appStore.publicSettingsLoaded)

const currentYear = computed(() => new Date().getFullYear())

onMounted(() => {
  appStore.fetchPublicSettings()
})
</script>

<style scoped>
.text-gradient {
  color: var(--ui-accent);
}
</style>
