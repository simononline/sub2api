<template>
  <!-- Custom Home Content: Full Page Mode -->
  <div v-if="homeContent" class="min-h-screen">
    <!-- iframe mode -->
    <iframe
      v-if="isHomeContentUrl"
      :src="homeContent.trim()"
      class="h-screen w-full border-0"
      allowfullscreen
    ></iframe>
    <!-- HTML mode - SECURITY: homeContent is admin-only setting, XSS risk is acceptable -->
    <div v-else v-html="homeContent"></div>
  </div>

  <!-- Default Home Page -->
  <div
    v-else
    class="relative flex min-h-screen flex-col overflow-hidden bg-gray-50 text-gray-900 dark:bg-dark-900 dark:text-dark-50"
  >
    <!-- Background Texture -->
    <div class="pointer-events-none absolute inset-0 overflow-hidden">
      <div
        class="absolute inset-0 bg-mesh-gradient bg-[size:72px_72px] opacity-80"
      ></div>
      <div
        class="absolute inset-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.92),rgba(255,255,255,0.58)_40%,rgba(255,255,255,0.9))] dark:bg-[linear-gradient(180deg,rgba(23,23,23,0.16),rgba(23,23,23,0.26)_42%,rgba(15,15,15,0.74))]"
      ></div>
    </div>

    <!-- Header -->
    <header class="relative z-20 px-6 py-4">
      <nav class="mx-auto flex max-w-6xl items-center justify-between">
        <!-- Logo -->
        <div class="flex items-center">
          <div class="h-10 w-10 overflow-hidden rounded-lg border border-primary-400/30 bg-dark-950/5 dark:bg-dark-950">
            <img :src="siteLogo || '/logo.png'" alt="Logo" class="h-full w-full object-contain" />
          </div>
        </div>

        <!-- Nav Actions -->
        <div class="flex items-center gap-3">
          <!-- Language Switcher -->
          <LocaleSwitcher />

          <!-- Doc Link -->
          <a
            v-if="docUrl"
            :href="docUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="rounded-md border border-transparent p-2 text-gray-500 transition-colors hover:border-gray-200 hover:bg-gray-100 hover:text-gray-900 dark:text-dark-400 dark:hover:border-dark-800 dark:hover:bg-dark-800 dark:hover:text-dark-50"
            :title="t('home.viewDocs')"
          >
            <Icon name="book" size="md" />
          </a>

          <!-- Theme Toggle -->
          <button
            @click="toggleTheme"
            class="rounded-md border border-transparent p-2 text-gray-500 transition-colors hover:border-gray-200 hover:bg-gray-100 hover:text-gray-900 dark:text-dark-400 dark:hover:border-dark-800 dark:hover:bg-dark-800 dark:hover:text-dark-50"
            :title="isDark ? t('home.switchToLight') : t('home.switchToDark')"
          >
            <Icon v-if="isDark" name="sun" size="md" />
            <Icon v-else name="moon" size="md" />
          </button>

          <!-- Login / Dashboard Button -->
          <router-link
            v-if="isAuthenticated"
            :to="dashboardPath"
            class="inline-flex items-center gap-1.5 rounded-full border border-gray-950 bg-gray-950 py-1 pl-1 pr-2.5 transition-colors hover:border-primary-400 dark:border-dark-50 dark:bg-dark-950 dark:hover:border-primary-400"
          >
            <span
              class="flex h-5 w-5 items-center justify-center rounded-full bg-primary-500 text-[10px] font-medium text-dark-950"
            >
              {{ userInitial }}
            </span>
            <span class="text-xs font-medium text-white">{{ t('home.dashboard') }}</span>
            <svg
              class="h-3 w-3 text-gray-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M4.5 19.5l15-15m0 0H8.25m11.25 0v11.25"
              />
            </svg>
          </router-link>
          <router-link
            v-else
            to="/login"
            class="inline-flex items-center rounded-full border border-gray-950 bg-gray-950 px-4 py-1.5 text-xs font-medium text-white transition-colors hover:border-primary-400 dark:border-dark-50 dark:bg-dark-950"
          >
            {{ t('home.login') }}
          </router-link>
        </div>
      </nav>
    </header>

    <!-- Main Content -->
    <main class="relative z-10 flex-1 px-6 py-14 md:py-20">
      <div class="mx-auto max-w-6xl">
        <!-- Pool Notice -->
        <div
          class="mb-8 flex flex-col gap-3 rounded-lg border border-primary-400/30 bg-primary-500/10 p-4 text-sm text-primary-800 backdrop-blur-sm dark:text-primary-200 sm:flex-row sm:items-center"
        >
          <div
            class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-primary-400/30 bg-white/70 text-primary-600 dark:bg-dark-950/70 dark:text-primary-400"
          >
            <Icon name="server" size="md" />
          </div>
          <p class="leading-6">
            {{ t('home.poolNotice') }}
          </p>
        </div>

        <!-- Hero Section - Left/Right Layout -->
        <div class="mb-14 flex flex-col items-center justify-between gap-12 lg:flex-row lg:gap-16">
          <!-- Left: Text Content -->
          <div class="flex-1 text-center lg:text-left">
            <div
              class="mb-4 inline-flex items-center gap-2 rounded-full border border-primary-400/30 bg-primary-500/10 px-3 py-1 text-xs font-medium text-primary-700 dark:text-primary-300"
            >
              <Icon name="sparkles" size="sm" />
              <span>{{ t('home.heroBadge') }}</span>
            </div>
            <h1
              class="mb-5 text-5xl font-normal leading-none text-gray-950 dark:text-dark-50 md:text-6xl lg:text-hero"
            >
              {{ siteName }}
            </h1>
            <p class="mb-8 max-w-xl text-base leading-7 text-gray-600 dark:text-dark-300 md:text-lg">
              {{ siteSubtitle }}
            </p>
            <p class="mb-8 max-w-xl text-sm leading-6 text-gray-500 dark:text-dark-400 md:text-base">
              {{ t('home.heroDescription') }}
            </p>

            <!-- CTA Button -->
            <div class="flex flex-col items-center gap-3 sm:flex-row lg:justify-start">
              <router-link
                :to="isAuthenticated ? dashboardPath : '/login'"
                class="btn btn-primary px-8 py-3 text-base"
              >
                {{ isAuthenticated ? t('home.goToDashboard') : t('home.getStarted') }}
                <Icon name="arrowRight" size="md" class="ml-2" :stroke-width="2" />
              </router-link>
              <a
                v-if="docUrl"
                :href="docUrl"
                target="_blank"
                rel="noopener noreferrer"
                class="btn btn-secondary px-6 py-3 text-base"
              >
                {{ t('home.viewDocs') }}
              </a>
            </div>
          </div>

          <!-- Right: Terminal Animation -->
          <div class="flex flex-1 justify-center lg:justify-end">
            <div class="terminal-container">
              <div class="terminal-window">
                <!-- Window header -->
                <div class="terminal-header">
                  <div class="terminal-buttons">
                    <span class="btn-close"></span>
                    <span class="btn-minimize"></span>
                    <span class="btn-maximize"></span>
                  </div>
                  <span class="terminal-title">terminal</span>
                </div>
                <!-- Terminal content -->
                <div class="terminal-body">
                  <div class="code-line line-1">
                    <span class="code-prompt">$</span>
                    <span class="code-cmd">curl</span>
                    <span class="code-flag">-X POST</span>
                    <span class="code-url">/v1/chat/completions</span>
                  </div>
                  <div class="code-line line-2">
                    <span class="code-comment"># GPT pool routing...</span>
                  </div>
                  <div class="code-line line-3">
                    <span class="code-success">200 OK</span>
                    <span class="code-response">{ "model": "gpt-*" }</span>
                  </div>
                  <div class="code-line line-4">
                    <span class="code-prompt">$</span>
                    <span class="cursor"></span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Feature Tags - Centered -->
        <div class="mb-12 flex flex-wrap items-center justify-center gap-4 md:gap-6">
          <div
            class="inline-flex items-center gap-2.5 rounded-full border border-gray-200 bg-white/80 px-5 py-2.5 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-950/80"
          >
            <Icon name="swap" size="sm" class="text-primary-500" />
            <span class="text-sm font-medium text-gray-700 dark:text-dark-200">{{
              t('home.tags.subscriptionToApi')
            }}</span>
          </div>
          <div
            class="inline-flex items-center gap-2.5 rounded-full border border-gray-200 bg-white/80 px-5 py-2.5 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-950/80"
          >
            <Icon name="shield" size="sm" class="text-primary-500" />
            <span class="text-sm font-medium text-gray-700 dark:text-dark-200">{{
              t('home.tags.stickySession')
            }}</span>
          </div>
          <div
            class="inline-flex items-center gap-2.5 rounded-full border border-gray-200 bg-white/80 px-5 py-2.5 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-950/80"
          >
            <Icon name="chart" size="sm" class="text-primary-500" />
            <span class="text-sm font-medium text-gray-700 dark:text-dark-200">{{
              t('home.tags.realtimeBilling')
            }}</span>
          </div>
          <div
            class="inline-flex items-center gap-2.5 rounded-full border border-gray-200 bg-white/80 px-5 py-2.5 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-950/80"
          >
            <Icon name="users" size="sm" class="text-primary-500" />
            <span class="text-sm font-medium text-gray-700 dark:text-dark-200">{{
              t('home.tags.engineerSupport')
            }}</span>
          </div>
        </div>

        <!-- Features Grid -->
        <div class="mb-12 grid gap-6 md:grid-cols-3">
          <!-- Feature 1: Unified Gateway -->
          <div
            class="group rounded-lg border border-gray-200 bg-white/75 p-6 backdrop-blur-sm transition-colors duration-200 hover:border-primary-400/50 dark:border-dark-800 dark:bg-dark-900/80"
          >
            <div
              class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg border border-primary-400/30 bg-primary-500/10 text-primary-500"
            >
              <Icon name="server" size="lg" />
            </div>
            <h3 class="mb-2 text-lg font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.features.unifiedGateway') }}
            </h3>
            <p class="text-sm leading-relaxed text-gray-600 dark:text-dark-400">
              {{ t('home.features.unifiedGatewayDesc') }}
            </p>
          </div>

          <!-- Feature 2: Account Pool -->
          <div
            class="group rounded-lg border border-gray-200 bg-white/75 p-6 backdrop-blur-sm transition-colors duration-200 hover:border-primary-400/50 dark:border-dark-800 dark:bg-dark-900/80"
          >
            <div
              class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg border border-primary-400/30 bg-primary-500/10 text-primary-500"
            >
              <svg
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z"
                />
              </svg>
            </div>
            <h3 class="mb-2 text-lg font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.features.multiAccount') }}
            </h3>
            <p class="text-sm leading-relaxed text-gray-600 dark:text-dark-400">
              {{ t('home.features.multiAccountDesc') }}
            </p>
          </div>

          <!-- Feature 3: Billing & Quota -->
          <div
            class="group rounded-lg border border-gray-200 bg-white/75 p-6 backdrop-blur-sm transition-colors duration-200 hover:border-primary-400/50 dark:border-dark-800 dark:bg-dark-900/80"
          >
            <div
              class="mb-4 flex h-12 w-12 items-center justify-center rounded-lg border border-primary-400/30 bg-primary-500/10 text-primary-500"
            >
              <svg
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="1.5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z"
                />
              </svg>
            </div>
            <h3 class="mb-2 text-lg font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.features.balanceQuota') }}
            </h3>
            <p class="text-sm leading-relaxed text-gray-600 dark:text-dark-400">
              {{ t('home.features.balanceQuotaDesc') }}
            </p>
          </div>
        </div>

        <!-- GPT Service Scope -->
        <section class="mb-16">
          <div class="mb-8 text-center">
            <h2 class="mb-3 text-2xl font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.providers.title') }}
            </h2>
            <p class="text-sm text-gray-600 dark:text-dark-400">
              {{ t('home.providers.description') }}
            </p>
          </div>

          <div class="grid gap-4 md:grid-cols-3">
            <div
              v-for="service in gptServiceCards"
              :key="service.title"
              class="rounded-lg border border-gray-200 bg-white/70 p-5 backdrop-blur-sm transition-colors hover:border-primary-400/50 dark:border-dark-800 dark:bg-dark-950/70"
            >
              <div class="mb-4 flex items-center justify-between gap-3">
                <div
                  :class="[
                    'flex h-10 w-10 items-center justify-center rounded-lg border',
                    service.iconClass
                  ]"
                >
                  <Icon :name="service.icon" size="md" />
                </div>
                <span
                  class="rounded bg-primary-100 px-2 py-1 text-[10px] font-medium text-primary-600 dark:bg-primary-900/30 dark:text-primary-400"
                >
                  {{ t('home.providers.supported') }}
                </span>
              </div>
              <h3 class="mb-2 text-base font-normal text-gray-950 dark:text-dark-50">
                {{ service.title }}
              </h3>
              <p class="text-sm leading-6 text-gray-600 dark:text-dark-400">
                {{ service.description }}
              </p>
            </div>
          </div>
        </section>

        <!-- Supported Models -->
        <section class="mb-16">
          <div class="mb-8 text-center">
            <h2 class="mb-3 text-2xl font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.supportedModels.title') }}
            </h2>
            <p class="text-sm text-gray-600 dark:text-dark-400">
              {{ t('home.supportedModels.description') }}
            </p>
          </div>

          <div
            class="rounded-lg border border-gray-200 bg-white/70 p-5 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-950/70"
          >
            <div class="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
              <div class="flex items-center gap-2 text-sm text-gray-600 dark:text-dark-300">
                <Icon name="database" size="sm" class="text-primary-500" />
                <span>
                  {{ modelsLoading
                    ? t('home.supportedModels.loading')
                    : t('home.supportedModels.count', { count: displayedSupportedModels.length }) }}
                </span>
              </div>
              <span
                class="text-xs text-gray-500 dark:text-dark-400"
              >
                {{ modelsFromFallback
                  ? t('home.supportedModels.fallback')
                  : t('home.supportedModels.live') }}
              </span>
            </div>

            <div
              v-if="displayedSupportedModels.length > 0"
              class="flex max-h-56 flex-wrap gap-2 overflow-y-auto pr-1"
            >
              <span
                v-for="model in displayedSupportedModels"
                :key="`${model.platform}:${model.name}`"
                class="inline-flex items-center gap-2 rounded-full border border-gray-200 bg-white/80 px-3 py-1.5 text-xs font-medium text-gray-700 dark:border-dark-800 dark:bg-dark-900/80 dark:text-dark-200"
              >
                <span>{{ model.name }}</span>
                <span
                  v-if="model.channel_count > 0"
                  class="rounded-full bg-primary-100 px-1.5 py-0.5 text-[10px] text-primary-700 dark:bg-primary-900/30 dark:text-primary-300"
                >
                  {{ t('home.supportedModels.channelCount', { count: model.channel_count }) }}
                </span>
              </span>
            </div>
            <div v-else class="py-6 text-center text-sm text-gray-500 dark:text-dark-400">
              {{ t('home.supportedModels.empty') }}
            </div>
          </div>
        </section>

        <!-- Service Highlights -->
        <section class="mb-16">
          <div class="mb-8 text-center">
            <h2 class="mb-3 text-2xl font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.serviceHighlights.title') }}
            </h2>
            <p class="text-sm text-gray-600 dark:text-dark-400">
              {{ t('home.serviceHighlights.description') }}
            </p>
          </div>

          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div
              v-for="item in highlightCards"
              :key="item.title"
              class="rounded-lg border border-gray-200 bg-white/65 p-5 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-900/70"
            >
              <Icon :name="item.icon" size="lg" class="mb-4 text-primary-500" />
              <h3 class="mb-2 text-base font-normal text-gray-950 dark:text-dark-50">
                {{ item.title }}
              </h3>
              <p class="text-sm leading-6 text-gray-600 dark:text-dark-400">
                {{ item.description }}
              </p>
            </div>
          </div>
        </section>

        <!-- Workflow -->
        <section class="mb-16">
          <div class="mb-8 text-center">
            <h2 class="mb-3 text-2xl font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.workflow.title') }}
            </h2>
            <p class="text-sm text-gray-600 dark:text-dark-400">
              {{ t('home.workflow.description') }}
            </p>
          </div>

          <div class="grid gap-4 md:grid-cols-3">
            <div
              v-for="step in workflowSteps"
              :key="step.number"
              class="rounded-lg border border-gray-200 bg-white/70 p-6 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-950/70"
            >
              <div class="mb-4 font-mono text-xs text-primary-600 dark:text-primary-400">
                {{ step.number }}
              </div>
              <h3 class="mb-2 text-lg font-normal text-gray-950 dark:text-dark-50">
                {{ step.title }}
              </h3>
              <p class="text-sm leading-6 text-gray-600 dark:text-dark-400">
                {{ step.description }}
              </p>
            </div>
          </div>
        </section>

        <!-- Comparison -->
        <section class="mb-16">
          <div class="mb-8 text-center">
            <h2 class="mb-3 text-2xl font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.comparison.title') }}
            </h2>
          </div>

          <div
            class="overflow-hidden rounded-lg border border-gray-200 bg-white/70 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-950/70"
          >
            <div
              class="hidden grid-cols-[1.1fr_1fr_1fr] border-b border-gray-200 bg-gray-100/70 text-xs font-medium uppercase text-gray-500 dark:border-dark-800 dark:bg-dark-900/80 dark:text-dark-400 md:grid"
            >
              <div class="px-5 py-3">{{ t('home.comparison.headers.feature') }}</div>
              <div class="px-5 py-3">{{ t('home.comparison.headers.official') }}</div>
              <div class="px-5 py-3">{{ t('home.comparison.headers.us') }}</div>
            </div>
            <div
              v-for="row in comparisonRows"
              :key="row.feature"
              class="grid gap-3 border-b border-gray-100 px-5 py-4 last:border-0 dark:border-dark-800 md:grid-cols-[1.1fr_1fr_1fr] md:gap-0 md:px-0 md:py-0"
            >
              <div class="font-medium text-gray-950 dark:text-dark-50 md:px-5 md:py-4">
                {{ row.feature }}
              </div>
              <div class="text-sm text-gray-500 dark:text-dark-400 md:px-5 md:py-4">
                <span class="mb-1 block text-xs font-medium uppercase text-gray-400 md:hidden">
                  {{ t('home.comparison.headers.official') }}
                </span>
                {{ row.official }}
              </div>
              <div class="text-sm text-primary-700 dark:text-primary-300 md:px-5 md:py-4">
                <span class="mb-1 block text-xs font-medium uppercase text-gray-400 md:hidden">
                  {{ t('home.comparison.headers.us') }}
                </span>
                {{ row.us }}
              </div>
            </div>
          </div>
        </section>

        <!-- FAQ -->
        <section class="mb-16">
          <div class="mb-8 text-center">
            <h2 class="mb-3 text-2xl font-normal text-gray-950 dark:text-dark-50">
              {{ t('home.faq.title') }}
            </h2>
            <p class="text-sm text-gray-600 dark:text-dark-400">
              {{ t('home.faq.description') }}
            </p>
          </div>

          <div class="grid gap-4 md:grid-cols-2">
            <div
              v-for="item in faqItems"
              :key="item.question"
              class="rounded-lg border border-gray-200 bg-white/65 p-5 backdrop-blur-sm dark:border-dark-800 dark:bg-dark-900/70"
            >
              <h3 class="mb-2 text-base font-normal text-gray-950 dark:text-dark-50">
                {{ item.question }}
              </h3>
              <p class="text-sm leading-6 text-gray-600 dark:text-dark-400">
                {{ item.answer }}
              </p>
            </div>
          </div>
        </section>

        <!-- CTA -->
        <section class="border-y border-gray-200 py-10 text-center dark:border-dark-800">
          <h2 class="mb-3 text-2xl font-normal text-gray-950 dark:text-dark-50">
            {{ t('home.cta.title') }}
          </h2>
          <p class="mx-auto mb-6 max-w-2xl text-sm leading-6 text-gray-600 dark:text-dark-400">
            {{ t('home.cta.description') }}
          </p>
          <router-link
            :to="isAuthenticated ? dashboardPath : '/login'"
            class="btn btn-primary px-8 py-3 text-base"
          >
            {{ isAuthenticated ? t('home.goToDashboard') : t('home.cta.button') }}
            <Icon name="arrowRight" size="md" class="ml-2" :stroke-width="2" />
          </router-link>
        </section>
      </div>
    </main>

    <!-- Footer -->
    <footer class="relative z-10 border-t border-gray-200 px-6 py-8 dark:border-dark-800">
      <div
        class="mx-auto flex max-w-6xl flex-col items-center justify-center gap-4 text-center sm:flex-row sm:text-left"
      >
        <p class="text-sm text-gray-500 dark:text-dark-400">
          &copy; {{ currentYear }} {{ siteName }}. {{ t('home.footer.allRightsReserved') }}
        </p>
        <div class="flex items-center gap-4">
          <a
            v-if="docUrl"
            :href="docUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="text-sm text-gray-500 transition-colors hover:text-gray-700 dark:text-dark-400 dark:hover:text-white"
          >
            {{ t('home.docs') }}
          </a>
          <a
            :href="githubUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="text-sm text-gray-500 transition-colors hover:text-gray-700 dark:text-dark-400 dark:hover:text-white"
          >
            GitHub
          </a>
        </div>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAuthStore, useAppStore } from '@/stores'
