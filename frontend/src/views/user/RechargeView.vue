<template>
  <AppLayout>
    <div class="mx-auto max-w-7xl space-y-8">
      <header class="space-y-6">
        <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h1 class="text-3xl font-semibold tracking-normal text-gray-950 dark:text-white">
              {{ t('onlineRecharge.title') }}
            </h1>
            <p class="mt-2 text-base text-gray-500 dark:text-dark-300">
              {{ t('onlineRecharge.subtitle') }}
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-3 text-sm text-gray-600 dark:text-dark-200">
            <button
              v-if="isAdmin"
              type="button"
              :disabled="configLoading"
              class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 text-sm font-medium text-gray-700 transition-colors hover:border-primary-400 hover:text-primary-700 disabled:cursor-not-allowed disabled:opacity-70 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200 dark:hover:border-primary-500 dark:hover:text-primary-300"
              @click="openConfigDialog"
            >
              <span v-if="configLoading" class="spinner h-4 w-4"></span>
              <Icon v-else name="cog" size="sm" />
              <span>{{ configLoading ? t('onlineRecharge.loadingProducts') : t('onlineRecharge.configureProducts') }}</span>
            </button>
            <div class="inline-flex items-center gap-2">
              <span class="font-medium">{{ t('onlineRecharge.currentBalance') }}:</span>
              <span class="text-lg font-semibold text-gray-950 dark:text-white">
                ${{ currentBalance }}
              </span>
            </div>
            <span class="hidden h-5 w-px bg-gray-200 dark:bg-dark-700 sm:inline-block"></span>
            <div class="inline-flex items-center gap-2">
              <Icon name="bolt" size="sm" class="text-gray-400 dark:text-dark-400" />
              <span class="text-lg font-semibold text-gray-950 dark:text-white">
                {{ user?.concurrency ?? 0 }} {{ t('onlineRecharge.requests') }}
              </span>
            </div>
          </div>
        </div>

        <div class="h-px bg-gray-200 dark:bg-dark-800"></div>

        <ol class="flex flex-wrap items-center gap-3 text-sm text-gray-500 dark:text-dark-300">
          <li
            v-for="(step, index) in steps"
            :key="step"
            class="inline-flex items-center gap-2"
          >
            <span class="grid h-7 w-7 place-items-center rounded-full bg-primary-500/15 text-sm font-semibold text-primary-700 dark:bg-primary-500/20 dark:text-primary-300">
              {{ index + 1 }}
            </span>
            <span>{{ step }}</span>
            <Icon
              v-if="index < steps.length - 1"
              name="arrowRight"
              size="sm"
              class="text-gray-300 dark:text-dark-600"
            />
          </li>
        </ol>
      </header>

      <section class="overflow-hidden rounded-lg border border-gray-200 bg-white/90 dark:border-dark-800 dark:bg-dark-900/90">
        <div class="border-b border-gray-100 px-5 py-5 dark:border-dark-800 sm:px-6">
          <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <h2 class="text-xl font-semibold text-gray-950 dark:text-white">
                {{ t('onlineRecharge.productList') }}
              </h2>
              <p class="mt-2 text-sm leading-6 text-gray-500 dark:text-dark-300">
                {{ t('onlineRecharge.productHint') }}
              </p>
            </div>
            <div v-if="typeKeywords.length" class="flex flex-wrap gap-2">
              <button
                type="button"
                class="min-h-9 rounded-lg border px-3 text-sm font-medium transition-colors"
                :class="selectedTypeKeyword === ''
                  ? 'border-primary-500 bg-primary-50 text-primary-700 dark:border-primary-400 dark:bg-primary-500/15 dark:text-primary-200'
                  : 'border-gray-200 bg-white text-gray-600 hover:border-primary-300 hover:text-primary-700 dark:border-dark-700 dark:bg-dark-950/40 dark:text-dark-300 dark:hover:border-primary-500 dark:hover:text-primary-300'"
                @click="selectedTypeKeyword = ''"
              >
                {{ t('onlineRecharge.filterAll') }}
              </button>
              <button
                v-for="keyword in typeKeywords"
                :key="keyword"
                type="button"
                class="min-h-9 rounded-lg border px-3 text-sm font-medium transition-colors"
                :class="selectedTypeKeyword === keyword
                  ? 'border-primary-500 bg-primary-50 text-primary-700 dark:border-primary-400 dark:bg-primary-500/15 dark:text-primary-200'
                  : 'border-gray-200 bg-white text-gray-600 hover:border-primary-300 hover:text-primary-700 dark:border-dark-700 dark:bg-dark-950/40 dark:text-dark-300 dark:hover:border-primary-500 dark:hover:text-primary-300'"
                @click="selectedTypeKeyword = keyword"
              >
                {{ keyword }}
              </button>
            </div>
          </div>
        </div>

        <div v-if="filteredProducts.length" class="grid gap-4 p-5 sm:p-6 lg:grid-cols-3">
          <article
            v-for="product in filteredProducts"
            :key="product.id"
            class="group flex min-h-[184px] flex-col justify-between rounded-lg border border-gray-200 bg-white p-5 transition-colors hover:border-primary-500/50 dark:border-dark-700 dark:bg-dark-950/40 dark:hover:border-primary-500/50"
          >
            <div class="space-y-4">
              <div class="flex items-start gap-4">
                <div class="grid h-14 w-14 shrink-0 place-items-center rounded-lg bg-sky-100 text-sky-700 dark:bg-sky-500/15 dark:text-sky-300">
                  <Icon name="badge" size="lg" />
                </div>
                <div class="min-w-0">
                  <div class="mb-2 inline-flex max-w-full items-center rounded-full bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300">
                    <span class="truncate">{{ product.type_keyword }}</span>
                  </div>
                  <h3 class="break-words text-base font-semibold text-gray-950 dark:text-white">
                    {{ product.title }}
                  </h3>
                </div>
              </div>
              <p class="break-words text-sm leading-6 text-gray-500 dark:text-dark-300">
                {{ product.description }}
              </p>
            </div>

            <button
              type="button"
              class="mt-5 inline-flex w-fit items-center gap-2 text-sm font-medium text-blue-600 transition-colors hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300"
              @click="buyProduct(product)"
            >
              <span>{{ t('onlineRecharge.buyRedeemCode') }}</span>
              <Icon name="arrowRight" size="sm" class="transition-transform group-hover:translate-x-0.5" />
            </button>
          </article>
        </div>

        <div v-else class="p-8 text-center text-sm text-gray-500 dark:text-dark-300">
          {{ t('onlineRecharge.productsEmpty') }}
        </div>
      </section>

      <section class="overflow-hidden rounded-lg border border-gray-200 bg-white/90 dark:border-dark-800 dark:bg-dark-900/90">
        <div class="border-b border-gray-100 px-5 py-5 dark:border-dark-800 sm:px-6">
          <h2 class="text-xl font-semibold text-gray-950 dark:text-white">
            {{ t('onlineRecharge.useRedeemCode') }}
          </h2>
        </div>

        <form class="space-y-3 p-5 sm:p-6" @submit.prevent="handleRedeem">
          <div class="flex flex-col gap-3 lg:flex-row">
            <div class="relative min-w-0 flex-1">
              <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-4">
                <Icon name="gift" size="md" class="text-gray-400 dark:text-dark-400" />
              </div>
              <input
                ref="codeInput"
                v-model="redeemCode"
                type="text"
                autocomplete="one-time-code"
                :placeholder="t('onlineRecharge.codePlaceholder')"
                :disabled="submitting"
                class="input min-h-[56px] rounded-lg pl-12 text-base"
              />
            </div>
            <button
              type="submit"
              :disabled="!redeemCode.trim() || submitting"
              class="inline-flex min-h-[56px] items-center justify-center gap-2 rounded-lg bg-primary-600 px-7 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:cursor-not-allowed disabled:bg-gray-300 disabled:text-gray-500 dark:disabled:bg-dark-700 dark:disabled:text-dark-400 lg:w-auto"
            >
              <span v-if="submitting" class="spinner h-4 w-4"></span>
              <span>{{ submitting ? t('onlineRecharge.redeeming') : t('onlineRecharge.redeem') }}</span>
            </button>
          </div>

          <p class="text-sm text-gray-500 dark:text-dark-300">
            {{ t('onlineRecharge.redeemHint') }}
          </p>

          <transition name="fade">
            <div
              v-if="resultMessage"
              class="rounded-lg border px-4 py-3 text-sm"
              :class="resultKind === 'success'
                ? 'border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-800/60 dark:bg-emerald-950/30 dark:text-emerald-300'
                : 'border-red-200 bg-red-50 text-red-700 dark:border-red-800/60 dark:bg-red-950/30 dark:text-red-300'"
            >
              {{ resultMessage }}
            </div>
          </transition>
        </form>
      </section>
    </div>

    <transition name="fade">
      <div
        v-if="configOpen"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
        @click.self="closeConfigDialog"
      >
        <div class="flex max-h-[90vh] w-full max-w-4xl flex-col overflow-hidden rounded-lg bg-white shadow-xl dark:bg-dark-900">
          <div class="flex items-start justify-between gap-4 border-b border-gray-100 px-5 py-4 dark:border-dark-800 sm:px-6">
            <div>
              <h2 class="text-lg font-semibold text-gray-950 dark:text-white">
                {{ t('onlineRecharge.configTitle') }}
              </h2>
              <p class="mt-1 text-sm text-gray-500 dark:text-dark-300">
                {{ t('onlineRecharge.configSubtitle') }}
              </p>
            </div>
            <button
              type="button"
              class="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700 dark:text-dark-300 dark:hover:bg-dark-800 dark:hover:text-white"
              :aria-label="t('common.close')"
              @click="closeConfigDialog"
            >
              <Icon name="x" size="sm" />
            </button>
          </div>

          <div class="overflow-y-auto px-5 py-5 sm:px-6">
            <div class="mb-4 rounded-lg border border-gray-200 bg-gray-50 p-4 dark:border-dark-700 dark:bg-dark-950/40">
              <div class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                <div>
                  <h3 class="text-sm font-semibold text-gray-900 dark:text-white">
                    {{ t('onlineRecharge.quickConfigTitle') }}
                  </h3>
                  <p class="mt-1 text-sm text-gray-500 dark:text-dark-300">
                    {{ t('onlineRecharge.quickConfigHint') }}
                  </p>
                </div>
                <div class="flex flex-wrap gap-2">
                  <button
                    type="button"
                    class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 text-sm font-medium text-gray-700 transition-colors hover:border-primary-400 hover:text-primary-700 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200 dark:hover:border-primary-500 dark:hover:text-primary-300"
                    @click="applyRecommendedProducts"
                  >
                    <Icon name="sparkles" size="sm" />
                    <span>{{ t('onlineRecharge.recommendedConfig') }}</span>
                  </button>
                  <button
                    type="button"
                    class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 text-sm font-medium text-gray-700 transition-colors hover:border-primary-400 hover:text-primary-700 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200 dark:hover:border-primary-500 dark:hover:text-primary-300"
                    @click="toggleJsonConfig"
                  >
                    <Icon name="clipboard" size="sm" />
                    <span>{{ t('onlineRecharge.jsonConfig') }}</span>
                  </button>
                </div>
              </div>

              <div v-if="jsonConfigOpen" class="mt-4 space-y-3">
                <label class="block">
                  <span class="mb-1 block text-sm font-medium text-gray-700 dark:text-dark-200">
                    {{ t('onlineRecharge.jsonConfigLabel') }}
                  </span>
                  <textarea
                    v-model="jsonConfigText"
                    rows="12"
                    class="input min-h-[240px] resize-y font-mono text-xs leading-5"
                    spellcheck="false"
                    :placeholder="t('onlineRecharge.jsonConfigPlaceholder')"
                  ></textarea>
                </label>
                <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                  <p class="text-sm text-gray-500 dark:text-dark-300">
                    {{ t('onlineRecharge.jsonConfigHint') }}
                  </p>
                  <div class="flex flex-wrap gap-2">
                    <button
                      type="button"
                      class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 text-sm font-medium text-gray-700 transition-colors hover:border-primary-400 hover:text-primary-700 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200 dark:hover:border-primary-500 dark:hover:text-primary-300"
                      @click="refreshJsonConfigText"
                    >
                      <Icon name="refresh" size="sm" />
                      <span>{{ t('onlineRecharge.refreshJsonConfig') }}</span>
                    </button>
                    <button
                      type="button"
                      class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg bg-primary-600 px-4 text-sm font-semibold text-white transition-colors hover:bg-primary-700"
                      @click="applyJsonConfig"
                    >
                      <Icon name="check" size="sm" />
                      <span>{{ t('onlineRecharge.applyJsonConfig') }}</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div class="space-y-4">
              <div
                v-for="(product, index) in configProducts"
                :key="product.id"
                class="rounded-lg border border-gray-200 bg-gray-50 p-4 dark:border-dark-700 dark:bg-dark-950/40"
              >
                <div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                  <div class="inline-flex items-center gap-2 text-sm font-semibold text-gray-800 dark:text-dark-100">
                    <Icon name="badge" size="sm" class="text-primary-600 dark:text-primary-300" />
                    <span>{{ t('onlineRecharge.productItem', { index: index + 1 }) }}</span>
                  </div>
                  <div class="flex flex-wrap items-center gap-2">
                    <label class="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200">
                      <input
                        v-model="product.enabled"
                        type="checkbox"
                        class="sr-only"
                      />
                      <span
                        class="relative inline-flex h-6 w-11 shrink-0 rounded-full transition-colors"
                        :class="product.enabled ? 'bg-primary-600' : 'bg-gray-300 dark:bg-dark-700'"
                      >
                        <span
                          class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform"
                          :class="product.enabled ? 'translate-x-5' : 'translate-x-0'"
                        ></span>
                      </span>
                      <span>{{ product.enabled ? t('onlineRecharge.productEnabled') : t('onlineRecharge.productDisabled') }}</span>
                    </label>
                    <button
                      type="button"
                      class="grid h-8 w-8 place-items-center rounded-lg text-gray-500 transition-colors hover:bg-white hover:text-gray-800 disabled:cursor-not-allowed disabled:opacity-40 dark:text-dark-300 dark:hover:bg-dark-800 dark:hover:text-white"
                      :disabled="index === 0"
                      :aria-label="t('onlineRecharge.moveUp')"
                      @click="moveConfigProduct(index, -1)"
                    >
                      <Icon name="arrowUp" size="sm" />
                    </button>
                    <button
                      type="button"
                      class="grid h-8 w-8 place-items-center rounded-lg text-gray-500 transition-colors hover:bg-white hover:text-gray-800 disabled:cursor-not-allowed disabled:opacity-40 dark:text-dark-300 dark:hover:bg-dark-800 dark:hover:text-white"
                      :disabled="index === configProducts.length - 1"
                      :aria-label="t('onlineRecharge.moveDown')"
                      @click="moveConfigProduct(index, 1)"
                    >
                      <Icon name="arrowDown" size="sm" />
                    </button>
                    <button
                      type="button"
                      class="grid h-8 w-8 place-items-center rounded-lg text-red-500 transition-colors hover:bg-red-50 hover:text-red-700 dark:text-red-300 dark:hover:bg-red-950/30 dark:hover:text-red-200"
                      :aria-label="t('onlineRecharge.removeProduct')"
                      @click="removeConfigProduct(index)"
                    >
                      <Icon name="trash" size="sm" />
                    </button>
                  </div>
                </div>

                <div class="grid gap-4 lg:grid-cols-3">
                  <label class="block">
                    <span class="mb-1 block text-sm font-medium text-gray-700 dark:text-dark-200">
                      {{ t('onlineRecharge.productTitleLabel') }}
                    </span>
                    <input
                      v-model="product.title"
                      type="text"
                      class="input"
                      :placeholder="t('onlineRecharge.productTitlePlaceholder')"
                    />
                  </label>
                  <label class="block">
                    <span class="mb-1 block text-sm font-medium text-gray-700 dark:text-dark-200">
                      {{ t('onlineRecharge.typeKeywordLabel') }}
                    </span>
                    <input
                      v-model="product.type_keyword"
                      type="text"
                      class="input"
                      :placeholder="t('onlineRecharge.typeKeywordPlaceholder')"
                    />
                  </label>
                  <label class="block">
                    <span class="mb-1 block text-sm font-medium text-gray-700 dark:text-dark-200">
                      {{ t('onlineRecharge.sortOrderLabel') }}
                    </span>
                    <input
                      v-model.number="product.sort_order"
                      type="number"
                      min="0"
                      step="1"
                      class="input"
                      :placeholder="t('onlineRecharge.sortOrderPlaceholder')"
                    />
                  </label>
                  <label class="block lg:col-span-3">
                    <span class="mb-1 block text-sm font-medium text-gray-700 dark:text-dark-200">
                      {{ t('onlineRecharge.productDescriptionLabel') }}
                    </span>
                    <textarea
                      v-model="product.description"
                      rows="3"
                      class="input min-h-[92px] resize-y"
                      :placeholder="t('onlineRecharge.productDescriptionPlaceholder')"
                    ></textarea>
                  </label>
                  <label class="block lg:col-span-3">
                    <span class="mb-1 block text-sm font-medium text-gray-700 dark:text-dark-200">
                      {{ t('onlineRecharge.targetUrlLabel') }}
                    </span>
                    <input
                      v-model="product.url"
                      type="url"
                      class="input"
                      :placeholder="t('onlineRecharge.targetUrlPlaceholder')"
                    />
                  </label>
                </div>
              </div>
            </div>

            <div class="mt-4 flex flex-wrap gap-3">
              <button
                type="button"
                class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 text-sm font-medium text-gray-700 transition-colors hover:border-primary-400 hover:text-primary-700 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200 dark:hover:border-primary-500 dark:hover:text-primary-300"
                @click="addConfigProduct"
              >
                <Icon name="plus" size="sm" />
                <span>{{ t('onlineRecharge.addProduct') }}</span>
              </button>
              <button
                type="button"
                class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 text-sm font-medium text-gray-700 transition-colors hover:border-primary-400 hover:text-primary-700 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200 dark:hover:border-primary-500 dark:hover:text-primary-300"
                @click="sortConfigProducts"
              >
                <Icon name="sort" size="sm" />
                <span>{{ t('onlineRecharge.sortProducts') }}</span>
              </button>
            </div>
          </div>

          <div class="flex flex-col-reverse gap-3 border-t border-gray-100 px-5 py-4 dark:border-dark-800 sm:flex-row sm:justify-end sm:px-6">
            <button
              type="button"
              class="inline-flex min-h-10 items-center justify-center rounded-lg border border-gray-200 bg-white px-5 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-50 dark:border-dark-700 dark:bg-dark-900 dark:text-dark-200 dark:hover:bg-dark-800"
              @click="closeConfigDialog"
            >
              {{ t('common.cancel') }}
            </button>
            <button
              type="button"
              :disabled="configSaving"
              class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg bg-primary-600 px-5 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:cursor-not-allowed disabled:bg-gray-300 disabled:text-gray-500 dark:disabled:bg-dark-700 dark:disabled:text-dark-400"
              @click="saveConfigProducts"
            >
              <span v-if="configSaving" class="spinner h-4 w-4"></span>
              <span>{{ configSaving ? t('onlineRecharge.savingProducts') : t('onlineRecharge.saveProducts') }}</span>
            </button>
          </div>
        </div>
      </div>
    </transition>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { redeemAPI } from '@/api'
