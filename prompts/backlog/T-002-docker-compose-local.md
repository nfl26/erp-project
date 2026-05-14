# T-002 · docker-compose local: PostgreSQL 15 + Redis + pgAdmin + RabbitMQ

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-002
**Agente asignado:** A7 (DevOps & Infra)
**Supervisor humano:** DO (DevOps / Plataforma)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 4 puntos
**Prioridad:** crítica
**Rama:** `feat/T-002-docker-compose-local`

---

## Contexto de negocio

Los 7 supervisores humanos van a levantar este entorno local cada mañana durante los próximos 6 meses. Este es el entorno base para el **monolito NestJS** (`services/erp-api/`) más los frontends. Es la primera experiencia de desarrollo del proyecto: si arranca lento, consume demasiada RAM, o tiene bugs sutiles, la fricción diaria se acumula de forma catastrófica.

Este ticket entrega el **entorno local estándar** que todos los supervisores usarán. Además de levantar los servicios base (PostgreSQL, Redis, pgAdmin, RabbitMQ), debe reflejar las decisiones arquitectónicas ya tomadas (multi-tenancy por schema, exchanges de RabbitMQ con convenciones definidas) para que los agentes A1 y A2 puedan empezar a desarrollar en los sprints siguientes sin descubrir problemas de configuración.

Este es también el **primer ticket del proyecto que sigue el flujo completo de PR** (rama feature → CI → review → merge). T-001 creó la infraestructura; T-002 ejercita el flujo por primera vez.

---

## Alcance técnico

### Crear

```
erp-project/
├── docker-compose.yml                 ← servicios base
├── docker-compose.dev.yml             ← overrides para desarrollo local
├── docker-compose.test.yml            ← overrides para CI/integración
├── .env.example                       ← template de variables de entorno
├── .env                               ← (NO commitear, pero existe en .gitignore)
├── infra/
│   └── local/
│       ├── postgres/
│       │   ├── init/
│       │   │   ├── 01-extensions.sql
│       │   │   ├── 02-create-tenants.sql
│       │   │   └── 03-seed-demo-data.sql
│       │   └── postgresql.conf       ← config opcional para dev
│       ├── pgadmin/
│       │   ├── servers.json
│       │   └── pgpass
│       ├── rabbitmq/
│       │   ├── rabbitmq.conf
│       │   ├── definitions.json      ← exchanges, colas, vhosts pre-creados
│       │   └── enabled_plugins
│       └── redis/
│           └── redis.conf
├── scripts/
│   ├── dev-up.sh                     ← levanta entorno local
│   ├── dev-down.sh                   ← detiene entorno local
│   ├── dev-reset.sh                  ← detiene + borra volúmenes + relevanta
│   ├── dev-logs.sh                   ← tail de logs de todos los servicios
│   ├── dev-psql.sh                   ← abre shell psql con el tenant demo
│   └── dev-rabbitmq-shell.sh         ← abre rabbitmqctl shell
└── docs/
    └── runbooks/
        └── dev-environment.md        ← guía para supervisores
```

### Modificar

- `.gitignore` — agregar `.env`, `volumes/`, `*.local.env`.
- `README.md` — agregar sección "Desarrollo local" con referencia al runbook.
- `docs/runbooks/bootstrap-T001.md` — referenciar este runbook en la sección "siguiente paso".

### No tocar

- No crear Dockerfile del servicio `erp-api` — eso es T-004.
- No configurar Keycloak en este ticket — eso es T-010. El docker-compose deja un placeholder con comentario `# TODO T-010`.
- No crear migraciones Prisma — eso es T-004 (primer `prisma db pull` y `prisma migrate dev --name init`). Solo creamos la base (extensiones, tenants, seeds mínimos).

---

## Criterios de aceptación

### Servicios levantados

