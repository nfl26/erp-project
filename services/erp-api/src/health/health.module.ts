import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import { HealthController } from './health.controller';

@Module({
  imports: [ConfigModule],
  controllers: [HealthController],
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) =>
        new Redis(configService.get<string>('REDIS_URL', 'redis://localhost:6379'), {
          lazyConnect: true,
          maxRetriesPerRequest: 1,
          connectTimeout: 3000,
        }),
      inject: [ConfigService],
    },
  ],
})
export class HealthModule {}