import { getSettings, updateOnlineRechargeProducts } from '@/api/admin/settings'
import AppLayout from '@/components/layout/AppLayout.vue'
import Icon from '@/components/icons/Icon.vue'
import { useAppStore } from '@/stores/app'
import { useAuthStore } from '@/stores/auth'
import { useSubscriptionStore } from '@/stores/subscriptions'
import type { OnlineRechargeProduct } from '@/types'
import { extractApiErrorMessage } from '@/utils/apiError'

defineOptions({
  name: 'RechargeView'
})

type ResultKind = 'success' | 'error'

const DEFAULT_TYPE_KEYWORDS = ['OpenAI', 'Claude', 'Gemini']

const { t } = useI18n()
const appStore = useAppStore()
const authStore = useAuthStore()
const subscriptionStore = useSubscriptionStore()

const user = computed(() => authStore.user)
const isAdmin = computed(() => authStore.isAdmin)
const redeemCode = ref('')
const submitting = ref(false)
const resultMessage = ref('')
const resultKind = ref<ResultKind>('success')
const codeInput = ref<HTMLInputElement | null>(null)
const selectedTypeKeyword = ref('')
const configOpen = ref(false)
const configLoading = ref(false)
const configSaving = ref(false)
const configProducts = ref<OnlineRechargeProduct[]>([])
const jsonConfigOpen = ref(false)
const jsonConfigText = ref('')

