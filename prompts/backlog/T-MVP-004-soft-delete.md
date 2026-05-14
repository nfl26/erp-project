# T-MVP-004 · Soft delete (nivel 2) en tablas catálogo

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-MVP-004
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1
**Sprint:** Sprint 2
**Estimación:** 5 puntos
**Prioridad:** alta
**Rama:** `feat/T-MVP-004-soft-delete`

---

## Contexto de negocio

Los módulos del ERP permiten "eliminar" entidades catálogo (materiales, usuarios, categorías, compradores, etc.). Sin soft delete, esas eliminaciones son `DELETE` físicos que:

1. **Rompen historial:** una O/P cerrada que referencia un material eliminado queda con FK inválida o sin nombre descriptivo.
2. **Son irreversibles:** un bodeguero que elimina un material por error no tiene forma de recuperarlo.
3. **No dejan rastro de auditoría:** no hay quién borró ni cuándo.

El patrón elegido para este proyecto es **soft delete nivel 2**: campo `deleted_at TIMESTAMPTZ` (cuándo se borró) + campo `deleted_by INT FK usuarios` (quién lo borró). Coexiste con el flag `activo` ya existente en algunas tablas, que tiene semántica diferente: `activo = false` significa "suspendido temporalmente" (reversible, operativo), mientras que `deleted_at IS NOT NULL` significa "eliminado definitivamente" (sin retorno desde la UI).

---

## Prerrequisitos

- [ ] **T-008 completado** — `@CurrentUser()` disponible para poblar `deleted_by`.
- [ ] **T-MVP-003 completado** — `@Auditar()` disponible para registrar eliminaciones sensibles.
- [ ] Verificar tablas objetivo antes de empezar:
  ```bash
  docker compose exec postgres psql -U erp_admin -d erp_db -c "
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'tenant_erp' ORDER BY table_name;"
  ```

---

## Tablas objetivo

### Tablas catálogo — reciben `deleted_at` + `deleted_by`

Estas son las entidades que usuarios pueden "eliminar" desde la UI. Son catálogos o maestros de datos:

| Tabla | Tiene `activo` | Observación |
|---|---|---|
| `materiales` | ✅ | `activo` queda para suspender; `deleted_at` para borrar |
| `productos` | ✅ | ídem |
| `categorias` | ❌ | solo recibe `deleted_at` + `deleted_by` |
| `compradores` | ❌ | ídem |
| `proveedores` | ✅ | ídem |
| `usuarios` | ✅ | ídem — nunca hard delete de usuarios |
| `vendedores` | ❌ | ídem |
| `mano_de_obra` | ✅ | ídem |

### Tablas que NO reciben soft delete (inmutables o transaccionales)

Estas tablas nunca se "eliminan" — tienen máquinas de estado (`cancelado`, `finalizado`) o son registros históricos inmutables:

| Tabla | Motivo |
|---|---|
| `pedidos` | Estado `cancelado` cubre el caso |
| `ordenes_produccion` | Estado `cancelado` / `finalizado` |
| `ventas` | Registros contables inmutables |
| `pagos` | Registros contables inmutables |
| `compras` | Registros inmutables |
| `detalle_compra` | Registro inmutable |
| `detalle_pedido` | Registro inmutable |
| `movimientos_bodega` | Append-only por ADR-005 |
| `recetas` | `activa` cubre el versionado |
| `tarifas` | Inmutables por ADR-007 |
| `niveles_precio_corte` | Referenciados por tarifas |
| `precios_venta` | Relacionados con productos activos |
| `grabados` | Relacionados con productos |
| `parametros_corte` | Relacionados con recetas |
| `public.tenants` | Gestionado por super-admin, fuera del MVP |

---

## Alcance técnico

### Modificar en `schema.prisma`

Agregar a cada tabla catálogo:

```prisma
model Material {
  // ... campos existentes ...
  deleted_at DateTime? @db.Timestamptz(6)
  deleted_by Int?
  deletedBy  Usuario?  @relation("MaterialDeletedBy", fields: [deleted_by], references: [id_usuario])
}

// Misma estructura para: Producto, Categoria, Comprador,
// Proveedor, Usuario, Vendedor, ManoDeObra
```

> **Nota sobre relaciones:** agregar `deleted_by` implica FK a `usuarios`. En tablas que ya tienen relación con `Usuario` (ej: `Compra.id_usuario`), agregar la relación con un nombre explícito (`@relation("MaterialDeletedBy")`) para evitar ambigüedad. Verificar cada caso antes de aplicar.

### Migración SQL adicional

```sql
-- Vista de conveniencia: solo registros "vivos" por tabla
-- (Prisma no soporta filtros default en modelos, así que la vista facilita las queries)
CREATE OR REPLACE VIEW tenant_erp.v_materiales_activos AS
  SELECT * FROM tenant_erp.materiales
  WHERE deleted_at IS NULL;

-- La misma vista existe para otras tablas si es necesario.
-- Verificar si ya existe v_materiales_activos (creada en T-004 o T-002)
-- y actualizarla para incluir el filtro deleted_at IS NULL.

-- Índice para queries filtradas por soft delete (patrón más común)
CREATE INDEX IF NOT EXISTS idx_materiales_not_deleted
  ON tenant_erp.materiales (id_material) WHERE deleted_at IS NULL;

-- Repetir para cada tabla catálogo
```

