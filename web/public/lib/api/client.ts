import { env } from '@/lib/env'
import { type ApiError, isApiError } from '@/lib/api/types'

export class ApiRequestError extends Error {
  constructor(public readonly error: ApiError) {
    super(error.detail ?? error.title)
    this.name = 'ApiRequestError'
  }
}

interface FetchOptions extends Omit<RequestInit, 'body'> {
  body?: unknown
  signal?: AbortSignal
}

async function request<T>(path: string, options: FetchOptions = {}): Promise<T> {
  const { body, signal, ...rest } = options

  const response = await fetch(`${env.NEXT_PUBLIC_API_URL}${path}`, {
    ...rest,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      // TODO T-015: agregar Authorization header desde cookie httpOnly
      ...rest.headers,
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
    signal,
  })

  if (!response.ok) {
    let errorPayload: unknown
    try {
      errorPayload = await response.json()
    } catch {
      errorPayload = null
    }

    if (isApiError(errorPayload)) {
      throw new ApiRequestError(errorPayload)
    }

    throw new ApiRequestError({
      type: 'about:blank',
      title: 'Error inesperado',
      status: response.status,
      detail: `El servidor respondió con status ${response.status}`,
    })
  }

  if (response.status === 204) {
    return undefined as T
  }

  return response.json() as Promise<T>
}

export const apiClient = {
  get: <T>(path: string, signal?: AbortSignal) =>
    request<T>(path, { method: 'GET', signal }),

  post: <T>(path: string, body: unknown, signal?: AbortSignal) =>
    request<T>(path, { method: 'POST', body, signal }),

  put: <T>(path: string, body: unknown, signal?: AbortSignal) =>
    request<T>(path, { method: 'PUT', body, signal }),

  patch: <T>(path: string, body: unknown, signal?: AbortSignal) =>
    request<T>(path, { method: 'PATCH', body, signal }),

  delete: <T>(path: string, signal?: AbortSignal) =>
    request<T>(path, { method: 'DELETE', signal }),
}
