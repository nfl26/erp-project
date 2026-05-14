import { z } from 'zod';

/**
 * Schemas Zod de los eventos del dominio producción.
 *
 * HOY: estos eventos viajan internamente con EventEmitter2 (monolito).
 * FUTURO: cuando el módulo se extraiga como microservicio, viajarán por
 * RabbitMQ. El schema es idéntico — solo cambia el transporte.
 *
 * Catálogo autoritativo: docs/events.md
 * Roadmap de extracción: docs/roadmap-microservicios.md
 */

// ─── Envelope compartido ───────────────────────────────────────────────────
// Campos definidos en docs/events.md § "Estructura estándar de un evento"

export const EnvelopeSchema = z.object({
  eventId:       z.string().uuid(),
  eventType:     z.string().min(1),
  occurredAt:    z.string().datetime(),
  producedBy:    z.string().min(1),   // formato: {servicio}@{build-tag}
  tenantId:      z.string().min(1),
  correlationId: z.string().optional(),
  causationId:   z.string().optional(),
});

export type Envelope = z.infer<typeof EnvelopeSchema>;

// ─── produccion.op.creada.v1 ──────────────────────────────────────────────
// Emitido cuando se crea una O/P (manualmente o desde venta.confirmada.v1).
// Payload mínimo — se amplía en T-028 (submódulo ordenes).

export const OpCreadaPayloadSchema = z.object({
  opId:         z.string().uuid(),
  ordenVentaId: z.string().uuid().nullable(),
  productoId:   z.string().uuid(),
  cantidad:     z.number().int().positive(),
  creadaPor:    z.string().uuid(),
});

export const OpCreadaSchema = z.object({
  envelope: EnvelopeSchema.refine(
    (e) => e.eventType === 'produccion.op.creada.v1',
    { message: "eventType debe ser 'produccion.op.creada.v1'" },
  ),
  payload: OpCreadaPayloadSchema,
});

export type OpCreadaEvent = z.infer<typeof OpCreadaSchema>;

// ─── produccion.op.cerrada.v1 ─────────────────────────────────────────────
// El evento monetariamente más crítico del sistema. Contiene el breakdown
// completo de costos. Detalle de payload en docs/events.md.

const CostoBreakdownEventSchema = z.object({
  costoInsumos:     z.string(),
  costoMaquina:     z.string(),
  costoHorasHombre: z.string(),
  costoTotal:       z.string(),
  detalleInsumos: z
    .array(
      z.object({
        insumoId:       z.string().uuid(),
        cantidad:       z.string(),
        precioUnitario: z.string(),
        subtotal:       z.string(),
      }),
    )
    .optional(),
});

export const OpCerradaPayloadSchema = z.object({
  ordenId:       z.string().uuid(),
  codigo:        z.string().min(1),
  ordenVentaId:  z.string().uuid().nullable().optional(),
  productoId:    z.string().uuid(),
  varianteId:    z.string().uuid(),
  recetaVersion: z.number().int().positive(),
  cantidad:      z.number().int().positive(),
  breakdown:     CostoBreakdownEventSchema,
  fechaCierre:   z.string().datetime(),
  cerradaPor:    z.string().uuid(),
});

export const OpCerradaSchema = z.object({
  envelope: EnvelopeSchema.refine(
    (e) => e.eventType === 'produccion.op.cerrada.v1',
    { message: "eventType debe ser 'produccion.op.cerrada.v1'" },
  ),
  payload: OpCerradaPayloadSchema,
});

export type OpCerradaEvent = z.infer<typeof OpCerradaSchema>;

// ─── produccion.tarifa.cambiada.v1 ────────────────────────────────────────
// Emitido cuando se registra una tarifa nueva cerrando la anterior.
// Ver ADR-007 (tarifas con vigencia temporal). Detalle en docs/events.md.

export const TarifaCambiadaPayloadSchema = z.object({
  tarifaAnteriorId: z.string().uuid().nullable(),
  tarifaNuevaId:    z.string().uuid(),
  entidadTipo:      z.enum(['MAQUINA', 'TIPO_TRABAJADOR']),
  entidadId:        z.string().min(1),
  valorAnterior:    z.string().nullable(),
  valorNuevo:       z.string(),
  validFrom:        z.string().datetime(),
  motivo:           z.string().min(1),
  cambiadaPor:      z.string().uuid(),
});

export const TarifaCambiadaSchema = z.object({
  envelope: EnvelopeSchema.refine(
    (e) => e.eventType === 'produccion.tarifa.cambiada.v1',
    { message: "eventType debe ser 'produccion.tarifa.cambiada.v1'" },
  ),
  payload: TarifaCambiadaPayloadSchema,
});

export type TarifaCambiadaEvent = z.infer<typeof TarifaCambiadaSchema>;
