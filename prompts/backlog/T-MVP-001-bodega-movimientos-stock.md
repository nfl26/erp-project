# T-MVP-001 · Bodega: movimientos, stock derivado y umbrales

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-MVP-001
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1 (con revisión obligatoria de PO antes de mergear)
**Sprint:** Sprint 1
**Estimación:** 8 puntos
**Prioridad:** crítica
**Rama:** `feat/T-MVP-001-bodega-movimientos-stock`

---

## Contexto de negocio

El `schema.prisma` actual de Arteo refleja la BD existente, pero **no incluye** los conceptos centrales de gestión de bodega que el ERP necesita para cumplir sus invariantes:

1. **No existe historial de movimientos.** Los `materiales` se compran vía `compras` + `detalle_compra`, pero no hay registro de **salidas** (consumo en O/P, ventas internas, ajustes por inventario físico, mermas).
2. **No existe stock calculado.** La tabla `materiales` solo guarda `valor_plancha` (precio), no `stock_actual`. Hoy nadie sabe — desde la BD — cuántas planchas de acero hay disponibles.
3. **No existen umbrales de reposición.** El rol `encargado-compras` debería "ver stock crítico y generar órdenes de compra a proveedores" (`rbac-matrix.md`), pero el material no tiene umbrales.

Sin estas piezas, dos invariantes declaradas en `CLAUDE.md` son aspiracionales y no implementables:

- *"Stock nunca negativo. Antes de registrar salida, validar stock disponible."*
- *"Toda mutación de bodega genera un evento `bodega.movimiento.registrado`."*

Este ticket cierra ese gap. **No implementa el CRUD ni los endpoints HTTP** — esos vienen en T-009. Aquí solo se construyen las piezas de schema, las constraints de integridad, y la vista derivada que T-009 va a consumir.

> **Decisión clave (ADR-005, vigente):** el `stock_actual` **no se almacena como columna**. Se deriva de la suma de movimientos. Esto evita el clásico bug de "stock denormalizado se desincroniza del historial" y hace que el historial sea la única fuente de verdad. La vista materializada hace que el cálculo sea barato en lectura.

---

## Prerrequisitos

- [ ] **T-004 completado** — `schema.prisma` generado, migración `0_init` aplicada.
- [ ] **T-FIX-001 completado** — el schema activo se llama `tenant_erp`, no `tenant_demo`.
- [ ] **PO disponible para revisar** — los umbrales `stock_minimo` y `stock_optimo` por material requieren datos reales del cliente, o al menos validación de los seeds.
- [ ] **Lectura previa obligatoria por el agente:**
  - `docs/adrs/ADR-005-stock-calculado-desde-movimientos.md` (decisión sobre stock derivado).
  - Sección "bodega" de `docs/rbac-matrix.md` (permisos de movimientos).
  - `docs/events.md` si existe y define el formato `bodega.movimiento.registrado`.

---

## Alcance técnico

### Crear

```
services/erp-api/prisma/
├── schema.prisma                                       ← agregar 1 enum + 1 modelo + 1 view + 2 campos
└── migrations/
    └── <timestamp>_add_bodega_movimientos_stock/
        └── migration.sql                               ← migración generada por prisma migrate dev

infra/local/postgres/init/
└── 04-bodega-functions.sql                            ← función + trigger de validación de stock
```

### Modificar

```
services/erp-api/prisma/schema.prisma
  ← agregar campos stock_minimo y stock_optimo al modelo Material
```

### No crear todavía (eso es T-009)

- Controladores HTTP (`MovimientosController`, etc.).
- Services NestJS de bodega.
- DTOs, guards, decoradores de eventos.
- README del módulo de bodega.
- Tests E2E de endpoints.

> **Regla del ticket:** este ticket termina cuando la migración corre limpia, las constraints funcionan, y la vista retorna datos correctos en un test de integración Prisma. Sin endpoints HTTP.

---

## Criterios de aceptación

### 1. Enum `TipoMovimiento`

Agregar al `schema.prisma`, schema `tenant_erp`:

