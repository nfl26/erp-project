# T-MVP-002 · Tarifas con vigencia temporal

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-MVP-002
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1 (con revisión obligatoria de PO y S2 antes de mergear)
**Sprint:** Sprint 2
**Estimación:** 13 puntos
**Prioridad:** crítica
**Rama:** `feat/T-MVP-002-tarifas-temporales`

---

## Contexto de negocio

Arteo cierra órdenes de producción con un costo calculado que mezcla tres componentes tarifados:

1. **Costo de máquina** — precio por minuto de operación de la cortadora/grabadora (hoy en `niveles_precio_corte.precio_por_minuto`).
2. **Costo de mano de obra** — valor hora del operario que ejecutó la O/P (hoy en `mano_de_obra.valor_hora`).
3. **Costo de material** — `valor_plancha` del material usado (hoy en `materiales.valor_plancha`).

Los tres son valores únicos, sin historial. Cuando Arteo sube el precio del acero o ajusta tarifas de máquina por IPC, **el nuevo valor sobreescribe el anterior**. Consecuencia: recalcular una O/P de hace tres meses da un costo diferente al que se cerró y facturó. Eso es incorrecto.

[ADR-007](../../docs/adrs/ADR-007-tarifas-temporales.md) define la solución: una tabla `tarifas` con `valid_from`/`valid_to` que preserva el historial completo. Las columnas de precio actuales pasan a ser campos de display/referencia rápida, y la fuente de verdad para cálculos es siempre la función `obtener_tarifa_vigente(tipo, id, fecha)`.

Este ticket también incluye la migración de datos existentes (backfill): los precios actuales pasan a la nueva tabla como tarifas vigentes desde `now()`.

> ⚠️ **Este ticket es de Sprint 2.** Requiere que PO confirme tres reglas de negocio que impactan el diseño (ver sección "Preguntas abiertas para PO"). No ejecutar sin esas respuestas.

---

## Prerrequisitos

- [ ] **T-MVP-001 completado** — patrón de inmutabilidad establecido.
- [ ] **T-008 completado** — auth funcional, necesario para `created_by` en tarifas.
- [ ] **PO confirmó las tres preguntas de negocio** de la sección correspondiente.
- [ ] Verificar:
  ```bash
  docker compose exec postgres psql -U erp_admin -d erp_db -c "
    SELECT id_nivel, nivel, precio_por_minuto FROM tenant_erp.niveles_precio_corte;"
  # Revisar qué registros hay y cuántos — determina el volumen del backfill
  ```

---

## Preguntas abiertas para PO

**Deben responderse antes de iniciar el ticket.**

1. **¿`valor_plancha` en materiales entra en el sistema de tarifas?**
   Los costos de material se calculan como `valor_plancha × area_usada`. Si el precio de un material sube, ¿se requiere calcular O/Ps históricas con el precio que tenía el material en la fecha de cierre? Si la respuesta es sí, `valor_plancha` necesita la misma tabla de tarifas. Si es no (el costo del material se fija cuando se registra la compra en `detalle_compra.precio_unitario`), entonces `valor_plancha` queda fuera del sistema de tarifas.

2. **¿`valor_hora` de mano de obra es tarifa de máquina o tarifa de persona?**
   ADR-007 describe `entidad_tipo IN ('MAQUINA','TIPO_TRABAJADOR')`. El schema actual tiene `mano_de_obra.valor_hora` como tarifa individual por operario, no por tipo. ¿La tarifa es por persona o por especialidad (ej: "cortador láser")?

3. **¿Qué fecha se usa como `valid_from` para el backfill inicial?**
   Los valores actuales en la BD no tienen fecha de origen. Tres opciones: (a) usar `'2020-01-01'` como fecha arbitraria de inicio, (b) usar la fecha de creación del primer registro encontrado en `created_at` de otras tablas, (c) usar la fecha del despliegue de esta migración. El PO debe decidir cuál es más preciso para el historial del cliente.

---

## Alcance técnico

### Nuevo en `schema.prisma`

```prisma
enum TipoEntidadTarifa {
  NIVEL_CORTE       // corresponde a niveles_precio_corte
  MANO_DE_OBRA      // corresponde a mano_de_obra
  MATERIAL          // solo si PO confirma pregunta 1

  @@schema("tenant_erp")
  @@map("tipo_entidad_tarifa")
}

model Tarifa {
  id_tarifa       Int                @id @default(autoincrement())
  tipo_entidad    TipoEntidadTarifa
  id_entidad      Int                // FK polimórfica: id_nivel, id_operario, o id_material
  valor           Decimal            @db.Decimal(14, 4)  // valor por unidad (minuto u hora)
  valid_from      DateTime           @db.Timestamptz(6)
  valid_to        DateTime?          @db.Timestamptz(6)  // NULL = vigente
  created_at      DateTime           @default(now()) @db.Timestamptz(6)
  id_usuario      Int                // quién creó la tarifa
  motivo          String             @db.VarChar(500)

  usuario Usuario @relation(fields: [id_usuario], references: [id_usuario])

  @@map("tarifas")
  @@schema("tenant_erp")
}
```

