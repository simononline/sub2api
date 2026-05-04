<template>
  <AppLayout>
    <div class="mx-auto max-w-6xl space-y-6">
      <section
        class="overflow-hidden rounded-lg border border-gray-200 bg-white/95 shadow-card dark:border-dark-800 dark:bg-dark-900/90"
      >
        <div class="grid gap-6 p-5 md:grid-cols-[minmax(0,1.5fr)_minmax(260px,0.5fr)] md:p-6">
          <div class="min-w-0">
            <div class="mb-3 inline-flex items-center gap-2 rounded-full border border-primary-200 bg-primary-50 px-3 py-1 text-xs font-semibold text-primary-700 dark:border-primary-500/20 dark:bg-primary-950/30 dark:text-primary-200">
              <Icon name="book" size="sm" />
              一起把成本摊薄
            </div>
            <h2 class="text-2xl font-semibold tracking-normal text-gray-950 dark:text-white md:text-3xl">
              稳定用上这份合购订阅
            </h2>
            <p class="mt-3 max-w-3xl text-sm leading-7 text-gray-600 dark:text-dark-300 md:text-base">
              这里把为什么开放、怎么加入订阅、如何配置 cc-switch 和 API Key 都说清楚。少一点折腾和额度焦虑，多一点能长期安心使用的确定感。
            </p>
          </div>

          <div class="flex flex-col justify-center gap-3 rounded-lg border border-gray-100 bg-gray-50/80 p-4 dark:border-dark-700 dark:bg-dark-800/60">
            <div class="text-xs font-semibold uppercase tracking-normal text-gray-500 dark:text-dark-400">
              国际请求 API 地址
            </div>
            <div class="flex flex-col gap-2 sm:flex-row sm:items-stretch">
              <code class="min-w-0 flex-1 break-all rounded-md bg-white px-3 py-2 font-mono text-sm font-semibold text-primary-700 ring-1 ring-gray-200 dark:bg-dark-950 dark:text-primary-200 dark:ring-dark-700">
                https://openai945.cn/
              </code>
              <a
                :href="apiSpeedTestUrl"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex shrink-0 items-center justify-center gap-1.5 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm font-semibold text-amber-700 transition-colors hover:border-amber-300 hover:bg-amber-100 dark:border-amber-500/30 dark:bg-amber-950/30 dark:text-amber-200 dark:hover:border-amber-400/40 dark:hover:bg-amber-900/40"
                aria-label="打开国际请求 API 地址测速"
              >
                <Icon name="bolt" size="sm" />
                测速
              </a>
            </div>
            <p class="text-xs leading-5 text-gray-500 dark:text-dark-400">
              在客户端配置中请保留末尾斜杠，API Key 使用控制台中创建的密钥。
            </p>
          </div>
        </div>
      </section>

      <nav
        class="grid grid-cols-1 gap-3 sm:grid-cols-3"
        aria-label="文档章节"
      >
        <router-link
          v-for="section in docSections"
          :key="section.id"
          :to="{ path: '/docs', hash: `#${section.id}` }"
          class="group rounded-lg border bg-white/95 p-4 text-left shadow-card transition-all hover:-translate-y-0.5 hover:shadow-card-hover dark:bg-dark-900/90"
          :class="activeSectionId === section.id
            ? 'border-primary-300 ring-2 ring-primary-500/15 dark:border-primary-500/40'
            : 'border-gray-200 hover:border-primary-200 dark:border-dark-800 dark:hover:border-primary-500/30'"
          :aria-current="activeSectionId === section.id ? 'page' : undefined"
        >
          <div class="flex items-start gap-3">
            <div
              class="grid h-10 w-10 shrink-0 place-items-center rounded-lg border transition-colors"
              :class="activeSectionId === section.id
                ? 'border-primary-200 bg-primary-50 text-primary-700 dark:border-primary-500/20 dark:bg-primary-950/30 dark:text-primary-200'
                : 'border-gray-200 bg-gray-50 text-gray-500 group-hover:text-primary-600 dark:border-dark-700 dark:bg-dark-800 dark:text-dark-300 dark:group-hover:text-primary-300'"
            >
              <Icon :name="section.icon" size="md" />
            </div>
            <div class="min-w-0">
              <div class="text-base font-semibold text-gray-950 dark:text-white">
                {{ section.label }}
              </div>
              <p class="mt-1 text-sm leading-5 text-gray-500 dark:text-dark-400">
                {{ section.summary }}
              </p>
            </div>
          </div>
        </router-link>
      </nav>

      <HeartfeltIntro v-if="activeSectionId === 'intro'" section-id="intro" />

      <section
        v-else-if="activeSectionId === 'purchase'"
        id="purchase"
        class="rounded-lg border border-gray-200 bg-white/95 p-5 shadow-card dark:border-dark-800 dark:bg-dark-900/90 md:p-6"
      >
        <div class="mb-5 flex items-center gap-3">
          <div class="grid h-11 w-11 place-items-center rounded-lg border border-orange-200 bg-orange-50 text-orange-600 dark:border-orange-500/20 dark:bg-orange-950/30 dark:text-orange-200">
            <Icon name="creditCard" size="lg" />
          </div>
          <div>
            <h3 class="text-xl font-semibold text-gray-950 dark:text-white">加入订阅</h3>
            <p class="text-sm text-gray-500 dark:text-dark-400">参与进来，其实大家是在一起合购</p>
          </div>
        </div>

        <ol class="space-y-4">
          <li
            v-for="(step, index) in purchaseSteps"
            :key="step.title"
            class="flex gap-4 rounded-lg border border-gray-100 bg-gray-50/70 p-4 dark:border-dark-800 dark:bg-dark-800/50"
          >
            <div class="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-orange-500 text-sm font-bold text-white">
              {{ index + 1 }}
            </div>
            <div class="min-w-0">
              <h4 class="font-semibold text-gray-950 dark:text-white">{{ step.title }}</h4>
              <p class="mt-1 text-sm leading-6 text-gray-600 dark:text-dark-300">{{ step.description }}</p>
            </div>
          </li>
        </ol>

        <div class="mt-6 flex flex-col gap-3 sm:flex-row">
          <router-link
            to="/subscriptions"
            class="inline-flex items-center justify-center gap-2 rounded-lg bg-primary-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700"
          >
            打开我的订阅
            <Icon name="arrowRight" size="sm" />
          </router-link>
          <router-link
            to="/redeem"
            class="inline-flex items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2.5 text-sm font-semibold text-gray-700 shadow-sm transition-colors hover:bg-gray-50 dark:border-dark-700 dark:bg-dark-800 dark:text-dark-100 dark:hover:bg-dark-700"
          >
            进入兑换页面
            <Icon name="key" size="sm" />
          </router-link>
        </div>
      </section>

      <section
        v-else
        id="prerequisites"
        class="rounded-lg border border-gray-200 bg-white/95 p-5 shadow-card dark:border-dark-800 dark:bg-dark-900/90 md:p-6"
      >
        <div class="mb-5 flex items-center gap-3">
          <div class="grid h-11 w-11 place-items-center rounded-lg border border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-500/20 dark:bg-emerald-950/30 dark:text-emerald-200">
            <Icon name="terminal" size="lg" />
          </div>
          <div>
            <h3 class="text-xl font-semibold text-gray-950 dark:text-white">推荐配置</h3>
            <p class="text-sm text-gray-500 dark:text-dark-400">使用 cc-switch 统一管理多客户端配置</p>
          </div>
        </div>

        <div class="space-y-5">
          <div class="rounded-lg border border-gray-100 bg-gray-50/70 p-4 dark:border-dark-800 dark:bg-dark-800/50">
            <h4 class="font-semibold text-gray-950 dark:text-white">安装最佳切换方案 cc-switch</h4>
            <p class="mt-2 text-sm leading-6 text-gray-600 dark:text-dark-300">
              如果你希望更顺手地切换和管理客户端配置，建议先安装 cc-switch。安装和基础配置请参考
              <a
                href="https://github.com/farion1231/cc-switch"
                target="_blank"
                rel="noopener noreferrer"
                class="font-semibold text-primary-700 underline-offset-4 hover:underline dark:text-primary-300"
              >
                cc-switch 开源项目
              </a>
              。这是目前最推荐的切换方案，能够一键帮你切换 Claude、Codex、OpenCode 的配置，也支持 OpenClaw、Hermes 等工具的配置管理。
            </p>
          </div>

          <div class="rounded-lg border border-gray-100 bg-gray-50/70 p-4 dark:border-dark-800 dark:bg-dark-800/50">
            <h4 class="font-semibold text-gray-950 dark:text-white">填写本站 API 地址</h4>
            <p class="mt-2 text-sm leading-6 text-gray-600 dark:text-dark-300">
              本网站国际请求 API 地址为：
            </p>
            <code class="mt-3 block break-all rounded-md bg-white px-3 py-2 font-mono text-sm font-semibold text-emerald-700 ring-1 ring-gray-200 dark:bg-dark-950 dark:text-emerald-200 dark:ring-dark-700">
              https://openai945.cn/
            </code>
            <p class="mt-2 text-sm leading-6 text-gray-600 dark:text-dark-300">
              在 cc-switch 或其他兼容客户端里，把 Base URL、API Base 或接口地址填写为上面的地址。
            </p>
          </div>

          <div class="rounded-lg border border-gray-100 bg-gray-50/70 p-4 dark:border-dark-800 dark:bg-dark-800/50">
            <h4 class="font-semibold text-gray-950 dark:text-white">获取 API Key</h4>
            <ol class="mt-3 space-y-3 text-sm leading-6 text-gray-600 dark:text-dark-300">
              <li>1. 登录控制台后进入 <router-link to="/keys" class="font-semibold text-primary-700 underline-offset-4 hover:underline dark:text-primary-300">API 密钥</router-link> 页面。</li>
              <li>2. 点击创建密钥，按需要填写名称、额度或分组等信息。</li>
              <li>3. 创建成功后复制生成的 Key，通常以 <code class="rounded bg-gray-100 px-1.5 py-0.5 font-mono text-xs text-gray-800 dark:bg-dark-700 dark:text-dark-100">sk-</code> 开头。</li>
              <li>4. 在 cc-switch 或客户端配置里，将这个 Key 填入 API Key、Token 或 Authorization Key 字段。</li>
            </ol>
            <div class="mt-4 rounded-lg border border-amber-200 bg-amber-50/80 px-3 py-2.5 text-sm leading-6 text-amber-900 dark:border-amber-500/25 dark:bg-amber-950/25 dark:text-amber-100">
              <span class="font-semibold">温馨提示：</span>需要先拥有可用套餐，才能配置并使用自己的 API Key。
            </div>
          </div>

          <div class="rounded-lg border border-primary-200 bg-primary-50/80 p-4 text-sm leading-6 text-primary-900 dark:border-primary-500/20 dark:bg-primary-950/25 dark:text-primary-100">
            配置完成后，可以先用一个简单请求或客户端自带测试功能验证连通性。如果提示鉴权失败，请优先检查 API Key 是否复制完整、Base URL 是否填写为本站地址。
          </div>

          <div class="rounded-lg border border-gray-100 bg-gray-50/70 p-4 dark:border-dark-800 dark:bg-dark-800/50">
            <h4 class="font-semibold text-gray-950 dark:text-white">如何知道自己能用哪些模型</h4>
            <p class="mt-2 text-sm leading-6 text-gray-600 dark:text-dark-300">
              当前 Key 可用的模型会跟随你的套餐和号池状态变化。你可以 1. 前往
              <router-link
                to="/subscriptions"
                class="mx-1 inline-flex items-center justify-center rounded-md bg-primary-600 px-2.5 py-1 text-xs font-semibold text-white shadow-sm transition-colors hover:bg-primary-700"
              >
                我的订阅
              </router-link>
              查看套餐说明，2. 也可以使用 cc-switch 的
              <span class="rounded bg-emerald-50 px-1.5 py-0.5 font-semibold text-emerald-800 dark:bg-emerald-500/15 dark:text-emerald-100">「获取模型列表」</span>
              功能，自动导入当前 Key 可用的模型配置。
            </p>
          </div>
        </div>
      </section>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppLayout from '@/components/layout/AppLayout.vue'