```prisma
enum TipoMovimiento {
  ENTRADA            // compra recibida, devolución de cliente, ingreso por inventario inicial
  SALIDA             // consumo en O/P, venta directa, devolución a proveedor
  AJUSTE_POSITIVO    // inventario físico mostró más unidades que la BD
  AJUSTE_NEGATIVO    // merma, robo, rotura, inventario físico mostró menos

  @@schema("tenant_erp")
  @@map("tipo_movimiento")
}
```

- [ ] Enum creado con los 4 valores exactos (mayúsculas, snake_case interno).
- [ ] `@@schema("tenant_erp")` y `@@map("tipo_movimiento")` presentes.

> **Por qué cuatro tipos y no dos:** separar ENTRADA/SALIDA de los ajustes es crítico para reportes. Una "salida" es operativa (consumo legítimo); un "ajuste negativo" es señal de problema (merma, robo, error de registro). Los reportes los agregan diferente.

### 2. Modelo `MovimientoBodega` (inmutable)

```prisma
model MovimientoBodega {
  id_movimiento     Int             @id @default(autoincrement())
  id_material       Int
  tipo              TipoMovimiento
  cantidad          Decimal         @db.Decimal(12, 4)
  unidad            String          @default("plancha") @db.VarChar(50)

  // Trazabilidad de origen — al menos UNO debe estar presente
  id_detalle_compra Int?            // si el movimiento nació de una compra
  id_orden          Int?            // si nació de una O/P (consumo)
  id_pedido         Int?            // si nació de una salida directa por pedido

  // Auditoría
  id_usuario        Int             // quién registró el movimiento (requerido)
  motivo            String?         @db.VarChar(300)    // obligatorio para AJUSTE_*, validado en service
  observaciones    String?
  fecha_movimiento  DateTime        @default(now()) @db.Timestamptz(6)
  created_at        DateTime        @default(now()) @db.Timestamptz(6)

  // Reversa: si este movimiento corrige a otro, apunta al original
  id_movimiento_reverso Int?
  movimiento_original   MovimientoBodega?  @relation("ReversaMovimiento", fields: [id_movimiento_reverso], references: [id_movimiento])
  reversas              MovimientoBodega[] @relation("ReversaMovimiento")

  material          Material        @relation(fields: [id_material], references: [id_material])
  detalle_compra    DetalleCompra?  @relation(fields: [id_detalle_compra], references: [id_detalle_compra])
  orden             OrdenProduccion? @relation(fields: [id_orden], references: [id_orden])
  pedido            Pedido?         @relation(fields: [id_pedido], references: [id_pedido])
  usuario           Usuario         @relation(fields: [id_usuario], references: [id_usuario])

  @@index([id_material, fecha_movimiento])
  @@index([tipo, fecha_movimiento])
  @@map("movimientos_bodega")
  @@schema("tenant_erp")
}
```

- [ ] Modelo creado con todos los campos arriba.
- [ ] **Sin campo `deleted_at`** — los movimientos son **inmutables**. Las correcciones se hacen creando un movimiento reversa que apunte al original vía `id_movimiento_reverso`. Esta es la diferencia entre tabla transaccional (inmutable) y tabla catálogo (admite soft delete).
- [ ] **Sin campo `updated_at`** — un movimiento no se edita. Si tiene un error, se crea un reversa.
- [ ] Las relaciones inversas se agregan a `Material`, `DetalleCompra`, `OrdenProduccion`, `Pedido` y `Usuario` (sin lo cual `prisma validate` falla).
- [ ] Los dos índices `[id_material, fecha_movimiento]` y `[tipo, fecha_movimiento]` se crean — son críticos para la vista de stock y para reportes.

### 3. Constraints CHECK en la migración SQL

La migración generada por `prisma migrate dev` debe **complementarse** con CHECKs que Prisma no expresa nativamente. El agente edita el `migration.sql` antes de aplicarlo:

