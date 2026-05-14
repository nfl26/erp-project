> **ARCHIVADO el 2026-05-13** — Este ticket no se ejecuta.
>
> Fue reescrito en `prompts/backlog/T-007-multi-tenant-runtime.md` (pendiente).
> Las razones del cambio:
> 1. El schema `tenant_demo` pasó a llamarse `tenant_erp` en T-FIX-001.
> 2. El enfoque original (replicar tablas por schema con SQL raw) fue
>    reemplazado porque T-004 ya generó `schema.prisma` con `multiSchema`
>    y `@@schema` por modelo, lo cual hace innecesaria la replicación manual.
>
> Este archivo se preserva como evidencia histórica del backlog. No editar.

# T-007 · Schema PostgreSQL v1 — Tenants, extensiones y seeds base

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-007
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1 (con revisión obligatoria de PO antes de mergear)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 3 puntos
**Prioridad:** alta
**Rama:** `feat/T-007-schema-postgresql-v1`

---

## Contexto de negocio

T-004 conectó Prisma con la BD Arteo existente y generó el `schema.prisma` desde esa BD. Ese schema refleja las tablas del negocio (insumos, recetas, órdenes, etc.). Lo que **no existe todavía** es la infraestructura multi-tenant que necesitamos para que el ERP pueda servir a múltiples clientes/rubros en el futuro.

Este ticket agrega esa capa: el schema `public` con la tabla `tenants`, los schemas por tenant (`tenant_demo`, `tenant_acme`), y los seeds mínimos que permiten al equipo trabajar con datos reales desde el día siguiente.

Cuando T-007 termine, cualquier miembro del equipo puede arrancar el proyecto con `./scripts/dev-reset.sh` y tener datos reales de Arteo disponibles en `tenant_demo` sin configuración manual.

---

## Prerrequisitos

- [ ] **T-002 completado** — docker-compose corriendo con PostgreSQL.
- [ ] **T-004 completado** — Prisma conectado, `schema.prisma` generado, migración `0_init` aplicada.

---

## Alcance técnico

### Crear

```
services/erp-api/
├── prisma/
│   ├── schema.prisma           ← agregar tabla tenants al modelo existente
│   └── migrations/
│       ├── 0_init/             ← ya existe (de T-004)
│       └── 20260427_add_multi_tenancy/
│           └── migration.sql   ← nueva migración
└── src/
    └── shared/
        ├── tenant/
        │   ├── tenant.module.ts
        │   ├── tenant.service.ts        ← resolver tenant desde request
        │   └── tenant.middleware.ts     ← SET search_path por request
        └── prisma/
            └── prisma.service.ts        ← actualizar para SET search_path

infra/local/postgres/
├── init/
│   ├── 01-extensions.sql       ← ya existe (de T-002)
│   ├── 02-create-tenants.sql   ← ya existe (de T-002)
│   └── 03-seed-arteo-demo.sql  ← NUEVO: datos Arteo en tenant_demo
└── scripts/
    └── seed-tenant.sh          ← script para seedear un tenant nuevo
```

### No tocar

- Las tablas de negocio existentes en `schema.prisma` — las creó Prisma con `db pull`, no se modifican en este ticket.
- `docker-compose.yml` — solo se agrega el archivo de seed si no existe.

---

## Criterios de aceptación

### 1. Tabla `tenants` en schema `public`

Agregar al `schema.prisma`:

```prisma
model Tenant {
  id          String   @id @default(uuid())
  slug        String   @unique          // ej: "acme", "demo"
  nombre      String                    // ej: "Arteo SpA"
  activo      Boolean  @default(true)
  config      Json?                     // configuración específica del tenant
  createdAt   DateTime @default(now())  @map("created_at")
  updatedAt   DateTime @updatedAt       @map("updated_at")

  @@map("tenants")
  @@schema("public")
}
```

- [ ] Modelo `Tenant` en `schema.prisma` con `@@schema("public")`.
- [ ] Migración generada con `prisma migrate dev --name add_multi_tenancy`.
- [ ] La tabla `public.tenants` existe en la BD después de la migración.

### 2. Schemas por tenant

- [ ] Existen los schemas: `tenant_demo`, `tenant_acme` en PostgreSQL.
- [ ] Cada schema tiene las mismas tablas (las del negocio Arteo).
- [ ] Los schemas están vacíos excepto `tenant_demo` (que tiene seeds).