import Icon from '@/components/icons/Icon.vue'
import HeartfeltIntro from '@/components/marketing/HeartfeltIntro.vue'

const docSections = [
  {
    id: 'intro',
    label: '心里话',
    summary: '从自用到合购，只想把成本摊薄、把稳定留给大家。',
    icon: 'book'
  },
  {
    id: 'purchase',
    label: '加入订阅',
    summary: '参与进来，其实大家是在一起合购。',
    icon: 'creditCard'
  },
  {
    id: 'prerequisites',
    label: '推荐配置',
    summary: '用 cc-switch 一键切换多客户端配置。',
    icon: 'terminal'
  }
] as const

type SectionId = typeof docSections[number]['id']

const route = useRoute()
const sectionIds = docSections.map((section) => section.id)
const apiSpeedTestUrl = 'https://www.tcptest.cn/http/https://openai945.cn'

const activeSectionId = computed<SectionId>(() => {
  const hashSection = route.hash.replace(/^#/, '')
  return sectionIds.includes(hashSection as SectionId) ? hashSection as SectionId : 'intro'
})

const purchaseSteps = [
  {
    title: '进入我的订阅',
    description: '登录控制台后打开「我的订阅」页面，也可以直接访问 /subscriptions。这里会展示当前套餐、可用额度和购买入口。'
  },
  {
    title: '购买套餐',
    description: '在页面中点击「购买套餐」，前往发卡网选择适合自己的套餐并完成购买。'
  },
  {
    title: '获取兑换卡密',
    description: '支付完成后，在发卡网订单信息中获取兑换卡密。请完整复制，避免多复制空格或漏掉字符。'
  },
  {
    title: '回填并兑换',
    description: '回到控制台，在订阅页的兑换入口或「兑换码」页面粘贴卡密并提交，系统会为账号发放对应套餐。'
  }
]
</script>