```sql
-- Cantidad debe ser positiva siempre. Las SALIDAS y AJUSTE_NEGATIVO
-- restan stock, pero la cantidad almacenada es siempre positiva.
ALTER TABLE tenant_erp.movimientos_bodega
  ADD CONSTRAINT movimientos_bodega_cantidad_positiva
  CHECK (cantidad > 0);

-- AJUSTE_POSITIVO y AJUSTE_NEGATIVO requieren motivo no vacío.
ALTER TABLE tenant_erp.movimientos_bodega
  ADD CONSTRAINT movimientos_bodega_motivo_obligatorio_ajustes
  CHECK (
    (tipo NOT IN ('AJUSTE_POSITIVO', 'AJUSTE_NEGATIVO'))
    OR (motivo IS NOT NULL AND length(trim(motivo)) >= 10)
  );

-- Al menos UNO de los identificadores de origen debe estar presente
-- EXCEPTO para ajustes (que pueden no tener origen transaccional).
ALTER TABLE tenant_erp.movimientos_bodega
  ADD CONSTRAINT movimientos_bodega_origen_trazable
  CHECK (
    (tipo IN ('AJUSTE_POSITIVO', 'AJUSTE_NEGATIVO'))
    OR (id_detalle_compra IS NOT NULL OR id_orden IS NOT NULL OR id_pedido IS NOT NULL)
  );

-- Un movimiento reversa apunta a otro del mismo material y tipo opuesto.
-- Esto se valida en aplicación, no en BD (sería un trigger complejo).
```

- [ ] Las tres constraints `CHECK` están en la migración SQL.
- [ ] La constraint `motivo_obligatorio_ajustes` exige **≥10 caracteres**, consistente con la regla de cambio de tarifa (`rbac-matrix.md` Regla 8).
- [ ] El comentario inline en el SQL explica por qué cada constraint existe (el agente A1 vendrá a leer esto en seis meses).

### 4. Función `validar_stock_no_negativo` + trigger

La invariante **"stock nunca negativo"** se enforza en BD, no solo en aplicación. Razón: si dos requests concurrentes intentan registrar salida del último material, el lock optimista de aplicación puede fallar. La BD es la única que garantiza atomicidad real.

`infra/local/postgres/init/04-bodega-functions.sql`:

```sql
-- Función: dado (id_material), retorna stock actual derivado de movimientos.
-- ENTRADA y AJUSTE_POSITIVO suman; SALIDA y AJUSTE_NEGATIVO restan.
CREATE OR REPLACE FUNCTION tenant_erp.calcular_stock_material(p_id_material INT)
RETURNS DECIMAL(14, 4)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_stock DECIMAL(14, 4);
BEGIN
  SELECT COALESCE(SUM(
    CASE
      WHEN tipo IN ('ENTRADA', 'AJUSTE_POSITIVO') THEN cantidad
      WHEN tipo IN ('SALIDA', 'AJUSTE_NEGATIVO') THEN -cantidad
    END
  ), 0)
  INTO v_stock
  FROM tenant_erp.movimientos_bodega
  WHERE id_material = p_id_material;

  RETURN v_stock;
END;
$$;

-- Trigger BEFORE INSERT: si el movimiento es SALIDA o AJUSTE_NEGATIVO,
-- verifica que el stock resultante no quede negativo.
CREATE OR REPLACE FUNCTION tenant_erp.tg_validar_stock_no_negativo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_stock_actual DECIMAL(14, 4);
BEGIN
  -- Solo validar para movimientos que restan
  IF NEW.tipo IN ('SALIDA', 'AJUSTE_NEGATIVO') THEN
    v_stock_actual := tenant_erp.calcular_stock_material(NEW.id_material);

    IF (v_stock_actual - NEW.cantidad) < 0 THEN
      RAISE EXCEPTION 'Stock insuficiente para material %: disponible=%, solicitado=%',
        NEW.id_material, v_stock_actual, NEW.cantidad
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_stock_no_negativo
  BEFORE INSERT ON tenant_erp.movimientos_bodega
  FOR EACH ROW
  EXECUTE FUNCTION tenant_erp.tg_validar_stock_no_negativo();
```