import LocaleSwitcher from '@/components/common/LocaleSwitcher.vue'
import Icon from '@/components/icons/Icon.vue'
import userChannelsAPI, { type PublicSupportedModel } from '@/api/channels'
import { getModelsByPlatform } from '@/composables/useModelWhitelist'

const { t } = useI18n()

type HomeIconName =
  | 'brain'
  | 'server'
  | 'shield'
  | 'bolt'
  | 'users'
  | 'chart'
  | 'key'
  | 'terminal'
  | 'creditCard'
  | 'chat'
  | 'clock'
  | 'badge'

const authStore = useAuthStore()
const appStore = useAppStore()
const supportedModels = ref<PublicSupportedModel[]>([])
const modelsLoading = ref(false)
const modelsFromFallback = ref(true)

// Site settings - directly from appStore (already initialized from injected config)
const siteName = computed(() => appStore.cachedPublicSettings?.site_name || appStore.siteName || 'WeShare')
const siteLogo = computed(() => appStore.cachedPublicSettings?.site_logo || appStore.siteLogo || '')
const siteSubtitle = computed(() => appStore.cachedPublicSettings?.site_subtitle || t('home.heroSubtitle'))
const docUrl = computed(() => appStore.cachedPublicSettings?.doc_url || appStore.docUrl || '')
const homeContent = computed(() => appStore.cachedPublicSettings?.home_content || '')

