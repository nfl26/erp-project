/** Error RFC 7807 — formato estándar que emite NestJS (T-004) */
export interface ApiError {
  type: string
  title: string
  status: number
  detail: string
  instance?: string
  traceId?: string
}

/** Respuesta paginada — estructura debe coincidir con el backend (ver T-016) */
export interface Page<T> {
  data: T[]
  meta: {
    total: number
    page: number
    pageSize: number
    totalPages: number
  }
}

export function isApiError(value: unknown): value is ApiError {
  return (
    typeof value === 'object' &&
    value !== null &&
    'status' in value &&
    'title' in value
  )
}
