# Runbook: Entorno de Desarrollo Local

> Guía para supervisores y agentes. Cubre la primera vez, operación diaria y troubleshooting.

---

## Requisitos previos

| Herramienta | Versión mínima | Verificar |
|---|---|---|
| Docker Desktop | 4.x | `docker --version` |
| Docker Compose | v2 (sin guión) | `docker compose version` |
| RAM disponible | 2 GB libres | Ver Docker Desktop → Resources |
| Puertos libres | 5432, 6379, 5050, 5672, 15672 | Ver sección Troubleshooting |

> **Importante:** Use `docker compose` (v2, sin guión), no `docker-compose` (v1).  
> Esta diferencia afecta algunas banderas y comportamientos.

---

## Primera vez

```bash
# 1. Clonar el repo (si aún no lo tiene)
git clone <repo-url>
cd erp-project

# 2. Copiar el template de variables de entorno
cp .env.example .env

# 3. (Opcional) Editar .env con sus preferencias
#    Los defaults de .env.example funcionan para desarrollo local sin cambios.

# 4. Levantar el entorno
./scripts/dev-up.sh
```

El script tarda **menos de 45 segundos** en una MacBook M2 o equivalente.
Al terminar verá las URLs y credenciales de acceso.

---

## Operación diaria

### Levantar el entorno

```bash
./scripts/dev-up.sh
```

### Ver logs en tiempo real

```bash
# Todos los servicios
./scripts/dev-logs.sh

# Solo un servicio (postgres | redis | pgadmin | rabbitmq)
./scripts/dev-logs.sh postgres
./scripts/dev-logs.sh rabbitmq
```

### Detener sin borrar datos

```bash
./scripts/dev-down.sh
```

### Reset completo (borra todos los datos)

```bash
./scripts/dev-reset.sh
# Pedirá confirmación: escriba 'RESET' para continuar
```

### Abrir shell psql

```bash
# Conectar al tenant demo (por defecto)
./scripts/dev-psql.sh

# Conectar a otro tenant
./scripts/dev-psql.sh acme
./scripts/dev-psql.sh beta
```

### Abrir shell RabbitMQ

```bash
./scripts/dev-rabbitmq-shell.sh
# Mostrará la URL del Management UI y abrirá un bash en el contenedor
```

---

## Accesos

| Servicio | URL / Host | Usuario | Password |
|---|---|---|---|
| PostgreSQL | `localhost:5432` | `erp_admin` | ver `.env` → `POSTGRES_PASSWORD` |
| Redis | `localhost:6379` | — | sin auth en dev |
| pgAdmin 4 | `http://localhost:5050` | ver `.env` → `PGADMIN_DEFAULT_EMAIL` | ver `.env` → `PGADMIN_DEFAULT_PASSWORD` |
| RabbitMQ UI | `http://localhost:15672` | ver `.env` → `RABBITMQ_DEFAULT_USER` | ver `.env` → `RABBITMQ_DEFAULT_PASS` |

### pgAdmin — primer uso

1. Abrir `http://localhost:5050`
2. Login con `PGADMIN_DEFAULT_EMAIL` y `PGADMIN_DEFAULT_PASSWORD` de `.env`
3. En el panel izquierdo: **Servers → ERP Local** (pre-configurado)
4. Click derecho → **Connect** → ingresar `POSTGRES_PASSWORD` de `.env`
5. Navegar a `Databases → erp_db → Schemas` para ver `tenant_demo`, `tenant_acme`, `tenant_beta`

### RabbitMQ — exchanges disponibles

Vhost `/erp`:

| Exchange | Tipo | Descripción |
|---|---|---|
| `bodega.events` | topic | Eventos de bodega (movimientos, stock crítico) |
| `ventas.events` | topic | Eventos de ventas (cotizaciones, órdenes) |
| `produccion.events` | topic | Eventos de producción (OPs, tarifas) |
| `auth.events` | topic | Eventos de autenticación |

DLQs: `dlq.bodega`, `dlq.ventas`, `dlq.produccion`, `dlq.auth`

### Por qué los passwords de RabbitMQ no están en `definitions.json`

`definitions.json` es un archivo commiteado en el repo. Si los passwords de `dev-publisher` y `dev-consumer` estuvieran ahí — aunque fuesen "solo dev" — el patrón permitiría por error passwords reales en staging o producción.

En su lugar, `dev-up.sh` los crea vía `rabbitmqctl` **después** de que el contenedor arranca, leyendo directamente de `.env`:

```bash
rabbitmqctl add_user "$RABBITMQ_PUBLISHER_USER" "$RABBITMQ_PUBLISHER_PASSWORD"
rabbitmqctl set_permissions -p /erp "$RABBITMQ_PUBLISHER_USER" "" ".*" ""
```

`definitions.json` solo define la topología (vhosts, exchanges, queues) — estructuras sin secretos. Este patrón aplica igual en staging y producción: la topología va en git, las credenciales van en el gestor de secretos (External Secrets / AWS Secrets Manager en T-018).

### Usuarios de desarrollo en `tenant_demo`

| Email | Password | Rol |
|---|---|---|
| `admin@arteo.dev` | `dev123` | admin |
| `bodeguero@arteo.dev` | `dev123` | operario |

> Estos usuarios son para desarrollo local únicamente. En staging/producción, la autenticación es vía Keycloak (T-010).

---

## Esquema de base de datos

La BD tiene 3 schemas de tenant + el schema `public`:

```
erp_db
├── public                  ← tabla tenants (lista de tenants)
├── tenant_demo             ← datos reales de Arteo (desde Excels) + 2 usuarios dev
├── tenant_acme             ← vacío (listo para migraciones de Prisma)
└── tenant_beta             ← vacío (listo para migraciones de Prisma)
```

Tabla `public.tenants`:
```sql
SELECT * FROM public.tenants;
-- id    | nombre                | active
-- acme  | ACME Industrial SA    | t
-- beta  | Beta Industrial SPA   | t
-- demo  | Taller Arteo — Demo   | t
```

`tenant_demo` tiene datos reales de Arteo: 14 categorías, 27 materiales, 50+ productos, recetas y precios de venta.

---

## Troubleshooting

### Puerto ya en uso

```
✗ Puerto 5432 ya en uso (esperado para PostgreSQL).
```

**Solución A — Identificar qué proceso lo ocupa:**
```bash
lsof -iTCP:5432 -sTCP:LISTEN
# En Windows: netstat -ano | findstr :5432
```

**Solución B — Cambiar el puerto en `.env`:**
```bash
# En .env:
POSTGRES_PORT=5434
```

---

### Volumen corrupto / BD en estado inconsistente

```bash
# Reset completo (pierde todos los datos)
./scripts/dev-reset.sh
```

---

### `docker compose` no encuentra `.env`

```
✗ Archivo .env no existe.
```

```bash
cp .env.example .env
# Editar si es necesario, luego:
./scripts/dev-up.sh
```

---

### RabbitMQ no arranca (Management plugin)

```bash
# Ver logs específicos
./scripts/dev-logs.sh rabbitmq

# Verificar enabled_plugins es válido (Erlang list con punto final):
cat infra/local/rabbitmq/enabled_plugins
# Debe mostrar: [rabbitmq_management,rabbitmq_prometheus].
```

---

### pgAdmin no muestra el servidor pre-configurado

El archivo `infra/local/pgadmin/servers.json` se monta en el contenedor.
Si ya existe un volumen `erp_pgadmin_data` de una versión anterior, los servers.json del volumen toman precedencia.

```bash
# Borrar solo el volumen de pgAdmin y reiniciar:
docker compose stop pgadmin
docker volume rm erp_pgadmin_data
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d pgadmin
```

---

### Los health checks tardan más de 45 segundos

En máquinas con menos de 8GB de RAM o con Docker Desktop configurado con poca memoria asignada:

1. Abrir Docker Desktop → Settings → Resources → Memory
2. Asignar al menos 4GB a Docker Desktop
3. Volver a ejecutar `./scripts/dev-reset.sh`

---

## Integración con la aplicación NestJS (T-004)

Cuando el monolito NestJS esté disponible, las variables de conexión son:

```env
DATABASE_URL=postgresql://erp_admin:${POSTGRES_PASSWORD}@localhost:5432/erp_db
REDIS_URL=redis://localhost:6379
RABBITMQ_URL=amqp://dev-publisher:${RABBITMQ_PUBLISHER_PASSWORD}@localhost:5672/erp
```

El middleware de multi-tenancy en NestJS establece `SET search_path = tenant_<id>` por conexión — nunca hardcodee el schema.

---

## Próximos pasos

- **T-004** — Crear el monolito NestJS base + primer `prisma db pull` y migración
- **T-010** — Configurar Keycloak en docker-compose (placeholder actual)
- **T-018** — Staging en Kubernetes

---

*Creado por A7 (DevOps & Infra) — T-002*  
*Última actualización: 2026-05*