- [ ] **PostgreSQL 15** en puerto `5432` con extensiones `uuid-ossp`, `pg_trgm`, `btree_gin` instaladas.
- [ ] **Redis 7** en puerto `6379` sin password (solo dev local).
- [ ] **pgAdmin 4** en puerto `5050` con el servidor PostgreSQL pre-configurado.
- [ ] **RabbitMQ 3.12** con management UI en puerto `15672` y AMQP en `5672`.
- [ ] Todos los servicios con health checks reales (no solo `depends_on`).
- [ ] Todos los servicios reinician automáticamente (`restart: unless-stopped`) en dev.

### Multi-tenancy pre-configurada

- [ ] En el init SQL se crea el schema `public` con tabla `tenants`.
- [ ] Se crean **3 tenants de desarrollo**: `tenant_acme`, `tenant_beta`, `tenant_erp`.
- [ ] Cada schema de tenant se crea vacío — las migraciones de cada servicio lo poblarán.
- [ ] Se registran los 3 tenants en `public.tenants`.

Ver [ADR-003](../../docs/adrs/ADR-003-multi-tenancy-por-schema.md).

### RabbitMQ pre-configurado con convenciones del proyecto

- [ ] Se crea vhost `/erp`.
- [ ] Se crean los 4 exchanges topic: `bodega.events`, `ventas.events`, `produccion.events`, `auth.events`.
- [ ] Se crean las DLQs placeholder: `dlq.bodega`, `dlq.ventas`, `dlq.produccion`, `dlq.auth`.
- [ ] Se crean 2 usuarios: `dev-publisher` (permisos write) y `dev-consumer` (permisos read). Los passwords leen desde `.env`.
- [ ] Management UI accesible sin configurar manualmente.

Ver [ADR-006](../../docs/adrs/ADR-006-rabbitmq-para-mensajeria.md) y [events.md](../../docs/events.md).

### Seeds de desarrollo

- [ ] En `tenant_erp` se insertan 5 categorías de ejemplo, 20 insumos de ejemplo, 2 usuarios (1 admin, 1 bodeguero) — útil para probar UIs durante desarrollo.
- [ ] Los seeds son **idempotentes** (usan `ON CONFLICT DO NOTHING`).
- [ ] Los seeds solo corren en `tenant_erp`, nunca en `tenant_acme` o `tenant_beta`.

### Scripts auxiliares

- [ ] `./scripts/dev-up.sh` levanta todo con feedback claro de qué servicio está listo y cuál no.
- [ ] `./scripts/dev-down.sh` detiene todo sin borrar volúmenes.
- [ ] `./scripts/dev-reset.sh` confirma con el usuario antes de borrar, luego detiene + borra volúmenes + relevanta + aplica seeds.
- [ ] `./scripts/dev-logs.sh` con argumentos opcionales (ej: `./dev-logs.sh postgres`).
- [ ] `./scripts/dev-psql.sh` conecta al tenant demo por defecto; acepta argumento para otros tenants.
- [ ] `./scripts/dev-rabbitmq-shell.sh` abre `rabbitmqctl` o muestra URL del management UI.
- [ ] Todos los scripts tienen `set -e` y mensajes de error útiles.
- [ ] Todos los scripts son ejecutables (`chmod +x`).

### Variables de entorno

- [ ] `.env.example` tiene **todas** las variables necesarias con comentarios explicativos y valores defaults para desarrollo.
- [ ] `.env.example` **no** contiene passwords reales, solo placeholders.
- [ ] `.env` aparece en `.gitignore` (ya debe estar por T-001, verificar).
- [ ] Al arrancar los servicios, falla con mensaje claro si `.env` no existe (guiar al usuario a copiar de `.env.example`).

### Runbook

- [ ] `docs/runbooks/dev-environment.md` existe con:
  - Requisitos previos (Docker Desktop 4.x, 8GB RAM mínimo).
  - Primera vez (copiar .env, correr dev-up).
  - Operación diaria (levantar, detener, logs).
  - Troubleshooting común (puertos ocupados, volumen corrupto, etc.).
  - Accesos (URLs, usuarios pre-creados, credenciales default).

