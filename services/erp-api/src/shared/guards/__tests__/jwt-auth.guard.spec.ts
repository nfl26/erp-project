import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtAuthGuard } from '../jwt-auth.guard';

function mockContext(url = '/api/v1/test') {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ url }),
    }),
  } as unknown as ExecutionContext;
}

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;

  beforeEach(() => {
    guard = new JwtAuthGuard();
  });

  it('allows access in non-production environment', () => {
    const original = process.env['NODE_ENV'];
    process.env['NODE_ENV'] = 'development';
    expect(guard.canActivate(mockContext())).toBe(true);
    process.env['NODE_ENV'] = original;
  });

  it('throws UnauthorizedException in production environment', () => {
    const original = process.env['NODE_ENV'];
    process.env['NODE_ENV'] = 'production';
    expect(() => guard.canActivate(mockContext())).toThrow(UnauthorizedException);
    process.env['NODE_ENV'] = original;
  });
});
