/**
 * Tipos públicos del módulo producción.
 * Solo estos tipos son accesibles para otros módulos del monolito.
 * Tipos internos (Receta, Variante, Tarifa interna, etc.) viven en internal/.
 */

/** Breakdown de costos calculados para una O/P. */
export interface CostoBreakdown {
  costoInsumos: string;      // Decimal como string, 2 decimales
  costoMaquina: string;
  costoHorasHombre: string;
  costoTotal: string;
  detalleInsumos: DetalleInsumo[];
}

export interface DetalleInsumo {
  insumoId: string;
  cantidad: string;
  precioUnitario: string;
  subtotal: string;
}

/** Tarifa vigente para una entidad (máquina o tipo de trabajador) en una fecha. */
export interface TarifaVigenteResult {
  tarifaId: string;
  entidadTipo: 'MAQUINA' | 'TIPO_TRABAJADOR';
  entidadId: string;
  valorPorMinuto: string;    // Decimal como string, 4 decimales
  validFrom: string;         // ISO 8601
  validTo: string | null;
}
