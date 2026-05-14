# T-FIX-001 · Rename schema `tenant_demo` → `tenant_erp`

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-FIX-001
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1
**Sprint:** Sprint 1 (bloqueante de T-007)
**Estimación:** 2 puntos
**Prioridad:** crítica
**Rama:** `fix/T-FIX-001-rename-schema-tenant-erp`

---

## Contexto

El `schema.prisma` generado en T-004 usa el nombre `tenant_demo` para el schema de tenant. Ese nombre era un placeholder heredado de T-002, redactado antes de definir la estrategia multi-tenant final. La decisión actual del Tech Lead es:

- **BD:** se mantiene `erp_db` (es el nombre del producto, no del cliente).
- **Schema tenant:** pasa de `tenant_demo` a `tenant_erp`.

El cambio es trivial técnicamente (find-replace + un `ALTER SCHEMA`) pero debe hacerse **antes de T-007** porque ese ticket hardcodea el nombre del schema en el `TenantMiddleware`, los seeds y los tests.

Este ticket no agrega funcionalidad. Solo renombra. Si rompe algo, ese algo estaba mal acoplado al nombre del schema.

---

## Prerrequisitos

- [ ] **T-004 completado** — `schema.prisma` existe y la migración `0_init` está aplicada.
- [ ] **T-007 NO iniciado todavía.** Si T-007 ya se empezó, abortar y coordinar con S1.
- [ ] **Antes de empezar verificar:**
  ```bash
  docker compose exec postgres psql -U erp_admin -d erp_db -c "\dn"
  # Debe mostrar: public, tenant_demo
  ```

---

## Alcance técnico

### Modificar

```
services/erp-api/
├── prisma/
│   ├── schema.prisma                              ← 18+ ocurrencias de "tenant_demo"
│   └── migrations/
│       └── <timestamp>_rename_tenant_demo_to_tenant_erp/
│           └── migration.sql                      ← NUEVA: ALTER SCHEMA
├── prisma.config.ts                               ← si referencia el schema
├── src/
│   └── **/*.ts                                    ← grep por "tenant_demo" en código
├── test/
│   └── **/*.ts                                    ← tests que mockean el schema
└── .env.example                                   ← si DEFAULT_TENANT=demo, pasa a erp

infra/local/postgres/
├── init/
│   ├── 02-create-tenants.sql                      ← cambiar CREATE SCHEMA tenant_demo
│   └── 03-seed-arteo-demo.sql                     ← si referencia el schema
└── scripts/
    └── *.sh                                       ← grep por tenant_demo

scripts/
├── dev-up.sh
├── dev-reset.sh
├── dev-psql.sh                                    ← si setea search_path
└── pre-pr-check.sh

prompts/
├── backlog/
│   └── T-007-schema-postgresql-v1.md              ← MOVER a prompts/archived/
└── archived/
    └── T-007-schema-postgresql-v1.md              ← destino del mv (crear carpeta si no existe)

docs/
├── architecture.md                                ← referencias al schema
├── prisma-workflow.md                             ← ejemplos con nombre del schema
├── rbac-matrix.md                                 ← si hay ejemplos SQL
└── adrs/ADR-003-multi-tenancy-por-schema.md       ← ejemplos del ADR

CLAUDE.md                                          ← grep "tenant_demo"
```

### No tocar

- Estructura de tablas dentro del schema (los 19 modelos no cambian).
- Datos existentes en `tenant_demo` (se preservan vía `ALTER SCHEMA`, no `DROP`).
- Nombre de la BD (`erp_db` se mantiene).
- Nombre de la tabla `public.tenants` (es la tabla de catálogo, no se renombra).
- El valor del campo `slug` en filas existentes de `public.tenants` — se ajusta en seeds, no en migración.

---

## Criterios de aceptación

### 1. Migración Prisma

Generada con `prisma migrate dev --name rename_tenant_demo_to_tenant_erp`. El SQL debe ser **idempotente y reversible**:

