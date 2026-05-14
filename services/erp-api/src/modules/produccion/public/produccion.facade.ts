import { Injectable, NotImplementedException } from '@nestjs/common';
import type { CostoBreakdown, TarifaVigenteResult } from './types';

/**
 * Fachada pública del módulo producción.
 * Único punto de entrada para que otros módulos del monolito interactúen
 * con el dominio de producción.
 *
 * Los métodos lanzan NotImplementedException hasta que los submódulos
 * correspondientes sean implementados (T-026 a T-034).
 */
@Injectable()
export class ProduccionFacade {
  /**
   * Retorna el breakdown de costos de una O/P cerrada.
   * Implementado en T-034 (motor de costos + validación fixture Excel).
   */
  async obtenerCostoActualDeOP(_opId: string): Promise<CostoBreakdown> {
    throw new NotImplementedException(
      'obtenerCostoActualDeOP — pendiente T-034',
    );
  }

  /**
   * Retorna la tarifa vigente para una entidad (máquina o tipo de trabajador)
   * en una fecha dada. Usa la tarifa con valid_from <= fecha < valid_to.
   * Implementado en T-030 (submódulo tarifas).
   */
  async obtenerTarifaVigente(
    _entidadTipo: string,
    _entidadId: string,
    _fecha: Date,
  ): Promise<TarifaVigenteResult> {
    throw new NotImplementedException(
      'obtenerTarifaVigente — pendiente T-030',
    );
  }
}
