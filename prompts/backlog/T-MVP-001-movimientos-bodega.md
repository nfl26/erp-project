# T-MVP-001 · Bodega: tabla `movimientos_bodega` + stock derivado + umbrales en `materiales`

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-MVP-001
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1 (con revisión obligatoria de PO antes de mergear)
**Sprint:** Sprint 1
**Estimación:** 8 puntos
**Prioridad:** crítica
**Rama:** `feat/T-MVP-001-movimientos-bodega`

---

## Contexto de negocio

El módulo de bodega del ERP necesita responder tres preguntas que hoy son imposibles de contestar con el schema actual:

1. **¿Cuánto stock hay de un material ahora mismo?** — `materiales` no tiene columna de stock; no hay fuente de verdad.
2. **¿Quién movió qué, cuándo y por qué?** — No existe historial de movimientos.
3. **¿Qué materiales están en nivel crítico de reposición?** — No hay umbral definido por material.

Sin resolver esto, T-009 (módulo bodega CRUD) no puede implementar la invariante más importante del sistema: **"stock nunca negativo"** declarada en `CLAUDE.md`.

Este ticket crea la infraestructura de base de datos que sustenta toda la lógica de bodega del MVP. Implementa la decisión de [ADR-005](../../docs/adrs/ADR-005-stock-calculado-desde-movimientos.md): el stock es siempre un valor **derivado e inmutable**, calculado desde una tabla de movimientos append-only. Nunca hay una columna `stock_actual` editable.

---

## Prerrequisitos

- [ ] **T-FIX-001 completado** — schema renombrado a `tenant_erp`.
- [ ] **T-007 completado** — `PrismaService` aplica `SET search_path` a `tenant_erp` por request.
- [ ] Verificar estado del schema:
  ```bash
  docker compose exec postgres psql -U erp_admin -d erp_db \
    -c "\dt tenant_erp.*" | grep materiales
  # Debe existir la tabla tenant_erp.materiales
  ```

---

## Alcance técnico

### Modificar en `schema.prisma`

```prisma
// Agregar campos a modelo Material existente
model Material {
  // ... campos existentes sin tocar ...
  stock_minimo   Decimal? @db.Decimal(12, 4)  // umbral de alerta roja
  stock_optimo   Decimal? @db.Decimal(12, 4)  // umbral de alerta amarilla
  unidad         String   @default("plancha") @db.VarChar(50) // unidad de medida de stock

  // nueva relación
  movimientos MovimientoBodega[]
}

// Nuevo enum
enum TipoMovimiento {
  ENTRADA
  SALIDA
  AJUSTE_POSITIVO
  AJUSTE_NEGATIVO

  @@schema("tenant_erp")
  @@map("tipo_movimiento")
}

// Nueva tabla — append-only
model MovimientoBodega {
  id_movimiento    Int            @id @default(autoincrement())
  id_material      Int
  tipo             TipoMovimiento
  cantidad         Decimal        @db.Decimal(12, 4)  // siempre positivo
  precio_unitario  Decimal?       @db.Decimal(10, 2)  // solo en ENTRADA (costo unitario de compra)
  motivo           String         @db.VarChar(500)    // obligatorio, sin "actualización"
  referencia_ext   String?        @db.VarChar(200)    // nro de compra, acta, OP, etc.
  id_usuario       Int
  created_at       DateTime       @default(now()) @db.Timestamptz(6)

  material Material @relation(fields: [id_material], references: [id_material])
  usuario  Usuario  @relation(fields: [id_usuario], references: [id_usuario])

  @@map("movimientos_bodega")
  @@schema("tenant_erp")
}
```

> **Nota:** la relación inversa `movimientos MovimientoBodega[]` se agrega al modelo `Material` existente y la relación `movimientos ManoDeObra[]` se agrega al modelo `Usuario`. Verificar que no haya conflicto de nombres con relaciones existentes antes de aplicar.

### Migración SQL adicional (raw, no generada por Prisma)

Además de la migración Prisma, el agente debe agregar en el mismo archivo de migración o en uno consecutivo:

```sql
-- 1. Restricción: cantidad siempre positiva
ALTER TABLE tenant_erp.movimientos_bodega
  ADD CONSTRAINT movimientos_cantidad_positiva CHECK (cantidad > 0);

-- 2. Tabla inmutable: revocar UPDATE y DELETE
REVOKE UPDATE, DELETE ON tenant_erp.movimientos_bodega FROM PUBLIC;
REVOKE UPDATE, DELETE ON tenant_erp.movimientos_bodega FROM erp_admin;
-- Nota: erp_admin necesita INSERT para que Prisma funcione, solo se revocan UPDATE/DELETE

-- 3. Vista para stock actual por material
CREATE OR REPLACE VIEW tenant_erp.v_stock_actual AS
SELECT
  m.id_material,
  m.cod_interno,
  m.tipo         AS tipo_material,
  m.descripcion,
  m.unidad,
  m.stock_minimo,
  m.stock_optimo,
  COALESCE(
    SUM(
      CASE
        WHEN mv.tipo IN ('ENTRADA', 'AJUSTE_POSITIVO') THEN mv.cantidad
        WHEN mv.tipo IN ('SALIDA',  'AJUSTE_NEGATIVO') THEN -mv.cantidad
      END
    ), 0
  ) AS stock_actual,
  CASE
    WHEN m.stock_minimo IS NULL THEN 'sin_umbral'
    WHEN COALESCE(SUM(...), 0) <= m.stock_minimo  THEN 'critico'
    WHEN COALESCE(SUM(...), 0) <= m.stock_optimo  THEN 'bajo'
    ELSE 'ok'
  END AS estado_stock
FROM tenant_erp.materiales m
LEFT JOIN tenant_erp.movimientos_bodega mv ON mv.id_material = m.id_material
WHERE m.activo = true
  AND m.deleted_at IS NULL
GROUP BY
  m.id_material, m.cod_interno, m.tipo,
  m.descripcion, m.unidad, m.stock_minimo, m.stock_optimo;

-- Índice para hacer la vista eficiente
CREATE INDEX IF NOT EXISTS idx_movimientos_material
  ON tenant_erp.movimientos_bodega (id_material, tipo, created_at);

-- 4. Función helper para consulta de stock con lock pesimista (usada por NestJS)
CREATE OR REPLACE FUNCTION tenant_erp.obtener_stock_para_salida(
  p_id_material INT
) RETURNS DECIMAL AS $$
DECLARE
  v_stock DECIMAL;
BEGIN
  -- Lock pesimista sobre el material para serializar escrituras concurrentes
  PERFORM id_material FROM tenant_erp.materiales
    WHERE id_material = p_id_material FOR UPDATE;

  SELECT COALESCE(
    SUM(CASE
      WHEN tipo IN ('ENTRADA', 'AJUSTE_POSITIVO') THEN cantidad
      WHEN tipo IN ('SALIDA',  'AJUSTE_NEGATIVO') THEN -cantidad
    END), 0
  ) INTO v_stock
  FROM tenant_erp.movimientos_bodega
  WHERE id_material = p_id_material;

  RETURN v_stock;
END;
$$ LANGUAGE plpgsql;
```

> **Por qué VIEW y no MATERIALIZED VIEW en el MVP:** la vista materializada requiere REFRESH manual o trigger. Para el volumen del MVP (< 100k movimientos), una vista regular con índice es suficiente. El ADR-005 describe el upgrade a materializada cuando el volumen lo justifique.

### Crear en `services/erp-api/src/`

```
src/shared/bodega/
├── stock.service.ts          ← calcular stock, consultar v_stock_actual, lock pesimista
├── stock.service.spec.ts
└── types/
    └── stock.types.ts        ← StockActual, EstadoStock, TipoMovimiento enum TS
```

> Este `StockService` es un **servicio compartido** (en `shared/`), no en `modules/bodega/`. Lo usan tanto el módulo bodega (T-009) como producción (cuando consume materiales en una O/P). Exportado desde un `BodegaSharedModule`.

### No tocar

- Campos existentes en `materiales` (no renombrar, no eliminar).
- Relaciones existentes en `Material` (`detalle_compras`, `recetas`).
- Cualquier tabla fuera del módulo bodega.
- `schema.prisma` de modelos que no son `Material` ni los nuevos.

---

## Criterios de aceptación

### 1. Migración Prisma limpia

- [ ] `npx prisma migrate dev --name add_movimientos_bodega` corre sin errores.
- [ ] `npx prisma generate` genera el cliente sin errores.
- [ ] `npx prisma validate` pasa.
- [ ] La migración incluye el SQL adicional (constraints, REVOKE, vista, función, índice).
- [ ] `npx prisma migrate status` muestra "All migrations applied".