const gptServiceCards = computed<Array<{
  icon: HomeIconName
  iconClass: string
  title: string
  description: string
}>>(() => [
  {
    icon: 'brain',
    iconClass: 'border-primary-500/30 bg-primary-500/10 text-primary-500',
    title: t('home.providers.gptCore'),
    description: t('home.providers.gptCoreDesc')
  },
  {
    icon: 'terminal',
    iconClass: 'border-blue-500/30 bg-blue-500/10 text-blue-500',
    title: t('home.providers.openaiCompatible'),
    description: t('home.providers.openaiCompatibleDesc')
  },
  {
    icon: 'chart',
    iconClass: 'border-amber-500/30 bg-amber-500/10 text-amber-500',
    title: t('home.providers.usageControl'),
    description: t('home.providers.usageControlDesc')
  }
])

const highlightCards = computed<Array<{
  icon: HomeIconName
  title: string
  description: string
}>>(() => [
  {
    icon: 'server',
    title: t('home.serviceHighlights.items.pool.title'),
    description: t('home.serviceHighlights.items.pool.desc')
  },
  {
    icon: 'bolt',
    title: t('home.serviceHighlights.items.speed.title'),
    description: t('home.serviceHighlights.items.speed.desc')
  },
  {
    icon: 'shield',
    title: t('home.serviceHighlights.items.security.title'),
    description: t('home.serviceHighlights.items.security.desc')
  },
  {
    icon: 'users',
    title: t('home.serviceHighlights.items.support.title'),
    description: t('home.serviceHighlights.items.support.desc')
  }
])