- [ ] La función `calcular_stock_material` existe y retorna el stock derivado correctamente.
- [ ] El trigger `trg_validar_stock_no_negativo` existe y rechaza inserts que dejarían stock negativo.
- [ ] El archivo `04-bodega-functions.sql` está bajo `infra/local/postgres/init/` y se ejecuta automáticamente al levantar el contenedor.
- [ ] El error que lanza el trigger usa `ERRCODE = 'check_violation'` para que NestJS pueda mapearlo a un 409 Conflict semántico, no a un 500.

> **Nota sobre concurrencia:** este trigger evita stock negativo bajo concurrencia porque PostgreSQL serializa los INSERTs en la misma fila (lock implícito). T-009 después agregará un `SELECT ... FOR UPDATE` o lock explícito a nivel aplicación, pero la última línea de defensa es siempre el trigger.

### 5. Vista `v_stock_actual`

```prisma
view VStockActual {
  id_material      Int      @unique
  cod_interno      String?  @db.VarChar(20)
  tipo             String   @db.VarChar(100)
  descripcion      String?  @db.VarChar(200)
  stock_actual     Decimal  @db.Decimal(14, 4)
  stock_minimo     Decimal? @db.Decimal(14, 4)
  stock_optimo     Decimal? @db.Decimal(14, 4)
  estado_stock     String   @db.VarChar(20)  // 'critico' | 'bajo' | 'normal' | 'optimo'
  ultima_entrada   DateTime? @db.Timestamptz(6)
  ultima_salida    DateTime? @db.Timestamptz(6)
  activo           Boolean

  @@map("v_stock_actual")
  @@schema("tenant_erp")
}
```

El SQL de la vista (en la migración):

```sql
CREATE OR REPLACE VIEW tenant_erp.v_stock_actual AS
SELECT
  m.id_material,
  m.cod_interno,
  m.tipo,
  m.descripcion,
  COALESCE(tenant_erp.calcular_stock_material(m.id_material), 0) AS stock_actual,
  m.stock_minimo,
  m.stock_optimo,
  CASE
    WHEN m.stock_minimo IS NULL THEN 'normal'
    WHEN tenant_erp.calcular_stock_material(m.id_material) <= 0 THEN 'critico'
    WHEN tenant_erp.calcular_stock_material(m.id_material) < m.stock_minimo THEN 'bajo'
    WHEN m.stock_optimo IS NOT NULL
         AND tenant_erp.calcular_stock_material(m.id_material) >= m.stock_optimo THEN 'optimo'
    ELSE 'normal'
  END AS estado_stock,
  (SELECT MAX(fecha_movimiento) FROM tenant_erp.movimientos_bodega mb
   WHERE mb.id_material = m.id_material AND mb.tipo IN ('ENTRADA', 'AJUSTE_POSITIVO')) AS ultima_entrada,
  (SELECT MAX(fecha_movimiento) FROM tenant_erp.movimientos_bodega mb
   WHERE mb.id_material = m.id_material AND mb.tipo IN ('SALIDA', 'AJUSTE_NEGATIVO')) AS ultima_salida,
  m.activo
FROM tenant_erp.materiales m;
```

- [ ] La vista existe en PostgreSQL después de aplicar la migración.
- [ ] El modelo `VStockActual` está declarado en `schema.prisma` con `view` (no `model`) — Prisma soporta views con `previewFeatures = ["views"]` que ya está activado en el schema actual.
- [ ] El campo `estado_stock` retorna uno de cuatro valores: `'critico'`, `'bajo'`, `'normal'`, `'optimo'`.
- [ ] Las columnas `ultima_entrada` y `ultima_salida` se calculan con subqueries (es la solución más simple; si el rendimiento se degrada con +100K movimientos, se convierte en vista materializada con refresh programado, pero **eso no es parte de este ticket**).

> **¿Vista o vista materializada?** En este ticket, **vista normal**. Razón: la BD del MVP arrancará con pocos miles de movimientos. Una vista materializada agrega complejidad de refresh y staleness. Si la vista se vuelve lenta (>200ms para listar todos los materiales), se convierte en materializada en un ticket aparte con datos reales de carga. Decisión documentada acá para que no se "optimice prematuro".

