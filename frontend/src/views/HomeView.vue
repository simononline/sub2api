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
    <header class="glass sticky top-0 z-30 border-b border-gray-200/50 dark:border-dark-700/50">
      <nav class="flex h-16 items-center justify-between px-4 md:px-6">
        <router-link to="/home" class="flex min-w-0 items-center gap-3">
          <div class="flex h-10 w-10 items-center justify-center overflow-hidden rounded-lg border border-primary-400/30 bg-dark-950/5 dark:bg-dark-950">
            <img :src="siteLogo || '/logo.png'" alt="Logo" class="h-full w-full object-contain" />
          </div>
          <div class="hidden min-w-0 sm:block">
            <div class="truncate text-sm font-medium text-gray-900 dark:text-white">
              {{ siteName }}
            </div>
            <div class="max-w-[18rem] truncate text-xs text-gray-500 dark:text-dark-400">
              {{ siteSubtitle }}
            </div>
          </div>
        </router-link>

        <div class="flex items-center gap-2 sm:gap-3">
          <router-link
            :to="consoleEntryPath"
            class="home-header-link home-header-console-link"
          >
            {{ t('home.goToDashboard') }}
          </router-link>

          <AnnouncementBell v-if="isAuthenticated" />
          <button
            v-else
            type="button"
            class="home-header-icon-button"
            :title="t('announcements.title')"
            :aria-label="t('announcements.title')"
            @click="handleGuestLogin"
          >
            <Icon name="bell" size="md" />
          </button>

          <LocaleSwitcher />

          <button
            type="button"
            @click="toggleTheme"
            class="home-header-action"
            :title="themeToggleLabel"
            :aria-label="themeToggleLabel"
          >
            <Icon v-if="isDark" name="sun" size="md" />
            <Icon v-else name="moon" size="md" />
            <span class="hidden sm:inline">{{ themeToggleLabel }}</span>
          </button>

          <template v-if="user">
            <div
              class="hidden items-center gap-2 rounded-full border border-primary-500/30 bg-primary-500/10 px-3 py-1.5 sm:flex"
            >
              <svg
                class="h-4 w-4 text-primary-600 dark:text-primary-400"
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
              <span class="text-sm font-semibold text-primary-700 dark:text-primary-300">
                ${{ user.balance?.toFixed(2) || '0.00' }}
              </span>
            </div>

            <div class="relative" ref="dropdownRef">
              <button
                type="button"
                @click="toggleDropdown"
                class="flex items-center gap-2 rounded-md p-1.5 transition-colors hover:bg-gray-100 dark:hover:bg-dark-800"
                aria-label="User Menu"
              >
                <div class="flex h-8 w-8 items-center justify-center overflow-hidden rounded-md border border-primary-500/30 bg-primary-500/10 text-sm font-medium text-primary-600 dark:text-primary-300">
                  <img
                    v-if="avatarUrl"
                    :src="avatarUrl"
                    :alt="displayName"
                    class="h-full w-full object-cover"
                  >
                  <span v-else>{{ userInitials }}</span>
                </div>
                <div class="hidden text-left md:block">
                  <div class="text-sm font-medium text-gray-900 dark:text-white">
                    {{ displayName }}
                  </div>
                  <div class="text-xs capitalize text-gray-500 dark:text-dark-400">
                    {{ user.role }}
                  </div>
                </div>
                <Icon name="chevronDown" size="sm" class="hidden text-gray-400 md:block" />
              </button>

              <transition name="dropdown">
                <div v-if="dropdownOpen" class="dropdown right-0 mt-2 w-56">
                  <div class="border-b border-gray-100 px-4 py-3 dark:border-dark-700">
                    <div class="text-sm font-medium text-gray-900 dark:text-white">
                      {{ displayName }}
                    </div>
                    <div class="text-xs text-gray-500 dark:text-dark-400">{{ user.email }}</div>
                  </div>

                  <div class="border-b border-gray-100 px-4 py-2 dark:border-dark-700 sm:hidden">
                    <div class="text-xs text-gray-500 dark:text-dark-400">
                      {{ t('common.balance') }}
                    </div>
                    <div class="text-sm font-semibold text-primary-600 dark:text-primary-400">
                      ${{ user.balance?.toFixed(2) || '0.00' }}
                    </div>
                  </div>

                  <div class="py-1">
                    <router-link :to="dashboardPath" @click="closeDropdown" class="dropdown-item">
                      <Icon name="chart" size="sm" />
                      {{ t('home.dashboard') }}
                    </router-link>

                    <router-link to="/profile" @click="closeDropdown" class="dropdown-item">
                      <Icon name="user" size="sm" />
                      {{ t('nav.profile') }}
                    </router-link>

                    <router-link to="/keys" @click="closeDropdown" class="dropdown-item">
                      <Icon name="key" size="sm" />
                      {{ t('nav.apiKeys') }}
                    </router-link>

                    <a
                      v-if="authStore.isAdmin"
                      href="https://github.com/Wei-Shaw/sub2api"
                      target="_blank"
                      rel="noopener noreferrer"
                      @click="closeDropdown"
                      class="dropdown-item"
                    >
                      <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                        <path
                          fill-rule="evenodd"
                          clip-rule="evenodd"
                          d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.17 6.839 9.49.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.604-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.464-1.11-1.464-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.831.092-.646.35-1.086.636-1.336-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.578 9.578 0 0112 6.836c.85.004 1.705.114 2.504.336 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.578.688.48C19.138 20.167 22 16.418 22 12c0-5.523-4.477-10-10-10z"
                        />
                      </svg>
                      {{ t('nav.github') }}
                    </a>
                  </div>

                  <div
                    v-if="contactInfo"
                    class="border-t border-gray-100 px-4 py-2.5 dark:border-dark-700"
                  >
                    <div class="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
                      <svg
                        class="h-3.5 w-3.5 flex-shrink-0"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                        stroke-width="1.5"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155"
                        />
                      </svg>
                      <span>{{ t('common.contactSupport') }}:</span>
                      <span class="font-medium text-gray-700 dark:text-gray-300">
                        {{ contactInfo }}
                      </span>
                    </div>
                  </div>

                  <div class="border-t border-gray-100 py-1 dark:border-dark-700">
                    <button
                      type="button"
                      @click="handleLogout"
                      class="dropdown-item w-full text-red-600 hover:bg-red-50 dark:text-red-400 dark:hover:bg-red-900/20"
                    >
                      <svg
                        class="h-4 w-4"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                        stroke-width="1.5"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75"
                        />
                      </svg>
                      {{ t('nav.logout') }}
                    </button>
                  </div>
                </div>
              </transition>
            </div>
          </template>

          <router-link
            v-else
            to="/login"
            class="home-header-link home-header-link-primary"
          >
            {{ t('home.login') }}
          </router-link>
        </div>
      </nav>
    </header>

    <!-- Main Content -->
    <main class="relative z-10 flex-1 px-6 py-14 md:py-20">
      <div class="mx-auto w-full max-w-[1440px]">
        <!-- Pool Notice -->
        <div
          class="mb-8 flex flex-col gap-3 rounded-lg border border-primary-400/30 bg-primary-500/10 p-4 text-sm text-primary-800 backdrop-blur-sm dark:text-primary-200 sm:flex-row sm:items-center"
        >
          <div
            class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-primary-400/30 bg-white/70 text-primary-600 dark:bg-dark-950/70 dark:text-primary-400"
          >
            <Icon name="server" size="md" />
          </div>
          <p class="pool-notice-text leading-6" :aria-label="t('home.poolNotice')">
            <span
              v-for="(character, index) in poolNoticeCharacters"
              :key="`${character}-${index}`"
              aria-hidden="true"
              class="pool-notice-char"
              :class="{ 'pool-notice-char-space': character === ' ' }"
              :style="getPoolNoticeCharStyle(index)"
            >{{ character }}</span>
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
              {{ t('home.heroTitle') }}
            </h1>
            <p class="mb-8 max-w-xl text-base leading-7 text-gray-600 dark:text-dark-300 md:text-lg">
              {{ siteSubtitle }}
            </p>
            <p class="mb-8 max-w-xl text-sm leading-6 text-gray-500 dark:text-dark-400 md:text-base">
              {{ t('home.heroDescription') }}
            </p>

            <!-- CTA Button -->
            <div class="flex flex-col items-center gap-3 sm:flex-row lg:justify-start">
              <router-link :to="consoleEntryPath" class="btn btn-primary px-8 py-3 text-base">
                {{ isAuthenticated ? t('home.goToDashboard') : t('home.getStarted') }}
                <Icon name="arrowRight" size="md" class="ml-2" :stroke-width="2" />
              </router-link>
              <router-link
                :to="plansEntryPath"
                class="btn btn-secondary px-6 py-3 text-base"
              >
                {{ t('home.viewPlans') }}
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
                    <span class="code-comment"># unified coding API</span>
                  </div>
                  <div class="code-line line-3">
                    <span class="code-success">200 OK</span>
                    <span class="code-response">{ "scene": "code_generation", "status": "ok" }</span>
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
        <!-- <section class="mb-16">
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
        </section> -->

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
              <p class="whitespace-pre-line text-sm leading-6 text-gray-600 dark:text-dark-400">
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
          <router-link :to="consoleEntryPath" class="btn btn-primary px-8 py-3 text-base">
            {{ isAuthenticated ? t('home.goToDashboard') : t('home.cta.button') }}
            <Icon name="arrowRight" size="md" class="ml-2" :stroke-width="2" />
          </router-link>
        </section>
      </div>
    </main>

    <!-- Footer -->
    <footer class="relative z-10 border-t border-gray-200 px-6 py-8 dark:border-dark-800">
      <div
        class="mx-auto flex w-full max-w-[1440px] flex-col items-center justify-center gap-4 text-center sm:flex-row sm:text-left"
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
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useAuthStore, useAppStore } from '@/stores'
import AnnouncementBell from '@/components/common/AnnouncementBell.vue'
import LocaleSwitcher from '@/components/common/LocaleSwitcher.vue'
import Icon from '@/components/icons/Icon.vue'
// import  { type PublicSupportedModel } from '@/api/channels'
// import { getModelsByPlatform } from '@/composables/useModelWhitelist'