const workflowSteps = computed(() => [
  {
    number: '01',
    title: t('home.workflow.steps.createKey.title'),
    description: t('home.workflow.steps.createKey.desc')
  },
  {
    number: '02',
    title: t('home.workflow.steps.callApi.title'),
    description: t('home.workflow.steps.callApi.desc')
  },
  {
    number: '03',
    title: t('home.workflow.steps.monitor.title'),
    description: t('home.workflow.steps.monitor.desc')
  }
])

const comparisonRows = computed(() => [
  {
    feature: t('home.comparison.items.pricing.feature'),
    official: t('home.comparison.items.pricing.official'),
    us: t('home.comparison.items.pricing.us')
  },
  {
    feature: t('home.comparison.items.models.feature'),
    official: t('home.comparison.items.models.official'),
    us: t('home.comparison.items.models.us')
  },
  {
    feature: t('home.comparison.items.management.feature'),
    official: t('home.comparison.items.management.official'),
    us: t('home.comparison.items.management.us')
  },
  {
    feature: t('home.comparison.items.stability.feature'),
    official: t('home.comparison.items.stability.official'),
    us: t('home.comparison.items.stability.us')
  },
  {
    feature: t('home.comparison.items.control.feature'),
    official: t('home.comparison.items.control.official'),
    us: t('home.comparison.items.control.us')
  }
])