### 6. Campos `stock_minimo` y `stock_optimo` en `Material`

Modificar el modelo `Material` en `schema.prisma`:

```prisma
model Material {
  // ... campos existentes
  stock_minimo     Decimal? @db.Decimal(14, 4)   // umbral bajo el cual se alerta
  stock_optimo     Decimal? @db.Decimal(14, 4)   // nivel objetivo de reposición
  // ... resto sin cambios

  movimientos      MovimientoBodega[]  // relación inversa nueva
}
```

- [ ] Ambos campos son `Decimal? @db.Decimal(14, 4)` — opcionales porque no todos los materiales tienen umbral definido todavía.
- [ ] El backfill **no setea valores**. Los materiales existentes quedan con `stock_minimo = NULL` y `stock_optimo = NULL`. Esos materiales aparecerán como `estado_stock = 'normal'` en la vista (regla CASE).
- [ ] Constraint en la migración: si `stock_optimo` está definido, debe ser **mayor o igual** a `stock_minimo` cuando ambos existen.

```sql
ALTER TABLE tenant_erp.materiales
  ADD CONSTRAINT materiales_stock_optimo_gte_minimo
  CHECK (
    stock_optimo IS NULL
    OR stock_minimo IS NULL
    OR stock_optimo >= stock_minimo
  );
```

### 7. Tests de integración (Prisma + Postgres real, sin NestJS)

Tests con Testcontainers o BD de test local. **Sin levantar el servidor NestJS** — este ticket es schema-only.

`services/erp-api/test/bodega/movimientos.integration.spec.ts`:

- [ ] **Test 1 — Movimiento ENTRADA suma al stock.**
  Setup: material con stock 0. Insertar ENTRADA de 10. Esperado: `v_stock_actual.stock_actual = 10`.

- [ ] **Test 2 — Movimiento SALIDA resta del stock.**
  Setup: ENTRADA de 10 previa. Insertar SALIDA de 3. Esperado: stock = 7.

- [ ] **Test 3 — SALIDA mayor al stock falla con check_violation.**
  Setup: stock = 5. Insertar SALIDA de 10. Esperado: error de Postgres con `code = '23514'` (check_violation), mensaje contiene "Stock insuficiente".

- [ ] **Test 4 — AJUSTE_NEGATIVO sin motivo falla.**
  Setup: stock = 100. Insertar AJUSTE_NEGATIVO de 5 con `motivo = null`. Esperado: violación de constraint `motivo_obligatorio_ajustes`.

- [ ] **Test 5 — AJUSTE_NEGATIVO con motivo "actualización" (9 chars) falla.**
  Esperado: violación de constraint (mínimo 10 chars).

- [ ] **Test 6 — Cantidad cero o negativa falla.**
  Esperado: violación de `cantidad_positiva`.

- [ ] **Test 7 — Estado de stock se calcula correctamente.**
  Setup: material con `stock_minimo=10`, `stock_optimo=50`, stock actual=5. Esperado: `estado_stock = 'bajo'`.
  Variantes para `'critico'` (stock=0), `'normal'` (stock=20), `'optimo'` (stock=60).

- [ ] **Test 8 — Movimiento sin trazabilidad falla (caso no-ajuste).**
  Setup: ENTRADA con `id_detalle_compra = null`, `id_orden = null`, `id_pedido = null`.
  Esperado: violación de `origen_trazable`.

- [ ] **Test 9 — Reversa apunta al movimiento original.**
  Setup: ENTRADA #1. Crear AJUSTE_NEGATIVO con `id_movimiento_reverso = #1`.
  Esperado: query a #1 puede listar sus reversas.

- [ ] **Test 10 — Stock derivado bajo concurrencia.**
  Setup: stock=1. Disparar dos transacciones simultáneas que intentan SALIDA de 1 cada una.
  Esperado: exactamente una succede, la otra falla con check_violation. **Bajo ningún caso queda stock = -1**.

- [ ] Cobertura: 100% de las constraints y triggers tocados (cada CHECK tiene al menos un test que lo dispara).

### 8. Documentación