```sql
-- Renombrar schema preservando todos los datos
ALTER SCHEMA tenant_demo RENAME TO tenant_erp;

-- Si en el futuro se necesita rollback:
-- ALTER SCHEMA tenant_erp RENAME TO tenant_demo;
```

- [ ] La migración usa `ALTER SCHEMA ... RENAME TO`, **no** `DROP SCHEMA + CREATE SCHEMA`.
- [ ] Los datos existentes en las tablas se preservan (verificar con `SELECT COUNT(*) FROM tenant_erp.materiales` antes y después).
- [ ] La migración se aplica sin errores con `npx prisma migrate dev`.
- [ ] **Importante:** si `prisma migrate dev` genera SQL que dropea y recrea las tablas (porque ve un "schema move" como destructivo), reescribir la migración a mano. La idea es renombrar, no recrear.

### 2. `schema.prisma` actualizado

- [ ] `datasource db.schemas` pasa de `["public", "tenant_demo"]` a `["public", "tenant_erp"]`.
- [ ] **Todas** las ocurrencias de `@@schema("tenant_demo")` cambian a `@@schema("tenant_erp")`. Esperar ~18 ocurrencias (modelos + enums).
- [ ] `npx prisma validate` pasa sin errores.
- [ ] `npx prisma generate` ejecuta sin errores.

### 3. Archivos SQL en `infra/local/postgres/`

- [ ] `02-create-tenants.sql`: `CREATE SCHEMA IF NOT EXISTS tenant_demo` → `CREATE SCHEMA IF NOT EXISTS tenant_erp`.
- [ ] Cualquier otro SQL que referencie `tenant_demo` se actualiza.
- [ ] Los archivos siguen siendo idempotentes (todos los `CREATE` con `IF NOT EXISTS`).

### 4. Catálogo `public.tenants`

El registro semilla del tenant debe quedar coherente:

- [ ] Si existe la fila con `slug = 'demo'` en `public.tenants`, **actualizarla** a `slug = 'erp'` en la misma migración (o en un seed posterior si T-007 todavía no creó esa fila — coordinar con S1).
- [ ] Si la fila no existe todavía (T-007 la creará): no hacer nada aquí, dejar que T-007 inserte directamente con `slug = 'erp'`.
- [ ] La migración no debe fallar si la fila no existe (`UPDATE` sin `WHERE` que matchee es seguro).

### 5. Código fuente

Ejecutar grep en `services/erp-api/`:

```bash
grep -r "tenant_demo" services/erp-api/src services/erp-api/test
```

Esperado: **cero resultados** después de la actualización. Los lugares típicos donde aparece:

- [ ] `PrismaService` si hace `$executeRawUnsafe('SET search_path TO tenant_demo')`.
- [ ] Tests que mockean conexiones a Prisma con un schema específico.
- [ ] Constantes de configuración (ej. `DEFAULT_SCHEMA = 'tenant_demo'`).

### 6. Variables de entorno

- [ ] `.env.example` de `services/erp-api/`: si tiene `DEFAULT_TENANT=demo`, pasa a `DEFAULT_TENANT=erp`.
- [ ] Documentar en el README del servicio que `DEFAULT_TENANT` debe matchear con un `slug` existente en `public.tenants`.
- [ ] **No tocar `.env` ni `.env.local`** (esos los ajusta cada developer en su máquina; basta documentarlo).

### 7. Scripts shell

Grep en `scripts/` e `infra/`:

```bash
grep -rn "tenant_demo" scripts/ infra/
```

- [ ] Cada referencia se actualiza.
- [ ] `dev-psql.sh`, si setea `search_path`, ahora apunta a `tenant_erp`.

### 8. Documentación

