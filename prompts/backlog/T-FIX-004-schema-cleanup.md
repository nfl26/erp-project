# T-FIX-004 · Correcciones técnicas del schema (Bolsa C)

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-FIX-004
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1
**Sprint:** Sprint 2 (no bloquea Sprint 1)
**Estimación:** 5 puntos
**Prioridad:** media
**Rama:** `fix/T-FIX-004-schema-cleanup`

---

## Contexto

Durante el análisis del `schema.prisma` generado en T-004 (vía `prisma db pull`) se identificaron inconsistencias técnicas que no dependen de decisiones de negocio: timestamps faltantes, campos calculados sin protección, constraints evidentes que faltan, y definiciones incompletas en el schema Prisma. Este ticket las corrige todas en una sola migración atómica.

Los issues que sí requieren decisión de PO **no están aquí** — están documentados en la sección "Pendientes de PO" al final del ticket como referencia para la próxima reunión.

Referencia: archivo `erp_arteo.dbml` generado en Bolsa B, items 1-31. Este ticket cubre los items del Grupo 1.

---

## Prerrequisitos

- [ ] **T-FIX-001 completado** — schema se llama `tenant_erp`.
- [ ] **T-004 completado** — schema.prisma es la fuente de verdad.
- [ ] **T-MVP-001 a T-MVP-004 NO iniciados** — si alguno ya está en curso, coordinar con S1 para evitar conflictos de migración.
- [ ] Verificar si hay datos en tablas que recibirán constraints nuevos:
  ```bash
  # Verificar si hay grabados huérfanos (id_producto NULL)
  docker compose exec postgres psql -U erp_admin -d erp_db \
    -c "SELECT COUNT(*) FROM tenant_erp.grabados WHERE id_producto IS NULL;"

  # Verificar si hay vendedores duplicados por usuario
  docker compose exec postgres psql -U erp_admin -d erp_db \
    -c "SELECT id_usuario, COUNT(*) FROM tenant_erp.vendedores
        GROUP BY id_usuario HAVING COUNT(*) > 1;"

  # Verificar si hay recetas duplicadas (mismo producto + material + version)
  docker compose exec postgres psql -U erp_admin -d erp_db \
    -c "SELECT id_producto, id_material, version, COUNT(*)
        FROM tenant_erp.recetas
        GROUP BY id_producto, id_material, version
        HAVING COUNT(*) > 1;"

  # Ver columnas de v_costos_productos
  docker compose exec postgres psql -U erp_admin -d erp_db \
    -c "SELECT column_name, data_type, character_maximum_length,
               numeric_precision, numeric_scale
        FROM information_schema.columns
        WHERE table_schema = 'tenant_erp'
          AND table_name = 'v_costos_productos'
        ORDER BY ordinal_position;"
  ```

  > Si alguna de las tres primeras queries devuelve filas, **parar y reportar a S1** antes de continuar. Los constraints nuevos fallarán con datos inconsistentes existentes.

---

## Alcance técnico — 17 correcciones

### Bloque 1: Timestamps faltantes

Agregar `created_at` y/o `updated_at` donde faltan. Todas las columnas son **nullable con default**, para no romper filas existentes.

| Tabla | Agrega | Nota |
|---|---|---|
| `tenant_erp.categorias` | `created_at`, `updated_at` | — |
| `tenant_erp.productos` | `created_at`, `updated_at` | — |
| `tenant_erp.grabados` | `created_at` | — |
| `tenant_erp.precios_venta` | `created_at`, `updated_at` | — |
| `tenant_erp.recetas` | `created_at`, `updated_at` | — |
| `tenant_erp.parametros_corte` | `created_at` | — |
| `tenant_erp.ordenes_produccion` | `created_at` | — |
| `tenant_erp.ventas` | `created_at`, `updated_at` | — |
| `tenant_erp.pagos` | `created_at` | — |
| `tenant_erp.pedidos` | `updated_at` | Ya tiene `created_at` |
| `public.tenants` | — | `updated_at` ya existe pero es nullable manual — agregar trigger `@updatedAt` |
| `tenant_erp.proveedores` | `created_at`, `updated_at` | — |

