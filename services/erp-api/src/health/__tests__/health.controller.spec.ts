import { ServiceUnavailableException } from '@nestjs/common';
import { HealthController } from '../health.controller';
import { PrismaService } from '../../shared/prisma/prisma.service';

function mockPrisma(fail = false) {
  return {
    $queryRaw: jest
      .fn()
      .mockImplementation(() =>
        fail
          ? Promise.reject(new Error('db connection refused'))
          : Promise.resolve([{ '?column?': 1 }]),
      ),
  } as unknown as PrismaService;
}

function mockRedis(response = 'PONG', fail = false) {
  return {
    ping: jest
      .fn()
      .mockImplementation(() =>
        fail ? Promise.reject(new Error('redis down')) : Promise.resolve(response),
      ),
  } as any;
}

describe('HealthController', () => {
  it('returns ok when database and redis are healthy', async () => {
    const ctrl = new HealthController(mockPrisma(), mockRedis());
    const result = await ctrl.check();
    expect(result.status).toBe('ok');
    expect(result.services.database).toBe('ok');
    expect(result.services.redis).toBe('ok');
    expect(typeof result.timestamp).toBe('string');
  });

  it('throws ServiceUnavailableException when database is down', async () => {
    const ctrl = new HealthController(mockPrisma(true), mockRedis());
    await expect(ctrl.check()).rejects.toThrow(ServiceUnavailableException);
  });

  it('returns redis=error when ping returns unexpected value', async () => {
    const ctrl = new HealthController(mockPrisma(), mockRedis('ERR'));
    const result = await ctrl.check();
    expect(result.services.redis).toBe('error');
  });

  it('returns redis=error when redis throws', async () => {
    const ctrl = new HealthController(mockPrisma(), mockRedis('PONG', true));
    const result = await ctrl.check();
    expect(result.services.redis).toBe('error');
  });
});
