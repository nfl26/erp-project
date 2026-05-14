import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { PrismaModule } from './shared/prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { ProduccionModule } from './modules/produccion/produccion.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    EventEmitterModule.forRoot({
      wildcard: true,
      maxListeners: 20,
    }),
    PrismaModule,
    HealthModule,
    ProduccionModule,
  ],
})
export class AppModule {}