- [ ] `CLAUDE.md`: si menciona `tenant_demo` en ejemplos, actualizar.
- [ ] `docs/architecture.md`: actualizar diagramas y ejemplos.
- [ ] `docs/prisma-workflow.md`: actualizar ejemplos de comandos.
- [ ] `docs/adrs/ADR-003-multi-tenancy-por-schema.md`: actualizar ejemplos.
- [ ] **No reescribir los ADRs** — solo cambiar el nombre en los bloques de código de ejemplo. La decisión arquitectónica no cambia.

### 9. Archivar T-007 viejo

El archivo `prompts/backlog/T-007-schema-postgresql-v1.md` quedará reemplazado por una nueva versión (T-007 nuevo, redactado en otro ticket). La política del proyecto es **mover prompts obsoletos a `prompts/archived/`**, no reescribirlos in place y no dejarlos en `backlog/` con banner deprecated. Esto mantiene `backlog/` limpio (solo prompts ejecutables) y preserva la auditoría histórica.

- [ ] Crear la carpeta `prompts/archived/` si no existe.
- [ ] **Mover** (no copiar) el archivo:
  ```bash
  mkdir -p prompts/archived
  git mv prompts/backlog/T-007-schema-postgresql-v1.md \
         prompts/archived/T-007-schema-postgresql-v1.md
  ```
- [ ] Agregar al inicio del archivo movido un banner que explique el archivado:

  ```markdown
  > 🗄️ **ARCHIVADO el 2026-05-13** — Este ticket no se ejecuta.
  >
  > Fue reescrito en `prompts/backlog/T-007-multi-tenant-runtime.md` (pendiente).
  > Las razones del cambio:
  > 1. El schema `tenant_demo` pasó a llamarse `tenant_erp` en T-FIX-001.
  > 2. El enfoque original (replicar tablas por schema con SQL raw) fue
  >    reemplazado porque T-004 ya generó `schema.prisma` con `multiSchema`
  >    y `@@schema` por modelo, lo cual hace innecesaria la replicación manual.
  >
  > Este archivo se preserva como evidencia histórica del backlog. No editar.
  ```

- [ ] Si `prompts/README.md` o algún otro doc tiene enlaces a `backlog/T-007-schema-postgresql-v1.md`, actualizarlos a `archived/T-007-schema-postgresql-v1.md`.
- [ ] Crear (o actualizar si existe) `prompts/archived/README.md` con una breve nota:

  ```markdown
  # Prompts archivados

  Esta carpeta contiene prompts que fueron redactados pero **no se ejecutan**
  porque quedaron obsoletos, fueron reescritos, o describen decisiones que
  el equipo descartó. Se preservan como evidencia histórica del proceso
  de decisión.

  **Regla:** los agentes IA nunca leen archivos de esta carpeta como instrucción.
  Si necesitas entender por qué un enfoque se descartó, este es el lugar.

  | Archivo | Reemplazado por | Motivo |
  |---|---|---|
  | T-007-schema-postgresql-v1.md | T-007-multi-tenant-runtime.md (pendiente) | Cambio de enfoque multi-tenant + rename de schema (ver T-FIX-001) |
  ```

### 10. Validación post-cambio

Después de aplicar todo:

```bash
# 1. Bajar y subir el stack limpio (decisión: ¿reset o preservar?)
#    Ver "Estrategia de aplicación" más abajo.

# 2. Verificar schemas
docker compose exec postgres psql -U erp_admin -d erp_db -c "\dn"
# Esperado: public, tenant_erp (NO tenant_demo)

# 3. Verificar que las tablas siguen ahí
docker compose exec postgres psql -U erp_admin -d erp_db \
  -c "SELECT count(*) FROM tenant_erp.materiales;"
# Esperado: el mismo count que había antes en tenant_demo.materiales

# 4. Verificar Prisma
cd services/erp-api
npx prisma validate
npx prisma generate
npx prisma migrate status
# Todo verde

# 5. Type-check completo
npm run typecheck
# Cero errores (si hay errores, son referencias rotas a constantes viejas)

# 6. Tests
npm test
# Todo pasa

# 7. Grep final
grep -rn "tenant_demo" services/erp-api/src services/erp-api/test \
  infra/ scripts/ docs/ CLAUDE.md prompts/backlog
# Esperado: cero resultados.
# (Sí puede aparecer en prompts/archived/T-007-schema-postgresql-v1.md
#  y en este propio ticket T-FIX-001 — eso es esperado y correcto)
```