### Migración SQL adicional

```sql
-- 1. Restricción: una sola tarifa vigente por entidad al mismo tiempo
CREATE UNIQUE INDEX tarifas_vigente_unica
  ON tenant_erp.tarifas (tipo_entidad, id_entidad)
  WHERE valid_to IS NULL;

-- 2. Restricción: tarifas cerradas son inmutables
-- Trigger que bloquea UPDATE sobre filas con valid_to NOT NULL
CREATE OR REPLACE FUNCTION tenant_erp.bloquear_update_tarifa_cerrada()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.valid_to IS NOT NULL THEN
    RAISE EXCEPTION 'Las tarifas cerradas son inmutables. valid_to = %', OLD.valid_to;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_tarifa_inmutable
  BEFORE UPDATE ON tenant_erp.tarifas
  FOR EACH ROW EXECUTE FUNCTION tenant_erp.bloquear_update_tarifa_cerrada();

-- 3. Función para resolver tarifa vigente en una fecha dada
CREATE OR REPLACE FUNCTION tenant_erp.obtener_tarifa_vigente(
  p_tipo_entidad tenant_erp.tipo_entidad_tarifa,
  p_id_entidad   INT,
  p_fecha        TIMESTAMPTZ DEFAULT now()
) RETURNS DECIMAL AS $$
DECLARE
  v_valor DECIMAL;
BEGIN
  SELECT valor INTO v_valor
  FROM tenant_erp.tarifas
  WHERE tipo_entidad = p_tipo_entidad
    AND id_entidad   = p_id_entidad
    AND valid_from  <= p_fecha
    AND (valid_to   >  p_fecha OR valid_to IS NULL)
  ORDER BY valid_from DESC
  LIMIT 1;

  IF v_valor IS NULL THEN
    RAISE EXCEPTION 'No existe tarifa vigente para % id=% en fecha %',
      p_tipo_entidad, p_id_entidad, p_fecha;
  END IF;

  RETURN v_valor;
END;
$$ LANGUAGE plpgsql;

-- 4. Índice para la función de resolución
CREATE INDEX idx_tarifas_resolucion
  ON tenant_erp.tarifas (tipo_entidad, id_entidad, valid_from, valid_to);

-- 5. BACKFILL: migrar valores actuales como tarifas vigentes
-- (La fecha valid_from la define PO según respuesta a pregunta 3)
INSERT INTO tenant_erp.tarifas
  (tipo_entidad, id_entidad, valor, valid_from, valid_to, id_usuario, motivo)
SELECT
  'NIVEL_CORTE',
  id_nivel,
  precio_por_minuto,
  '<FECHA_DEFINIDA_POR_PO>',  -- A1 reemplaza con la fecha que responda PO
  NULL,
  (SELECT id_usuario FROM tenant_erp.usuarios WHERE rol = 'admin' LIMIT 1),
  'Migración inicial desde niveles_precio_corte — T-MVP-002'
FROM tenant_erp.niveles_precio_corte
ON CONFLICT DO NOTHING;

-- Backfill mano_de_obra (similar al de arriba, según respuesta PO pregunta 2)
-- Backfill materiales (solo si PO confirma pregunta 1)
```

### Modificar en `services/erp-api/src/`

```
src/modules/produccion/
└── tarifas/
    ├── tarifa.module.ts
    ├── tarifa.service.ts         ← cambiar(), obtenerVigente(), historial()
    ├── tarifa.controller.ts      ← GET /tarifas, POST /tarifas/cambiar
    ├── dto/
    │   ├── cambiar-tarifa.dto.ts
    │   └── filtro-tarifa.dto.ts
    ├── exceptions/
    │   └── tarifa-no-vigente.exception.ts
    └── tarifa.service.spec.ts
```

### Modificar columnas existentes (sin eliminarlas)

- `niveles_precio_corte.precio_por_minuto` — **conservar** para display rápido en UI, pero documentar en código y en el campo que ya no es la fuente de verdad para cálculos.
- `mano_de_obra.valor_hora` — ídem.
- `materiales.valor_plancha` — ídem (si PO confirma pregunta 1).

> **Por qué no eliminar las columnas actuales:** las eliminaciones son disruptivas y rompen cualquier código existente que ya use esos campos. En el MVP coexisten; en una fase posterior se puede hacer el cleanup si se justifica.

---

## Criterios de aceptación

### 1. Tabla `tarifas` y constraints

