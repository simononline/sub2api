import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, shallowMount } from '@vue/test-utils'
import PaymentView from '../PaymentView.vue'
import { PAYMENT_RECOVERY_STORAGE_KEY } from '@/components/payment/paymentFlow'

const routeState = vi.hoisted(() => ({
  path: '/purchase',
  query: {} as Record<string, unknown>,
}))

const routerReplace = vi.hoisted(() => vi.fn())
const routerPush = vi.hoisted(() => vi.fn())
const routerResolve = vi.hoisted(() => vi.fn(() => ({ href: '/payment/stripe?mock=1' })))
const createOrder = vi.hoisted(() => vi.fn())
const refreshUser = vi.hoisted(() => vi.fn())
const fetchActiveSubscriptions = vi.hoisted(() => vi.fn().mockResolvedValue(undefined))
const showError = vi.hoisted(() => vi.fn())
const showInfo = vi.hoisted(() => vi.fn())
const showWarning = vi.hoisted(() => vi.fn())
const getCheckoutInfo = vi.hoisted(() => vi.fn())
const bridgeInvoke = vi.hoisted(() => vi.fn())

vi.mock('vue-router', async () => {
  const actual = await vi.importActual<typeof import('vue-router')>('vue-router')
  return {
    ...actual,
    useRoute: () => routeState,
    useRouter: () => ({
      replace: routerReplace,
      push: routerPush,
      resolve: routerResolve,
    }),
  }
})

vi.mock('vue-i18n', async () => {
  const actual = await vi.importActual<typeof import('vue-i18n')>('vue-i18n')
  return {
    ...actual,
    useI18n: () => ({
      t: (key: string) => key,
    }),
  }
})

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({
    user: {
      username: 'demo-user',
      balance: 0,
    },
    refreshUser,
  }),
}))

vi.mock('@/stores/payment', () => ({
  usePaymentStore: () => ({
    createOrder,
  }),
}))

vi.mock('@/stores/subscriptions', () => ({
  useSubscriptionStore: () => ({
    activeSubscriptions: [],
    fetchActiveSubscriptions,
  }),
}))

vi.mock('@/stores', () => ({
  useAppStore: () => ({
    showError,
    showInfo,
    showWarning,
  }),
}))

vi.mock('@/api/payment', () => ({
  paymentAPI: {
    getCheckoutInfo,
  },
}))

vi.mock('@/utils/device', () => ({
  isMobileDevice: () => true,
}))

function checkoutInfoFixture() {
  return {
    data: {
      methods: {
        wxpay: {
          daily_limit: 0,
          daily_used: 0,
          daily_remaining: 0,
          single_min: 0,
          single_max: 0,
          fee_rate: 0,
          available: true,
        },
      },
      global_min: 0,
      global_max: 0,
      plans: [],
      balance_disabled: false,
      balance_recharge_multiplier: 1,
      recharge_fee_rate: 0,
      help_text: '',
      help_image_url: '',
      stripe_publishable_key: '',
    },
  }
}

function checkoutInfoWithPlansFixture() {
  return {
    data: {
      ...checkoutInfoFixture().data,
      plans: [
        {
          id: 7,
          group_id: 3,
          name: 'Starter',
          description: '',
          price: 128,
          original_price: 0,
          validity_days: 30,
          validity_unit: 'day',
          rate_multiplier: 1,
          daily_limit_usd: null,
          weekly_limit_usd: null,
          monthly_limit_usd: null,
          supported_model_scopes: ['claude'],
          features: [],
          group_platform: 'openai',
          sort_order: 1,
          for_sale: true,
          group_name: 'OpenAI',
        },
      ],
    },
  }
}

