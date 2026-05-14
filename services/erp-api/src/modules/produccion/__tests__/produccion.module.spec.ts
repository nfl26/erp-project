import { Test } from '@nestjs/testing';
import { NotImplementedException } from '@nestjs/common';
import { ProduccionModule } from '../produccion.module';
import { ProduccionFacade } from '../public/produccion.facade';

describe('ProduccionModule', () => {
  let facade: ProduccionFacade;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ProduccionModule],
    }).compile();

    facade = moduleRef.get(ProduccionFacade);
  });

  // Caso 1: el módulo arranca sin errores
  it('el módulo se carga sin errores de DI', () => {
    expect(facade).toBeDefined();
  });

  // Caso 2: ProduccionFacade es inyectable
  it('ProduccionFacade está disponible para inyección', () => {
    expect(facade).toBeInstanceOf(ProduccionFacade);
  });

  // Caso 2 (cont.): los métodos placeholder lanzan NotImplementedException
  describe('métodos placeholder', () => {
    it('obtenerCostoActualDeOP lanza NotImplementedException (no Error genérico)', async () => {
      await expect(facade.obtenerCostoActualDeOP('op-123')).rejects.toThrow(
        NotImplementedException,
      );
    });

    it('obtenerTarifaVigente lanza NotImplementedException (no Error genérico)', async () => {
      await expect(
        facade.obtenerTarifaVigente('MAQUINA', 'maquina-1', new Date()),
      ).rejects.toThrow(NotImplementedException);
    });
  });

  // Caso 7: el módulo puede coexistir con PrismaService en el contexto de DI
  // (sin conexión real a BD — se resuelve cuando T-026+ inyecte PrismaService)
  it('ProduccionModule no rompe el grafo de DI cuando PrismaService está disponible', async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ProduccionModule],
      providers: [
        {
          provide: 'PrismaService',
          useValue: { $connect: jest.fn(), $disconnect: jest.fn() },
        },
      ],
    }).compile();

    expect(moduleRef.get(ProduccionFacade)).toBeDefined();
  });
});
