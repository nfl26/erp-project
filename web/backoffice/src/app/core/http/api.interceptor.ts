import { HttpInterceptorFn, HttpErrorResponse } from '@angular/common/http';
import { catchError, throwError } from 'rxjs';
import { env } from '../config/env';
import { ApiError } from './api.types';

export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const apiReq = req.clone({
    url: req.url.startsWith('http') ? req.url : `${env.NG_APP_API_URL}${req.url}`,
    setHeaders: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // TODO T-015: agregar Bearer token de Keycloak
    },
  });

  return next(apiReq).pipe(
    catchError((err: unknown) => {
      if (err instanceof HttpErrorResponse) {
        const apiError: ApiError = {
          type: err.error?.type ?? 'about:blank',
          title: err.error?.title ?? err.statusText,
          status: err.status,
          detail: err.error?.detail ?? err.message,
          instance: err.error?.instance,
          traceId: err.error?.traceId,
        };
        return throwError(() => apiError);
      }
      return throwError(() => err);
    }),
  );
};