function checkoutInfoWithRenewalPlansFixture() {
  return {
    data: {
      ...checkoutInfoFixture().data,
      plans: [
        {
          id: 11,
          group_id: 2,
          name: 'Codex Mini',
          description: '',
          price: 45,
          original_price: 0,
          validity_days: 30,
          validity_unit: 'day',
          rate_multiplier: 1,
          daily_limit_usd: null,
          weekly_limit_usd: null,
          monthly_limit_usd: null,
          supported_model_scopes: ['claude'],
          features: [],
          group_platform: 'openai',
          sort_order: 1,
          for_sale: true,
          group_name: 'OpenAI',
        },
        {
          id: 12,
          group_id: 2,
          name: 'Codex Lite',
          description: '',
          price: 75,
          original_price: 0,
          validity_days: 30,
          validity_unit: 'day',
          rate_multiplier: 1,
          daily_limit_usd: null,
          weekly_limit_usd: null,
          monthly_limit_usd: null,
          supported_model_scopes: ['claude'],
          features: [],
          group_platform: 'openai',
          sort_order: 2,
          for_sale: true,
          group_name: 'OpenAI',
        },
        {
          id: 21,
          group_id: 3,
          name: 'Claude Pro',
          description: '',
          price: 199,
          original_price: 0,
          validity_days: 30,
          validity_unit: 'day',
          rate_multiplier: 1,
          daily_limit_usd: null,
          weekly_limit_usd: null,
          monthly_limit_usd: null,
          supported_model_scopes: ['claude'],
          features: [],
          group_platform: 'anthropic',
          sort_order: 3,
          for_sale: true,
          group_name: 'Anthropic',
        },
      ],
    },
  }
}

function unwrapSetupValue<T>(value: unknown): T {
  if (value && typeof value === 'object' && 'value' in value) {
    return (value as { value: T }).value
  }
  return value as T
}

function jsapiOrderFixture(resumeToken: string) {
  return {
    order_id: 123,
    amount: 88,
    pay_amount: 88,
    fee_rate: 0,
    expires_at: '2099-01-01T00:10:00.000Z',
    payment_type: 'wxpay',
    out_trade_no: 'sub2_jsapi_123',
    result_type: 'jsapi_ready' as const,
    resume_token: resumeToken,
    jsapi: {
      appId: 'wx123',
      timeStamp: '1712345678',
      nonceStr: 'nonce',
      package: 'prepay_id=wx123',
      signType: 'RSA',
      paySign: 'signed',
    },
  }
}

function oauthOrderFixture() {
  return {
    order_id: 456,
    amount: 128,
    pay_amount: 128,
    fee_rate: 0,
    expires_at: '2099-01-01T00:10:00.000Z',
    payment_type: 'wxpay',
    result_type: 'oauth_required' as const,
    oauth: {
      authorize_url: '/api/v1/auth/oauth/wechat/payment/start?payment_type=wxpay&redirect=%2Fpurchase%3Ffrom%3Dwechat',
      appid: 'wx123',
      scope: 'snsapi_base',
      redirect_url: '/auth/wechat/payment/callback',
    },
  }
}

