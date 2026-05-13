import { ExecutionContext } from '@nestjs/common';
import { of, throwError } from 'rxjs';
import { LoggingInterceptor } from '../logging.interceptor';

function mockContext() {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ method: 'GET', url: '/api/v1/test' }),
      getResponse: () => ({ statusCode: 200 }),
    }),
  } as unknown as ExecutionContext;
}

describe('LoggingInterceptor', () => {
  let interceptor: LoggingInterceptor;

  beforeEach(() => {
    interceptor = new LoggingInterceptor();
  });

  it('passes through the response value', (done) => {
    const handler = { handle: () => of({ status: 'ok' }) };
    interceptor.intercept(mockContext(), handler).subscribe({
      next: (value) => expect(value).toEqual({ status: 'ok' }),
      complete: done,
    });
  });

  it('propagates errors from the handler', (done) => {
    const error = new Error('upstream failure');
    const handler = { handle: () => throwError(() => error) };
    interceptor.intercept(mockContext(), handler).subscribe({
      error: (e) => {
        expect(e).toBe(error);
        done();
      },
    });
  });
});