- [ ] Crear archivo `services/erp-api/prisma/README.md` (o agregar sección si ya existe) explicando:
  - Por qué `MovimientoBodega` es inmutable.
  - Por qué `stock_actual` no es columna sino vista.
  - Cómo crear un movimiento reversa para corregir.
  - Que el trigger es la última línea de defensa, pero la aplicación debe validar primero (para devolver 409 Conflict y no esperar a que el trigger lance excepción).

---

## Invariantes que el agente DEBE respetar

1. **`MovimientoBodega` es append-only.** No tiene `updated_at`. No tiene `deleted_at`. Errores se corrigen con movimientos reversa, nunca con UPDATE o DELETE.
2. **`stock_actual` nunca se almacena.** Solo se deriva de la suma de movimientos. Si alguien propone agregar `Material.stock_actual` como columna, está violando ADR-005.
3. **El trigger es la última línea de defensa, no la única.** T-009 implementará validación en aplicación primero (devolver 409 antes de llegar al trigger). Pero **el trigger queda como red de seguridad** para concurrencia real.
4. **Cantidad siempre positiva.** La semántica de suma/resta vive en el `tipo`, no en el signo de `cantidad`.
5. **Motivo obligatorio para ajustes con mínimo 10 caracteres.** No "ok", "fix", "ajuste". Consistente con `rbac-matrix.md` Regla 8.
6. **No tocar la lógica de `compras` ni `detalle_compra`.** Esas tablas siguen siendo el registro de compras a proveedores; T-009 después emitirá movimientos ENTRADA cuando se reciban detalles de compra, pero ese link es trabajo del módulo, no del schema.
7. **No emitir eventos `bodega.movimiento.registrado` desde la BD.** Los eventos se emiten en NestJS vía `EventEmitter2` (T-009). El trigger solo valida, no emite.

---

## Casos de prueba obligatorios

Los **10 tests de la sección 7** son obligatorios. No es opcional cubrir solo algunos.

Casos adicionales para test manual / smoke post-merge:

- **Caso manual A — Stock inicial:**
  Después de aplicar la migración, consultar `SELECT * FROM tenant_erp.v_stock_actual LIMIT 5` debe retornar filas con `stock_actual = 0` para todos los materiales existentes (porque no hay movimientos todavía).

- **Caso manual B — Vista refresca al insertar:**
  Insertar manualmente un movimiento ENTRADA. Re-consultar la vista. El `stock_actual` del material correspondiente debe haber subido.

- **Caso manual C — Backfill no destructivo:**
  Verificar que después de la migración, los materiales existentes tienen `stock_minimo = NULL` y `stock_optimo = NULL`. Ninguno fue setearado con valores inventados.

---

## Lo que NO se debe hacer en esta tarea

- ❌ No crear `MovimientosController` ni ningún controlador HTTP. Eso es T-009.
- ❌ No crear `MovimientosService` ni lógica de aplicación en NestJS. Eso es T-009.
- ❌ No emitir eventos `bodega.movimiento.registrado` todavía. Eso es T-009.
- ❌ No agregar `stock_actual` como columna en `Material`. Solo vista.
- ❌ No convertir `v_stock_actual` en vista materializada en este ticket.
- ❌ No setear valores por default a `stock_minimo` ni `stock_optimo` en el backfill — quedan NULL.
- ❌ No tocar el flag `activo` de `Material`. Soft delete completo viene en T-MVP-004.
- ❌ No agregar campos para "stock reservado" (para O/Ps liberadas pero no consumidas). Eso es decisión de negocio que va en T-MVP-002 o un ticket de producción.
- ❌ No instalar librerías nuevas en `package.json`. Este ticket es 100% schema + SQL + tests con lo ya disponible.

---

## Entregables

- [ ] Migración Prisma generada y aplicada localmente.
- [ ] `schema.prisma` actualizado (enum + modelo + view + 2 campos en Material + relaciones inversas).
- [ ] Archivo `infra/local/postgres/init/04-bodega-functions.sql` creado.
- [ ] Los 10 tests de integración pasando.
- [ ] README de Prisma actualizado con las decisiones de diseño.
- [ ] Commit con formato: `feat(bodega): add movimientos table + stock derived view [A1]`.
- [ ] PR abierto con labels `agent:A1`, `supervisor:S1`, `sprint:1`, `priority:critical`, `requires-po-review`.

