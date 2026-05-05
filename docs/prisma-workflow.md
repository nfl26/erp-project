# Flujo de trabajo con Prisma

> Documento autoritativo sobre cómo se gestionan los cambios de base de datos en el proyecto. **Todo agente IA y supervisor humano debe leer esto antes de tocar el schema.**

---

## Principio fundamental

**La base de datos existente es el punto de partida. Prisma es la fuente de verdad a partir de ese punto.**

```
Base de datos existente
        │
        │  prisma db pull  (una vez, al inicio)
        ▼
  schema.prisma   ←──── fuente de verdad permanente
        │
        │  prisma migrate dev  (en desarrollo)
        │  prisma migrate deploy  (en producción)
        ▼
  Base de datos actualizada
```

A partir del `prisma db pull` inicial, **nunca más se hacen cambios manuales directos en PostgreSQL**. Todo cambio estructural nace en `schema.prisma`.

---

## Las dos reglas de oro

### Regla 1: El cambio nace en el código

```bash
# 1. Modificar schema.prisma
# 2. Generar migración
npx prisma migrate dev --name descripcion_del_cambio

# 3. Prisma aplica la migración en la BD de desarrollo automáticamente
# 4. En producción
npx prisma migrate deploy
```

Usar cuando: agregas una columna, creas una tabla, modificas un tipo, añades un índice.

### Regla 2: El cambio nació en la base de datos

```bash
# 1. Alguien hizo un cambio directo en PostgreSQL (ej: desde pgAdmin)
# 2. Sincronizar Prisma
npx prisma db pull

# 3. Revisar qué cambió en schema.prisma
git diff prisma/schema.prisma

# 4. Formalizar como migración
npx prisma migrate dev --name sync_cambio_externo

# 5. Commitear schema.prisma + la nueva migración juntos
git add prisma/
git commit -m "chore(schema): sync external db change [agente]"
```

Usar cuando: un cambio llegó de afuera (migración de datos, cambio de DBA, emergencia en producción).

---

## Setup inicial del proyecto (una sola vez)

Esto es lo que hace el agente A1 en el ticket T-004 (proyecto NestJS base):

```bash
cd services/erp-api

# 1. Instalar Prisma
npm install prisma @prisma/client
npx prisma init

# 2. Configurar DATABASE_URL en .env
# postgresql://erp_admin:password@localhost:5432/erp_db?schema=public

# 3. Hacer pull del schema existente
npx prisma db pull
# Genera schema.prisma con todas las tablas que existen en la BD

# 4. Revisar el schema generado
# Prisma puede no detectar bien: enums, relaciones implícitas, JSONB, etc.
# Corregir manualmente donde sea necesario

# 5. Establecer el estado inicial de migraciones
npx prisma migrate dev --name init
# Esto crea prisma/migrations/0_init/migration.sql con el DDL completo

# 6. Generar el cliente Prisma
npx prisma generate

# 7. Commitear todo
git add prisma/
git commit -m "chore(schema): initial prisma setup from existing db [A1]"
```

---

## Flujo diario en desarrollo

```
Quiero agregar una columna
          │
          ▼
Editar schema.prisma
          │
          ▼
npx prisma migrate dev --name add_columna_X
          │
          ├─→ Prisma genera el SQL en prisma/migrations/
          ├─→ Prisma aplica la migración en la BD local
          └─→ Prisma regenera el cliente (@prisma/client)
          │
          ▼
El código ya puede usar el campo nuevo
          │
          ▼
git add prisma/ src/  →  PR  →  Review  →  Merge
```

---

## Flujo en producción (CI/CD)

```yaml
# .github/workflows/ci.yml (fragmento)
- name: Apply DB migrations
  run: npx prisma migrate deploy
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL_PROD }}
```

`prisma migrate deploy`:
- Aplica **solo** las migraciones pendientes (las que no están en `_prisma_migrations`).
- No crea migraciones nuevas.
- No interactúa (modo no-interactivo, seguro para CI).
- Falla si hay conflictos de migración → el deploy se detiene.

---

## Estructura de archivos Prisma por servicio