> **Cómo se crean los schemas:** la migración Prisma crea `tenant_demo` y `tenant_acme` con un bloque SQL raw. Cuando en el futuro se agregue un nuevo tenant, el `TenantService` crea su schema automáticamente.

La migración debe incluir:

```sql
-- Crear schemas de tenants de desarrollo
CREATE SCHEMA IF NOT EXISTS tenant_demo;
CREATE SCHEMA IF NOT EXISTS tenant_acme;

-- Copiar estructura del schema public a cada tenant
-- (Prisma no soporta esto nativamente, usar SQL raw)
-- Las tablas se crean con el mismo DDL del schema inicial
```

### 3. Middleware de tenant

El middleware resuelve el tenant desde el request y hace `SET search_path`:

```typescript
// tenant.middleware.ts
@Injectable()
export class TenantMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    // Resolver tenant desde:
    // 1. Header X-Tenant-Id (para APIs internas)
    // 2. Subdominio (ej: acme.erp.arteo.cl → tenant_acme)
    // 3. Variable de entorno DEFAULT_TENANT (para desarrollo)
    const tenantSlug = this.resolveTenant(req);

    if (!tenantSlug) {
      throw new BadRequestException('Tenant no identificado');
    }

    req['tenantId'] = tenantSlug;
    next();
  }
}
```

- [ ] `TenantMiddleware` aplicado a todas las rutas excepto `/health` y `/api/docs`.
- [ ] El tenant se resuelve en este orden: header `X-Tenant-Id` → subdominio → `DEFAULT_TENANT`.
- [ ] Si el tenant no existe en `public.tenants`: retorna 404 con mensaje claro.

### 4. PrismaService actualizado para multi-tenancy

```typescript
// En cada request, Prisma debe usar el schema del tenant correcto
// Opción: extender PrismaClient con middleware
this.$use(async (params, next) => {
  // Antes de cada query: SET search_path al tenant del request
  await this.$executeRawUnsafe(`SET search_path TO ${tenantSchema}, public`);
  return next(params);
});
```

- [ ] `PrismaService` aplica `SET search_path` antes de cada query.
- [ ] En tests, se usa `tenant_demo` por defecto.
- [ ] El search_path nunca se setea a un schema que no existe.

### 5. Seeds para `tenant_demo`

El seed de `tenant_demo` incluye datos mínimos para que el equipo pueda desarrollar:

**`infra/local/postgres/init/03-seed-arteo-demo.sql`:**

```sql
-- Solo ejecutar en tenant_demo
SET search_path TO tenant_demo, public;

-- Insertar tenant en tabla pública
INSERT INTO public.tenants (id, slug, nombre, activo)
VALUES (gen_random_uuid(), 'demo', 'Arteo Demo', true)
ON CONFLICT (slug) DO NOTHING;

-- Datos base tomados del schema Arteo existente
-- (el agente A1 los adapta según el schema.prisma generado en T-004)

-- Ejemplo: si existe tabla materiales
-- INSERT INTO materiales (nombre, unidad, precio_unitario, activo)
-- VALUES
--   ('Acero inox 1mm', 'M2', 8500, true),
--   ('Acero galvanizado 2mm', 'M2', 6200, true),
--   ...
-- ON CONFLICT DO NOTHING;
```

- [ ] Seeds idempotentes (`ON CONFLICT DO NOTHING`).
- [ ] Al menos 10 registros por tabla principal que tenga datos en el Excel Arteo.
- [ ] Los datos son representativos del negocio real (no Lorem Ipsum).
- [ ] Los seeds solo afectan `tenant_demo`.
- [ ] **PO revisa y aprueba** los seeds antes de mergear (los datos deben ser correctos).

### 6. Script `seed-tenant.sh`

```bash
#!/bin/bash
# Uso: ./seed-tenant.sh acme "Empresa Acme SpA"
# Crea el schema, aplica migraciones y seed base para un nuevo tenant

TENANT_SLUG=$1
TENANT_NOMBRE=$2

# Crear schema
psql $DATABASE_URL -c "CREATE SCHEMA IF NOT EXISTS tenant_${TENANT_SLUG};"

# Aplicar migraciones al nuevo schema
DATABASE_URL="${DATABASE_URL}?schema=tenant_${TENANT_SLUG}" npx prisma migrate deploy

# Insertar en tabla tenants
psql $DATABASE_URL -c "
  INSERT INTO public.tenants (id, slug, nombre, activo)
  VALUES (gen_random_uuid(), '${TENANT_SLUG}', '${TENANT_NOMBRE}', true)
  ON CONFLICT (slug) DO NOTHING;
"

echo "✓ Tenant ${TENANT_SLUG} creado y listo"
```