const faqItems = computed(() => [
  {
    question: t('home.faq.items.difference.question'),
    answer: t('home.faq.items.difference.answer')
  },
  {
    question: t('home.faq.items.compatibility.question'),
    answer: t('home.faq.items.compatibility.answer')
  },
  {
    question: t('home.faq.items.security.question'),
    answer: t('home.faq.items.security.answer')
  },
  {
    question: t('home.faq.items.support.question'),
    answer: t('home.faq.items.support.answer')
  }
])

const fallbackOpenAIModels = getModelsByPlatform('openai').map((name) => ({
  name,
  platform: 'openai',
  channel_count: 0
}))

const displayedSupportedModels = computed(() => (
  supportedModels.value.length > 0 ? supportedModels.value : fallbackOpenAIModels
))

async function loadSupportedModels() {
  modelsLoading.value = true
  try {
    const models = await userChannelsAPI.getPublicModels({ platform: 'openai' })
    supportedModels.value = models
    modelsFromFallback.value = models.length === 0
  } catch (err) {
    console.error('Failed to load public supported models:', err)
    supportedModels.value = []
    modelsFromFallback.value = true
  } finally {
    modelsLoading.value = false
  }
}

// Check if homeContent is a URL (for iframe display)
const isHomeContentUrl = computed(() => {
  const content = homeContent.value.trim()
  return content.startsWith('http://') || content.startsWith('https://')
})