### Performance mínima

- [ ] Arranque completo (todos los health checks verdes) en **menos de 45 segundos** en una MacBook M2 o equivalente.
- [ ] Consumo de RAM total **menor a 2 GB** en reposo.

### Integración con CI

- [ ] `docker-compose.test.yml` override usa puertos random o aislados para no colisionar con servicios locales.
- [ ] GitHub Actions workflow de CI (creado en T-001) puede invocar `docker compose -f docker-compose.yml -f docker-compose.test.yml up -d` sin errores.
- [ ] Se agrega un test smoke en `.github/workflows/ci.yml` que verifica que el docker-compose arranca correctamente.

---

## Invariantes que el agente DEBE respetar

1. **Pinear versiones específicas de imágenes.** Nunca `postgres:latest`. Sí `postgres:15.5-alpine`. Evita sorpresas.
2. **Nunca commitear passwords reales.** Todo password viene de `.env`, nunca hardcodeado en YAML.
3. **Health checks reales, no placeholders.** PostgreSQL con `pg_isready`, RabbitMQ con `rabbitmq-diagnostics`, etc.
4. **Volúmenes nombrados, no bind mounts para datos.** Los datos persistentes viven en volúmenes Docker nombrados (`erp_postgres_data`), no en directorios locales que se confunden con el workspace.
5. **Una sola red `erp-network`.** Todos los servicios del docker-compose se comunican por esta red interna.
6. **DNS interno obligatorio.** Un servicio se refiere a otro por nombre de contenedor (`postgres`, `redis`), no por `localhost` ni por IP.
7. **Puertos hacia host documentados.** Cada puerto expuesto al host tiene un comentario explicando por qué (debug, acceso desde IDE, etc.).
8. **Seeds no tocan datos de producción.** Los seeds solo corren en `tenant_erp`, nunca en otros schemas.

---

## Casos de prueba obligatorios

### Caso 1 — Arranque desde cero

```bash
./scripts/dev-reset.sh  # destructive
./scripts/dev-up.sh
# esperado: todos los health checks verdes en < 45s
```

### Caso 2 — Conexión a PostgreSQL desde host

```bash
psql -h localhost -p 5432 -U erp_admin -d erp_db -c "\dt public.*"
# esperado: muestra tabla 'tenants'

psql -h localhost -p 5432 -U erp_admin -d erp_db -c "\dn"
# esperado: muestra schemas tenant_acme, tenant_beta, tenant_erp
```

### Caso 3 — Conexión a PostgreSQL desde un contenedor

```bash
docker compose exec postgres psql -U erp_admin -d erp_db \
  -c "SELECT COUNT(*) FROM tenant_erp.insumos;"
# esperado: 20 (seeds aplicados)
```

### Caso 4 — Publicar y consumir en RabbitMQ

```bash
# Publicar (desde host con rabbitmqadmin o similar)
docker compose exec rabbitmq rabbitmqadmin publish \
  -V /erp -u dev-publisher -p $RABBITMQ_PUBLISHER_PASSWORD \
  exchange=bodega.events routing_key=bodega.movimiento.registrado.v1 \
  payload='{"test":true}'

# Consumir
docker compose exec rabbitmq rabbitmqadmin get \
  -V /erp -u dev-consumer -p $RABBITMQ_CONSUMER_PASSWORD \
  queue=dlq.bodega ackmode=ack_requeue_false
```

### Caso 5 — Acceso a pgAdmin

```
Abrir http://localhost:5050
Login con credenciales de .env
Servidor "ERP Local" debe estar pre-configurado
Conexión al PostgreSQL funciona al primer clic
```

### Caso 6 — Reset completo

```bash
./scripts/dev-reset.sh  # pide confirmación
# Después: todos los datos se pierden, seeds se re-aplican, sistema vuelve a estado limpio
```

### Caso 7 — Detección de puertos ocupados