```
services/erp-api/
├── prisma/
│   ├── schema.prisma          ← fuente de verdad del schema (compartido por todos los módulos)
│   └── migrations/
│       ├── migration_lock.toml
│       ├── 0_init/
│       │   └── migration.sql  ← DDL inicial (del prisma db pull)
│       ├── 20260422_add_stock_minimo/
│       │   └── migration.sql
│       └── 20260430_add_categoria_descripcion/
│           └── migration.sql
├── src/
│   ├── shared/
│   │   └── prisma/
│   │       └── prisma.service.ts  ← wrapper de PrismaClient
│   └── modules/
│       ├── auth/
│       ├── bodega/
│       ├── ventas/
│       ├── produccion/
│       └── notificaciones/
└── package.json
```

---

## Convenciones de nombres para migraciones

```bash
# ✅ Descriptivos y en snake_case
npx prisma migrate dev --name add_stock_minimo_to_insumos
npx prisma migrate dev --name create_tabla_movimientos_bodega
npx prisma migrate dev --name add_index_insumos_categoria
npx prisma migrate dev --name rename_precio_to_precio_unitario

# ❌ Evitar
npx prisma migrate dev --name fix
npx prisma migrate dev --name update
npx prisma migrate dev --name cambios
```

---

## Convivencia entre módulos del monolito

Todos los módulos del monolito comparten el mismo `services/erp-api/prisma/schema.prisma`. Sin embargo, **cada módulo es dueño de sus tablas**. Ningún módulo accede directamente a las tablas de otro.

```
schema.prisma (único, fuente de verdad)
├── tablas de auth/         ← solo AuthModule lee/escribe
├── tablas de bodega/       ← solo BodegaModule lee/escribe
├── tablas de ventas/       ← solo VentasModule lee/escribe
├── tablas de produccion/   ← solo ProduccionModule lee/escribe
└── tablas de notificaciones/ ← solo NotificacionesModule lee/escribe
```

Un módulo que necesite datos de otro lo hace **vía servicio público (declarado en `exports`) o vía evento (`EventEmitter2`)**.

Cuando un módulo se extraiga como microservicio (ver `docs/roadmap-microservicios.md`), su `schema.prisma` se mueve a su propio repositorio y conserva las migraciones existentes.

Ver [ADR-010](adrs/ADR-010-monolito-modular.md).

---

## Casos comunes y cómo resolverlos

### Agregar una columna nueva

```prisma
// schema.prisma
model Insumo {
  id          Int      @id @default(autoincrement())
  codigo      String   @unique
  nombre      String
  stockMinimo Decimal? @map("stock_minimo")  // ← NUEVO
}
```

```bash
npx prisma migrate dev --name add_stock_minimo_to_insumos
```

### Agregar una tabla nueva

```prisma
// schema.prisma
model ProveedorInsumo {
  id         Int      @id @default(autoincrement()) @map("id_proveedor_insumo")
  insumoId   Int      @map("id_insumo")
  proveedorId Int     @map("id_proveedor")
  precio     Decimal
  
  insumo     Insumo   @relation(fields: [insumoId], references: [id])
  @@map("proveedor_insumo")
}
```

```bash
npx prisma migrate dev --name create_proveedor_insumo
```

### Renombrar una columna

```prisma
// ANTES
precio      Decimal

// DESPUÉS — usar @map para mantener la columna en BD con nombre original
precioUnitario Decimal @map("precio_unitario")
```

Si el nombre de la columna en BD también debe cambiar:

```bash
npx prisma migrate dev --name rename_precio_to_precio_unitario
# Prisma genera: ALTER TABLE ... RENAME COLUMN precio TO precio_unitario
```

### Agregar un índice

```prisma
model Insumo {
  // ...
  categoriaId Int @map("id_categoria")
  
  @@index([categoriaId])  // ← NUEVO
}
```

```bash
npx prisma migrate dev --name add_index_insumos_categoria_id
```

### Manejar JSONB (campos dinámicos)

```prisma
model VarianteProducto {
  id          Int    @id @default(autoincrement()) @map("id_variante")
  productoId  Int    @map("id_producto")
  atributos   Json   // ← JSONB en PostgreSQL
  
  @@map("variante_producto")
}
```