---

## Estrategia de aplicación

Hay dos formas de aplicar este cambio y el agente debe **preguntar a S1 cuál usar**:

### Opción A — Migración limpia preservando datos

Aplicar la migración `ALTER SCHEMA` sobre la BD que ya está corriendo. Los datos en `tenant_demo` se preservan automáticamente, solo cambia el nombre del contenedor.

- **Pros:** cero pérdida de datos, refleja cómo se aplicaría en producción real.
- **Contras:** si alguien en el equipo tiene una BD local con estado divergente, puede haber inconsistencias.
- **Cuándo:** si ya hay datos importantes en `tenant_demo` o si el equipo está coordinado.

### Opción B — Reset completo

Bajar el stack, borrar volúmenes, volver a levantar con el nombre nuevo desde cero.

- **Pros:** garantiza estado limpio en todas las máquinas.
- **Contras:** se pierden datos locales que cada developer haya cargado a mano.
- **Cuándo:** si todavía no hay datos importantes (este es el caso esperado en Semana 1).

```bash
./scripts/dev-reset.sh  # opción B
# o
docker compose exec postgres psql -U erp_admin -d erp_db \
  -f /docker-entrypoint-initdb.d/migration-rename.sql  # opción A
```

- [ ] El agente pregunta a S1 cuál opción aplicar antes de proceder.
- [ ] En el PR se documenta cuál se eligió y por qué.

---

## Invariantes que el agente DEBE respetar

1. **No `DROP SCHEMA`.** El comando `ALTER SCHEMA ... RENAME TO` preserva los datos. Cualquier alternativa que dropea es **inaceptable**.
2. **No tocar la estructura de tablas.** Esto es solo un rename, no un refactor.
3. **El nombre nuevo es exactamente `tenant_erp`.** No `tenant_ERP`, ni `tenantErp`, ni `TenantErp`. PostgreSQL convierte identificadores no quoteados a minúsculas, y la convención del proyecto es snake_case.
4. **Si la migración generada por `prisma migrate dev` es destructiva** (dropea y recrea), reescribir manualmente. Esto pasa a veces cuando Prisma no detecta bien un rename de schema completo.
5. **Cero referencias a `tenant_demo`** quedan en el código vivo o en `prompts/backlog/`. Las únicas excepciones permitidas: `prompts/archived/T-007-schema-postgresql-v1.md` (registro histórico) y este propio ticket T-FIX-001.
6. **No introducir librerías nuevas.** Esto es una operación de rename, no requiere dependencias.

---

## Casos de prueba obligatorios

- **Caso 1 — Migración preserva datos:**
  - Setup: insertar 5 filas en `tenant_demo.materiales` antes de la migración.
  - Input: aplicar la migración.
  - Esperado: 5 filas en `tenant_erp.materiales`, `tenant_demo` no existe.

- **Caso 2 — Prisma client funciona post-rename:**
  - Setup: migración aplicada, `prisma generate` ejecutado.
  - Input: `prisma.material.count()` desde un script de prueba.
  - Esperado: retorna el count correcto sin error.

- **Caso 3 — Grep limpio:**
  - Input: `grep -rn "tenant_demo" services/erp-api/src services/erp-api/test infra/ scripts/`.
  - Esperado: cero resultados.

- **Caso 4 — Migration status:**
  - Input: `npx prisma migrate status`.
  - Esperado: "All migrations have been applied". No hay drift entre BD y `schema.prisma`.

---

## Lo que NO se debe hacer en esta tarea