const defaultProducts = computed<OnlineRechargeProduct[]>(() => [
  {
    id: 'default-openai',
    title: `${t('onlineRecharge.products.lite.name')} ${t('onlineRecharge.products.lite.price')}`,
    description: t('onlineRecharge.products.lite.quota'),
    url: '',
    type_keyword: DEFAULT_TYPE_KEYWORDS[0],
    sort_order: 0,
    enabled: true,
  },
  {
    id: 'default-claude',
    title: `${t('onlineRecharge.products.plus.name')} ${t('onlineRecharge.products.plus.price')}`,
    description: t('onlineRecharge.products.plus.quota'),
    url: '',
    type_keyword: DEFAULT_TYPE_KEYWORDS[1],
    sort_order: 1,
    enabled: true,
  },
  {
    id: 'default-gemini',
    title: `${t('onlineRecharge.products.pro.name')} ${t('onlineRecharge.products.pro.price')}`,
    description: t('onlineRecharge.products.pro.quota'),
    url: '',
    type_keyword: DEFAULT_TYPE_KEYWORDS[2],
    sort_order: 2,
    enabled: true,
  },
])

const recommendedProducts = computed<OnlineRechargeProduct[]>(() => [
  {
    id: 'recommended-openai',
    title: t('onlineRecharge.recommended.openai.title'),
    description: t('onlineRecharge.recommended.openai.description'),
    url: 'https://example.com/openai',
    type_keyword: DEFAULT_TYPE_KEYWORDS[0],
    sort_order: 0,
    enabled: true,
  },
  {
    id: 'recommended-claude',
    title: t('onlineRecharge.recommended.claude.title'),
    description: t('onlineRecharge.recommended.claude.description'),
    url: 'https://example.com/claude',
    type_keyword: DEFAULT_TYPE_KEYWORDS[1],
    sort_order: 1,
    enabled: true,
  },
  {
    id: 'recommended-gemini',
    title: t('onlineRecharge.recommended.gemini.title'),
    description: t('onlineRecharge.recommended.gemini.description'),
    url: 'https://example.com/gemini',
    type_keyword: DEFAULT_TYPE_KEYWORDS[2],
    sort_order: 2,
    enabled: true,
  },
])