const { t } = useI18n()
const router = useRouter()

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
  | 'chatBubble'
  | 'clock'
  | 'badge'
  | 'document'
  | 'lightbulb'
  | 'cog'
  | 'database'
  | 'beaker'

const authStore = useAuthStore()
const appStore = useAppStore()
// const supportedModels = ref<PublicSupportedModel[]>([])
// const modelsLoading = ref(false)
// const modelsFromFallback = ref(true)
const dropdownOpen = ref(false)
const dropdownRef = ref<HTMLElement | null>(null)

// Site settings - directly from appStore (already initialized from injected config)
const siteName = computed(() => appStore.cachedPublicSettings?.site_name || appStore.siteName || 'WeShare')
const siteLogo = computed(() => appStore.cachedPublicSettings?.site_logo || appStore.siteLogo || '')
const siteSubtitle = computed(() => t('admin.settings.site.siteSubtitlePlaceholder'))
const docUrl = computed(() => appStore.cachedPublicSettings?.doc_url || appStore.docUrl || '')
const homeContent = computed(() => appStore.cachedPublicSettings?.home_content || '')
const contactInfo = computed(() => appStore.contactInfo)
const poolNoticeScanStepMs = 95
const poolNoticeCharacters = computed(() => Array.from(t('home.poolNotice')))
const poolNoticeScanDurationMs = computed(() => (
  (poolNoticeCharacters.value.length * poolNoticeScanStepMs) + 1200
))