Prisma mapea `Json` a `jsonb` en PostgreSQL automáticamente. La validación del schema JSON se hace en el servicio, no en la BD. Ver [ADR-004](adrs/ADR-004-jsonb-para-campos-dinamicos.md).

### Datos existentes + migración

Si la migración afecta datos (ej: dividir una columna en dos):

```sql
-- migration.sql generada por Prisma (editada manualmente)
-- Step 1: Add new columns
ALTER TABLE "insumos" ADD COLUMN "nombre_corto" VARCHAR(50);
ALTER TABLE "insumos" ADD COLUMN "nombre_largo" VARCHAR(200);

-- Step 2: Migrate data
UPDATE "insumos" SET "nombre_corto" = LEFT("nombre", 50);
UPDATE "insumos" SET "nombre_largo" = "nombre";

-- Step 3: Make old column nullable (o eliminarla en migración posterior)
ALTER TABLE "insumos" ALTER COLUMN "nombre" DROP NOT NULL;
```

**Regla:** si editas manualmente el SQL generado por Prisma, añade un comentario `-- MANUAL EDIT:` para que sea visible en revisión.

---

## Errores comunes y cómo resolverlos

### "The migration `X` was modified after it was applied"

```bash
# Alguien editó una migración ya aplicada (nunca hacer esto)
# Solución: revertir el cambio en el archivo de migración
git checkout prisma/migrations/X/migration.sql
```

### "Drift detected: Your database schema is not in sync"

```bash
# La BD tiene cambios que Prisma no conoce
npx prisma db pull
git diff prisma/schema.prisma
npx prisma migrate dev --name sync_drift
```

### "Migration failed to apply cleanly to the shadow database"

```bash
# El SQL generado tiene un error
# Revisar manualmente: prisma/migrations/{última}/migration.sql
# Corregir el SQL o el schema.prisma
npx prisma migrate dev --name fix_migration
```

### Cliente Prisma desactualizado

```bash
# Después de cualquier cambio en schema.prisma:
npx prisma generate
# Si no se corre, el código compilará pero usará tipos viejos
```

---

## Invariantes que los agentes deben respetar

1. **Nunca modificar una migración ya commiteada.** Si está en el historial git, es inmutable.
2. **Siempre hacer `prisma generate` después de cambiar el schema.** El cliente tiene que estar actualizado.
3. **Nunca usar `prisma db push` en staging o producción.** Solo `prisma migrate deploy`.
4. **`prisma db push` es solo para exploración local** — no genera archivos de migración, no deja historial.
5. **Migraciones deben ser idempotentes** cuando sea posible (usar `IF NOT EXISTS`, `IF EXISTS`).
6. **Schema y migraciones van en el mismo commit** — nunca separados.

---

## Referencia rápida de comandos

| Comando | Cuándo usar |
|---|---|
| `prisma db pull` | Pull del schema de la BD hacia schema.prisma |
| `prisma migrate dev --name X` | Crear migración en desarrollo |
| `prisma migrate deploy` | Aplicar migraciones en producción/CI |
| `prisma migrate status` | Ver qué migraciones están pendientes |
| `prisma generate` | Regenerar el cliente después de cambios al schema |
| `prisma studio` | UI visual para explorar datos (solo desarrollo) |
| `prisma db push` | Sync rápido sin generar migraciones (solo exploración local) |
| `prisma migrate reset` | Borrar BD y re-aplicar todas las migraciones (solo local) |

---

## Referencias

- [ADR-003](adrs/ADR-003-multi-tenancy-por-schema.md) — multi-tenancy por schema PostgreSQL
- [ADR-004](adrs/ADR-004-jsonb-para-campos-dinamicos.md) — campos JSONB
- [ADR-005](adrs/ADR-005-stock-calculado-desde-movimientos.md) — tablas inmutables
- [agents/A1-nestjs.md](../agents/A1-nestjs.md) — contrato del agente NestJS
- [stack.md](stack.md) — stack completo del proyecto
- Documentación oficial Prisma: https://www.prisma.io/docs/

---

**Versión:** 1.0
**Mantenedor:** Tech Lead (TL)
**Última actualización:** abril 2026
**Frecuencia de revisión:** cuando cambie el stack de ORM o las convenciones de migración