- [ ] El script existe, es ejecutable, y funciona.
- [ ] Tiene validación: si `TENANT_SLUG` está vacío, imprime uso y sale.
- [ ] Funciona con la variable `DATABASE_URL` del `.env`.

### 7. Tests

- [ ] Test de integración: `TenantMiddleware` resuelve el tenant correctamente.
- [ ] Test de integración: request sin tenant retorna 404.
- [ ] Test de integración: `PrismaService` hace query en el schema correcto.
- [ ] Test E2E: `GET /health` con header `X-Tenant-Id: demo` retorna 200.

---

## Invariantes que el agente DEBE respetar

1. **Nunca `SET search_path` a un valor que venga directamente del usuario sin validar.** Siempre validar que el slug existe en `public.tenants` antes de usarlo en el search_path.
2. **Los seeds son idempotentes.** El script puede correrse múltiples veces sin duplicar datos.
3. **Los seeds solo tocan `tenant_demo`.** Nunca insertar datos en `tenant_acme` o `public` directamente desde seeds.
4. **El schema `public` solo tiene la tabla `tenants`.** Las tablas de negocio van en los schemas de tenant.

---

## Validación post-ejecución

```bash
# 1. Verificar schemas
docker compose exec postgres psql -U erp_admin -d erp_db -c "\dn"
# Debe mostrar: public, tenant_demo, tenant_acme

# 2. Verificar tabla tenants
docker compose exec postgres psql -U erp_admin -d erp_db \
  -c "SELECT slug, nombre FROM public.tenants;"
# Debe mostrar: demo | Arteo Demo

# 3. Verificar seeds en tenant_demo
docker compose exec postgres psql -U erp_admin -d erp_db \
  -c "SET search_path TO tenant_demo; SELECT COUNT(*) FROM materiales;"
# Debe retornar > 0

# 4. Verificar middleware
curl -H "X-Tenant-Id: demo" http://localhost:3000/health
# Esperado: 200 OK

curl -H "X-Tenant-Id: inexistente" http://localhost:3000/health
# Esperado: 404 Not Found

# 5. Crear tenant nuevo con el script
./infra/local/postgres/scripts/seed-tenant.sh beta "Empresa Beta SPA"
docker compose exec postgres psql -U erp_admin -d erp_db -c "\dn"
# Debe aparecer tenant_beta
```

---

## Cómo invocar al agente

```bash
git checkout -b feat/T-007-schema-postgresql-v1
claude
```

Prompt:

```
Ejecuta T-007 (schema PostgreSQL v1 + multi-tenancy).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-007-schema-postgresql-v1.md
4. @docs/adrs/ADR-003-multi-tenancy-por-schema.md
5. @docs/prisma-workflow.md
6. @services/erp-api/prisma/schema.prisma

Antes de empezar:
- Confirmar que T-002 y T-004 están completos
- Verificar el schema.prisma existente para saber
  qué tablas tiene la BD Arteo

Importante: los seeds deben usar datos reales
del negocio Arteo, no datos ficticios.
Pregúntame si necesitas confirmar algún dato.
```

---

## Nota para S1 y PO

**S1 revisa:** la migración SQL, el middleware, los tests.

**PO revisa obligatoriamente:** los seeds de `tenant_demo`. Los datos insertados deben ser representativos del negocio real (categorías, materiales, precios) y correctos según el conocimiento del cliente. Un seed con datos incorrectos puede confundir al equipo durante todo el desarrollo.

---

## Validación post-ejecución (lo llena S1)

- **Fecha:** _pendiente_
- **Schemas creados:** _pendiente_
- **Seeds en tenant_demo:** _pendiente (listar tablas y conteos)_
- **Middleware funcionando:** _pendiente_
- **Script seed-tenant.sh:** _pendiente_
- **PO aprobó los seeds:** _pendiente_
- **Resultado:** _pendiente_

---

**Creado:** 2026-04-27 por S1 + PO
**Prerrequisitos:** T-002 y T-004 completados
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