describe('PaymentView WeChat JSAPI flow', () => {
  beforeEach(() => {
    routeState.path = '/purchase'
    routeState.query = {
      wechat_resume: '1',
      wechat_resume_token: 'resume-token-123',
    }
    routerReplace.mockReset().mockResolvedValue(undefined)
    routerPush.mockReset().mockResolvedValue(undefined)
    routerResolve.mockClear()
    createOrder.mockReset()
    refreshUser.mockReset()
    fetchActiveSubscriptions.mockReset().mockResolvedValue(undefined)
    showError.mockReset()
    showInfo.mockReset()
    showWarning.mockReset()
    getCheckoutInfo.mockReset().mockResolvedValue(checkoutInfoFixture())
    bridgeInvoke.mockReset()
    window.localStorage.clear()
    ;(window as Window & { WeixinJSBridge?: { invoke: typeof bridgeInvoke } }).WeixinJSBridge = {
      invoke: bridgeInvoke,
    }
  })

  it('resets payment state and redirects to /payment/result after JSAPI reports success', async () => {
    createOrder.mockResolvedValue(jsapiOrderFixture('resume-token-123'))
    bridgeInvoke.mockImplementation((_action, _payload, callback) => {
      callback({ err_msg: 'get_brand_wcpay_request:ok' })
    })

    shallowMount(PaymentView, {
      global: {
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })
    await flushPromises()
    await flushPromises()

    expect(routerReplace).toHaveBeenCalledWith({ path: '/purchase', query: {} })
    expect(routerPush).toHaveBeenCalledWith({
      path: '/payment/result',
      query: {
        order_id: '123',
        out_trade_no: 'sub2_jsapi_123',
        resume_token: 'resume-token-123',
      },
    })
    expect(window.localStorage.getItem(PAYMENT_RECOVERY_STORAGE_KEY)).toBeNull()
  })

  it('resets payment state when JSAPI reports cancellation', async () => {
    createOrder.mockResolvedValue(jsapiOrderFixture('resume-token-cancel'))
    bridgeInvoke.mockImplementation((_action, _payload, callback) => {
      callback({ err_msg: 'get_brand_wcpay_request:cancel' })
    })

    shallowMount(PaymentView, {
      global: {
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })
    await flushPromises()
    await flushPromises()

    expect(showInfo).toHaveBeenCalledWith('payment.qr.cancelled')
    expect(routerPush).not.toHaveBeenCalled()
    expect(window.localStorage.getItem(PAYMENT_RECOVERY_STORAGE_KEY)).toBeNull()
  })

  it('clears stale recovery state when JSAPI never becomes available', async () => {
    vi.useFakeTimers()
    createOrder.mockResolvedValue(jsapiOrderFixture('resume-token-missing-bridge'))
    ;(window as Window & { WeixinJSBridge?: { invoke: typeof bridgeInvoke } }).WeixinJSBridge = undefined

    const wrapper = shallowMount(PaymentView, {
      global: {
        renderStubDefaultSlot: true,
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })

    await flushPromises()
    await vi.advanceTimersByTimeAsync(4000)
    await flushPromises()
    await flushPromises()

    expect(showError).toHaveBeenCalledWith(
      'payment.errors.wechatJsapiUnavailable payment.errors.wechatOpenInWeChatHint',
    )
    expect(routerPush).not.toHaveBeenCalled()
    expect(window.localStorage.getItem(PAYMENT_RECOVERY_STORAGE_KEY)).toBeNull()
    expect(wrapper.html()).not.toContain('payment-status-panel-stub')
  })

  it('clears a stale recovery snapshot before handling wechat resume callback params', async () => {
    createOrder.mockRejectedValueOnce(new Error('resume failed'))
    window.localStorage.setItem(PAYMENT_RECOVERY_STORAGE_KEY, JSON.stringify({
      orderId: 999,
      amount: 66,
      qrCode: 'stale-qr',
      expiresAt: '2099-01-01T00:10:00.000Z',
      paymentType: 'alipay',
      payUrl: 'https://pay.example.com/stale',
      outTradeNo: 'stale-out-trade-no',
      clientSecret: '',
      payAmount: 66,
      orderType: 'balance',
      paymentMode: 'popup',
      resumeToken: '',
      createdAt: Date.UTC(2099, 0, 1, 0, 0, 0),
    }))

    shallowMount(PaymentView, {
      global: {
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })
    await flushPromises()
    await flushPromises()

    expect(createOrder).toHaveBeenCalledWith(expect.objectContaining({
      wechat_resume_token: 'resume-token-123',
    }))
    expect(window.localStorage.getItem(PAYMENT_RECOVERY_STORAGE_KEY)).toBeNull()
  })

  it('keeps subscription resume context for token-only WeChat callbacks', async () => {
    routeState.query = {
      wechat_resume: '1',
      wechat_resume_token: 'resume-subscription-7',
      payment_type: 'wxpay_direct',
      order_type: 'subscription',
      plan_id: '7',
    }
    getCheckoutInfo.mockResolvedValue(checkoutInfoWithPlansFixture())
    createOrder.mockResolvedValue(oauthOrderFixture())

    const originalLocation = window.location
    const locationState = {
      href: 'http://localhost/purchase',
      origin: 'http://localhost',
    }
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: locationState,
    })

    shallowMount(PaymentView, {
      global: {
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })
    await flushPromises()
    await flushPromises()

    expect(routerReplace).toHaveBeenCalledWith({ path: '/purchase', query: {} })
    expect(createOrder).toHaveBeenCalledWith(expect.objectContaining({
      payment_type: 'wxpay',
      order_type: 'subscription',
      plan_id: 7,
      wechat_resume_token: 'resume-subscription-7',
    }))
    expect(locationState.href).toContain('/api/v1/auth/oauth/wechat/payment/start?')
    expect(new URL(locationState.href, 'http://localhost').searchParams.get('redirect')).toBe(
      '/purchase?from=wechat&payment_type=wxpay&order_type=subscription&plan_id=7',
    )

    Object.defineProperty(window, 'location', {
      configurable: true,
      value: originalLocation,
    })
  })

  it('falls back to QR flow when mobile WeChat payment is unavailable', async () => {
    routeState.query = {
      wechat_resume: '1',
      wechat_resume_token: 'resume-token-h5',
      payment_type: 'wxpay_direct',
    }
    createOrder
      .mockRejectedValueOnce({ reason: 'WECHAT_H5_NOT_AUTHORIZED' })
      .mockResolvedValueOnce({
        order_id: 778,
        amount: 88,
        pay_amount: 88,
        fee_rate: 0,
        expires_at: '2099-01-01T00:10:00.000Z',
        payment_type: 'wxpay',
        qr_code: 'weixin://wxpay/bizpayurl?pr=fallback-native',
        out_trade_no: 'sub2_qr_778',
      })

    shallowMount(PaymentView, {
      global: {
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })
    await flushPromises()
    await flushPromises()

    expect(createOrder).toHaveBeenNthCalledWith(1, expect.objectContaining({
      payment_type: 'wxpay',
      is_mobile: true,
      wechat_resume_token: 'resume-token-h5',
    }))
    expect(createOrder).toHaveBeenNthCalledWith(2, expect.objectContaining({
      payment_type: 'wxpay',
      is_mobile: false,
      payment_source: 'hosted_redirect',
    }))
    expect(showWarning).toHaveBeenCalledWith('payment.errors.mobilePaymentFallbackToQr')
    expect(showError).not.toHaveBeenCalled()
    expect(window.localStorage.getItem(PAYMENT_RECOVERY_STORAGE_KEY)).toContain('weixin://wxpay/bizpayurl?pr=fallback-native')
  })
})

describe('PaymentView subscription name filters', () => {
  beforeEach(() => {
    routeState.path = '/purchase'
    routeState.query = {
      tab: 'subscription',
    }
    routerReplace.mockReset().mockResolvedValue(undefined)
    routerPush.mockReset().mockResolvedValue(undefined)
    routerResolve.mockClear()
    createOrder.mockReset()
    refreshUser.mockReset()
    fetchActiveSubscriptions.mockReset().mockResolvedValue(undefined)
    showError.mockReset()
    showInfo.mockReset()
    showWarning.mockReset()
    window.localStorage.clear()
    ;(window as Window & { WeixinJSBridge?: { invoke: typeof bridgeInvoke } }).WeixinJSBridge = undefined
    getCheckoutInfo.mockReset().mockResolvedValue({
      data: {
        ...checkoutInfoFixture().data,
        plans: [
          {
            id: 1,
            group_id: 11,
            name: 'clAuDe Pro',
            description: '',
            price: 199,
            original_price: 0,
            validity_days: 30,
            validity_unit: 'day',
            rate_multiplier: 1,
            daily_limit_usd: null,
            weekly_limit_usd: null,
            monthly_limit_usd: null,
            supported_model_scopes: ['claude'],
            features: [],
            group_platform: 'anthropic',
            sort_order: 1,
            for_sale: true,
            group_name: 'Anthropic',
          },
          {
            id: 2,
            group_id: 12,
            name: 'Codex Team',
            description: '',
            price: 249,
            original_price: 0,
            validity_days: 30,
            validity_unit: 'day',
            rate_multiplier: 1,
            daily_limit_usd: null,
            weekly_limit_usd: null,
            monthly_limit_usd: null,
            supported_model_scopes: ['claude', 'gemini_text'],
            features: [],
            group_platform: 'gemini',
            sort_order: 2,
            for_sale: true,
            group_name: 'Gemini',
          },
          {
            id: 3,
            group_id: 13,
            name: 'CODEX Starter',
            description: '',
            price: 299,
            original_price: 0,
            validity_days: 30,
            validity_unit: 'day',
            rate_multiplier: 1,
            daily_limit_usd: null,
            weekly_limit_usd: null,
            monthly_limit_usd: null,
            supported_model_scopes: ['gemini_image'],
            features: [],
            group_platform: 'gemini',
            sort_order: 3,
            for_sale: true,
            group_name: 'Gemini',
          },
          {
            id: 4,
            group_id: 14,
            name: 'Gemini Mixed',
            description: '',
            price: 159,
            original_price: 0,
            validity_days: 30,
            validity_unit: 'day',
            rate_multiplier: 1,
            daily_limit_usd: null,
            weekly_limit_usd: null,
            monthly_limit_usd: null,
            supported_model_scopes: ['gemini_text'],
            features: [],
            group_platform: 'gemini',
            sort_order: 4,
            for_sale: true,
            group_name: 'Gemini',
          },
        ],
      },
    })
  })

  it('filters subscription plans by plan name, case-insensitively', async () => {
    const wrapper = shallowMount(PaymentView, {
      global: {
        renderStubDefaultSlot: true,
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })

    await flushPromises()
    await flushPromises()

    const filteredPlanCount = () => {
      const state = (wrapper.vm as unknown as { $: { setupState: Record<string, unknown> } }).$.setupState.filteredPlans
      if (Array.isArray(state)) return state.length
      return (state as { value: unknown[] }).value.length
    }

    expect(filteredPlanCount()).toBe(4)

    await wrapper.get('[data-testid="plan-name-filter-claude"]').trigger('click')
    expect(filteredPlanCount()).toBe(1)

    await wrapper.get('[data-testid="plan-name-filter-openai"]').trigger('click')
    expect(filteredPlanCount()).toBe(2)

    await wrapper.get('[data-testid="plan-name-filter-all"]').trigger('click')
    expect(filteredPlanCount()).toBe(4)
  })
})

describe('PaymentView renewal navigation', () => {
  beforeEach(() => {
    routeState.path = '/purchase'
    routeState.query = {
      tab: 'subscription',
      group: '2',
    }
    routerReplace.mockReset().mockResolvedValue(undefined)
    routerPush.mockReset().mockResolvedValue(undefined)
    routerResolve.mockClear()
    createOrder.mockReset()
    refreshUser.mockReset()
    fetchActiveSubscriptions.mockReset().mockResolvedValue(undefined)
    showError.mockReset()
    showInfo.mockReset()
    showWarning.mockReset()
    window.localStorage.clear()
    ;(window as Window & { WeixinJSBridge?: { invoke: typeof bridgeInvoke } }).WeixinJSBridge = undefined
    getCheckoutInfo.mockReset().mockResolvedValue(checkoutInfoWithRenewalPlansFixture())
  })

  it('does not open the renewal modal when only group is present and multiple plans match', async () => {
    const wrapper = shallowMount(PaymentView, {
      global: {
        renderStubDefaultSlot: true,
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })

    await flushPromises()
    await flushPromises()

    const setupState = (wrapper.vm as unknown as { $: { setupState: Record<string, unknown> } }).$.setupState
    expect(unwrapSetupValue<boolean>(setupState.showRenewalModal)).toBe(false)
    expect(unwrapSetupValue<unknown>(setupState.selectedPlan)).toBeNull()
    expect(unwrapSetupValue<string>(setupState.activeTab)).toBe('subscription')
  })

  it('selects the exact plan when plan_id is present in the route query', async () => {
    routeState.query = {
      tab: 'subscription',
      group: '2',
      plan_id: '12',
    }

    const wrapper = shallowMount(PaymentView, {
      global: {
        renderStubDefaultSlot: true,
        stubs: {
          Teleport: true,
          Transition: false,
        },
      },
    })

    await flushPromises()
    await flushPromises()

    const setupState = (wrapper.vm as unknown as { $: { setupState: Record<string, unknown> } }).$.setupState
    const selectedPlan = unwrapSetupValue<{ id: number } | null>(setupState.selectedPlan)
    expect(unwrapSetupValue<boolean>(setupState.showRenewalModal)).toBe(false)
    expect(selectedPlan?.id).toBe(12)
    expect(unwrapSetupValue<string>(setupState.activeTab)).toBe('subscription')
  })
})