### 2. Tabla `movimientos_bodega`

- [ ] Existe en `tenant_erp` con las columnas del schema.
- [ ] `CHECK (cantidad > 0)` activo — intentar insertar cantidad ≤ 0 falla con error de BD.
- [ ] `UPDATE` y `DELETE` revocados — intentar modificar o borrar un movimiento desde psql falla con error de permisos.
- [ ] `motivo` tiene constraint `CHECK (length(trim(motivo)) >= 10)` — motivos vacíos o de una palabra fallan.
- [ ] Índice `idx_movimientos_material` existe.

### 3. Campos nuevos en `materiales`

- [ ] `stock_minimo DECIMAL(12,4) NULL` existe en la tabla.
- [ ] `stock_optimo DECIMAL(12,4) NULL` existe en la tabla.
- [ ] `unidad VARCHAR(50) DEFAULT 'plancha'` existe en la tabla.
- [ ] Las filas existentes no se alteraron (solo se agregaron columnas nullable).
- [ ] `stock_optimo >= stock_minimo` cuando ambos tienen valor — constraint `CHECK` en la tabla.

### 4. Vista `v_stock_actual`

- [ ] La vista existe en `tenant_erp`.
- [ ] `SELECT * FROM tenant_erp.v_stock_actual` retorna una fila por material activo.
- [ ] Con 0 movimientos: `stock_actual = 0`, `estado_stock = 'sin_umbral'` (si no hay umbral) o `'critico'` (si hay umbral).
- [ ] Con movimientos de entrada y salida: el saldo es correcto.
- [ ] `estado_stock` es `'critico'` cuando `stock_actual <= stock_minimo`.
- [ ] `estado_stock` es `'bajo'` cuando `stock_minimo < stock_actual <= stock_optimo`.
- [ ] `estado_stock` es `'ok'` cuando `stock_actual > stock_optimo`.
- [ ] `estado_stock` es `'sin_umbral'` cuando `stock_minimo IS NULL`.

### 5. `StockService` en NestJS

`stock.service.ts` implementa:

```typescript
// Obtiene stock actual desde la vista (lectura rápida)
async obtenerStock(idMaterial: number): Promise<StockActual>

// Registra un movimiento con validación previa de stock para SALIDAs
// Usa transacción + lock pesimista para SALIDA y AJUSTE_NEGATIVO
async registrarMovimiento(dto: RegistrarMovimientoDto, idUsuario: number): Promise<MovimientoBodega>

// Lista histórico de movimientos de un material con paginación
async historialMovimientos(idMaterial: number, opts: PaginacionOpts): Promise<Paginated<MovimientoBodega>>

// Lista materiales en estado crítico o bajo (para reporte de reposición)
async materialesCriticos(opts?: FiltroStockOpts): Promise<StockActual[]>
```

- [ ] `registrarMovimiento` para SALIDA/AJUSTE_NEGATIVO usa `$transaction` con `$executeRaw` para el lock pesimista vía la función `obtener_stock_para_salida`.
- [ ] Si stock resultante < 0: lanza `StockInsuficienteException` (extiende `BadRequestException`) con mensaje `"Stock insuficiente: disponible ${actual}, solicitado ${cantidad}"`.
- [ ] Para ENTRADA/AJUSTE_POSITIVO: inserta directamente sin lock (no pueden dejar stock negativo).
- [ ] `motivo` se valida en el DTO: mínimo 10 caracteres, requerido.
- [ ] `precio_unitario` es requerido solo para tipo `ENTRADA`.
- [ ] `referencia_ext` es opcional en todos los tipos.
- [ ] Después de cada movimiento exitoso: emite evento `bodega.movimiento.registrado.v1` via `EventEmitter2`.

### 6. Evento `bodega.movimiento.registrado.v1`

Formato del payload (mismo que se usaría con RabbitMQ cuando se extraiga el módulo):

```typescript
interface MovimientoRegistradoEvent {
  eventType: 'bodega.movimiento.registrado.v1';
  idMovimiento: number;
  idMaterial: number;
  tipo: TipoMovimiento;
  cantidad: number;           // Decimal serializado como string para evitar pérdida de precisión
  stockResultante: number;    // Decimal serializado como string
  idUsuario: number;
  timestamp: string;          // ISO 8601
  tenantSlug: string;
}
```

