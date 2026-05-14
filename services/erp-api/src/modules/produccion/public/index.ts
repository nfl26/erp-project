/**
 * API pública del módulo producción.
 * Re-exporta únicamente la fachada y los tipos públicos.
 *
 * REGLA: nunca re-exportar nada que venga de ./internal/
 * Si necesitas exponer algo nuevo, agrégalo a la fachada o a types.ts
 * y coordina con S1 (y S2 si toca el dominio de costos).
 */
export { ProduccionFacade } from './produccion.facade';
export type { CostoBreakdown, DetalleInsumo, TarifaVigenteResult } from './types';