function getPoolNoticeCharStyle(index: number) {
  return {
    animationDelay: `${index * poolNoticeScanStepMs}ms`,
    animationDuration: `${poolNoticeScanDurationMs.value}ms`
  }
}

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
    icon: 'document',
    iconClass: 'border-emerald-500/30 bg-emerald-500/10 text-emerald-500',
    title: t('home.providers.usageControl'),
    description: t('home.providers.usageControlDesc')
  },
  {
    icon: 'server',
    iconClass: 'border-amber-500/30 bg-amber-500/10 text-amber-500',
    title: t('home.providers.apiAccess'),
    description: t('home.providers.apiAccessDesc')
  }
])

const highlightCards = computed<Array<{
  icon: HomeIconName
  title: string
  description: string
}>>(() => [
  {
    icon: 'terminal',
    title: t('home.serviceHighlights.items.tooling.title'),
    description: t('home.serviceHighlights.items.tooling.desc')
  },
  {
    icon: 'brain',
    title: t('home.serviceHighlights.items.assistant.title'),
    description: t('home.serviceHighlights.items.assistant.desc')
  },
  {
    icon: 'chatBubble',
    title: t('home.serviceHighlights.items.supportDesk.title'),
    description: t('home.serviceHighlights.items.supportDesk.desc')
  },
  {
    icon: 'document',
    title: t('home.serviceHighlights.items.docs.title'),
    description: t('home.serviceHighlights.items.docs.desc')
  },
  {
    icon: 'lightbulb',
    title: t('home.serviceHighlights.items.rewrite.title'),
    description: t('home.serviceHighlights.items.rewrite.desc')
  },
  {
    icon: 'cog',
    title: t('home.serviceHighlights.items.systems.title'),
    description: t('home.serviceHighlights.items.systems.desc')
  },
  {
    icon: 'database',
    title: t('home.serviceHighlights.items.knowledge.title'),
    description: t('home.serviceHighlights.items.knowledge.desc')
  },
  {
    icon: 'beaker',
    title: t('home.serviceHighlights.items.education.title'),
    description: t('home.serviceHighlights.items.education.desc')
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
    question: t('home.faq.items.service.question'),
    answer: t('home.faq.items.service.answer')
  },
  {
    question: t('home.faq.items.virtualAssets.question'),
    answer: t('home.faq.items.virtualAssets.answer')
  },
  {
    question: t('home.faq.items.usage.question'),
    answer: t('home.faq.items.usage.answer')
  },
  {
    question: t('home.faq.items.scenarios.question'),
    answer: t('home.faq.items.scenarios.answer')
  },
  {
    question: t('home.faq.items.refund.question'),
    answer: t('home.faq.items.refund.answer')
  },
  {
    question: t('home.faq.items.official.question'),
    answer: t('home.faq.items.official.answer')
  }
])