// Theme
const isDark = ref(document.documentElement.classList.contains('dark'))

// GitHub URL
const githubUrl = 'https://github.com/Wei-Shaw/sub2api'

// Auth state
const isAuthenticated = computed(() => authStore.isAuthenticated)
const isAdmin = computed(() => authStore.isAdmin)
const dashboardPath = computed(() => isAdmin.value ? '/admin/dashboard' : '/dashboard')
const userInitial = computed(() => {
  const user = authStore.user
  if (!user || !user.email) return ''
  return user.email.charAt(0).toUpperCase()
})

// Current year for footer
const currentYear = computed(() => new Date().getFullYear())

// Toggle theme
function toggleTheme() {
  isDark.value = !isDark.value
  document.documentElement.classList.toggle('dark', isDark.value)
  localStorage.setItem('theme', isDark.value ? 'dark' : 'light')
}

// Initialize theme
function initTheme() {
  const savedTheme = localStorage.getItem('theme')
  if (!savedTheme || savedTheme === 'dark') {
    isDark.value = true
    document.documentElement.classList.add('dark')
  }
}

onMounted(() => {
  initTheme()

  // Check auth state
  authStore.checkAuth()
  loadSupportedModels()

  // Ensure public settings are loaded (will use cache if already loaded from injected config)
  if (!appStore.publicSettingsLoaded) {
    appStore.fetchPublicSettings()
  }
})
</script>

