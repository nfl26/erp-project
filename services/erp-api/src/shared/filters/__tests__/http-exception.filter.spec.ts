import { HttpException, HttpStatus } from '@nestjs/common';
import { HttpExceptionFilter } from '../http-exception.filter';

function makeHost(url: string, traceId?: string) {
  const sent: { statusCode: number; body: unknown } = { statusCode: 0, body: null };
  const request = { url, headers: traceId ? { 'x-trace-id': traceId } : {} };
  const response = {
    status: (code: number) => ({
      send: (body: unknown) => {
        sent.statusCode = code;
        sent.body = body;
      },
    }),
  };
  return {
    host: {
      switchToHttp: () => ({
        getRequest: () => request,
        getResponse: () => response,
      }),
    } as any,
    sent,
  };
}

describe('HttpExceptionFilter', () => {
  let filter: HttpExceptionFilter;

  beforeEach(() => {
    filter = new HttpExceptionFilter();
  });

  it('formats a 404 as RFC 7807', () => {
    const { host, sent } = makeHost('/api/v1/not-found');
    filter.catch(new HttpException('Not found', HttpStatus.NOT_FOUND), host);

    expect(sent.statusCode).toBe(404);
    const body = sent.body as Record<string, unknown>;
    expect(body['type']).toBe('https://erp.arteo.cl/errors/not-found');
    expect(body['title']).toBe('Not Found');
    expect(body['status']).toBe(404);
    expect(body['instance']).toBe('/api/v1/not-found');
    expect(typeof body['timestamp']).toBe('string');
    expect(typeof body['traceId']).toBe('string');
  });

  it('propagates x-trace-id header into traceId', () => {
    const { host, sent } = makeHost('/api/v1/test', 'trace-abc-123');
    filter.catch(new HttpException('Forbidden', HttpStatus.FORBIDDEN), host);

    const body = sent.body as Record<string, unknown>;
    expect(body['traceId']).toBe('trace-abc-123');
  });

  it('joins array messages into a single detail string', () => {
    const { host, sent } = makeHost('/api/v1/bodega/insumos');
    filter.catch(
      new HttpException(
        { message: ['nombre must not be empty', 'precio must be a number'] },
        HttpStatus.UNPROCESSABLE_ENTITY,
      ),
      host,
    );

    const body = sent.body as Record<string, unknown>;
    expect(body['status']).toBe(422);
    expect(body['type']).toBe('https://erp.arteo.cl/errors/validation-error');
    expect(body['detail']).toContain('nombre must not be empty');
    expect(body['detail']).toContain('precio must be a number');
  });
});