// const fallbackOpenAIModels = getModelsByPlatform('openai').map((name) => ({
//   name,
//   platform: 'openai',
//   channel_count: 0
// }))

// const displayedSupportedModels = computed(() => (
//   supportedModels.value.length > 0 ? supportedModels.value : fallbackOpenAIModels
// ))

// async function loadSupportedModels() {
//   modelsLoading.value = true
//   try {
//     const models = await userChannelsAPI.getPublicModels({ platform: 'openai' })
//     supportedModels.value = models
//     modelsFromFallback.value = models.length === 0
//   } catch (err) {
//     console.error('Failed to load public supported models:', err)
//     supportedModels.value = []
//     modelsFromFallback.value = true
//   } finally {
//     modelsLoading.value = false
//   }
// }

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
const user = computed(() => authStore.user)
const isAuthenticated = computed(() => authStore.isAuthenticated)
const isAdmin = computed(() => authStore.isAdmin)
const dashboardPath = computed(() => isAdmin.value ? '/admin/dashboard' : '/dashboard')
const consoleEntryPath = computed(() =>
  isAuthenticated.value ? (isAdmin.value ? '/admin/dashboard' : '/subscriptions') : '/login'
)
const plansEntryPath = computed(() => isAuthenticated.value ? '/purchase' : '/login')
const avatarUrl = computed(() => user.value?.avatar_url?.trim() || '')
const userInitials = computed(() => {
  if (!user.value) return ''
  if (user.value.username) {
    return user.value.username.substring(0, 2).toUpperCase()
  }
  if (user.value.email) {
    return user.value.email.split('@')[0].substring(0, 2).toUpperCase()
  }
  return ''
})
const displayName = computed(() => {
  if (!user.value) return ''
  return user.value.username || user.value.email?.split('@')[0] || ''
})

