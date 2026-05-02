<template>
  <AppLayout>
    <div class="space-y-6">
      <!-- 加群联系方式 -->
      <div class="grid grid-cols-1 gap-5 lg:grid-cols-3">
        <section
          class="overflow-hidden rounded-lg border border-gray-200 bg-white/95 shadow-card dark:border-dark-800 dark:bg-dark-900/90"
        >
          <div class="flex h-full flex-col gap-4 p-5">
            <div class="flex items-start gap-3">
              <div
                class="grid h-11 w-11 shrink-0 place-items-center rounded-lg border border-primary-200 bg-primary-50 text-primary-600 shadow-sm dark:border-primary-500/20 dark:bg-primary-950/30 dark:text-primary-300"
              >
                <Icon name="users" size="lg" />
              </div>
              <div class="min-w-0">
                <h2
                  class="text-base font-semibold text-gray-950 dark:text-white"
                >
                  {{ t("userSubscriptions.contactTitle") }}
                </h2>
                <p class="mt-1 text-sm text-gray-600 dark:text-dark-300">
                  {{ t("userSubscriptions.contactDesc") }}
                </p>
              </div>
            </div>

            <div
              class="space-y-3 rounded-md border border-gray-100 bg-gray-50/80 p-3 dark:border-dark-800 dark:bg-dark-800/50"
            >
              <p class="flex items-center justify-between gap-3 text-sm">
                <span class="text-gray-500 dark:text-dark-400">
                  {{ t("userSubscriptions.contactGroup") }}
                </span>
                <span
                  class="font-mono font-semibold text-gray-950 dark:text-white"
                  >1041906235</span
                >
              </p>
              <div
                class="border-t border-gray-100 dark:border-dark-700/70"
              ></div>
              <p class="flex items-start justify-between gap-3 text-sm">
                <span class="text-gray-500 dark:text-dark-400">
                  {{ t("userSubscriptions.contactQuestion") }}
                </span>
                <span
                  class="text-right font-medium text-gray-900 dark:text-gray-100"
                >
                  {{ t("userSubscriptions.contactQuestionText") }}
                </span>
              </p>
              <p class="flex items-center justify-between gap-3 text-sm">
                <span class="text-gray-500 dark:text-dark-400">
                  {{ t("userSubscriptions.contactAnswer") }}
                </span>
                <span
                  class="font-mono font-semibold text-primary-700 dark:text-primary-300"
                >
                  weshare
                </span>
              </p>
            </div>
          </div>
        </section>

        <!-- 可用模型 -->
        <section
          class="overflow-hidden rounded-lg border border-gray-200 bg-white/95 shadow-card dark:border-dark-800 dark:bg-dark-900/90 lg:col-span-2"
        >
          <UserDashboardAvailableModels
            embedded
            :models="availableModels"
            :loading="loadingAvailableModels"
            :error="availableModelsError"
            :active-key-count="activeModelKeyCount"
            :queried-key-count="queriedModelKeyCount"
            :failed-key-count="failedModelKeyCount"
            @refresh="loadAvailableModels"
          />
        </section>
      </div>

      <!-- 购买套餐 -->
      <div class="grid grid-cols-1 gap-5 lg:grid-cols-3">
        <section
          class="overflow-hidden rounded-lg border border-orange-200/70 bg-gradient-to-br from-orange-50 to-white shadow-card dark:border-orange-500/20 dark:from-orange-950/30 dark:to-dark-900"
        >
          <div
            class="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="flex min-w-0 items-start gap-3">
              <div
                class="grid h-11 w-11 shrink-0 place-items-center rounded-lg border border-orange-200 bg-white text-orange-500 shadow-sm dark:border-orange-500/20 dark:bg-dark-800 dark:text-orange-300"
              >
                <Icon name="gift" size="lg" />
              </div>
              <div class="min-w-0">
                <h2
                  class="text-base font-semibold text-gray-950 dark:text-white"
                >
                  {{ t("userSubscriptions.purchasePackageTitle") }}
                </h2>
                <p class="mt-1 text-sm text-gray-600 dark:text-dark-300">
                  {{ t("userSubscriptions.purchasePackageDesc") }}
                </p>
              </div>
            </div>

            <div class="grid w-full shrink-0 grid-cols-1 gap-2 sm:w-auto sm:grid-cols-2">
              <router-link
                to="/recharge"
                class="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-orange-600 active:bg-orange-700"
              >
                <Icon name="creditCard" size="sm" />
                {{ t("userSubscriptions.purchasePackageButton") }}
              </router-link>
              <button
                type="button"
                class="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg border border-orange-200 bg-white px-4 py-2.5 text-sm font-semibold text-orange-700 shadow-sm transition-colors hover:bg-orange-50 active:bg-orange-100 dark:border-orange-500/25 dark:bg-dark-800 dark:text-orange-200 dark:hover:bg-orange-950/30"
                @click="showRedeemDialog = true"
              >
                <Icon name="key" size="sm" />
                {{ t("userSubscriptions.redeemCodeButton") }}
              </button>
            </div>
          </div>
        </section>

        <!-- 配置教程 -->
        <section
          class="overflow-hidden rounded-lg border border-amber-200/80 bg-gradient-to-br from-amber-50/70 to-white shadow-card dark:border-amber-500/20 dark:from-amber-950/10 dark:to-dark-900/90 lg:col-span-2"
        >
          <div
            class="flex h-full flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="flex min-w-0 items-start gap-3">
              <div
                class="grid h-11 w-11 shrink-0 place-items-center rounded-lg border border-amber-200 bg-amber-50 text-amber-600 shadow-sm dark:border-amber-500/20 dark:bg-amber-950/30 dark:text-amber-300"
              >
                <Icon name="document" size="lg" />
              </div>
              <div class="min-w-0">
                <h2 class="text-base font-semibold text-gray-950 dark:text-white">
                  {{ t("userSubscriptions.configGuideTitle") }}
                </h2>
                <p class="mt-1 text-sm text-gray-600 dark:text-dark-300">
                  {{ t("userSubscriptions.configGuideDesc") }}
                </p>
              </div>
            </div>

            <router-link
              to="/keys"
              class="inline-flex w-full shrink-0 items-center justify-center gap-2 rounded-lg border border-amber-200 bg-amber-50 px-5 py-2.5 text-sm font-semibold text-amber-700 shadow-sm transition-colors hover:bg-amber-100 active:bg-amber-200 dark:border-amber-500/25 dark:bg-amber-950/30 dark:text-amber-200 dark:hover:bg-amber-900/35 sm:w-auto"
            >
              {{ t("userSubscriptions.configGuideButton") }}
              <Icon name="externalLink" size="sm" />
            </router-link>
          </div>
        </section>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="flex justify-center py-12">
        <div
          class="h-8 w-8 animate-spin rounded-full border-2 border-primary-500 border-t-transparent"
        ></div>
      </div>

      <!-- Empty State -->
      <div v-else-if="subscriptions.length === 0" class="card p-12 text-center">
        <div
          class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-lg bg-gray-100 text-gray-400 dark:bg-dark-800 dark:text-dark-300"
        >
          <Icon name="creditCard" size="xl" />
        </div>
        <h3 class="mb-2 text-lg font-semibold text-gray-900 dark:text-white">
          {{ t("userSubscriptions.noActiveSubscriptions") }}
        </h3>
        <p class="text-gray-500 dark:text-dark-400">
          {{ t("userSubscriptions.noActiveSubscriptionsDesc") }}
        </p>
      </div>

      <!-- Subscriptions Grid -->
      <div v-else class="grid grid-cols-1 gap-5 lg:grid-cols-3">
        <div
          v-for="subscription in subscriptions"
          :key="subscription.id"
          class="group relative flex min-h-[390px] flex-col overflow-hidden rounded-lg border bg-white/95 shadow-card transition-all duration-300 hover:-translate-y-0.5 hover:shadow-card-hover dark:bg-dark-900/90"
          :class="platformBorderClass(subscription.group?.platform || '')"
        >
          <div
            :class="[
              'h-1 w-full',
              platformAccentBarClass(subscription.group?.platform || ''),
            ]"
          />

          <!-- Header -->
          <div class="border-b border-gray-100 p-4 dark:border-dark-800">
            <div class="flex items-start justify-between gap-3">
              <div class="flex min-w-0 items-start gap-3">
                <div
                  :class="[
                    'grid h-10 w-10 shrink-0 place-items-center rounded-lg border bg-gray-50 shadow-inner dark:bg-dark-800',
                    platformBorderClass(subscription.group?.platform || ''),
                    platformIconClass(subscription.group?.platform || ''),
                  ]"
                >
                  <PlatformIcon
                    :platform="subscription.group?.platform"
                    size="lg"
                  />
                </div>

                <div class="min-w-0">
                  <div class="flex min-w-0 flex-wrap items-center gap-2">
                    <h3
                      class="min-w-0 max-w-full truncate text-base font-semibold text-gray-950 dark:text-white"
                    >
                      {{
                        displaySubscriptionGroupName(
                          subscription.group?.name,
                          subscription.group_id,
                        )
                      }}
                    </h3>
                    <span
                      :class="[
                        'shrink-0 rounded-md border px-2 py-0.5 text-[11px] font-semibold',
                        platformBadgeClass(subscription.group?.platform || ''),
                      ]"
                    >
                      {{ platformLabel(subscription.group?.platform || "") }}
                    </span>
                  </div>
                  <p
                    v-if="subscription.group?.description"
                    class="mt-1 line-clamp-2 text-xs leading-5 text-gray-500 dark:text-dark-400"
                  >
                    {{ sanitizeComplianceText(subscription.group.description) }}
                  </p>
                </div>
              </div>

              <span
                :class="[
                  'inline-flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-xs font-semibold',
                  getSubscriptionStatusClass(subscription.status),
                ]"
              >
                <Icon
                  :name="getSubscriptionStatusIcon(subscription.status)"
                  size="xs"
                />
                {{ t(`userSubscriptions.status.${subscription.status}`) }}
              </span>
            </div>
          </div>

          <!-- Usage Progress -->
          <div class="flex flex-1 flex-col gap-4 p-4">
            <!-- Expiration Info -->
            <div
              class="flex items-start gap-3 rounded-md border border-gray-100 bg-gray-50/80 p-3 dark:border-dark-800 dark:bg-dark-800/50"
            >
              <div
                class="grid h-8 w-8 shrink-0 place-items-center rounded-md bg-white text-gray-500 shadow-sm dark:bg-dark-900 dark:text-dark-300"
              >
                <Icon name="calendar" size="sm" />
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-xs font-medium text-gray-500 dark:text-dark-400">
                  {{ t("userSubscriptions.expires") }}
                </p>
                <p
                  v-if="subscription.expires_at"
                  :class="[
                    'mt-1 text-sm font-semibold leading-5',
                    getExpirationClass(subscription.expires_at),
                  ]"
                >
                  {{ formatExpirationDate(subscription.expires_at) }}
                </p>
                <p
                  v-else
                  class="mt-1 text-sm font-semibold text-gray-800 dark:text-gray-200"
                >
                  {{ t("userSubscriptions.noExpiration") }}
                </p>
              </div>
            </div>

            <div v-if="hasUsageLimits(subscription)" class="space-y-3">
              <!-- Daily Usage -->
              <div v-if="subscription.group?.daily_limit_usd" class="space-y-2">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p
                      class="text-sm font-semibold text-gray-800 dark:text-gray-200"
                    >
                      {{ t("userSubscriptions.daily") }}
                    </p>
                    <p
                      v-if="subscription.daily_window_start"
                      class="mt-0.5 text-xs text-gray-500 dark:text-dark-400"
                    >
                      {{
                        t("userSubscriptions.resetIn", {
                          time: formatResetTime(
                            subscription.daily_window_start,
                            24,
                          ),
                        })
                      }}
                    </p>
                  </div>
                  <div class="shrink-0 text-right">
                    <p
                      class="text-sm font-semibold text-gray-900 dark:text-white"
                    >
                      {{
                        getProgressLabel(
                          subscription.daily_usage_usd,
                          subscription.group.daily_limit_usd,
                        )
                      }}
                    </p>
                    <p class="text-xs text-gray-500 dark:text-dark-400">
                      {{ formatUsd(subscription.daily_usage_usd) }} /
                      {{ formatUsd(subscription.group.daily_limit_usd) }}
                    </p>
                  </div>
                </div>
                <div
                  class="relative h-2.5 overflow-hidden rounded-full bg-gray-100 dark:bg-dark-800"
                >
                  <div
                    class="absolute inset-y-0 left-0 rounded-full transition-all duration-300"
                    :class="
                      getProgressBarClass(
                        subscription.daily_usage_usd,
                        subscription.group.daily_limit_usd,
                      )
                    "
                    :style="{
                      width: getProgressWidth(
                        subscription.daily_usage_usd,
                        subscription.group.daily_limit_usd,
                      ),
                    }"
                  ></div>
                </div>
              </div>

              <!-- Weekly Usage -->
              <div
                v-if="subscription.group?.weekly_limit_usd"
                class="space-y-2"
              >
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p
                      class="text-sm font-semibold text-gray-800 dark:text-gray-200"
                    >
                      {{ t("userSubscriptions.weekly") }}
                    </p>
                    <p
                      v-if="subscription.weekly_window_start"
                      class="mt-0.5 text-xs text-gray-500 dark:text-dark-400"
                    >
                      {{
                        t("userSubscriptions.resetIn", {
                          time: formatResetTime(
                            subscription.weekly_window_start,
                            168,
                          ),
                        })
                      }}
                    </p>
                  </div>
                  <div class="shrink-0 text-right">
                    <p
                      class="text-sm font-semibold text-gray-900 dark:text-white"
                    >
                      {{
                        getProgressLabel(
                          subscription.weekly_usage_usd,
                          subscription.group.weekly_limit_usd,
                        )
                      }}
                    </p>
                    <p class="text-xs text-gray-500 dark:text-dark-400">
                      {{ formatUsd(subscription.weekly_usage_usd) }} /
                      {{ formatUsd(subscription.group.weekly_limit_usd) }}
                    </p>
                  </div>
                </div>
                <div
                  class="relative h-2.5 overflow-hidden rounded-full bg-gray-100 dark:bg-dark-800"
                >
                  <div
                    class="absolute inset-y-0 left-0 rounded-full transition-all duration-300"
                    :class="
                      getProgressBarClass(
                        subscription.weekly_usage_usd,
                        subscription.group.weekly_limit_usd,
                      )
                    "
                    :style="{
                      width: getProgressWidth(
                        subscription.weekly_usage_usd,
                        subscription.group.weekly_limit_usd,
                      ),
                    }"
                  ></div>
                </div>
              </div>

              <!-- Monthly Usage -->
              <div
                v-if="subscription.group?.monthly_limit_usd"
                class="space-y-2"
              >
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p
                      class="text-sm font-semibold text-gray-800 dark:text-gray-200"
                    >
                      {{ t("userSubscriptions.monthly") }}
                    </p>
                    <p
                      v-if="subscription.monthly_window_start"
                      class="mt-0.5 text-xs text-gray-500 dark:text-dark-400"
                    >
                      {{
                        t("userSubscriptions.resetIn", {
                          time: formatResetTime(
                            subscription.monthly_window_start,
                            720,
                          ),
                        })
                      }}
                    </p>
                  </div>
                  <div class="shrink-0 text-right">
                    <p
                      class="text-sm font-semibold text-gray-900 dark:text-white"
                    >
                      {{
                        getProgressLabel(
                          subscription.monthly_usage_usd,
                          subscription.group.monthly_limit_usd,
                        )
                      }}
                    </p>
                    <p class="text-xs text-gray-500 dark:text-dark-400">
                      {{ formatUsd(subscription.monthly_usage_usd) }} /
                      {{ formatUsd(subscription.group.monthly_limit_usd) }}
                    </p>
                  </div>
                </div>
                <div
                  class="relative h-2.5 overflow-hidden rounded-full bg-gray-100 dark:bg-dark-800"
                >
                  <div
                    class="absolute inset-y-0 left-0 rounded-full transition-all duration-300"
                    :class="
                      getProgressBarClass(
                        subscription.monthly_usage_usd,
                        subscription.group.monthly_limit_usd,
                      )
                    "
                    :style="{
                      width: getProgressWidth(
                        subscription.monthly_usage_usd,
                        subscription.group.monthly_limit_usd,
                      ),
                    }"
                  ></div>
                </div>
              </div>
            </div>

            <!-- No limits configured - Unlimited badge -->
            <div
              v-else
              class="flex flex-1 items-center justify-center rounded-md border border-emerald-200/70 bg-emerald-50/80 px-4 py-6 dark:border-emerald-900/50 dark:bg-emerald-950/20"
            >
              <div class="flex items-center gap-3">
                <span
                  class="flex h-11 w-11 items-center justify-center rounded-lg bg-white text-3xl font-semibold text-emerald-600 shadow-sm dark:bg-dark-900 dark:text-emerald-300"
                >
                  ∞
                </span>
                <div>
                  <p
                    class="text-sm font-medium text-emerald-700 dark:text-emerald-300"
                  >
                    {{ t("userSubscriptions.unlimited") }}
                  </p>
                  <p
                    class="text-xs text-emerald-600/70 dark:text-emerald-400/70"
                  >
                    {{ t("userSubscriptions.unlimitedDesc") }}
                  </p>
                </div>
              </div>
            </div>

            <div v-if="subscription.status === 'active'" class="mt-auto pt-1">
              <button
                :class="[
                  'inline-flex w-full items-center justify-center gap-2 rounded-md px-3 py-2 text-sm font-semibold text-white transition-colors',
                  platformButtonClass(subscription.group?.platform || ''),
                ]"
                @click="renewSubscription(subscription)"
              >
                <Icon name="refresh" size="sm" />
                {{ t("payment.renewNow") }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <BaseDialog
        :show="showRedeemDialog"
        :title="t('userSubscriptions.redeemDialogTitle')"
        width="normal"
        @close="showRedeemDialog = false"
      >
        <RedeemCodeForm embedded :after-redeem="handleRedeemSuccess" />
      </BaseDialog>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { useRouter } from "vue-router";
import { useAppStore } from "@/stores/app";
import subscriptionsAPI from "@/api/subscriptions";
import type { UserSubscription } from "@/types";
import AppLayout from "@/components/layout/AppLayout.vue";
import Icon from "@/components/icons/Icon.vue";
import BaseDialog from "@/components/common/BaseDialog.vue";
import PlatformIcon from "@/components/common/PlatformIcon.vue";
import RedeemCodeForm from "@/components/user/RedeemCodeForm.vue";
import UserDashboardAvailableModels from "@/components/user/dashboard/UserDashboardAvailableModels.vue";
import { modelsAPI, type GatewayModel } from "@/api/models";
import { sanitizeComplianceText } from "@/utils/complianceText";
import { formatDateOnly } from "@/utils/format";
import {
  platformAccentBarClass,
  platformBadgeClass,
  platformBorderClass,
  platformButtonClass,
  platformIconClass,
  platformLabel,
} from "@/utils/platformColors";

function displaySubscriptionGroupName(
  name: string | null | undefined,
  groupId: number,
): string {
  const sanitized = sanitizeComplianceText(name || "");
  return sanitized || `Group #${groupId}`;
}

const { t } = useI18n();
const router = useRouter();
const appStore = useAppStore();

const subscriptions = ref<UserSubscription[]>([]);
const loading = ref(true);
const availableModels = ref<GatewayModel[]>([]);
const loadingAvailableModels = ref(true);
const availableModelsError = ref(false);
const activeModelKeyCount = ref(0);
const queriedModelKeyCount = ref(0);
const failedModelKeyCount = ref(0);
const showRedeemDialog = ref(false);

function renewSubscription(subscription: UserSubscription) {
  router.push({
    path: "/purchase",
    query: { tab: "subscription", group: String(subscription.group_id) },
  });
}

async function loadSubscriptions() {
  try {
    loading.value = true;
    subscriptions.value = await subscriptionsAPI.getMySubscriptions();
  } catch (error) {
    console.error("Failed to load subscriptions:", error);
    appStore.showError(t("userSubscriptions.failedToLoad"));
  } finally {
    loading.value = false;
  }
}

async function loadAvailableModels() {
  loadingAvailableModels.value = true;
  availableModelsError.value = false;

  try {
    const res = await modelsAPI.getCurrentUserAvailableModels();
    availableModels.value = res.models;
    activeModelKeyCount.value = res.active_key_count;
    queriedModelKeyCount.value = res.queried_key_count;
    failedModelKeyCount.value = res.failed_key_count;
  } catch (error) {
    console.error("Failed to load available models:", error);
    availableModels.value = [];
    activeModelKeyCount.value = 0;
    queriedModelKeyCount.value = 0;
    failedModelKeyCount.value = 0;
    availableModelsError.value = true;
  } finally {
    loadingAvailableModels.value = false;
  }
}

async function handleRedeemSuccess() {
  await Promise.all([loadSubscriptions(), loadAvailableModels()]);
}

function getProgressWidth(
  used: number | undefined,
  limit: number | null | undefined,
): string {
  return `${getUsagePercentage(used, limit)}%`;
}

function getUsagePercentage(
  used: number | undefined,
  limit: number | null | undefined,
): number {
  if (!limit || limit === 0) return 0;
  return Math.min(((used || 0) / limit) * 100, 100);
}

function getProgressLabel(
  used: number | undefined,
  limit: number | null | undefined,
): string {
  return `${Math.round(getUsagePercentage(used, limit))}%`;
}

function formatUsd(value: number | null | undefined): string {
  return `$${(value || 0).toFixed(2)}`;
}

function getProgressBarClass(
  used: number | undefined,
  limit: number | null | undefined,
): string {
  if (!limit || limit === 0) return "bg-gray-400";
  const percentage = ((used || 0) / limit) * 100;
  if (percentage >= 90) return "bg-red-500";
  if (percentage >= 70) return "bg-orange-500";
  return "bg-emerald-500";
}

function hasUsageLimits(subscription: UserSubscription): boolean {
  return Boolean(
    subscription.group?.daily_limit_usd ||
    subscription.group?.weekly_limit_usd ||
    subscription.group?.monthly_limit_usd,
  );
}

function getSubscriptionStatusClass(
  status: UserSubscription["status"],
): string {
  switch (status) {
    case "active":
      return "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300";
    case "expired":
      return "bg-gray-100 text-gray-600 dark:bg-dark-800 dark:text-gray-400";
    case "revoked":
      return "bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300";
    default:
      return "bg-gray-100 text-gray-600 dark:bg-dark-800 dark:text-gray-400";
  }
}

function getSubscriptionStatusIcon(
  status: UserSubscription["status"],
): "checkCircle" | "clock" | "xCircle" {
  switch (status) {
    case "active":
      return "checkCircle";
    case "expired":
      return "clock";
    case "revoked":
      return "xCircle";
    default:
      return "clock";
  }
}

function formatExpirationDate(expiresAt: string): string {
  const now = new Date();
  const expires = new Date(expiresAt);
  const diff = expires.getTime() - now.getTime();
  const days = Math.ceil(diff / (1000 * 60 * 60 * 24));

  if (days < 0) {
    return t("userSubscriptions.status.expired");
  }

  const dateStr = formatDateOnly(expires);

  if (days === 0) {
    return `${dateStr} (${t("common.today")})`;
  }
  if (days === 1) {
    return `${dateStr} (${t("common.tomorrow")})`;
  }

  return t("userSubscriptions.daysRemaining", { days }) + ` (${dateStr})`;
}

function getExpirationClass(expiresAt: string): string {
  const now = new Date();
  const expires = new Date(expiresAt);
  const diff = expires.getTime() - now.getTime();
  const days = Math.ceil(diff / (1000 * 60 * 60 * 24));

  if (days <= 0) return "text-red-600 dark:text-red-400 font-medium";
  if (days <= 3) return "text-red-600 dark:text-red-400";
  if (days <= 7) return "text-orange-600 dark:text-orange-400";
  return "text-gray-700 dark:text-gray-300";
}

function formatResetTime(
  windowStart: string | null,
  windowHours: number,
): string {
  if (!windowStart) return t("userSubscriptions.windowNotActive");

  const start = new Date(windowStart);
  const end = new Date(start.getTime() + windowHours * 60 * 60 * 1000);
  const now = new Date();
  const diff = end.getTime() - now.getTime();

  if (diff <= 0) return t("userSubscriptions.windowNotActive");

  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

  if (hours > 24) {
    const days = Math.floor(hours / 24);
    const remainingHours = hours % 24;
    return `${days}d ${remainingHours}h`;
  }

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }

  return `${minutes}m`;
}

onMounted(() => {
  loadSubscriptions();
  loadAvailableModels();
});
</script>
