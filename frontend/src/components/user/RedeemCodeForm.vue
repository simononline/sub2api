<template>
  <div class="space-y-4">
    <section :class="formContainerClass">
      <div
        class="border-b border-gray-100 bg-gradient-to-r from-orange-50 via-white to-primary-50 px-5 py-4 dark:border-dark-800 dark:from-orange-950/20 dark:via-dark-900 dark:to-primary-950/20"
      >
        <div class="flex items-start gap-3">
          <div
            class="grid h-11 w-11 shrink-0 place-items-center rounded-lg border border-orange-200 bg-white text-orange-500 shadow-sm dark:border-orange-500/20 dark:bg-dark-800 dark:text-orange-300"
          >
            <Icon name="gift" size="lg" />
          </div>
          <div class="min-w-0">
            <h2 class="text-base font-semibold text-gray-950 dark:text-white">
              {{ t('redeem.title') }}
            </h2>
            <p class="mt-1 text-sm text-gray-600 dark:text-dark-300">
              {{ t('redeem.description') }}
            </p>
          </div>
        </div>
      </div>

      <form class="space-y-5 p-5 sm:p-6" @submit.prevent="handleRedeem">
        <div>
          <label for="redeem-code" class="input-label">
            {{ t('redeem.redeemCodeLabel') }}
          </label>
          <div class="relative mt-1">
            <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-4">
              <Icon name="key" size="md" class="text-gray-400 dark:text-dark-500" />
            </div>
            <input
              id="redeem-code"
              v-model="redeemCode"
              type="text"
              required
              autocomplete="one-time-code"
              :placeholder="t('redeem.redeemCodePlaceholder')"
              :disabled="submitting"
              class="input py-3 pl-12 text-base font-medium sm:text-lg"
            />
          </div>
          <p class="input-hint">
            {{ t('redeem.redeemCodeHint') }}
          </p>
        </div>

        <button
          type="submit"
          :disabled="!redeemCode || submitting"
          class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-primary-600 px-5 py-3 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 active:bg-primary-800 disabled:cursor-not-allowed disabled:bg-gray-300 disabled:text-gray-500 dark:disabled:bg-dark-700 dark:disabled:text-dark-400"
        >
          <svg
            v-if="submitting"
            class="h-5 w-5 animate-spin"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            ></circle>
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            ></path>
          </svg>
          <Icon v-else name="checkCircle" size="md" />
          {{ submitting ? t('redeem.redeeming') : t('redeem.redeemButton') }}
        </button>
      </form>
    </section>

    <transition name="fade">
      <div
        v-if="redeemResult"
        class="rounded-lg border border-emerald-200 bg-emerald-50/90 shadow-sm dark:border-emerald-800/50 dark:bg-emerald-950/30"
      >
        <div class="p-5">
          <div class="flex items-start gap-4">
            <div
              class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-emerald-100 dark:bg-emerald-900/40"
            >
              <Icon name="checkCircle" size="md" class="text-emerald-600 dark:text-emerald-300" />
            </div>
            <div class="min-w-0 flex-1">
              <h3 class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                {{ t('redeem.redeemSuccess') }}
              </h3>
              <div class="mt-2 space-y-1 text-sm text-emerald-700 dark:text-emerald-300">
                <p>{{ redeemResult.message }}</p>
                <p v-if="redeemResult.type === 'balance'" class="font-medium">
                  {{ t('redeem.added') }}: ${{ redeemResult.value.toFixed(2) }}
                </p>
                <p v-else-if="redeemResult.type === 'concurrency'" class="font-medium">
                  {{ t('redeem.added') }}: {{ redeemResult.value }}
                  {{ t('redeem.concurrentRequests') }}
                </p>
                <p v-else-if="redeemResult.type === 'subscription'" class="font-medium">
                  {{ t('redeem.subscriptionAssigned') }}
                  <span v-if="redeemResult.group_name"> - {{ redeemResult.group_name }}</span>
                  <span v-if="redeemResult.validity_days">
                    ({{ t('redeem.subscriptionDays', { days: redeemResult.validity_days }) }})
                  </span>
                </p>
                <p v-if="redeemResult.new_balance !== undefined">
                  {{ t('redeem.newBalance') }}:
                  <span class="font-semibold">${{ redeemResult.new_balance.toFixed(2) }}</span>
                </p>
                <p v-if="redeemResult.new_concurrency !== undefined">
                  {{ t('redeem.newConcurrency') }}:
                  <span class="font-semibold">
                    {{ redeemResult.new_concurrency }} {{ t('redeem.requests') }}
                  </span>
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </transition>

    <transition name="fade">
      <div
        v-if="errorMessage"
        class="rounded-lg border border-red-200 bg-red-50/90 shadow-sm dark:border-red-800/50 dark:bg-red-950/30"
      >
        <div class="p-5">
          <div class="flex items-start gap-4">
            <div
              class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-red-100 dark:bg-red-900/40"
            >
              <Icon name="exclamationCircle" size="md" class="text-red-600 dark:text-red-300" />
            </div>
            <div class="min-w-0 flex-1">
              <h3 class="text-sm font-semibold text-red-800 dark:text-red-200">
                {{ t('redeem.redeemFailed') }}
              </h3>
              <p class="mt-2 text-sm text-red-700 dark:text-red-300">
                {{ errorMessage }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </transition>

    <div
      v-if="showInfo"
      class="rounded-lg border border-gray-200 bg-gray-50/90 shadow-sm dark:border-dark-800 dark:bg-dark-800/50"
    >
      <div class="p-5">
        <div class="flex items-start gap-4">
          <div
            class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-gray-200 bg-white text-gray-500 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-300"
          >
            <Icon name="infoCircle" size="md" />
          </div>
          <div class="min-w-0 flex-1">
            <h3 class="text-sm font-semibold text-gray-900 dark:text-gray-100">
              {{ t('redeem.aboutCodes') }}
            </h3>
            <ul class="mt-2 list-inside list-disc space-y-1 text-sm text-gray-600 dark:text-dark-300">
              <li>{{ t('redeem.codeRule1') }}</li>
              <li>{{ t('redeem.codeRule2') }}</li>
              <li>
                {{ t('redeem.codeRule3') }}
                <span
                  v-if="contactInfo"
                  class="ml-1.5 inline-flex items-center rounded-md border border-gray-200 bg-white px-2 py-0.5 text-xs font-medium text-gray-700 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200"
                >
                  {{ contactInfo }}
                </span>
              </li>
              <li>{{ t('redeem.codeRule4') }}</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { authAPI, redeemAPI } from '@/api'
import { useAppStore } from '@/stores/app'
import { useAuthStore } from '@/stores/auth'
import { useSubscriptionStore } from '@/stores/subscriptions'
import Icon from '@/components/icons/Icon.vue'

interface RedeemResult {
  message: string
  type: string
  value: number
  new_balance?: number
  new_concurrency?: number
  group_name?: string
  validity_days?: number
}

interface Props {
  embedded?: boolean
  showInfo?: boolean
  afterRedeem?: () => Promise<void> | void
}

interface Emits {
  (e: 'success', result: RedeemResult): void
}

const props = withDefaults(defineProps<Props>(), {
  embedded: false,
  showInfo: true
})

const emit = defineEmits<Emits>()

const { t } = useI18n()
const authStore = useAuthStore()
const appStore = useAppStore()
const subscriptionStore = useSubscriptionStore()

const redeemCode = ref('')
const submitting = ref(false)
const redeemResult = ref<RedeemResult | null>(null)
const errorMessage = ref('')
const contactInfo = ref('')

const formContainerClass = computed(() =>
  props.embedded
    ? 'overflow-hidden rounded-lg border border-gray-200 bg-white/95 shadow-sm dark:border-dark-800 dark:bg-dark-900/90'
    : 'card overflow-hidden'
)

const getRedeemErrorMessage = (error: unknown): string => {
  const responseError = error as { response?: { data?: { detail?: string } } }
  return responseError.response?.data?.detail || t('redeem.failedToRedeem')
}

const handleRedeem = async () => {
  if (!redeemCode.value.trim()) {
    appStore.showError(t('redeem.pleaseEnterCode'))
    return
  }

  submitting.value = true
  errorMessage.value = ''
  redeemResult.value = null

  try {
    const result = await redeemAPI.redeem(redeemCode.value.trim())
    redeemResult.value = result

    await authStore.refreshUser()

    if (result.type === 'subscription') {
      try {
        await subscriptionStore.fetchActiveSubscriptions(true)
      } catch (error) {
        console.error('Failed to refresh subscriptions after redeem:', error)
        appStore.showWarning(t('redeem.subscriptionRefreshFailed'))
      }
    }

    redeemCode.value = ''

    await props.afterRedeem?.()
    emit('success', result)

    appStore.showSuccess(t('redeem.codeRedeemSuccess'))
  } catch (error) {
    errorMessage.value = getRedeemErrorMessage(error)
    appStore.showError(t('redeem.redeemFailed'))
  } finally {
    submitting.value = false
  }
}

onMounted(async () => {
  if (!props.showInfo) return

  try {
    const settings = await authAPI.getPublicSettings()
    contactInfo.value = settings.contact_info || ''
  } catch (error) {
    console.error('Failed to load contact info:', error)
  }
})
</script>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: all 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>