```sql
-- Patrón para cada tabla (repetir por tabla):
ALTER TABLE tenant_erp.categorias
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- Trigger para updated_at automático (crear función helper una vez, reutilizar):
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_categorias_updated_at
  BEFORE UPDATE ON tenant_erp.categorias
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Repetir el trigger para cada tabla que tiene updated_at
```

> **Por qué trigger en lugar de `DEFAULT now()` en updated_at:** `DEFAULT` solo aplica en INSERT. Para que `updated_at` se actualice en cada UPDATE se necesita un trigger. Prisma puede manejar esto con `@updatedAt` en el client, pero el trigger es la garantía a nivel BD independiente del ORM.

### Bloque 2: `public.tenants.updated_at` con trigger

```sql
-- tenants.updated_at ya existe como columna nullable.
-- Solo agregar el trigger si no existe:
CREATE TRIGGER IF NOT EXISTS trg_tenants_updated_at
  BEFORE UPDATE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

- [ ] Trigger creado en `public.tenants`.

### Bloque 3: Unique constraints evidentes

```sql
-- vendedores: un usuario solo puede tener un perfil vendedor
ALTER TABLE tenant_erp.vendedores
  ADD CONSTRAINT uq_vendedores_usuario UNIQUE (id_usuario);

-- materiales: cod_interno es un código identificador, debe ser único
ALTER TABLE tenant_erp.materiales
  ADD CONSTRAINT uq_materiales_cod_interno UNIQUE (cod_interno)
  DEFERRABLE INITIALLY DEFERRED;
-- DEFERRABLE porque cod_interno es nullable — el constraint solo aplica a valores no NULL en PostgreSQL
```

- [ ] `uq_vendedores_usuario` activo. Si la query de prereq devolvió duplicados: parar, reportar a S1.
- [ ] `uq_materiales_cod_interno` activo (solo afecta filas con `cod_interno NOT NULL`).

### Bloque 4: `estade_orden` — agregar valor `cancelado`

```sql
ALTER TYPE tenant_erp.estado_orden ADD VALUE IF NOT EXISTS 'cancelado';
```

- [ ] `cancelado` disponible en el enum `estado_orden`.
- [ ] `npx prisma generate` actualiza el enum en el cliente TypeScript.
- [ ] El valor `cancelado` aparece en `EstadoOrden` en el código NestJS.

> **Nota:** `ADD VALUE` en un enum PostgreSQL no es transaccional — no se puede hacer dentro de un `BEGIN/COMMIT` con otras operaciones. Esta instrucción va **sola** al inicio de la migración, antes del resto.

### Bloque 5: `ordenes_produccion.closed_at`

Necesario para ADR-007: la fecha de referencia para buscar tarifas vigentes es el cierre de la O/P, no `fecha_fin` (que puede ser nula hasta que finalice).

```sql
ALTER TABLE tenant_erp.ordenes_produccion
  ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;

COMMENT ON COLUMN tenant_erp.ordenes_produccion.closed_at IS
  'Timestamp exacto del cierre de la O/P. Usado como fecha de referencia para
   resolver tarifas vigentes (ADR-007). Se setea cuando estado pasa a finalizado
   o cancelado. Distinto de fecha_fin (tiempo de máquina).';
```

- [ ] Columna `closed_at` existe en `ordenes_produccion`.
- [ ] Comentario de columna documentado en BD.
- [ ] `schema.prisma` actualizado con el campo.

### Bloque 6: Campos calculados — documentar y proteger

Las siguientes columnas son campos calculados que se almacenan pero podrían desincronizarse:

- `tenant_erp.recetas.costo_material_calculado`
- `tenant_erp.recetas.costo_tiempo_base`
- `tenant_erp.recetas.valor_neto`
- `tenant_erp.detalle_pedido.subtotal`
- `tenant_erp.ventas.total_final`
- `tenant_erp.detalle_compra.subtotal`
- `tenant_erp.materiales.cm2_por_plancha`

Para el MVP: convertir los que son operaciones simples a **generated columns** de PostgreSQL (calculados automáticamente por la BD, nunca desincronizados). Para los más complejos: agregar comentario de BD y marcar en `schema.prisma`.

```sql
-- detalle_pedido.subtotal = cantidad × precio_unitario_acordado
ALTER TABLE tenant_erp.detalle_pedido
  DROP COLUMN IF EXISTS subtotal;
