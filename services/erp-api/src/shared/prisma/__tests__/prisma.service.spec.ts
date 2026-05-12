import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma.service';

const mockConfigService = {
  get: jest.fn().mockReturnValue('postgresql://test:test@localhost:5432/test'),
};

describe('PrismaService', () => {
  let service: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PrismaService,
        { provide: ConfigService, useValue: mockConfigService },
      ],
    }).compile();

    service = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('calls $connect on onModuleInit', async () => {
    const spy = jest.spyOn(service, '$connect').mockResolvedValue();
    await service.onModuleInit();
    expect(spy).toHaveBeenCalledTimes(1);
  });

  it('calls $disconnect on onModuleDestroy', async () => {
    const spy = jest.spyOn(service, '$disconnect').mockResolvedValue();
    await service.onModuleDestroy();
    expect(spy).toHaveBeenCalledTimes(1);
  });
});