- [ ] Tabla `tenant_erp.tarifas` existe con todas las columnas.
- [ ] `UNIQUE INDEX` de tarifa vigente activo — intentar insertar segunda tarifa vigente para misma entidad falla.
- [ ] Trigger de inmutabilidad activo — intentar `UPDATE` una tarifa con `valid_to NOT NULL` lanza excepción de BD.
- [ ] Función `obtener_tarifa_vigente` existe y retorna el valor correcto para una fecha dada.
- [ ] Función lanza excepción cuando no hay tarifa para esa fecha.

### 2. Backfill

- [ ] Todos los registros de `niveles_precio_corte` tienen una tarifa vigente correspondiente en `tarifas`.
- [ ] Todos los registros de `mano_de_obra` tienen una tarifa vigente (según respuesta PO).
- [ ] El backfill es idempotente (`ON CONFLICT DO NOTHING`).
- [ ] Los valores backfilleados coinciden exactamente con los valores actuales en las tablas origen.

### 3. `TarifaService`

```typescript
// Cambia una tarifa: cierra la actual y abre la nueva en transacción
async cambiar(dto: CambiarTarifaDto, idUsuario: number): Promise<Tarifa>

// Resuelve tarifa vigente en una fecha (default: now())
async obtenerVigente(tipo: TipoEntidadTarifa, idEntidad: number, fecha?: Date): Promise<Decimal>

// Historial de tarifas de una entidad
async historial(tipo: TipoEntidadTarifa, idEntidad: number): Promise<Tarifa[]>
```

- [ ] `cambiar()` usa `$transaction` con `UPDATE valid_to` + `INSERT` nueva fila — nunca dos operaciones separadas.
- [ ] `cambiar()` valida que `motivo` tenga mínimo 10 caracteres.
- [ ] `cambiar()` valida que `valid_from` de la nueva tarifa sea ≥ `now()` — no se puede crear tarifas retroactivas.
- [ ] `obtenerVigente()` llama a la función PostgreSQL `obtener_tarifa_vigente` con `$queryRaw`.
- [ ] Si no hay tarifa vigente: lanza `TarifaNoVigenteException` con mensaje claro.
- [ ] Después de `cambiar()` exitoso: emite evento `produccion.tarifa.cambiada.v1` con payload `{ tipo, idEntidad, valorAnterior, valorNuevo, motivo, idUsuario, timestamp }`.

### 4. Endpoints REST

- [ ] `GET /api/v1/tarifas?tipo=NIVEL_CORTE&id_entidad=1` — retorna historial de tarifas. Requiere rol `jefe-produccion` o `admin-sistema`.
- [ ] `POST /api/v1/tarifas/cambiar` — crea nueva tarifa y cierra la anterior. Requiere `produccion:tarifa:cambiar`.
- [ ] Los endpoints existentes de `GET /api/v1/produccion/ordenes/:id` que calculan costos deben usar `TarifaService.obtenerVigente()` con la fecha de cierre de la O/P, no los valores directo de `niveles_precio_corte` ni `mano_de_obra`.

### 5. Tests

- [ ] `cambiar()` con tarifa previa vigente: cierra la anterior (`valid_to` seteado), crea la nueva, emite evento.
- [ ] `cambiar()` sin tarifa previa vigente: crea la primera, emite evento.
- [ ] `cambiar()` con motivo de 9 caracteres: falla antes de tocar BD.
- [ ] `cambiar()` con `valid_from` en el pasado: falla con mensaje claro.
- [ ] `obtenerVigente()` en fecha donde hay tarifa: retorna el valor correcto.
- [ ] `obtenerVigente()` en fecha donde no hay tarifa: lanza `TarifaNoVigenteException`.
- [ ] Trigger inmutabilidad: intento de `UPDATE` sobre tarifa cerrada desde `$executeRaw` → error de BD capturado.
- [ ] Unique index: intento de insertar segunda tarifa vigente para mismo tipo+entidad → error de BD capturado.
- [ ] **Cobertura ≥ 90%** en `tarifa.service.ts`.

---

## Invariantes que el agente DEBE respetar

Tomadas directamente de ADR-007:

1. **NUNCA `UPDATE tarifas SET valor = ?`** sobre una tarifa existente (ni siquiera la vigente). Solo `cambiar()` que cierra + crea.
2. **NUNCA `DELETE FROM tarifas`**. Las tarifas son eternas.
3. **`cambiar()` es el único punto de entrada** para modificar tarifas. No hay `updateTarifa()`, ni `patchTarifa()`, ni ningún endpoint PATCH.
4. **La fecha de referencia para cálculos de costo es el cierre de la O/P**, nunca `now()`.
5. **`motivo` obligatorio** con mínimo 10 caracteres en DTO y en la tabla (CHECK de BD).
6. **Solo rol `jefe-produccion` o superior** puede cambiar tarifas. El guard debe verificar explícitamente.
7. **Si no existe tarifa vigente para la fecha de cierre de una O/P**: la O/P no puede cerrarse. Lanzar `TarifaNoVigenteException` y notificar al supervisor.