### Crear en `services/erp-api/src/shared/`

```
src/shared/soft-delete/
├── soft-delete.mixin.ts        ← mixin con métodos softDelete() y restore()
└── is-not-deleted.pipe.ts      ← pipe que verifica que el recurso no está deleted
                                   antes de procesar el request
```

`soft-delete.mixin.ts` provee:

```typescript
// Mixin que cualquier service puede usar
export function withSoftDelete<T extends { new(...args: any[]): {} }>(Base: T) {
  return class extends Base {
    // Soft delete: setea deleted_at y deleted_by
    async softDelete(id: number, idUsuario: number): Promise<void>

    // Restaurar: limpia deleted_at y deleted_by
    async restore(id: number, idUsuario: number): Promise<void>
  }
}
```

---

## Criterios de aceptación

### 1. Migración

- [ ] `deleted_at TIMESTAMPTZ NULL` agregado a las 8 tablas catálogo.
- [ ] `deleted_by INT NULL FK usuarios.id_usuario` agregado a las 8 tablas catálogo.
- [ ] Migración no toca las tablas de la sección "no reciben soft delete".
- [ ] Los registros existentes no se alteran (columnas nullable, default NULL).
- [ ] `npx prisma migrate dev` corre sin errores.
- [ ] `npx prisma validate` pasa.
- [ ] Vista `v_materiales_activos` actualizada o creada con filtro `deleted_at IS NULL`.

### 2. Índices

- [ ] Índice parcial `WHERE deleted_at IS NULL` en cada tabla catálogo.

### 3. `soft-delete.mixin.ts`

- [ ] `softDelete(id, idUsuario)` setea `deleted_at = now()` y `deleted_by = idUsuario`.
- [ ] `softDelete` en un registro ya eliminado: lanza `NotFoundException` con mensaje `"Recurso no encontrado o ya eliminado"`.
- [ ] `restore(id, idUsuario)` limpia `deleted_at = NULL` y `deleted_by = NULL`. Solo permitido para roles `admin-sistema`.
- [ ] `restore` en un registro no eliminado: no-op (no lanza error, solo loggea warning).

### 4. Filtros en queries existentes

**Crítico:** todos los endpoints que listan o buscan entidades catálogo deben filtrar `deleted_at IS NULL` automáticamente. Esto se hace en el service correspondiente, no en el controller.

- [ ] `GET /materiales` ya no retorna materiales con `deleted_at IS NOT NULL`.
- [ ] `GET /categorias` ídem.
- [ ] `GET /compradores` ídem.
- [ ] `GET /usuarios` ídem.
- [ ] Esto aplica también a las queries internas (ej: cuando un módulo busca un material por ID para calcular costos — si está eliminado, debe lanzar `NotFoundException`).

> **Qué pasa con registros relacionados:** un material eliminado puede seguir siendo referenciado por recetas y O/Ps históricas. Esas relaciones se preservan. La eliminación no hace cascade — solo oculta el registro en queries nuevas.

### 5. Endpoint de eliminación

Los endpoints `DELETE /<recurso>/:id` en cada módulo deben:

- [ ] Llamar `softDelete(id, currentUser.id)` — nunca `prisma.recurso.delete()`.
- [ ] Retornar `204 No Content`.
- [ ] Registrar en auditoría con `@Auditar({ accion: '<recurso>.eliminado', recursoTipo: '<Recurso>' })`.

> **Nota:** este ticket agrega los campos en BD y el mixin. La actualización de cada endpoint individual de DELETE puede ir aquí o en los tickets de cada módulo (T-009, T-016, etc.). Coordinar con S1. Lo mínimo requerido aquí es que al menos `Material` y `Usuario` tengan su DELETE actualizado.

### 6. Tests

- [ ] `softDelete()` en registro existente: setea `deleted_at` y `deleted_by` correctamente.
- [ ] `softDelete()` en registro ya eliminado: lanza `NotFoundException`.
- [ ] `restore()` en registro eliminado: limpia los campos.
- [ ] `GET /materiales` no incluye materiales eliminados.
- [ ] `GET /materiales/:id` para material eliminado: retorna 404.
- [ ] Cobertura ≥ 85% en `soft-delete.mixin.ts`.

---

## Invariantes que el agente DEBE respetar