const configuredProducts = computed<OnlineRechargeProduct[]>(() => {
  const products = appStore.cachedPublicSettings?.online_recharge_products ?? []
  return normalizeProducts(products)
})

const products = computed(() => {
  const source = configuredProducts.value.length > 0 ? configuredProducts.value : defaultProducts.value
  return source.filter((product) => product.enabled)
})

const typeKeywords = computed(() => uniqueKeywords(products.value.map((product) => product.type_keyword)))

const filteredProducts = computed(() => {
  if (!selectedTypeKeyword.value) return products.value
  return products.value.filter((product) => product.type_keyword === selectedTypeKeyword.value)
})

const steps = computed(() => [
  t('onlineRecharge.steps.selectProduct'),
  t('onlineRecharge.steps.buyRedeemCode'),
  t('onlineRecharge.steps.useRedeemCode'),
])

const currentBalance = computed(() => (user.value?.balance ?? 0).toFixed(2))

watch(typeKeywords, (keywords) => {
  if (selectedTypeKeyword.value && !keywords.includes(selectedTypeKeyword.value)) {
    selectedTypeKeyword.value = ''
  }
})

onMounted(() => {
  appStore.fetchPublicSettings().catch(() => undefined)
})

function uniqueKeywords(values: string[]) {
  const seen = new Set<string>()
  const result: string[] = []
  for (const value of values) {
    const keyword = value.trim()
    if (!keyword || seen.has(keyword)) continue
    seen.add(keyword)
    result.push(keyword)
  }
  return result
}

