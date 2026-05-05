# ADR-005: Stock calculado desde movimientos, no editable directamente

- **Status:** accepted
- **Date:** 2026-04-16
- **Deciders:** TL, PO, S1
- **Tags:** dominio, bodega, invariante-critico, auditoria

---

## Contexto

El stock de un insumo es el dato más consultado y más sensible del módulo de bodega. Si está mal, todo el sistema de costos y producción se contamina en cascada. En los Excel del cliente, el stock se edita directamente en una celda y el historial se pierde — causa de varios errores operativos que el cliente mencionó en el kickoff.

Hay dos formas de modelar stock en sistemas ERP:

1. **Stock como saldo editable:** una columna `stock_actual` en la tabla de insumos, modificable directamente por endpoints o por UI.
2. **Stock como saldo calculado:** una tabla de movimientos inmutables, y `stock_actual` es siempre `SUM(entradas) - SUM(salidas)`.

Esta decisión tiene ramificaciones profundas en toda la arquitectura del módulo de bodega y afecta directamente al cálculo de costos del módulo de producción.

---

## Decisión

El **stock actual de un insumo es un valor derivado, calculado siempre desde la tabla `movimientos_bodega`**. Nunca editable directamente.

### Implementación

```sql
-- Tabla de movimientos: inmutable, append-only
CREATE TABLE movimientos_bodega (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  insumo_id uuid NOT NULL REFERENCES insumos(id),
  tipo text NOT NULL CHECK (tipo IN ('ENTRADA','SALIDA','AJUSTE_POSITIVO','AJUSTE_NEGATIVO')),
  cantidad numeric(14,4) NOT NULL CHECK (cantidad > 0),
  precio_unitario numeric(14,4),
  motivo text NOT NULL,
  referencia_externa text,
  usuario_id uuid NOT NULL REFERENCES usuarios(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Regla: nunca UPDATE, nunca DELETE
REVOKE UPDATE, DELETE ON movimientos_bodega FROM PUBLIC;

-- Vista materializada para consulta rápida
CREATE MATERIALIZED VIEW stock_actual AS
SELECT
  i.id AS insumo_id,
  i.codigo_interno,
  COALESCE(SUM(
    CASE
      WHEN m.tipo IN ('ENTRADA','AJUSTE_POSITIVO') THEN m.cantidad
      WHEN m.tipo IN ('SALIDA','AJUSTE_NEGATIVO') THEN -m.cantidad
    END
  ), 0) AS stock_actual
FROM insumos i
LEFT JOIN movimientos_bodega m ON m.insumo_id = i.id
GROUP BY i.id, i.codigo_interno;

CREATE UNIQUE INDEX ON stock_actual (insumo_id);
```

La vista materializada se refresca en tiempo real (trigger al insertar movimiento) o cada N segundos según carga. En tiempo de diseño: trigger. En tiempo de carga alta: cache en Redis.

### Operaciones válidas

| Operación | Cómo se hace |
|---|---|
| Consultar stock actual | Query a `stock_actual` (vista) o cache Redis |
| Aumentar stock | Insertar movimiento tipo `ENTRADA` |
| Disminuir stock | Insertar movimiento tipo `SALIDA` |
| Corregir stock al alza | Insertar movimiento `AJUSTE_POSITIVO` con motivo |
| Corregir stock a la baja | Insertar movimiento `AJUSTE_NEGATIVO` con motivo |
| Cambiar el stock histórico | **Imposible.** Hay que insertar un ajuste. |

### Validación de stock no negativo

Antes de insertar un movimiento de salida:

```typescript
await this.db.$transaction(async (tx) => {
  // Lock pesimista sobre el insumo para evitar race conditions
  const insumo = await tx.$queryRaw`
    SELECT id FROM insumos WHERE id = ${insumoId} FOR UPDATE
  `;

  const stockActual = await tx.stockActual.findUnique({
    where: { insumo_id: insumoId }
  });

  if (stockActual.stock_actual - cantidad < 0) {
    throw new StockInsuficienteException();
  }

  await tx.movimientoBodega.create({
    data: { insumo_id: insumoId, tipo: 'SALIDA', cantidad, ... }
  });
});
```

---

## Alternativas consideradas

### A) Stock como columna editable

Columna `stock_actual` en `insumos`, editable.

**Pros:**
- Query trivial: `SELECT stock_actual FROM insumos WHERE id = ?`.
- Menos storage (no se guarda historial).

**Cons:**
- **Pierde la trazabilidad histórica.** ¿Por qué el stock bajó de 50 a 30? ¿Quién lo hizo? ¿Cuándo?
- Race conditions graves si dos procesos escriben al mismo tiempo.
- No hay forma de reconstruir el pasado (imposible recalcular costos históricos).
- El cliente tuvo problemas exactamente por esto en sus Excel.
- **Descartada.**

### B) Stock como columna + tabla de movimientos paralela

Stock editable pero se escribe también un registro en movimientos.