1. **NUNCA `prisma.<tabla>.delete()` en ningún módulo** después de este ticket. Toda eliminación usa `softDelete()`. Si el agente encuentra algún `delete()` existente, debe convertirlo.
2. **`deleted_at` y `activo` son conceptos distintos.** `activo = false` es "suspendido" (reversible por el propio usuario). `deleted_at IS NOT NULL` es "eliminado" (solo restaurable por `admin-sistema`). No mezclar.
3. **No hay cascade soft delete.** Eliminar un material no elimina sus recetas ni O/Ps relacionadas. Los registros históricos se preservan completos.
4. **`deleted_by` siempre poblado cuando `deleted_at` no es NULL.** No existe un "borrado anónimo".
5. **Toda eliminación se registra en auditoría** vía `@Auditar()`.

---

## Casos de prueba obligatorios

- **Caso 1 — Listado excluye eliminados:**
  - Setup: 5 materiales activos, 2 con `deleted_at` seteado.
  - Input: `GET /api/v1/bodega/materiales`.
  - Esperado: retorna 5, no 7.

- **Caso 2 — GET por ID de eliminado:**
  - Setup: material con `deleted_at IS NOT NULL`.
  - Input: `GET /api/v1/bodega/materiales/:id`.
  - Esperado: 404, no 200.

- **Caso 3 — Doble eliminación:**
  - Setup: material ya eliminado.
  - Input: `DELETE /api/v1/bodega/materiales/:id`.
  - Esperado: 404, no 500.

- **Caso 4 — Relaciones históricas preservadas:**
  - Setup: material A usado en receta R y en O/P histórica cerrada.
  - Input: soft delete de material A.
  - Esperado: material A no aparece en listados, pero `receta R` y la O/P siguen teniendo `id_material = A` intacto. Las O/Ps históricas no se rompen.

- **Caso 5 — `deleted_by` correcto:**
  - Setup: usuario con id 42 hace la eliminación.
  - Input: `DELETE /api/v1/bodega/materiales/:id` con JWT del usuario 42.
  - Esperado: `deleted_by = 42` en la fila.

---

## Lo que NO se debe hacer en esta tarea

- ❌ No agregar soft delete a tablas transaccionales o inmutables (pedidos, ventas, movimientos, etc.).
- ❌ No hacer cascade soft delete a registros relacionados.
- ❌ No confundir `activo = false` con `deleted_at IS NOT NULL`.
- ❌ No eliminar el campo `activo` de las tablas que ya lo tienen.
- ❌ No crear endpoint de restauración accesible para roles no admin.
- ❌ No usar `prisma.<tabla>.delete()` en ningún módulo nuevo o existente.

---

## Entregables

- [ ] Migración con `deleted_at` y `deleted_by` en las 8 tablas catálogo.
- [ ] Índices parciales `WHERE deleted_at IS NULL`.
- [ ] Vista `v_materiales_activos` actualizada.
- [ ] `soft-delete.mixin.ts` con `softDelete()` y `restore()`.
- [ ] Al menos `Material` y `Usuario` con endpoint DELETE actualizado.
- [ ] Filtros `deleted_at IS NULL` en todos los GET de las tablas afectadas.
- [ ] Tests con cobertura ≥ 85% en el mixin.
- [ ] Commit: `feat(shared): add soft delete nivel 2 a tablas catalogo [A1]`.
- [ ] PR con labels `agent:A1`, `supervisor:S1`, `sprint:2`, `priority:high`.

---

## Cómo invocar al agente

```bash
git checkout -b feat/T-MVP-004-soft-delete
claude
```

Prompt:

```
Ejecuta T-MVP-004 (soft delete nivel 2 en tablas catálogo).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-MVP-004-soft-delete.md
4. @services/erp-api/prisma/schema.prisma

Antes de empezar:
- Lista qué tablas ya tienen campo 'activo' y cuáles no.
- Confirma que entiende la diferencia entre activo=false (suspendido)
  y deleted_at IS NOT NULL (eliminado) — son conceptos distintos.
- Verifica si v_materiales_activos ya existe y qué columnas tiene.

Regla crítica: NUNCA prisma.<tabla>.delete().
Todo DELETE físico es un bug después de este ticket.
```

---

## Validación post-ejecución (lo llena S1)

```bash
# 1. Verificar columnas en tablas catálogo
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT table_name, column_name
  FROM information_schema.columns
  WHERE table_schema = 'tenant_erp'
    AND column_name IN ('deleted_at', 'deleted_by')
  ORDER BY table_name;"
# Esperado: 8 tablas × 2 columnas = 16 filas

# 2. Verificar índices parciales
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT indexname, tablename, indexdef
  FROM pg_indexes
  WHERE schemaname = 'tenant_erp'
    AND indexdef LIKE '%deleted_at IS NULL%';"
# Esperado: 8 índices

# 3. Tests
cd services/erp-api && npm test -- --testPathPattern=soft-delete
```

- **Fecha:** _pendiente_
- **8 tablas con deleted_at + deleted_by:** _pendiente_
- **Índices parciales:** _pendiente_
- **soft-delete.mixin.ts funcional:** _pendiente_
- **Tests:** _pendiente_
- **Resultado:** _pendiente_

---

**Creado:** 2026-05-13 por TL + S1
**Prerrequisitos:** T-008, T-MVP-003 completados
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
