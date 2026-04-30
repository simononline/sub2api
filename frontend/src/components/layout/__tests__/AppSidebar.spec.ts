import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

const componentPath = resolve(dirname(fileURLToPath(import.meta.url)), '../AppSidebar.vue')
const componentSource = readFileSync(componentPath, 'utf8')
const stylePath = resolve(dirname(fileURLToPath(import.meta.url)), '../../../style.css')
const styleSource = readFileSync(stylePath, 'utf8')

describe('AppSidebar custom SVG styles', () => {
  it('does not override uploaded SVG fill or stroke colors', () => {
    expect(componentSource).toContain('.sidebar-svg-icon {')
    expect(componentSource).toContain('color: currentColor;')
    expect(componentSource).toContain('display: block;')
    expect(componentSource).not.toContain('stroke: currentColor;')
    expect(componentSource).not.toContain('fill: none;')
  })
})

describe('AppSidebar header styles', () => {
  it('does not clip the version badge dropdown', () => {
    const sidebarHeaderBlockMatch = styleSource.match(/\.sidebar-header\s*\{[\s\S]*?\n {2}\}/)
    const sidebarBrandBlockMatch = componentSource.match(/\.sidebar-brand\s*\{[\s\S]*?\n\}/)

    expect(sidebarHeaderBlockMatch).not.toBeNull()
    expect(sidebarBrandBlockMatch).not.toBeNull()
    expect(sidebarHeaderBlockMatch?.[0]).not.toContain('@apply overflow-hidden;')
    expect(sidebarBrandBlockMatch?.[0]).not.toContain('overflow: hidden;')
  })
})

describe('AppSidebar admin sections', () => {
  it('places leaderboard under the public area section instead of my account', () => {
    expect(componentSource).toContain("{{ t('nav.publicArea') }}")
    expect(componentSource).toContain("const isPublicNavItem = (item: NavItem) => item.path === '/leaderboard'")
    expect(componentSource).toContain('const adminSelfNavSections = computed(() => splitSelfNavItems(finalizeNav(buildSelfNavItems(false, true))))')
    expect(componentSource).toContain('const publicNavItems = computed((): NavItem[] => adminSelfNavSections.value.publicItems)')
    expect(componentSource).toContain('const personalNavItems = computed((): NavItem[] => adminSelfNavSections.value.personalItems)')
  })
})

describe('AppSidebar regular user sections', () => {
  it('places leaderboard under the public area section and the remaining items under my account', () => {
    expect(componentSource).toContain('v-if="userPublicNavItems.length" class="sidebar-section"')
    expect(componentSource).toContain('v-for="item in userPublicNavItems"')
    expect(componentSource).toContain("{{ t('nav.myAccount') }}")
    expect(componentSource).toContain('v-if="userNavItems.length" class="sidebar-section"')
    expect(componentSource).toContain('const userSelfNavSections = computed(() => splitSelfNavItems(finalizeNav(buildSelfNavItems(true))))')
    expect(componentSource).toContain('const userPublicNavItems = computed((): NavItem[] => userSelfNavSections.value.publicItems)')
    expect(componentSource).toContain('const userNavItems = computed((): NavItem[] => userSelfNavSections.value.personalItems)')
  })
})