---

## Cómo invocar al agente

```bash
git checkout feat/T-FIX-001-rename-schema-tenant-erp  # asegurarse que ya está mergeado
git pull
git checkout -b feat/T-MVP-001-bodega-movimientos-stock
claude
```

Prompt:

```
Ejecuta T-MVP-001 (bodega: movimientos + stock derivado + umbrales).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-MVP-001-bodega-movimientos-stock.md
4. @docs/adrs/ADR-005-stock-calculado-desde-movimientos.md
5. @docs/prisma-workflow.md
6. @services/erp-api/prisma/schema.prisma

Antes de empezar, confirma:
1. ¿T-FIX-001 ya fue mergeado y el schema activo se llama tenant_erp?
2. ¿Hay materiales con stock real cargado en la BD?
   Si los hay: NO los toques. La migración solo agrega columnas null.
3. ¿PO está disponible para revisar el modelo de movimientos?
   (no bloquea ejecución, pero sí merge)

CRÍTICO:
- MovimientoBodega es inmutable (sin updated_at, sin deleted_at).
- stock_actual NUNCA es columna, solo vista.
- El trigger es red de seguridad; T-009 validará primero en aplicación.
- Este ticket NO crea endpoints HTTP. Es schema + SQL + tests de integración.
```

---

## Validación post-ejecución (lo llena S1)

```bash
cd services/erp-api

# 1. Migración aplicada
npx prisma migrate status
# Esperado: "All migrations have been applied"

# 2. Schema reflejado
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  \d tenant_erp.movimientos_bodega
"
# Esperado: las columnas y constraints listadas

# 3. Función y trigger existen
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT proname FROM pg_proc
  WHERE pronamespace = 'tenant_erp'::regnamespace
  AND proname LIKE '%stock%';
"
# Esperado: calcular_stock_material, tg_validar_stock_no_negativo

# 4. Vista existe
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT count(*) FROM tenant_erp.v_stock_actual;
"
# Esperado: count = número de materiales (con stock_actual = 0 todos)

# 5. Tests pasan
npm run test:integration -- bodega/movimientos

# 6. Smoke manual: intentar SALIDA sin stock
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  INSERT INTO tenant_erp.movimientos_bodega
    (id_material, tipo, cantidad, id_usuario, id_orden)
  VALUES (1, 'SALIDA', 999, 1, 1);
"
# Esperado: ERROR con código check_violation, mensaje "Stock insuficiente"
```

- **Fecha:** _pendiente_
- **Migración aplicada:** _pendiente_
- **Tests pasando (10/10):** _pendiente_
- **PO revisó el modelo:** _pendiente_
- **Resultado:** _pendiente_

---

## Notas para S1 y PO

**S1 revisa:**
- La migración SQL es no-destructiva sobre tablas existentes.
- Las constraints CHECK están escritas idiomáticamente.
- La función PL/pgSQL maneja correctamente el caso de tabla vacía (retorna 0, no NULL).
- Los tests de concurrencia (test 10) realmente disparan dos transacciones simultáneas.

**PO revisa obligatoriamente:**
- Los 4 valores de `TipoMovimiento` cubren los escenarios reales de Arteo. ¿Falta algo como `TRANSFERENCIA` entre bodegas, o `DEVOLUCION_PROVEEDOR` separado de `SALIDA`? **Si falta, agregar AHORA es barato; agregar después de tener datos en producción es caro.**
- El umbral de "10 caracteres en motivo" es razonable o muy laxo.
- Los nombres `stock_minimo` / `stock_optimo` son los que Arteo usa internamente, o tienen otra palabra (`punto_reposicion`, `stock_seguridad`).

---

**Creado:** 2026-05-13 por TL
**Prerrequisitos:** T-FIX-001 completado
**Bloquea:** T-009 (módulo bodega con endpoints HTTP)
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