- [ ] Evento emitido después de cada `registrarMovimiento` exitoso.
- [ ] El payload incluye `stockResultante` calculado post-inserción.
- [ ] El evento no se emite si la transacción falla (EventEmitter2 lo garantiza si se emite dentro de la transacción).

### 7. Tests

**Unitarios (`stock.service.spec.ts`):**
- [ ] `registrarMovimiento ENTRADA`: inserta correctamente, emite evento.
- [ ] `registrarMovimiento SALIDA con stock suficiente`: inserta, decrementa, emite evento.
- [ ] `registrarMovimiento SALIDA con stock insuficiente`: lanza `StockInsuficienteException`, no inserta, no emite evento.
- [ ] `registrarMovimiento AJUSTE_NEGATIVO que deja stock en 0`: permitido (stock = 0 no es negativo).
- [ ] `registrarMovimiento AJUSTE_NEGATIVO que deja stock < 0`: lanza excepción.
- [ ] `motivo menor a 10 caracteres`: falla validación DTO antes de llegar al servicio.
- [ ] `materialesCriticos`: retorna solo materiales en estado 'critico' o 'bajo'.

**Integración (requiere BD real con Testcontainers):**
- [ ] Dos inserciones concurrentes de SALIDA sobre el mismo material no dejan stock negativo.
- [ ] REVOKE en BD: intentar `UPDATE movimientos_bodega SET cantidad = 999` desde Prisma lanza error de BD.

**Cobertura mínima:** 90% en `stock.service.ts`.

---

## Invariantes que el agente DEBE respetar

Tomadas directamente de ADR-005:

1. **NUNCA generar un endpoint ni método que haga `UPDATE materiales SET stock_actual = ?`**. El campo no existe y no debe existir.
2. **NUNCA generar un endpoint ni método que haga `DELETE FROM movimientos_bodega`**. Los movimientos son inmutables por diseño y por REVOKE en BD.
3. **Las salidas y ajustes negativos usan lock pesimista** dentro de una transacción Prisma para evitar race conditions.
4. **El campo `motivo` es obligatorio con contenido real**. Validar con `MinLength(10)` en DTO y con `CHECK` en BD. No son equivalentes — ambos son necesarios.
5. **`precio_unitario` solo en movimientos de tipo ENTRADA**. Las salidas no tienen costo asociado directamente (el costo histórico se recupera por fecha desde los movimientos de entrada anteriores).
6. **El stock puede llegar a 0 pero nunca a negativo.**
7. **Toda inserción exitosa emite `bodega.movimiento.registrado.v1`** antes de retornar al caller.

---

## Casos de prueba obligatorios

- **Caso 1 — Race condition:**
  - Setup: material con stock = 5, dos requests simultáneos de SALIDA por cantidad 5.
  - Esperado: uno aprueba (stock → 0), el otro lanza `StockInsuficienteException`. Stock final = 0, no -5.

- **Caso 2 — Ajuste negativo que lleva stock a exactamente 0:**
  - Setup: material con stock = 3.
  - Input: `AJUSTE_NEGATIVO` cantidad = 3, motivo = "Inventario físico coincide con 0 unidades".
  - Esperado: movimiento insertado, stock = 0, evento emitido.

- **Caso 3 — Entrada con precio unitario nulo:**
  - Input: `ENTRADA` sin `precio_unitario`.
  - Esperado: validación falla con mensaje claro indicando que `precio_unitario` es requerido en ENTRADAs.

- **Caso 4 — Cálculo de estado_stock:**
  - Setup: material con `stock_minimo = 10`, `stock_optimo = 50`, stock actual = 8.
  - Query: `SELECT estado_stock FROM v_stock_actual WHERE id_material = ?`.
  - Esperado: `'critico'`.

- **Caso 5 — Historial con varios tipos:**
  - Setup: 2 ENTRADAs (100 + 50), 1 SALIDA (30), 1 AJUSTE_POSITIVO (5).
  - Query: `StockService.obtenerStock(id)`.
  - Esperado: `stock_actual = 125` (100 + 50 - 30 + 5).

- **Caso 6 — Inmutabilidad desde NestJS:**
  - Input: intentar `prisma.movimientoBodega.update(...)` desde cualquier service.
  - Esperado: error de BD (permisos revocados). Si el agente tiene algún método `update` en el service, el test falla porque ese método no debería existir.