<style scoped>
/* Terminal Container */
.terminal-container {
  position: relative;
  display: inline-block;
}

/* Terminal Window */
.terminal-window {
  width: min(420px, calc(100vw - 48px));
  background: rgb(15 15 15 / 0.96);
  border: 1px solid #2e2e2e;
  border-radius: 12px;
  overflow: hidden;
  transition: border-color 0.2s ease;
}

.terminal-window:hover {
  border-color: rgb(62 207 142 / 0.3);
}

/* Terminal Header */
.terminal-header {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background: rgb(23 23 23 / 0.92);
  border-bottom: 1px solid #2e2e2e;
}

.terminal-buttons {
  display: flex;
  gap: 8px;
}

.terminal-buttons span {
  width: 12px;
  height: 12px;
  border-radius: 50%;
}

.btn-close {
  background: #4d4d4d;
}
.btn-minimize {
  background: #898989;
}
.btn-maximize {
  background: #3ecf8e;
}

.terminal-title {
  flex: 1;
  text-align: center;
  font-size: 12px;
  font-family: 'Source Code Pro', ui-monospace, monospace;
  color: #898989;
  margin-right: 52px;
  text-transform: uppercase;
  letter-spacing: 1.2px;
}

/* Terminal Body */
.terminal-body {
  padding: 20px 24px;
  font-family: 'Source Code Pro', ui-monospace, monospace;
  font-size: 14px;
  line-height: 2;
}