function toStringValue(value: unknown) {
  if (value === null || value === undefined) return ''
  return String(value)
}

function normalizeEnabled(value: unknown) {
  if (typeof value === 'boolean') return value
  if (typeof value === 'string') return value.trim().toLowerCase() !== 'false'
  return true
}

function normalizeSortOrder(value: unknown, fallback: number) {
  const order = Number(value)
  return Number.isFinite(order) ? Math.max(0, Math.trunc(order)) : fallback
}

function serializeProduct(product: OnlineRechargeProduct, index: number) {
  return {
    id: product.id || createProductId(),
    title: product.title.trim(),
    description: product.description.trim(),
    url: product.url.trim(),
    type_keyword: product.type_keyword.trim(),
    sort_order: normalizeSortOrder(product.sort_order, index),
    enabled: product.enabled !== false,
  }
}

function normalizeProducts(productsToNormalize: OnlineRechargeProduct[]) {
  return [...productsToNormalize]
    .map((product, index) => ({
      id: product.id?.trim() || createProductId(),
      title: product.title?.trim() || '',
      description: product.description?.trim() || '',
      url: product.url?.trim() || '',
      type_keyword: product.type_keyword?.trim() || '',
      sort_order: normalizeSortOrder(product.sort_order, index),
      enabled: product.enabled !== false,
    }))
    .filter((product) => product.title && product.description && product.type_keyword)
    .sort((a, b) => a.sort_order - b.sort_order)
}

