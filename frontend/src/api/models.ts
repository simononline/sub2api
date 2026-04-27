import { keysAPI } from './keys'
import type { ApiKey } from '@/types'

export interface GatewayModel {
  id: string
  type?: string
  object?: string
  display_name?: string
  created_at?: string
  created?: number
  owned_by?: string
}

export interface CurrentUserAvailableModels {
  models: GatewayModel[]
  active_key_count: number
  queried_key_count: number
  failed_key_count: number
}

const DEFAULT_API_BASE_URL = '/api/v1'

export function resolveGatewayModelsURL(apiBaseURL = (import.meta.env.VITE_API_BASE_URL as string | undefined) || DEFAULT_API_BASE_URL): string {
  const trimmed = (apiBaseURL || DEFAULT_API_BASE_URL).trim().replace(/\/+$/, '')
  const gatewayRoot = trimmed
    .replace(/\/api\/v\d+$/i, '')
    .replace(/\/api$/i, '')

  if (!gatewayRoot) {
    return '/v1/models'
  }
  if (/\/v\d+$/i.test(gatewayRoot)) {
    return `${gatewayRoot}/models`
  }
  return `${gatewayRoot}/v1/models`
}

function normalizeModel(raw: unknown): GatewayModel | null {
  if (!raw || typeof raw !== 'object') {
    return null
  }

  const model = raw as Record<string, unknown>
  const id = typeof model.id === 'string' ? model.id.trim() : ''
  if (!id) {
    return null
  }

  return {
    id,
    type: typeof model.type === 'string' ? model.type : undefined,
    object: typeof model.object === 'string' ? model.object : undefined,
    display_name: typeof model.display_name === 'string' ? model.display_name : undefined,
    created_at: typeof model.created_at === 'string' ? model.created_at : undefined,
    created: typeof model.created === 'number' ? model.created : undefined,
    owned_by: typeof model.owned_by === 'string' ? model.owned_by : undefined
  }
}

async function readGatewayError(response: Response): Promise<string> {
  const fallback = `Failed to load models (${response.status})`
  const body = await response.json().catch(() => null)
  if (!body || typeof body !== 'object') {
    return fallback
  }

  const record = body as Record<string, unknown>
  const error = record.error && typeof record.error === 'object' ? record.error as Record<string, unknown> : null
  const message = error?.message || record.message || record.detail
  return typeof message === 'string' && message.trim() ? message : fallback
}

export async function getModels(apiKey: string, options: { signal?: AbortSignal } = {}): Promise<GatewayModel[]> {
  const response = await fetch(resolveGatewayModelsURL(), {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${apiKey}`
    },
    signal: options.signal
  })

  if (!response.ok) {
    throw new Error(await readGatewayError(response))
  }

  const payload = await response.json() as { data?: unknown }
  const data: unknown[] = Array.isArray(payload.data) ? payload.data : []
  const normalizedModels: Array<GatewayModel | null> = data.map(normalizeModel)
  return normalizedModels.filter((model: GatewayModel | null): model is GatewayModel => !!model)
}

function representativeKeysByGroup(keys: ApiKey[]): ApiKey[] {
  const selected = new Map<string, ApiKey>()
  for (const key of keys) {
    if (!key.key || key.status !== 'active') {
      continue
    }
    const groupKey = key.group_id == null ? 'ungrouped' : String(key.group_id)
    if (!selected.has(groupKey)) {
      selected.set(groupKey, key)
    }
  }
  return Array.from(selected.values())
}

export async function getCurrentUserAvailableModels(options: { signal?: AbortSignal } = {}): Promise<CurrentUserAvailableModels> {
  const keys = await keysAPI.list(
    1,
    1000,
    { status: 'active', sort_by: 'created_at', sort_order: 'desc' },
    { signal: options.signal }
  )
  const activeKeys = keys.items.filter((key) => key.status === 'active' && !!key.key)
  const queryKeys = representativeKeysByGroup(activeKeys)

  if (queryKeys.length === 0) {
    return {
      models: [],
      active_key_count: 0,
      queried_key_count: 0,
      failed_key_count: 0
    }
  }

  const results = await Promise.allSettled(queryKeys.map((key) => getModels(key.key, options)))
  const modelsByID = new Map<string, GatewayModel>()
  let failedKeyCount = 0

  for (const result of results) {
    if (result.status === 'rejected') {
      failedKeyCount += 1
      continue
    }
    for (const model of result.value) {
      if (!modelsByID.has(model.id)) {
        modelsByID.set(model.id, model)
      }
    }
  }

  return {
    models: Array.from(modelsByID.values()).sort((a, b) => a.id.localeCompare(b.id)),
    active_key_count: activeKeys.length,
    queried_key_count: queryKeys.length,
    failed_key_count: failedKeyCount
  }
}

export const modelsAPI = {
  getModels,
  getCurrentUserAvailableModels
}

export default modelsAPI
