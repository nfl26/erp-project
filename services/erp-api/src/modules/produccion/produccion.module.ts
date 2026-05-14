import { Module } from '@nestjs/common';
import { ProduccionFacade } from './public/produccion.facade';

/**
 * Módulo producción — bounded context del motor de costos, recetas y órdenes.
 *
 * Regla de encapsulamiento: otros módulos del monolito solo pueden importar
 * desde ./public/. Nunca desde ./internal/. Ver README.md de este módulo.
 *
 * Submódulos internos se implementan en tickets posteriores:
 * - recetas   → T-026
 * - variantes → T-027
 * - ordenes   → T-028
 * - costos    → T-029
 * - tarifas   → T-030
 */
@Module({
  providers: [ProduccionFacade],
  exports: [ProduccionFacade],
})
export class ProduccionModule {}