.code-line {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  opacity: 0;
  animation: line-appear 0.5s ease forwards;
}

.line-1 {
  animation-delay: 0.3s;
}
.line-2 {
  animation-delay: 1s;
}
.line-3 {
  animation-delay: 1.8s;
}
.line-4 {
  animation-delay: 2.5s;
}

@keyframes line-appear {
  from {
    opacity: 0;
    transform: translateY(5px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.code-prompt {
  color: #3ecf8e;
  font-weight: 500;
}
.code-cmd {
  color: #fafafa;
}
.code-flag {
  color: hsl(251 63.2% 63.2%);
}
.code-url {
  color: #00c573;
}
.code-comment {
  color: #898989;
  font-style: italic;
}
.code-success {
  color: #3ecf8e;
  background: rgb(62 207 142 / 0.1);
  border: 1px solid rgb(62 207 142 / 0.25);
  padding: 2px 8px;
  border-radius: 4px;
  font-weight: 500;
}
.code-response {
  color: hsl(46 100% 70%);
}

/* Blinking Cursor */
.cursor {
  display: inline-block;
  width: 8px;
  height: 16px;
  background: #3ecf8e;
  animation: blink 1s step-end infinite;
}

@keyframes blink {
  0%,
  50% {
    opacity: 1;
  }
  51%,
  100% {
    opacity: 0;
  }
}

</style>