---

## Casos de prueba obligatorios

- **Caso 1 — Recalcular O/P histórica:**
  - Setup: tarifa A vigente desde 2025-01-01 ($780/min), tarifa B vigente desde 2026-01-01 ($850/min). O/P cerrada el 2025-06-15.
  - Input: `TarifaService.obtenerVigente('NIVEL_CORTE', 1, new Date('2025-06-15'))`.
  - Esperado: $780 (tarifa A), no $850 (tarifa B).

- **Caso 2 — Cambio de tarifa:**
  - Setup: tarifa vigente $780/min.
  - Input: `cambiar({ tipo: 'NIVEL_CORTE', idEntidad: 1, valor: 850, validFrom: '2026-06-01', motivo: 'Ajuste anual IPC 2026' })`.
  - Esperado: tarifa anterior tiene `valid_to = '2026-06-01'`, tarifa nueva tiene `valid_from = '2026-06-01'`, `valid_to = NULL`.

- **Caso 3 — Tarifa retroactiva rechazada:**
  - Input: `cambiar({ ..., validFrom: '2025-01-01' })` (fecha en el pasado).
  - Esperado: error de validación, ninguna tarifa modificada.

- **Caso 4 — Unique index:**
  - Setup: ya existe tarifa vigente para NIVEL_CORTE id=1.
  - Input: intentar insertar directamente otra tarifa vigente para NIVEL_CORTE id=1.
  - Esperado: error de violación de unique index.

---

## Lo que NO se debe hacer en esta tarea

- ❌ No eliminar `precio_por_minuto` de `niveles_precio_corte` ni `valor_hora` de `mano_de_obra`. Coexisten en el MVP.
- ❌ No crear endpoint `PATCH /tarifas/:id`. Las tarifas no se editan, se cambian.
- ❌ No usar `now()` como fecha de referencia en cálculos de costo de O/Ps históricas.
- ❌ No ejecutar el backfill sin confirmación de PO sobre las tres preguntas abiertas.
- ❌ No iniciar este ticket antes de que T-008 esté completo (necesita `id_usuario` autenticado en todas las operaciones).

---

## Entregables

- [ ] Tabla `tarifas` con constraints, trigger y función PostgreSQL.
- [ ] Backfill de datos existentes.
- [ ] `TarifaService` con `cambiar()`, `obtenerVigente()`, `historial()`.
- [ ] Endpoints `GET /tarifas` y `POST /tarifas/cambiar` con RBAC.
- [ ] Tests con cobertura ≥ 90%.
- [ ] Evento `produccion.tarifa.cambiada.v1` emitido y documentado en `docs/events.md`.
- [ ] Commit: `feat(produccion): add tarifas temporales con vigencia [A1]`.
- [ ] PR con labels `agent:A1`, `supervisor:S1`, `sprint:2`, `priority:critical`.

---

## Cómo invocar al agente

```bash
git checkout -b feat/T-MVP-002-tarifas-temporales
claude
```

Prompt:

```
Ejecuta T-MVP-002 (tarifas con vigencia temporal).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-MVP-002-tarifas-temporales.md
4. @docs/adrs/ADR-007-tarifas-temporales.md
5. @docs/rbac-matrix.md (sección produccion:tarifa)
6. @services/erp-api/prisma/schema.prisma

STOP: antes de escribir una sola línea de código, muéstrame
las respuestas de PO a las tres preguntas de negocio del ticket.
Si no tienes esas respuestas, detenerse y pedirlas a S1.
```

---

## Validación post-ejecución (lo llena S1)

```bash
# 1. Verificar trigger de inmutabilidad
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  UPDATE tenant_erp.tarifas SET valor = 999 WHERE valid_to IS NOT NULL LIMIT 1;"
# Esperado: ERROR: Las tarifas cerradas son inmutables

# 2. Verificar función de resolución
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT tenant_erp.obtener_tarifa_vigente('NIVEL_CORTE', 1, now());"

# 3. Verificar backfill
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT COUNT(*) FROM tenant_erp.tarifas;"
# Esperado: mismo count que niveles_precio_corte + mano_de_obra (+ materiales si aplica)

# 4. Tests
cd services/erp-api && npm test -- --testPathPattern=tarifa
```

- **Fecha:** _pendiente_
- **Preguntas PO respondidas:** _pendiente_
- **Trigger inmutabilidad:** _pendiente_
- **Backfill completo:** _pendiente_
- **Tests:** _pendiente_
- **Resultado:** _pendiente_

---

**Creado:** 2026-05-13 por TL + S1
**Prerrequisitos:** T-MVP-001, T-008 completados + respuestas PO
**ADR de referencia:** ADR-007
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
