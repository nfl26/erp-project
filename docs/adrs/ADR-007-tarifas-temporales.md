# ADR-007: Tarifas con vigencia temporal inmutables

- **Status:** accepted
- **Date:** 2026-04-17
- **Deciders:** TL, S2, PO
- **Tags:** dominio, produccion, costos, invariante-critico

---

## Contexto

El cliente cobra a sus clientes finales en base a un cálculo que mezcla costos de insumos, costos de máquina y costos de horas-hombre (ver [Glosario](../glossary.md#costo-total-de-op)). Las tarifas por minuto de máquina y por minuto de trabajador **cambian a lo largo del tiempo**:

- Incrementos anuales por IPC.
- Ajustes cuando entra maquinaria nueva más cara.
- Cambios por renegociación sindical (tipos de trabajador).

En los Excel actuales del cliente, cuando sube una tarifa, **sobrescriben la celda**. Esto genera dos problemas serios:

1. **No se puede recalcular una O/P histórica** con las tarifas que realmente estaban vigentes cuando se cerró.
2. **Disputas con clientes finales** imposibles de resolver: "este cobro del mes pasado es incorrecto" → nadie puede reproducir el cálculo original porque la tarifa ya es otra.

El cliente explícitamente pidió que el nuevo sistema resuelva esto. Es una de las razones por las que contrataron el desarrollo.

---

## Decisión

Las tarifas de máquina y tipo de trabajador se modelan como **entidades con vigencia temporal**. Una nueva tarifa **nunca sobrescribe** una anterior — se crea una nueva fila con su propia vigencia, y la anterior queda marcada como cerrada.

### Implementación

```sql
CREATE TABLE tarifas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entidad_tipo text NOT NULL CHECK (entidad_tipo IN ('MAQUINA','TIPO_TRABAJADOR')),
  entidad_id text NOT NULL,  -- código de máquina o enum de tipo trabajador
  valor_por_minuto numeric(14,4) NOT NULL CHECK (valor_por_minuto > 0),
  valid_from timestamptz NOT NULL,
  valid_to timestamptz,  -- null = vigente hasta hoy
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL REFERENCES usuarios(id),
  motivo text NOT NULL
);

-- Restricción: solo una tarifa vigente por entidad al mismo tiempo
CREATE UNIQUE INDEX tarifas_vigente_unica
  ON tarifas (entidad_tipo, entidad_id)
  WHERE valid_to IS NULL;

-- Índice para búsqueda por fecha
CREATE INDEX tarifas_por_fecha
  ON tarifas (entidad_tipo, entidad_id, valid_from, valid_to);
```

### Cómo se cambia una tarifa

Cuando entra una tarifa nueva, se hace en una transacción:

```sql
BEGIN;
  -- Cierra la tarifa anterior
  UPDATE tarifas
  SET valid_to = '2026-01-01 00:00:00'
  WHERE entidad_tipo = 'MAQUINA'
    AND entidad_id = 'SOLD-02'
    AND valid_to IS NULL;

  -- Inserta la nueva
  INSERT INTO tarifas (entidad_tipo, entidad_id, valor_por_minuto, valid_from, valid_to, created_by, motivo)
  VALUES ('MAQUINA', 'SOLD-02', 850, '2026-01-01', NULL, '<uid>', 'Ajuste anual IPC 2026');
COMMIT;
```

Las tarifas con `valid_to` no-nulo son **inmutables**: un trigger de BD bloquea cualquier `UPDATE` sobre ellas.

### Cómo se resuelve una tarifa para un cálculo

Para calcular el costo de una O/P cerrada el `2026-04-15`:

```sql
SELECT valor_por_minuto
FROM tarifas
WHERE entidad_tipo = 'MAQUINA'
  AND entidad_id = 'SOLD-02'
  AND valid_from <= '2026-04-15'
  AND (valid_to > '2026-04-15' OR valid_to IS NULL)
LIMIT 1;
```

**La fecha de referencia es el cierre de la O/P**, no la fecha actual. Esto es lo que permite recalcular costos históricos coherentes.

---

## Alternativas consideradas

### A) Columna `valor` editable en tabla de máquinas/trabajadores

Simplemente un campo en la entidad `Maquina` que se actualiza.

**Pros:**
- Query trivial.
- Sin tabla extra.

**Cons:**
- **Pierde el historial** — exactamente el problema que hay que resolver.
- Al recalcular una O/P histórica se usa la tarifa actual, produciendo cifras incorrectas.
- Imposible auditar cambios de tarifas.
- **Descartada. No resuelve el problema real.**

### B) Tarifas versionadas con tabla de historial paralela

Columna actual editable + tabla `tarifas_historial` de solo-inserción.

**Pros:**
- Consulta rápida de tarifa actual.
- Historial disponible.

**Cons:**
- Dos fuentes de verdad (campo actual vs histórico) que pueden divergir.
- El código de cálculo de costos debe saber "si es hoy usa la columna, si es histórico usa la tabla" → lógica condicional frágil.
- Un bug que actualice la columna sin insertar en historial produce divergencia silenciosa.
- **Descartada.**

### C) Tarifas con vigencia temporal, tabla única inmutable **(elegida)**

Una sola tabla donde cada tarifa vive con sus fechas de vigencia. Las tarifas cerradas son inmutables.

**Pros:**
- **Una sola fuente de verdad** para todo tiempo.
- Recalcular una O/P histórica usa exactamente la misma lógica que calcular una actual.
- Imposible que haya divergencia.
- Auditoría completa por diseño.
- Patrón bien conocido (_bi-temporal data_, _effective dating_).

**Cons:**
- Queries un poco más complejas (rangos de fecha).
- Requiere disciplina: no hay `UPDATE`, siempre cerrar + insertar.

---

## Consecuencias

### Positivas

- **Recalcular cualquier O/P histórica produce el mismo resultado**, sin importar cuántas tarifas hayan cambiado desde su cierre.
- **Resolución de disputas trivial**: "este cobro del 2026-03-10 fue $X porque las tarifas vigentes eran Y, Z y W, documentadas en la BD".
- **Compatibilidad total con la validación contra Excel** ([ADR-008](ADR-008-excel-validation-como-guardrail.md)): los 50 casos del fixture tienen fechas específicas y deben producir los mismos resultados año tras año.
- **Auditoría regulatoria**: el cliente puede responder en cualquier momento "quién, cuándo y por qué cambió esta tarifa".

### Negativas aceptadas

- Overhead en escritura: cambiar una tarifa requiere 2 operaciones SQL en transacción.
- Queries de tarifa vigente son más complejas que un `SELECT` simple.
- Hay que educar al cliente: "cuando sube la tarifa, no se edita, se crea una nueva".

---

## Reglas derivadas que los agentes deben respetar

**⚠️ Críticas — hay tests que verifican esto:**

1. **NUNCA generar código que haga `UPDATE tarifas SET valor_por_minuto = ?` sobre una tarifa existente.** Prohibido.

2. **NUNCA generar código que haga `DELETE FROM tarifas`.** Las tarifas son inmutables.

3. **Para cambiar una tarifa**: siempre una transacción con `UPDATE` de `valid_to` en la anterior + `INSERT` de la nueva. Debe existir un método único `TarifaService.cambiar()` que encapsula esto.

4. **Al calcular costo**: la fecha de referencia es el **cierre** de la O/P (`orden.closed_at`), nunca `now()`. Violación de esta regla produce cálculos incorrectos para O/Ps históricas.

5. **Si no existe tarifa vigente** para una entidad en la fecha de cierre: lanzar excepción clara (`TarifaNoVigenteException`). Nunca usar valor default ni cero.

6. **El campo `motivo` es obligatorio** y debe tener contenido real. No "actualización" — tiene que decir "IPC 2026", "Nueva máquina X", "Renegociación sindical Q2".

7. **Los cambios de tarifa son privilegio del rol `jefe-produccion`** o superior. Nadie más tiene el permiso.

### Cómo verificar que el agente respetó las reglas

En `services/produccion/src/tarifas/TarifaService.java`:

```java
// Debe existir este método y NO debe existir un update() directo
public Tarifa cambiarTarifa(
    EntidadTipo tipo,
    String entidadId,
    `BigDecimal` (originalmente; hoy `Decimal.js` en NestJS — ver ADR-010) nuevoValor,
    Instant desde,
    String motivo,
    UUID usuario
);

// Método explícitamente prohibido — un test debe fallar si alguien lo crea
// public Tarifa updateTarifa(UUID id, BigDecimal nuevoValor); // ← NO
```

Un test de invariante bloquea cualquier PR que intente modificar tarifas con `valid_to` no nulo.

---

## Ejemplo completo

**Situación:**
- El 2025-06-01 entra la tarifa inicial de máquina `SOLD-02` a $780/min.
- El 2026-01-01 sube a $850/min por IPC.
- El 2026-04-15 se cierra una O/P que usó `SOLD-02`.

**Estado de la tabla `tarifas`:**

| id | entidad_tipo | entidad_id | valor | valid_from | valid_to | motivo |
|---|---|---|---|---|---|---|
| a1 | MAQUINA | SOLD-02 | 780.00 | 2025-06-01 | 2026-01-01 | Tarifa inicial |
| a2 | MAQUINA | SOLD-02 | 850.00 | 2026-01-01 | NULL | IPC 2026 |

**Cálculo al 2026-04-15:** usa tarifa `a2` → $850/min.

**Si en 2026-07-01 sube nuevamente a $900** y el cliente pregunta por la O/P del 2026-04-15:

- Query en `tarifas` con fecha 2026-04-15 → sigue devolviendo $850.
- El cálculo da el mismo resultado que tenía cuando se cerró.
- El cliente tiene una respuesta auditable.

---

## Referencias

- Patrón _Effective Dating_ / _Bi-temporal data_ (ver libros de Martin Fowler).
- [Glosario](../glossary.md) — definición de [Tarifa](../glossary.md#tarifa).
- [ADR-005](ADR-005-stock-calculado-desde-movimientos.md) — patrón similar de inmutabilidad aplicado a stock.
- [ADR-008](ADR-008-excel-validation-como-guardrail.md) — validación contra Excel que depende de esta decisión.
- Tickets T-029, T-030 — implementación del motor de costos y tarifas.

---

**Revisitar esta decisión si:** el cliente cambia requisitos regulatorios que exijan edición directa (muy improbable) o si el patrón resulta insuficiente para casos de negocio nuevos (por ejemplo, tarifas dependientes de múltiples dimensiones como cliente + máquina).