```bash
# Simular puerto ocupado
nc -l 5432 &
./scripts/dev-up.sh
# esperado: mensaje claro "puerto 5432 ya en uso, revise procesos o configure otro puerto"
```

### Caso 8 — Arranque sin .env

```bash
mv .env .env.bak
./scripts/dev-up.sh
# esperado: mensaje claro "archivo .env no existe. Copie .env.example a .env primero."
mv .env.bak .env
```

---

## Lo que NO se debe hacer en esta tarea

- **No configurar Keycloak.** Deja un placeholder comentado en docker-compose para T-010.
- **No crear Dockerfiles para los servicios de negocio** (bodega, producción, etc.). Este ticket solo levanta infraestructura base.
- **No crear migraciones.** Los agentes A1 y A2 las crearán en sus tickets. Aquí solo preparamos los schemas vacíos.
- **No configurar SSL/TLS.** Es dev local. TLS se configura en staging (ticket T-018).
- **No agregar Prometheus/Grafana al docker-compose local.** Van en Kubernetes para staging (ticket T-022). Local no los necesita.
- **No usar `docker-compose` v1 (con guión).** Solo `docker compose` v2 (sin guión). Dejar constancia en el runbook.

---

## Contratos y referencias

- **Contrato del agente:** [agents/A7-devops.md](../../agents/A7-devops.md)
- **Stack tecnológico:** [docs/stack.md](../../docs/stack.md)
- **ADRs relevantes:**
  - [ADR-003 Multi-tenancy](../../docs/adrs/ADR-003-multi-tenancy-por-schema.md)
  - [ADR-006 RabbitMQ](../../docs/adrs/ADR-006-rabbitmq-para-mensajeria.md)
- **Events catalog:** [docs/events.md](../../docs/events.md) (convenciones de exchanges)
- **Runbook previo:** [docs/runbooks/bootstrap-T001.md](../../docs/runbooks/bootstrap-T001.md)

---

## Entregables

- [ ] `docker-compose.yml` + overrides + configs en `infra/local/`
- [ ] `.env.example` con todas las variables documentadas
- [ ] 6 scripts de `scripts/dev-*.sh` ejecutables
- [ ] SQL de init con extensiones, tenants y seeds
- [ ] RabbitMQ `definitions.json` con exchanges y colas pre-creadas
- [ ] pgAdmin `servers.json` con servidor pre-configurado
- [ ] `docs/runbooks/dev-environment.md` completo
- [ ] Workflow de CI actualizado para ejecutar smoke test del compose
- [ ] Commit con formato: `infra(local): add docker-compose with postgres, redis, pgadmin, rabbitmq [A7]`
- [ ] PR con labels `agent:A7`, `supervisor:DO`, `sprint:semana-1`, `priority:critical`, `type:infra`

---

## Validación post-ejecución

**El supervisor DO ejecuta en orden:**

```bash
# 1. Pre-check automático
./scripts/pre-pr-check.sh

# 2. Validación de levantamiento
./scripts/dev-reset.sh
time ./scripts/dev-up.sh    # debe terminar en < 45s

# 3. Ejecutar los 8 casos de prueba listados arriba

# 4. Medir consumo
docker stats --no-stream

# 5. Smoke test desde un contenedor de prueba
docker run --rm --network erp-network postgres:15.5-alpine \
  psql -h postgres -U erp_admin -d erp_db -c "SELECT 1;"
```

Si todo pasa, el DO aprueba el PR y mergea a main.

---

## Validación post-ejecución (lo llena el supervisor humano)

- **Fecha de ejecución:** _pendiente_
- **Iteraciones necesarias:** _pendiente_
- **Tiempo real de levantamiento:** _pendiente (objetivo <45s)_
- **Consumo RAM en reposo:** _pendiente (objetivo <2GB)_
- **Casos de prueba 1–8:** _pendiente_
- **Resultado:** _pendiente_
- **Notas para el equipo:** _pendiente_

---

**Creado:** 2026-04-22 por DO
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