ALTER TABLE tenant_erp.detalle_pedido
  ADD COLUMN subtotal DECIMAL(10,2)
    GENERATED ALWAYS AS (cantidad * precio_unitario_acordado) STORED;

-- ventas.total_final = total_bruto - descuento
ALTER TABLE tenant_erp.ventas
  DROP COLUMN IF EXISTS total_final;
ALTER TABLE tenant_erp.ventas
  ADD COLUMN total_final DECIMAL(12,2)
    GENERATED ALWAYS AS (total_bruto - descuento) STORED;

-- detalle_compra.subtotal = cantidad × precio_unitario
ALTER TABLE tenant_erp.detalle_compra
  DROP COLUMN IF EXISTS subtotal;
ALTER TABLE tenant_erp.detalle_compra
  ADD COLUMN subtotal DECIMAL(10,2)
    GENERATED ALWAYS AS (cantidad * precio_unitario) STORED;

-- materiales.cm2_por_plancha = ancho_cm × alto_cm × 100
-- (nullable porque ancho_cm y alto_cm son nullables)
ALTER TABLE tenant_erp.materiales
  DROP COLUMN IF EXISTS cm2_por_plancha;
ALTER TABLE tenant_erp.materiales
  ADD COLUMN cm2_por_plancha DECIMAL(12,2)
    GENERATED ALWAYS AS (
      CASE WHEN ancho_cm IS NOT NULL AND alto_cm IS NOT NULL
           THEN ancho_cm * alto_cm * 100
           ELSE NULL
      END
    ) STORED;
```

Para los costos de receta (más complejos, dependen de tarifas):

```sql
-- Estos NO se convierten a generated columns porque dependen de tarifas externas.
-- Se documentan como "campos de caché deprecados" hasta que T-029 (motor de costos)
-- los calcule en runtime.
COMMENT ON COLUMN tenant_erp.recetas.costo_material_calculado IS
  'DEPRECATED: campo de caché. El costo real lo calcula el motor de costos (T-029)
   usando las tarifas vigentes al cierre de la O/P (ADR-007). No usar en nuevos endpoints.';

COMMENT ON COLUMN tenant_erp.recetas.costo_tiempo_base IS
  'DEPRECATED: campo de caché. Ver costo_material_calculado.';

COMMENT ON COLUMN tenant_erp.recetas.valor_neto IS
  'DEPRECATED: campo de caché. Ver costo_material_calculado.';
```

> ⚠️ **Antes de aplicar el `DROP COLUMN` + `ADD COLUMN` en los campos calculados:** verificar que ningún código existente haga `INSERT` o `UPDATE` sobre esas columnas. Si lo hace, fallará con "cannot insert into a generated column". Grep obligatorio:
> ```bash
> grep -rn "subtotal\|total_final\|cm2_por_plancha" \
>   services/erp-api/src services/erp-api/test
> ```

### Bloque 7: `pedidos` — consolidar timestamps redundantes

`pedidos` tiene `fecha_pedido` (timestamptz, default now()) y `created_at` (timestamptz, default now()). Son semánticamente diferentes en teoría (fecha en que el cliente hizo el pedido vs fecha en que se registró en el sistema), pero en la práctica del cliente son siempre iguales.

**Decisión para este ticket:** no eliminar ninguno (eliminar `fecha_pedido` podría romper reportes del cliente). En cambio:

```sql
COMMENT ON COLUMN tenant_erp.pedidos.fecha_pedido IS
  'Fecha que el cliente indica como fecha del pedido (puede diferir de created_at
   si se registra con retraso). Para reportes contables usar esta columna.';

COMMENT ON COLUMN tenant_erp.pedidos.created_at IS
  'Timestamp de inserción del registro en la BD. No modificar.';