---

## Lo que NO se debe hacer en esta tarea

- ❌ No crear endpoints HTTP REST en este ticket. Solo la infraestructura de BD + el `StockService`. Los endpoints vienen en T-009.
- ❌ No agregar columna `stock_actual` en `materiales`. El stock es siempre derivado.
- ❌ No usar `MATERIALIZED VIEW` todavía. Vista regular es suficiente para el MVP. Cuando el volumen lo justifique, hay un camino claro en ADR-005.
- ❌ No modificar tablas fuera del dominio bodega (`recetas`, `pedidos`, `ventas`, etc.).
- ❌ No instalar nuevas dependencias. Todo lo necesario ya está en el stack.
- ❌ No agregar cache Redis todavía. Eso va en un ticket posterior de optimización.

---

## Entregables

- [ ] Migración Prisma generada, aplicada y commiteada.
- [ ] SQL adicional (constraints, REVOKE, vista, función, índice) en la misma migración.
- [ ] `schema.prisma` actualizado con `MovimientoBodega` y campos nuevos en `Material`.
- [ ] `StockService` implementado con tests.
- [ ] Cobertura ≥ 90% en `stock.service.ts`.
- [ ] Test de integración de race condition pasando.
- [ ] Commit: `feat(bodega): add movimientos_bodega table + stock view + StockService [A1]`.
- [ ] PR con labels `agent:A1`, `supervisor:S1`, `sprint:1`, `priority:critical`.

---

## Cómo invocar al agente

```bash
git checkout -b feat/T-MVP-001-movimientos-bodega
claude
```

Prompt:

```
Ejecuta T-MVP-001 (tabla movimientos_bodega + stock derivado).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-MVP-001-movimientos-bodega.md
4. @docs/adrs/ADR-005-stock-calculado-desde-movimientos.md
5. @docs/prisma-workflow.md
6. @services/erp-api/prisma/schema.prisma

Antes de empezar, verifica:
1. T-FIX-001 está mergeado (schema se llama tenant_erp).
2. T-007 está mergeado (PrismaService aplica search_path).
3. docker compose está corriendo y la BD es accesible.

Reglas críticas:
- La tabla movimientos_bodega es append-only (REVOKE UPDATE, DELETE).
- El stock NUNCA se almacena: es siempre SUM de movimientos.
- Las salidas requieren lock pesimista dentro de $transaction.
- motivo es obligatorio, mínimo 10 caracteres, en DTO Y en BD.
- No crear endpoints REST en este ticket, solo StockService + migración.
```

---

## Notas para S1 y PO

**S1 revisa:** la migración SQL (especialmente el REVOKE y el CHECK de motivo), el lock pesimista en el service, los tests de race condition, y que no exista ningún método `update` ni `delete` en `StockService`.

**PO revisa:** los campos `unidad`, `stock_minimo` y `stock_optimo` en materiales. ¿El equipo de Arteo usa "plancha" como unidad por default? ¿Qué unidades alternativas existen (m², cm², kg, unidad)? Si hay un listado definido, agregar un enum o tabla de unidades. Si no, el campo libre `VarChar(50)` es suficiente para el MVP.

---

## Validación post-ejecución (lo llena S1)

```bash
# 1. Verificar tabla y restricciones
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'tenant_erp'
    AND table_name = 'movimientos_bodega'
  ORDER BY ordinal_position;"

# 2. Verificar inmutabilidad
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  UPDATE tenant_erp.movimientos_bodega SET cantidad = 999 WHERE id_movimiento = 1;"
# Esperado: ERROR: permission denied

# 3. Verificar vista
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT * FROM tenant_erp.v_stock_actual LIMIT 5;"

# 4. Tests
cd services/erp-api && npm test -- --testPathPattern=stock
```

- **Fecha:** _pendiente_
- **Migración aplicada:** _pendiente_
- **REVOKE verificado:** _pendiente_
- **Vista funcional:** _pendiente_
- **Tests:** _pendiente_
- **PO aprobó campos materiales:** _pendiente_
- **Resultado:** _pendiente_

---

**Creado:** 2026-05-13 por TL + S1
**Prerrequisitos:** T-FIX-001, T-007 completados
**Bloquea:** T-009 (módulo bodega CRUD)
**ADR de referencia:** ADR-005
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