**Pros:**
- Queries rápidas.
- Trazabilidad parcial.

**Cons:**
- Dos fuentes de verdad que pueden divergir (bug típico de ERPs viejos).
- Si un bug hace que se actualice el stock sin insertar movimiento, la divergencia es silenciosa.
- Requiere trigger de verificación periódica.
- **Descartada.**

### C) Stock como saldo calculado desde movimientos **(elegida)**

Solo los movimientos son la fuente de verdad. El stock es siempre derivado.

**Pros:**
- **Una sola fuente de verdad.** Imposible que diverja.
- Auditoría completa por diseño (no hay que agregar logs).
- Permite reconstruir el stock en cualquier momento del pasado: `SUM(entradas - salidas WHERE created_at < timestamp)`.
- Natural para la lógica de cálculo de costo histórico (ADR-007).
- Alineado con el patrón de event sourcing sin la complejidad completa.

**Cons:**
- Queries requieren agregación. Mitigación: vista materializada + cache.
- Alto volumen de movimientos requiere particionamiento después. Mitigación: pensarlo cuando pase, no antes.

---

## Consecuencias

### Positivas

- **Trazabilidad total**: "¿quién, cuándo, por qué cambió este stock?" siempre es contestable.
- **Compatibilidad con cálculo de costos**: el precio usado para valorizar consumo es el del último movimiento de entrada **anterior al cierre de la O/P**. Esto solo es posible porque los movimientos son inmutables y fechados.
- **Reconciliación periódica**: se puede comparar el stock calculado con inventario físico y generar ajustes visibles.
- **Detección de anomalías**: queries analíticas sobre movimientos revelan patrones (mermas, robos, errores operativos).

### Negativas aceptadas

- Cada consulta de stock requiere un JOIN/agregación (mitigado con vista materializada y cache Redis).
- Operaciones de escritura son un poco más caras (insertar + refrescar vista).
- Hay que educar al cliente: "no puedes editar el stock, solo puedes registrar movimientos".

---

## Reglas derivadas que los agentes deben respetar

**⚠️ Críticas — hay tests que verifican esto:**

1. **NUNCA generar un endpoint que haga `UPDATE insumos SET stock_actual = ?`.** El campo ni siquiera existe en la tabla.
2. **NUNCA generar un endpoint que permita `DELETE` sobre un movimiento.** Los movimientos son inmutables.
3. **Las salidas requieren validación de stock con lock pesimista** (ver código arriba).
4. **Toda mutación emite evento** `bodega.movimiento.v1` a RabbitMQ.
5. **Los movimientos son append-only**. Si hay un error, se corrige con otro movimiento (`AJUSTE_*`).
6. **El campo `motivo` es obligatorio** y con contenido significativo, no un placeholder.

### Cómo corregir un error en stock

Si el bodeguero descubre que el sistema marca 50 unidades pero físicamente hay 48:

```typescript
// NO: UPDATE insumos SET stock_actual = 48  ← imposible, el campo no existe

// SÍ: insertar movimiento de ajuste
await service.registrarMovimiento({
  tipo: 'AJUSTE_NEGATIVO',
  cantidad: 2,
  motivo: 'Inventario físico 2026-04-15: diferencia de -2 unidades. Acta adjunta.',
  referencia_externa: 'ACTA-INV-2026-04-15'
});
```

El historial queda intacto y explicado.

---

## Performance y escalabilidad

### MVP (hasta ~100k movimientos)

- Vista materializada refrescada por trigger.
- Cache en Redis con TTL de 10 segundos.
- Sin particionamiento.

### Cuando supere ~1M movimientos

- Particionar `movimientos_bodega` por rango de fecha (mensual).
- Snapshot periódico de stock (tabla `stock_snapshots` con stock al cierre de cada mes).
- Cálculo incremental: `stock_actual = snapshot_ultimo + SUM(movimientos desde snapshot)`.

### Cuando haya multi-tenancy activa

- Particionar también por `tenant_id` (esquema separado según ADR-003).

---

## Referencias

- Patrón _Event Sourcing_ (variante parcial aplicada).
- _Domain-Driven Design_ (Evans) — inmutabilidad de eventos de dominio.
- [Glosario](../glossary.md) — definiciones de [Movimiento de bodega](../glossary.md#movimiento-de-bodega), [Stock crítico](../glossary.md#stock-crítico).
- [ADR-001](ADR-001-microservicios-por-dominio.md) — contexto de microservicios.
- [ADR-007](ADR-007-tarifas-temporales.md) — patrón similar aplicado a tarifas.
- Tickets T-014, T-015, T-017 — implementación de bodega en el MVP.

---

**Revisitar esta decisión si:**

- El volumen de movimientos hace que el cálculo sea insostenible incluso con snapshots y cache (improbable a escala del cliente).
- El cliente exige la edición directa de stock por motivos regulatorios específicos (pedir ADR nuevo que supere este).