```

- [ ] Comentarios agregados en BD.
- [ ] En `schema.prisma`: agregar comentario `/// @deprecated — usar fecha_pedido para reportes` sobre `created_at` del modelo `Pedido` para que quede en el código.

### Bloque 8: `v_costos_productos` — completar en schema.prisma

```bash
# A1 ejecuta esto antes de tocar el schema:
docker compose exec postgres psql -U erp_admin -d erp_db \
  -c "SELECT column_name, data_type, character_maximum_length,
             numeric_precision, numeric_scale
      FROM information_schema.columns
      WHERE table_schema = 'tenant_erp'
        AND table_name = 'v_costos_productos'
      ORDER BY ordinal_position;"
```

Con el resultado, completar el bloque comentado en `schema.prisma`:

```prisma
// Descomentar y completar con las columnas reales:
view VCostosProductos {
  id_producto Int @unique
  // ... columnas exactas del resultado psql ...
  @@map("v_costos_productos")
  @@schema("tenant_erp")
}
```

- [ ] `VCostosProductos` descomentado y completo en `schema.prisma`.
- [ ] `npx prisma generate` pasa sin errores.

---

## Criterios de aceptación consolidados

### Migración

- [ ] `npx prisma migrate dev --name schema_cleanup_fix_004` corre sin errores.
- [ ] `npx prisma validate` pasa.
- [ ] `npx prisma generate` pasa.
- [ ] `npx prisma migrate status` — "All migrations applied".

### Timestamps (Bloque 1 + 2)

- [ ] 12 tablas tienen `created_at` y/o `updated_at` donde faltaban.
- [ ] Trigger `set_updated_at()` existe como función helper compartida.
- [ ] Triggers de `updated_at` activos en todas las tablas que tienen esa columna.
- [ ] Filas existentes no afectadas (columnas nullable).

### Constraints (Bloque 3)

- [ ] `uq_vendedores_usuario` activo.
- [ ] `uq_materiales_cod_interno` activo (deferrable).

### Enum (Bloque 4)

- [ ] `cancelado` disponible en `estado_orden`.
- [ ] `EstadoOrden` en el cliente Prisma TypeScript incluye `cancelado`.

### `closed_at` (Bloque 5)

- [ ] Columna existe en `ordenes_produccion`.
- [ ] Comentario de columna legible en BD (`\d+ ordenes_produccion` lo muestra).

### Campos calculados (Bloque 6)

- [ ] `detalle_pedido.subtotal` es `GENERATED ALWAYS AS (...) STORED`.
- [ ] `ventas.total_final` ídem.
- [ ] `detalle_compra.subtotal` ídem.
- [ ] `materiales.cm2_por_plancha` ídem (nullable cuando algún factor es null).
- [ ] Intentar `UPDATE tenant_erp.detalle_pedido SET subtotal = 999` falla con error de BD.
- [ ] Costos de receta tienen `COMMENT` de deprecación legible en BD.

### Comentarios (Bloque 7)

- [ ] `pedidos.fecha_pedido` y `pedidos.created_at` tienen comentarios en BD.

### Vista (Bloque 8)

- [ ] `VCostosProductos` completo en `schema.prisma`.

### Tests

- [ ] `npm run typecheck` pasa sin errores (los generated columns pueden romper tipos Prisma si no se regenera el cliente).
- [ ] `npm test` pasa (ningún test existente usa escritura sobre los campos que pasaron a generated).
- [ ] Grep de `subtotal|total_final|cm2_por_plancha` en `src/` y `test/`: cualquier escritura directa sobre esos campos debe ser eliminada o reportada.

---

## Invariantes que el agente DEBE respetar