function createProductId() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }
  return `product_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`
}

function cloneProducts(source: OnlineRechargeProduct[]) {
  return source.map((product, index) => ({
    ...product,
    id: product.id || createProductId(),
    sort_order: normalizeSortOrder(product.sort_order, index),
    enabled: product.enabled !== false,
  }))
}

function getNextSortOrder() {
  if (configProducts.value.length === 0) return 0
  return Math.max(
    ...configProducts.value.map((product, index) => normalizeSortOrder(product.sort_order, index)),
  ) + 1
}

function createBlankProduct(): OnlineRechargeProduct {
  return {
    id: createProductId(),
    title: '',
    description: '',
    url: '',
    type_keyword: '',
    sort_order: getNextSortOrder(),
    enabled: true,
  }
}

function productHasContent(product: OnlineRechargeProduct) {
  return Boolean(
    product.title.trim()
      || product.description.trim()
      || product.url.trim()
      || product.type_keyword.trim()
  )
}

function getProductsJson(productsToFormat = configProducts.value) {
  return JSON.stringify(
    productsToFormat.map((product, index) => serializeProduct(product, index)),
    null,
    2,
  )
}

function refreshJsonConfigText() {
  jsonConfigText.value = getProductsJson()
}

function toggleJsonConfig() {
  jsonConfigOpen.value = !jsonConfigOpen.value
  if (jsonConfigOpen.value) {
    refreshJsonConfigText()
  }
}

