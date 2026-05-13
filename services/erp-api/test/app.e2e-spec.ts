import { Test, TestingModule } from '@nestjs/testing';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/shared/prisma/prisma.service';

describe('Health (e2e)', () => {
  let app: NestFastifyApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue({
        $connect: jest.fn(),
        $disconnect: jest.fn(),
        $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
      })
      .overrideProvider('REDIS_CLIENT')
      .useValue({ ping: jest.fn().mockResolvedValue('PONG') })
      .compile();

    app = moduleFixture.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health → 200 with ok status', async () => {
    const response = await app
      .getHttpAdapter()
      .getInstance()
      .inject({ method: 'GET', url: '/health' });

    expect(response.statusCode).toBe(200);

    const body = JSON.parse(response.payload) as {
      status: string;
      timestamp: string;
      services: { database: string; redis: string };
    };
    expect(body.status).toBe('ok');
    expect(body.services.database).toBe('ok');
    expect(body.services.redis).toBe('ok');
    expect(typeof body.timestamp).toBe('string');
  });

  it('GET /health → 503 when database is down', async () => {
    const prisma = app.get(PrismaService);
    jest.spyOn(prisma, '$queryRaw').mockRejectedValueOnce(new Error('connection refused'));

    const response = await app
      .getHttpAdapter()
      .getInstance()
      .inject({ method: 'GET', url: '/health' });

    expect(response.statusCode).toBe(503);
  });
});