- ❌ No renombrar la BD (`erp_db` se mantiene).
- ❌ No renombrar `public.tenants` ni ninguna otra tabla.
- ❌ No agregar tablas nuevas.
- ❌ No tocar las migraciones anteriores (`0_init` no se reescribe — la nueva migración se agrega encima).
- ❌ No modificar la estrategia multi-tenant (ADR-003 sigue vigente).
- ❌ No reescribir T-007 en este ticket — solo moverlo a `prompts/archived/`.
- ❌ No cambiar el `slug` del tenant si T-007 todavía no lo creó.

---

## Entregables

- [ ] Migración Prisma generada y aplicada.
- [ ] `schema.prisma` actualizado.
- [ ] Todos los archivos SQL, scripts, env y docs actualizados.
- [ ] T-007 viejo movido a `prompts/archived/` con banner explicativo y entrada en `prompts/archived/README.md`.
- [ ] Tests pasando.
- [ ] Grep final limpio.
- [ ] Commit con formato: `fix(schema): rename tenant_demo to tenant_erp [A1]`.
- [ ] PR abierto con labels `agent:A1`, `supervisor:S1`, `type:fix`, `priority:critical`.

---

## Cómo invocar al agente

```bash
git checkout -b fix/T-FIX-001-rename-schema-tenant-erp
claude
```

Prompt:

```
Ejecuta T-FIX-001 (rename schema tenant_demo → tenant_erp).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-FIX-001-rename-schema-tenant-erp.md
4. @docs/prisma-workflow.md
5. @services/erp-api/prisma/schema.prisma

Antes de empezar, pregúntame:
1. ¿Aplicamos la migración preservando datos (Opción A)
   o hacemos reset completo (Opción B)?
2. ¿Hay alguien más con T-007 en marcha? (debe estar pausado)

Importante:
- ALTER SCHEMA RENAME, NUNCA DROP.
- El nombre del schema es exactamente "tenant_erp" (snake_case).
- La BD sigue llamándose erp_db (no cambia).
```

---

## Validación post-ejecución (lo llena S1)

```bash
# Antes del merge, S1 verifica:

# 1. Schemas
docker compose exec postgres psql -U erp_admin -d erp_db -c "\dn"
# Esperado: public, tenant_erp

# 2. Datos preservados (si Opción A)
docker compose exec postgres psql -U erp_admin -d erp_db \
  -c "SELECT table_name FROM information_schema.tables WHERE table_schema='tenant_erp';"
# Esperado: las 19 tablas de negocio

# 3. Prisma alineado
cd services/erp-api && npx prisma migrate status

# 4. Build limpio
npm run build && npm test

# 5. Grep limpio
grep -rn "tenant_demo" \
  services/erp-api/src services/erp-api/test \
  infra/ scripts/ docs/ CLAUDE.md README.md prompts/backlog
# Esperado: cero resultados.
# (En prompts/archived/ sí debe seguir apareciendo — eso es correcto)
```

- **Fecha:** _pendiente_
- **Opción aplicada (A/B):** _pendiente_
- **Datos preservados:** _pendiente_
- **Resultado:** _pendiente_

---

## Notas

**Por qué `tenant_erp` y no `tenant_arteo`:** decisión del Tech Lead. La BD se llama `erp_db` (genérica del producto), y el schema del único cliente actual mantiene la misma lógica genérica. Cuando aparezca un segundo cliente, su schema seguirá patrón `tenant_<slug>` con el slug específico del cliente nuevo.

**Por qué un ticket separado y no agregarlo a T-007:** rename de schema es destructivo de coordinación (cualquiera con la rama vieja queda desincronizado). Aislarlo en un fix corto permite mergearlo rápido y desbloquear T-007 sin mezclar responsabilidades.

---

**Creado:** 2026-05-13 por TL
**Prerrequisitos:** T-004 completado, T-007 NO iniciado
**Bloquea:** T-007 (multi-tenant runtime)
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