function applyRecommendedProducts() {
  configProducts.value = cloneProducts(recommendedProducts.value)
  if (jsonConfigOpen.value) {
    refreshJsonConfigText()
  }
  appStore.showSuccess(t('onlineRecharge.recommendedApplied'))
}

function extractProductsFromJson(value: unknown) {
  if (Array.isArray(value)) return value
  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>
    if (Array.isArray(record.products)) return record.products
    if (Array.isArray(record.online_recharge_products)) return record.online_recharge_products
  }
  return null
}

function normalizeJsonProduct(value: unknown, index: number): OnlineRechargeProduct {
  const product = value && typeof value === 'object'
    ? value as Record<string, unknown>
    : {}
  return {
    id: toStringValue(product.id).trim() || createProductId(),
    title: toStringValue(product.title).trim(),
    description: toStringValue(product.description).trim(),
    url: toStringValue(product.url).trim(),
    type_keyword: toStringValue(product.type_keyword ?? product.typeKeyword).trim(),
    sort_order: normalizeSortOrder(product.sort_order ?? product.sortOrder, index),
    enabled: normalizeEnabled(product.enabled),
  }
}

function applyJsonConfig() {
  let parsed: unknown
  try {
    parsed = JSON.parse(jsonConfigText.value)
  } catch {
    appStore.showWarning(t('onlineRecharge.invalidJsonConfig'))
    return
  }

  const rawProducts = extractProductsFromJson(parsed)
  if (!rawProducts) {
    appStore.showWarning(t('onlineRecharge.jsonConfigMustBeArray'))
    return
  }

  const importedProducts = rawProducts
    .map((product, index) => normalizeJsonProduct(product, index))
    .filter(productHasContent)
    .sort((a, b) => a.sort_order - b.sort_order)

  if (importedProducts.length === 0) {
    appStore.showWarning(t('onlineRecharge.noProductToSave'))
    return
  }

  configProducts.value = cloneProducts(importedProducts)
  refreshJsonConfigText()
  appStore.showSuccess(t('onlineRecharge.jsonConfigApplied'))
}

function isAbsoluteHttpURL(value: string) {
  try {
    const url = new URL(value)
    return url.protocol === 'http:' || url.protocol === 'https:'
  } catch {
    return false
  }
}

async function openConfigDialog() {
  if (!isAdmin.value) return
  if (configLoading.value) return

  configLoading.value = true
  try {
    const settings = await getSettings()
    const adminProducts = normalizeProducts(settings.online_recharge_products ?? [])
    const source = adminProducts.length > 0 ? adminProducts : defaultProducts.value
    configProducts.value = cloneProducts(source)
    jsonConfigOpen.value = false
    jsonConfigText.value = ''
    configOpen.value = true
  } catch (error) {
    appStore.showError(extractApiErrorMessage(error, t('onlineRecharge.productsLoadFailed')))
  } finally {
    configLoading.value = false
  }
}