// Current year for footer
const currentYear = computed(() => new Date().getFullYear())
const themeToggleLabel = computed(() => (
  isDark.value ? t('nav.lightMode') : t('nav.darkMode')
))

// Toggle theme
function toggleTheme() {
  isDark.value = !isDark.value
  document.documentElement.classList.toggle('dark', isDark.value)
  localStorage.setItem('theme', isDark.value ? 'dark' : 'light')
}

function toggleDropdown() {
  dropdownOpen.value = !dropdownOpen.value
}

function closeDropdown() {
  dropdownOpen.value = false
}

function handleGuestLogin() {
  router.push('/login')
}

async function handleLogout() {
  closeDropdown()
  try {
    await authStore.logout()
  } catch (error) {
    console.error('Logout error:', error)
  }
  await router.push('/login')
}

function handleClickOutside(event: MouseEvent) {
  if (dropdownRef.value && !dropdownRef.value.contains(event.target as Node)) {
    closeDropdown()
  }
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
  document.addEventListener('click', handleClickOutside)

  // Check auth state
  authStore.checkAuth()
  // loadSupportedModels()

  // Ensure public settings are loaded (will use cache if already loaded from injected config)
  if (!appStore.publicSettingsLoaded) {
    appStore.fetchPublicSettings()
  }
})

onBeforeUnmount(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped>
.home-header-icon-button {
  @apply flex h-9 w-9 items-center justify-center rounded-md border border-transparent text-gray-600 transition-colors hover:border-gray-200 hover:bg-gray-100;
  @apply dark:text-gray-400 dark:hover:border-dark-800 dark:hover:bg-dark-800;
}

.home-header-action {
  @apply inline-flex h-10 items-center gap-1.5 rounded-lg px-2.5 text-sm font-medium text-gray-600 transition-colors hover:bg-gray-100 hover:text-gray-900;
  @apply dark:text-dark-400 dark:hover:bg-dark-800 dark:hover:text-dark-50;
}

.home-header-link {
  @apply inline-flex h-10 items-center gap-2 rounded-lg border border-gray-200 bg-white/80 px-3 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-100 hover:text-gray-900;
  @apply dark:border-dark-800 dark:bg-dark-900/70 dark:text-dark-100 dark:hover:bg-dark-800 dark:hover:text-white;
}

.home-header-console-link {
  @apply shrink-0 whitespace-nowrap;
}

.home-header-link-primary {
  @apply border-gray-950 bg-gray-950 text-white hover:border-primary-400 hover:bg-gray-950 hover:text-white;
  @apply dark:border-dark-50 dark:bg-dark-950 dark:hover:border-primary-400;
}

.dropdown-enter-active,
.dropdown-leave-active {
  transition: all 0.2s ease;
}

.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: scale(0.95) translateY(-4px);
}

.pool-notice-text {
  max-width: 100%;
}

.pool-notice-char {
  display: inline-block;
  height: 1.5rem;
  line-height: 1.5rem;
  white-space: pre;
  vertical-align: top;
  animation-name: pool-notice-scan;
  animation-timing-function: linear;
  animation-iteration-count: infinite;
}

.pool-notice-char-space {
  min-width: 0.35em;
}

@keyframes pool-notice-scan {
  0% {
    background: rgb(62 207 142 / 0.36);
  }

  1.4% {
    background: rgb(62 207 142 / 0.24);
  }

  3.8% {
    background: rgb(62 207 142 / 0.12);
  }

  5.2%,
  100% {
    background: transparent;
  }
}

@media (prefers-reduced-motion: reduce) {
  .pool-notice-char {
    animation: none;
  }
}

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
