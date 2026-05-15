/** RFC 7807 Problem Details — idéntico al de web/public */
export interface ApiError {
  type: string;
  title: string;
  status: number;
  detail: string;
  instance?: string;
  traceId?: string;
}

/** Respuesta paginada — idéntica a la que devuelve el backend (T-016+) */
export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}