1. **No tocar tablas de los tickets T-MVP-*** — `movimientos_bodega` (no existe aún), `tarifas` (no existe aún), `auditoria_global` (no existe aún). Si hay overlap, coordinar con S1.
2. **`ADD VALUE` al enum va primero**, fuera de transacción explícita, antes de cualquier otra instrucción SQL en la migración.
3. **`DROP COLUMN` + `ADD COLUMN` para los campos calculados** — no es posible `ALTER COLUMN ... SET GENERATED` en PostgreSQL. Es necesario drop + add. Verificar que ningún código escribe en esas columnas antes de aplicar.
4. **No cambiar tipos de columnas existentes.** Solo agregar columnas y constraints. Cambiar tipos es destructivo y necesita su propio ticket con análisis de impacto.
5. **No eliminar `fecha_pedido` en `pedidos`.** Puede parecer redundante con `created_at` pero el cliente puede tener semántica distinta. Solo documentar.
6. **No modificar el tipo de `tenants.id`** (UUID → INT). Ese cambio requiere migración de datos y ADR nuevo. No va en este ticket.

---

## Casos de prueba obligatorios

- **Caso 1 — Generated column rechaza escritura:**
  - Input: `prisma.detallePedido.update({ where: { id: 1 }, data: { subtotal: 999 } })`.
  - Esperado: error de BD "cannot assign to a generated column".

- **Caso 2 — Generated column calcula correctamente:**
  - Setup: insertar `detalle_pedido` con `cantidad = 3`, `precio_unitario_acordado = 150`.
  - Query: `SELECT subtotal FROM detalle_pedido WHERE id_detalle = <nuevo>`.
  - Esperado: `subtotal = 450.00`.

- **Caso 3 — Unique vendedor:**
  - Setup: crear vendedor para usuario id=5.
  - Input: intentar crear segundo vendedor para el mismo usuario id=5.
  - Esperado: error de unique constraint.

- **Caso 4 — EstadoOrden cancelado:**
  - Input: `prisma.ordenProduccion.update({ data: { estado: 'cancelado' } })`.
  - Esperado: éxito (sin error de enum inválido).

- **Caso 5 — cm2_por_plancha con valores nulos:**
  - Setup: material con `ancho_cm = NULL`, `alto_cm = 50`.
  - Query: `SELECT cm2_por_plancha FROM materiales WHERE id_material = <id>`.
  - Esperado: `NULL` (no 0, no error).

- **Caso 6 — cm2_por_plancha calculado:**
  - Setup: material con `ancho_cm = 60`, `alto_cm = 40`.
  - Esperado: `cm2_por_plancha = 240000.00` (60 × 40 × 100).

- **Caso 7 — updated_at automático:**
  - Setup: categoria con `updated_at = NULL`.
  - Input: `prisma.categoria.update({ data: { nombre: 'Test' } })`.
  - Esperado: `updated_at` tiene un timestamp reciente (no NULL).

---

## Lo que NO se debe hacer en esta tarea

- ❌ No cambiar tipos de columnas existentes (UUID → INT, VARCHAR → TEXT, etc.).
- ❌ No eliminar columnas existentes excepto los 4 campos calculados que pasan a generated.
- ❌ No crear tablas nuevas — eso es terreno de T-MVP-*.
- ❌ No resolver los issues del Grupo 2 (pendientes de PO) que están listados más abajo.
- ❌ No modificar `enums` excepto el `ADD VALUE 'cancelado'` a `estado_orden`.
- ❌ No cambiar `tenants.id` de UUID a INT — requiere ADR nuevo.
- ❌ No agregar `NOT NULL` a `grabados.id_producto` sin verificar primero que no hay huérfanos en BD.

---

## Entregables

- [ ] Migración única con todos los cambios del Bloque 1 al 8.
- [ ] `schema.prisma` actualizado (nuevos campos, `VCostosProductos` completo, `EstadoOrden` con `cancelado`).
- [ ] Triggers `set_updated_at` en todas las tablas con `updated_at`.
- [ ] Comentarios de columna en BD para campos sensibles.
- [ ] Grep de campos calculated limpio en `src/` y `test/`.
- [ ] `npm run typecheck` y `npm test` pasando.
- [ ] Commit: `fix(schema): cleanup tecnico post T-004 — timestamps, constraints, generated cols, enum [A1]`.
- [ ] PR con labels `agent:A1`, `supervisor:S1`, `type:fix`, `sprint:2`, `priority:medium`.

---

## Cómo invocar al agente

```bash
git checkout -b fix/T-FIX-004-schema-cleanup
claude
```

Prompt:

```
Ejecuta T-FIX-004 (correcciones técnicas del schema).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-FIX-004-schema-cleanup.md
4. @docs/prisma-workflow.md
5. @services/erp-api/prisma/schema.prisma

Antes de escribir una sola línea de código:
1. Corre los 4 queries de prerequisito del ticket y reporta los resultados.
2. Si cualquier query devuelve filas (duplicados, huérfanos): PARAR y reportar a S1.
3. Corre el SELECT de v_costos_productos y muéstrame las columnas.

Reglas críticas de este ticket:
- ADD VALUE al enum va PRIMERO, fuera de transacción.
- DROP + ADD para campos calculated — verificar grep antes.
- No cambiar tipos de columnas existentes.
- No crear tablas nuevas.
```

---

## Validación post-ejecución (lo llena S1)

```bash
# 1. Verificar generated columns
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT column_name, generation_expression
  FROM information_schema.columns
  WHERE table_schema = 'tenant_erp'
    AND is_generated = 'ALWAYS';"
# Esperado: subtotal (detalle_pedido), subtotal (detalle_compra),
#           total_final (ventas), cm2_por_plancha (materiales)

# 2. Verificar triggers updated_at
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT trigger_name, event_object_table
  FROM information_schema.triggers
  WHERE trigger_schema = 'tenant_erp'
    AND trigger_name LIKE '%updated_at%'
  ORDER BY event_object_table;"

# 3. Verificar enum
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT enumlabel FROM pg_enum
  JOIN pg_type ON pg_enum.enumtypid = pg_type.oid
  WHERE pg_type.typname = 'estado_orden';"
# Esperado: pendiente, en_proceso, finalizado, cancelado

# 4. Build completo
cd services/erp-api
npm run typecheck && npm test
```

- **Fecha:** _pendiente_
- **Generated columns verificados:** _pendiente_
- **Triggers updated_at:** _pendiente_
- **estado_orden incluye cancelado:** _pendiente_
- **Build + tests:** _pendiente_
- **Resultado:** _pendiente_

---

## Pendientes de PO — NO ejecutar en este ticket

Estos issues del DBML requieren respuesta de negocio antes de modelar. Documentados aquí para que no se pierdan.

| # | Issue | Pregunta para PO | Impacto si sí |
|---|---|---|---|
| 7 | `materiales.proveedor` es texto libre, no FK | ¿Queremos vincular materiales a la tabla proveedores? ¿Hay materiales sin proveedor? | Migración de datos, FK nueva |
| 9 | `compradores` sin RUT | ¿Necesitamos RUT para factura electrónica SII en el MVP? | Campo nuevo, validación chilena |
| 10 | `proveedores` sin RUT | Ídem | Campo nuevo |
| 13 | `precios_venta` sin historial | ¿Los precios de venta necesitan historial temporal como las tarifas? | T-MVP-005 completo |
| 14 | `precio_con_argolla` | ¿Qué es una argolla? ¿Es un accesorio estándar del catálogo? | Puede modelarse mejor |
| 15 | unique en `recetas` | ¿Puede existir más de una receta activa para el mismo producto+material? | Constraint nuevo (verificar datos primero) |
| 18 | `parametros_corte.tecnica` | ¿Cuáles son los valores posibles de técnica? ¿corte, grabado, marcado? | Enum nuevo |
| 19 | `grabados.id_producto` nullable | ¿Puede existir un diseño de grabado sin producto asociado? | NOT NULL o FK obligatoria |
| 29 | 4 roles vs 9 en rbac-matrix.md | ¿Los 9 roles del RBAC se mapean sobre los 4 del enum, o el enum debe ampliarse? | Impacta T-008 directamente |
| 1 | `tenants.id` UUID vs INT | ¿Vale la pena migrar a INT para coherencia? | ADR nuevo, migración costosa |

**Acción:** llevar esta tabla a la próxima reunión con PO antes de iniciar Sprint 2.

---

**Creado:** 2026-05-13 por TL + S1
**Prerrequisitos:** T-FIX-001, T-004 completados
**No bloquea:** T-007, T-008, T-009, T-010 (puede correr en paralelo con Sprint 1)
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