function closeConfigDialog() {
  if (configSaving.value) return
  configOpen.value = false
  jsonConfigOpen.value = false
  jsonConfigText.value = ''
}

function addConfigProduct() {
  configProducts.value.push(createBlankProduct())
}

function renumberConfigProducts() {
  configProducts.value.forEach((product, productIndex) => {
    product.sort_order = productIndex
  })
}

function removeConfigProduct(index: number) {
  configProducts.value.splice(index, 1)
  renumberConfigProducts()
}

function moveConfigProduct(index: number, direction: -1 | 1) {
  const nextIndex = index + direction
  if (nextIndex < 0 || nextIndex >= configProducts.value.length) return
  const [item] = configProducts.value.splice(index, 1)
  configProducts.value.splice(nextIndex, 0, item)
  renumberConfigProducts()
}

function sortConfigProducts() {
  configProducts.value = [...configProducts.value].sort((a, b) => (
    normalizeSortOrder(a.sort_order, 0) - normalizeSortOrder(b.sort_order, 0)
  ))
  if (jsonConfigOpen.value) {
    refreshJsonConfigText()
  }
}

function buildProductsPayload() {
  return configProducts.value
    .filter(productHasContent)
    .map((product, index) => serializeProduct(product, index))
}

async function saveConfigProducts() {
  const payload = buildProductsPayload()
  if (payload.length === 0) {
    appStore.showWarning(t('onlineRecharge.noProductToSave'))
    return
  }

  const invalidProduct = payload.find((product) => (
    !product.title || !product.description || !product.type_keyword || !product.url
  ))
  if (invalidProduct) {
    appStore.showWarning(t('onlineRecharge.productRequired'))
    return
  }

  if (payload.some((product) => !isAbsoluteHttpURL(product.url))) {
    appStore.showWarning(t('onlineRecharge.invalidProductUrl'))
    return
  }

  configSaving.value = true
  try {
    const savedProducts = await updateOnlineRechargeProducts(payload)
    configProducts.value = cloneProducts(savedProducts)
    await appStore.fetchPublicSettings(true)
    configOpen.value = false
    appStore.showSuccess(t('onlineRecharge.productsSaved'))
  } catch (error) {
    appStore.showError(extractApiErrorMessage(error, t('onlineRecharge.productsSaveFailed')))
  } finally {
    configSaving.value = false
  }
}

function buyProduct(product: OnlineRechargeProduct) {
  if (!product.url) {
    appStore.showWarning(t('onlineRecharge.storeLinkMissing'))
    codeInput.value?.focus()
    return
  }

  window.open(product.url, '_blank', 'noopener,noreferrer')
}

function buildRedeemSuccessMessage(result: {
  message?: string
  type: string
  value: number
  new_balance?: number
  new_concurrency?: number
  group_name?: string
  validity_days?: number
}) {
  if (result.type === 'balance' && result.new_balance !== undefined) {
    return t('onlineRecharge.balanceRedeemSuccess', { balance: result.new_balance.toFixed(2) })
  }
  if (result.type === 'concurrency' && result.new_concurrency !== undefined) {
    return t('onlineRecharge.concurrencyRedeemSuccess', { concurrency: result.new_concurrency })
  }
  if (result.type === 'subscription') {
    return result.group_name
      ? t('onlineRecharge.subscriptionRedeemSuccessWithGroup', { group: result.group_name })
      : t('onlineRecharge.subscriptionRedeemSuccess')
  }

  return result.message || t('onlineRecharge.redeemSuccess')
}

async function handleRedeem() {
  const code = redeemCode.value.trim()
  if (!code || submitting.value) return

  submitting.value = true
  resultMessage.value = ''
  resultKind.value = 'success'

  try {
    const result = await redeemAPI.redeem(code)
    await authStore.refreshUser()
    if (result.type === 'subscription') {
      await subscriptionStore.fetchActiveSubscriptions(true).catch(() => {
        appStore.showWarning(t('redeem.subscriptionRefreshFailed'))
      })
    }

    redeemCode.value = ''
    resultKind.value = 'success'
    resultMessage.value = buildRedeemSuccessMessage(result)
    appStore.showSuccess(t('redeem.codeRedeemSuccess'))
  } catch (error) {
    resultKind.value = 'error'
    resultMessage.value = extractApiErrorMessage(error, t('redeem.failedToRedeem'))
    appStore.showError(t('redeem.redeemFailed'))
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: all 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>
