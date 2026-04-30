import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import ProfileAvatarCard from '@/components/user/profile/ProfileAvatarCard.vue'
import type { User } from '@/types'

const {
  updateProfileMock,
  showSuccessMock,
  showErrorMock,
  authStoreState
} = vi.hoisted(() => ({
  updateProfileMock: vi.fn(),
  showSuccessMock: vi.fn(),
  showErrorMock: vi.fn(),
  authStoreState: {
    user: null as User | null
  }
}))

vi.mock('@/api', () => ({
  userAPI: {
    updateProfile: updateProfileMock
  }
}))

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => authStoreState
}))

vi.mock('@/stores/app', () => ({
  useAppStore: () => ({
    showSuccess: showSuccessMock,
    showError: showErrorMock
  })
}))

vi.mock('@/utils/apiError', () => ({
  extractApiErrorMessage: (error: unknown) => (error as Error).message || 'request failed'
}))

vi.mock('vue-i18n', async (importOriginal) => {
  const actual = await importOriginal<typeof import('vue-i18n')>()
  return {
    ...actual,
    useI18n: () => ({
      t: (key: string) => {
        if (key === 'profile.avatar.title') return 'Profile avatar'
        if (key === 'profile.avatar.description') return 'Manage current avatar'
        if (key === 'profile.avatar.currentHint') return 'Current account avatar'
        if (key === 'profile.avatar.emptyHint') return 'Your initial is shown when no avatar is set'
        if (key === 'profile.avatar.deleteSuccess') return 'Avatar removed'
        if (key === 'profile.avatar.emptyDeleteHint') return 'Avatar is already empty'
        if (key === 'common.delete') return 'Delete'
        return key
      }
    })
  }
})

function createUser(overrides: Partial<User> = {}): User {
  return {
    id: 5,
    username: 'alice',
    email: 'alice@example.com',
    avatar_url: null,
    role: 'user',
    balance: 10,
    concurrency: 2,
    status: 'active',
    allowed_groups: null,
    balance_notify_enabled: true,
    balance_notify_threshold: null,
    balance_notify_extra_emails: [],
    created_at: '2026-04-20T00:00:00Z',
    updated_at: '2026-04-20T00:00:00Z',
    ...overrides
  }
}

describe('ProfileAvatarCard', () => {
  beforeEach(() => {
    updateProfileMock.mockReset()
    showSuccessMock.mockReset()
    showErrorMock.mockReset()
    authStoreState.user = null
  })

  it('renders the current avatar without upload controls', () => {
    authStoreState.user = createUser({ avatar_url: 'https://cdn.example.com/avatar.png' })

    const wrapper = mount(ProfileAvatarCard, {
      props: {
        user: authStoreState.user
      },
      global: {
        stubs: {
          Icon: true
        }
      }
    })

    const preview = wrapper.get('[data-testid="profile-avatar-preview"]')
    expect(preview.attributes('src')).toBe('https://cdn.example.com/avatar.png')
    expect(wrapper.find('[data-testid="profile-avatar-file-input"]').exists()).toBe(false)
    expect(wrapper.find('[data-testid="profile-avatar-save"]').exists()).toBe(false)
  })

  it('deletes the current avatar', async () => {
    const updatedUser = createUser({ avatar_url: null })
    updateProfileMock.mockResolvedValue(updatedUser)
    authStoreState.user = createUser({ avatar_url: 'https://cdn.example.com/old.png' })

    const wrapper = mount(ProfileAvatarCard, {
      props: {
        user: authStoreState.user
      },
      global: {
        stubs: {
          Icon: true
        }
      }
    })

    await wrapper.get('[data-testid="profile-avatar-delete"]').trigger('click')

    expect(updateProfileMock).toHaveBeenCalledWith({ avatar_url: '' })
    expect(authStoreState.user?.avatar_url).toBeNull()
    expect(showSuccessMock).toHaveBeenCalledWith('Avatar removed')
  })

  it('does not render unsafe stored data avatars', () => {
    authStoreState.user = createUser({
      avatar_url: 'data:image/svg+xml;base64,PHN2ZyBvbmxvYWQ9YWxlcnQoMSk+PC9zdmc+'
    })

    const wrapper = mount(ProfileAvatarCard, {
      props: {
        user: authStoreState.user
      },
      global: {
        stubs: {
          Icon: true
        }
      }
    })

    expect(wrapper.find('[data-testid="profile-avatar-preview"]').exists()).toBe(false)
    expect(wrapper.find('[data-testid="profile-avatar-delete"]').exists()).toBe(true)
  })

  it('does not render the delete action when no avatar exists', () => {
    authStoreState.user = createUser()

    const wrapper = mount(ProfileAvatarCard, {
      props: {
        user: authStoreState.user
      },
      global: {
        stubs: {
          Icon: true
        }
      }
    })

    expect(wrapper.find('[data-testid="profile-avatar-delete"]').exists()).toBe(false)
  })
})
