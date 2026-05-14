# T-010 · Keycloak en docker-compose: realm ERP, clientes OAuth2 y roles

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-010
**Agente asignado:** A7 (DevOps & Infra)
**Supervisor humano:** DO (DevOps / Plataforma) con consulta a S1 (NestJS auth) y S3 (frontends)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 3 puntos
**Prioridad:** alta
**Rama:** `feat/T-010-keycloak-docker-compose`

---

## Contexto de negocio

El ERP tiene 4 tipos de usuario (bodeguero, jefe de producción, vendedor, gerencia + admin) con permisos diferenciados, accediendo desde dos frontends (portal Next.js + backoffice Angular) hacia un solo backend NestJS. Necesitamos una solución de identidad y autorización que:

- Centralice los usuarios y roles en un solo lugar (ningún supervisor quiere mantener tablas de usuarios duplicadas).
- Permita SSO entre los dos frontends.
- Hable OAuth2 / OIDC estándar para que cualquier futuro consumidor (móvil, integración Oracle, BI) se conecte sin reinventar auth.
- Funcione localmente para los 7 supervisores sin depender de un servicio cloud (productividad diaria > comodidad).
- Sea fácil de migrar a staging y producción cuando llegue el momento (T-020 K8s, T-046 backups).

**Keycloak** es el estándar de la industria para esto. Se incluyó en `docker-compose.yml` (T-002) solo como **placeholder con `# TODO T-010`**. Este ticket lo deja funcional con un realm, dos clientes OAuth2, los roles del MVP y usuarios de desarrollo pre-creados.

A partir de este ticket:
- T-013 (auth NestJS) conecta el backend con Keycloak vía JWT.
- T-014 (RBAC en NestJS) usa los roles de Keycloak en los guards.
- T-015 (login Next.js) hace el flujo OAuth2 contra Keycloak.

Sin este ticket, esos tres quedan bloqueados.

---

## Alcance técnico

### Crear

```
docker-compose.yml                       ← modificar: descomentar/agregar servicio keycloak
infra/local/keycloak/
├── realm-export.json                    ← realm ERP completo exportado
├── README.md                            ← cómo gestionar Keycloak local
├── themes/                              ← (vacío por ahora, con .gitkeep)
└── providers/                           ← (vacío por ahora, con .gitkeep)

scripts/
├── dev-keycloak-import.sh               ← importa el realm desde realm-export.json
└── dev-keycloak-export.sh               ← exporta el realm actual a realm-export.json

docs/runbooks/
└── keycloak-local.md                    ← cómo administrar Keycloak en dev
```

### Modificar

- `docker-compose.yml` — agregar servicio `keycloak` con health check, depends_on, volúmenes.
- `.env.example` — agregar variables de Keycloak.
- `docs/runbooks/dev-environment.md` (creado en T-002) — agregar sección de Keycloak.
- `README.md` raíz — actualizar la lista de servicios locales con Keycloak.

### No tocar

- **Código de aplicación NestJS** (autenticación, guards, validación de JWT). Eso es T-013 y T-014, dominio de A1.
- **Código de frontends** (flujo OAuth2 desde Next.js o Angular). Eso es T-015, dominio de A3 (y/o A4).
- **Realm para staging/producción**. Esos vienen en T-020 y T-046. Este ticket es solo el realm de **desarrollo local**.

---

## Criterios de aceptación

### Servicio Keycloak en docker-compose

- [ ] Imagen pinneada: `quay.io/keycloak/keycloak:25.0.6` (o la LTS más reciente al momento de ejecutar — confirmar con DO).
- [ ] Modo **`start-dev`** (no `start`). En dev no usamos HTTPS ni configuración productiva.
- [ ] Puerto **`8080`** expuesto al host (admin console + endpoints OIDC).
- [ ] Almacenamiento: PostgreSQL del docker-compose existente (no SQLite ni H2 embebido). Esto facilita:
  - Backups consistentes (todo en un solo Postgres).
  - Aprender a usar la misma estrategia que en producción.
- [ ] Base de datos dedicada `keycloak_db` (separada del `erp_db` de los módulos de negocio).
- [ ] Usuario admin pre-creado: `admin` / password desde `.env` (variable `KEYCLOAK_ADMIN_PASSWORD`).
- [ ] **Health check** real: `curl -f http://localhost:8080/health/ready || exit 1`.
- [ ] **depends_on:** `postgres` (con `condition: service_healthy`).
- [ ] `restart: unless-stopped`.
- [ ] Variables de entorno:
  - `KC_DB=postgres`
  - `KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak_db`
  - `KC_DB_USERNAME` y `KC_DB_PASSWORD` desde `.env`
  - `KC_HOSTNAME=localhost`
  - `KC_HOSTNAME_STRICT=false` (dev local)
  - `KC_HTTP_ENABLED=true`
  - `KEYCLOAK_ADMIN` y `KEYCLOAK_ADMIN_PASSWORD` desde `.env`

### Init SQL para crear `keycloak_db`

- [ ] Agregar a `infra/local/postgres/init/02-create-tenants.sql` (o crear `04-create-keycloak-db.sql`) un `CREATE DATABASE keycloak_db;` y `GRANT` al usuario `erp_admin`.
- [ ] El script es idempotente (`IF NOT EXISTS`).

### Realm ERP

- [ ] Realm: `erp`.
- [ ] Configuración del realm:
  - Display name: "ERP — Desarrollo local".
  - Login con email habilitado.
  - Reset password habilitado (en dev solo, en producción puede diferir).
  - Brute force protection: deshabilitado en dev (acelera testing). Documentar en runbook que en staging/producción se activa.
  - Session timeout: 8 horas (dev).
  - Access token lifespan: 15 minutos.
  - Refresh token lifespan: 8 horas.

### Clientes OAuth2

Dos clientes pre-creados:

#### Cliente 1: `erp-backend`

- [ ] Tipo: **confidential** (server-to-server, valida tokens).
- [ ] Access Type: `bearer-only` (no inicia flow de login, solo valida tokens emitidos por otros clientes).
- [ ] Service Accounts: habilitado (para ETL y jobs internos que necesiten token sin user).
- [ ] Client roles: vacío inicialmente.
- [ ] Web origins: `*` (solo dev).

#### Cliente 2: `erp-frontend`

- [ ] Tipo: **public** (los frontends no guardan secret, usan PKCE).
- [ ] Standard Flow: habilitado (Authorization Code + PKCE).
- [ ] Direct Access Grants: deshabilitado (no queremos password grant).
- [ ] Implicit Flow: deshabilitado.
- [ ] Valid Redirect URIs:
  - `http://localhost:3001/api/auth/callback/keycloak` (Next.js portal)
  - `http://localhost:4200/auth/callback` (Angular backoffice)
- [ ] Valid Post Logout Redirect URIs:
  - `http://localhost:3001/*`
  - `http://localhost:4200/*`
- [ ] Web origins:
  - `http://localhost:3001`
  - `http://localhost:4200`
- [ ] PKCE Code Challenge Method: S256 (obligatorio).

### Roles del realm

5 roles del MVP (matrix completa de permisos viene en T-014 y T-047):

- [ ] `admin` — administrador del sistema, todos los permisos.
- [ ] `bodeguero` — operaciones de bodega (movimientos, consultas de stock).
- [ ] `jefe-produccion` — recetas, OPs, validación de costos.
- [ ] `vendedor` — cotizaciones, OVs, clientes.
- [ ] `gerencia` — solo lectura de dashboards y reportes.

Cada rol con descripción clara en el realm.

### Usuarios de desarrollo pre-creados

5 usuarios, uno por rol, con password fácil de recordar **solo en dev**:

| Usuario | Email | Password (.env) | Rol |
|---|---|---|---|
| `dev-admin` | admin@erp.local | desde `KC_DEV_PASSWORD` | admin |
| `dev-bodega` | bodega@erp.local | desde `KC_DEV_PASSWORD` | bodeguero |
| `dev-produccion` | produccion@erp.local | desde `KC_DEV_PASSWORD` | jefe-produccion |
| `dev-ventas` | ventas@erp.local | desde `KC_DEV_PASSWORD` | vendedor |
| `dev-gerencia` | gerencia@erp.local | desde `KC_DEV_PASSWORD` | gerencia |

- [ ] Los 5 usuarios tienen `emailVerified: true` (en dev no validamos email real).
- [ ] El password es el mismo para los 5 (es dev), leído de `.env`.
- [ ] El password de dev se documenta en el runbook con advertencia clara de no usarlo nunca fuera de local.

### Realm export

- [ ] Después de configurar manualmente todo lo anterior (vía admin console o `kcadm.sh`), exportar el realm completo a `infra/local/keycloak/realm-export.json`.
- [ ] El archivo exportado se commitea al repo (sin passwords reales — Keycloak permite exportar usuarios sin credentials).
- [ ] El archivo es **idempotente**: si se importa dos veces, no genera errores ni duplicados.
- [ ] El archivo está formateado (JSON indentado con 2 espacios) para que los diffs en PR sean legibles.

### Scripts auxiliares

- [ ] `scripts/dev-keycloak-import.sh`:
  - Espera que Keycloak esté `ready`.
  - Importa el realm desde `realm-export.json` usando `kcadm.sh`.
  - Crea los 5 usuarios de desarrollo si no existen (idempotente).
  - Setea passwords desde `KC_DEV_PASSWORD`.
  - Exit code 0 si todo bien, no-cero si algo falla.
- [ ] `scripts/dev-keycloak-export.sh`:
  - Exporta el realm `erp` actual.
  - Sobrescribe `realm-export.json`.
  - Útil cuando un dev hace cambios en el realm vía consola y los quiere persistir.
- [ ] Ambos scripts tienen `set -e`, mensajes claros, y son ejecutables.

### Integración con `dev-up.sh`

- [ ] Modificar `scripts/dev-up.sh` (de T-002) para que:
  - Después de levantar Keycloak y verificar que está ready, llame a `dev-keycloak-import.sh` automáticamente.
  - Si la importación falla, advierte pero no detiene el resto del entorno (algunos devs pueden no necesitar auth para sus tickets).
- [ ] Documentar el flag opcional `--skip-keycloak` por si alguien quiere omitir.

### Variables de entorno

Agregar a `.env.example`:

```bash
# Keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=change-me-local-only

KC_DB_USERNAME=erp_admin
KC_DB_PASSWORD=change-me-local-only

# Password unificado para usuarios dev-* del realm erp
# NUNCA usar este valor fuera de desarrollo local
KC_DEV_PASSWORD=dev1234
```

- [ ] El `.env.example` documenta cada variable con comentarios.
- [ ] Validar que el archivo `.env` real esté en `.gitignore`.

### Runbook `docs/runbooks/keycloak-local.md`

- [ ] **Cómo arrancar Keycloak**: `./scripts/dev-up.sh` (ya lo levanta) o `docker compose up keycloak`.
- [ ] **Cómo acceder a admin console**: http://localhost:8080 → realm "erp".
- [ ] **Credenciales admin**: las definidas en `.env`.
- [ ] **Credenciales de los 5 usuarios dev**: tabla con usuario/password.
- [ ] **Cómo obtener un access token manualmente** (curl con `password` grant en cliente `erp-frontend` — solo para debugging):
  ```bash
  curl -X POST http://localhost:8080/realms/erp/protocol/openid-connect/token \
    -d "client_id=erp-frontend" \
    -d "username=dev-admin" \
    -d "password=$KC_DEV_PASSWORD" \
    -d "grant_type=password"
  ```
  (Solo para curiosidad/debugging. Los frontends usan PKCE flow estándar.)
- [ ] **Cómo agregar un nuevo rol o usuario**: vía admin console + exportar con `dev-keycloak-export.sh`.
- [ ] **Cómo resetear Keycloak**: `./scripts/dev-reset.sh` resetea todo (T-002).
- [ ] **Troubleshooting común**:
  - Keycloak no arranca → revisar logs de Postgres (puede ser que `keycloak_db` no se haya creado).
  - El JWT no valida en el backend → verificar `KC_HOSTNAME` y el `iss` del token.
  - El redirect en el frontend falla → verificar `Valid Redirect URIs` del cliente.
- [ ] **Diferencias dev vs staging/producción**:
  - En dev: `start-dev`, sin TLS, sin brute force, password fáciles.
  - En staging/producción: `start`, TLS obligatorio, brute force activo, passwords largos.
  - Apuntar a T-020 (K8s staging) y T-046 (producción).

### Performance

- [ ] Keycloak arranca con health check verde en **< 60 segundos** desde `docker compose up`.
- [ ] Consumo de RAM de Keycloak en reposo: **< 600 MB** (ajustar `-Xmx` si es necesario con `JAVA_OPTS`).
- [ ] El arranque de Keycloak no impacta el tiempo total objetivo de `dev-up.sh` (< 90 segundos con todo).

### Tests smoke

- [ ] Endpoint OIDC discovery responde:
  ```bash
  curl http://localhost:8080/realms/erp/.well-known/openid-configuration
  # Debe retornar JSON con issuer, authorization_endpoint, token_endpoint, etc.
  ```
- [ ] Obtener token con usuario dev:
  ```bash
  ./scripts/dev-keycloak-import.sh
  curl -X POST http://localhost:8080/realms/erp/protocol/openid-connect/token \
    -d "client_id=erp-frontend" \
    -d "username=dev-admin" \
    -d "password=$KC_DEV_PASSWORD" \
    -d "grant_type=password" \
    | jq .access_token
  # Debe retornar un JWT válido
  ```
- [ ] Verificar que el JWT contiene el rol esperado:
  ```bash
  # Decodificar con jwt-cli o jq
  echo "$TOKEN" | jwt decode
  # Debe contener: realm_access.roles: ["admin"]
  ```

---

## Invariantes que el agente DEBE respetar

1. **Pinear la versión de Keycloak**. Nunca `latest`. La versión se acuerda con DO al inicio.
2. **Passwords nunca hardcodeados** en YAML, scripts o realm-export.json. Solo en `.env`.
3. **Realm-export.json NO contiene credenciales reales.** Los usuarios se importan sin password (vacío) y el script `dev-keycloak-import.sh` los setea después leyendo de `.env`.
4. **El realm de dev no se usa nunca como base para staging/producción.** Tiene configuración relajada (brute force off, password corta, sin TLS) — peligrosa fuera de local.
5. **Cliente `erp-frontend` es público con PKCE obligatorio.** No autorizar `Direct Access Grants` para producción (en dev sirve para testing manual, pero documentar la diferencia).
6. **El backend `erp-backend` es bearer-only.** No genera tokens, solo los valida. NestJS recibe el JWT del header `Authorization: Bearer ...` y lo valida contra el JWKS de Keycloak.
7. **Los 5 roles del MVP son los nombres canónicos** (ver glosario T-009 cuando esté firmado). Si A7 propone otro naming, escala a S1 + PO antes.

---

## Casos de prueba obligatorios

### Caso 1 — Arranque limpio

```bash
./scripts/dev-reset.sh
./scripts/dev-up.sh
# Esperado: Keycloak ready en <60s, realm "erp" importado, 5 usuarios creados.

curl -s http://localhost:8080/realms/erp/.well-known/openid-configuration | jq .issuer
# Esperado: "http://localhost:8080/realms/erp"
```

### Caso 2 — Obtener token con cada uno de los 5 usuarios

```bash
for user in dev-admin dev-bodega dev-produccion dev-ventas dev-gerencia; do
  token=$(curl -s -X POST http://localhost:8080/realms/erp/protocol/openid-connect/token \
    -d "client_id=erp-frontend" \
    -d "username=$user" \
    -d "password=$KC_DEV_PASSWORD" \
    -d "grant_type=password" | jq -r .access_token)
  echo "$user → token len: ${#token}"
done
# Esperado: 5 tokens, todos con longitud > 800 chars.
```

### Caso 3 — Verificar que los roles están en el token

```bash
token=$(curl -s -X POST http://localhost:8080/realms/erp/protocol/openid-connect/token \
  -d "client_id=erp-frontend" -d "username=dev-bodega" \
  -d "password=$KC_DEV_PASSWORD" -d "grant_type=password" | jq -r .access_token)

echo "$token" | jwt decode --json | jq .realm_access.roles
# Esperado: ["bodeguero"] (y los roles por defecto del realm como "default-roles-erp")
```

### Caso 4 — Re-importar es idempotente

```bash
./scripts/dev-keycloak-import.sh
./scripts/dev-keycloak-import.sh
# Esperado: ambas ejecuciones exit 0, sin errores de "ya existe".
```

### Caso 5 — Reset destruye y recrea limpio

```bash
./scripts/dev-reset.sh
# Confirma destrucción
./scripts/dev-up.sh
# Esperado: el realm "erp" sigue existiendo después del reset (porque se importa al arrancar).
curl -s http://localhost:8080/realms/erp/.well-known/openid-configuration | jq .issuer
# Esperado: "http://localhost:8080/realms/erp"
```

### Caso 6 — Cambios manuales en consola se persisten al exportar

```bash
# 1. Abrir admin console, crear un rol nuevo "test-role".
# 2. Exportar:
./scripts/dev-keycloak-export.sh
# 3. Verificar:
grep "test-role" infra/local/keycloak/realm-export.json
# Esperado: encuentra al menos una ocurrencia.

# 4. Limpieza:
# Eliminar el rol manualmente y re-exportar.
```

### Caso 7 — Falta de variables de entorno

```bash
unset KC_DEV_PASSWORD
./scripts/dev-keycloak-import.sh
# Esperado: error claro indicando qué variable falta.
```

### Caso 8 — Health check responde correctamente

```bash
docker compose exec keycloak curl -f http://localhost:8080/health/ready
# Esperado: 200 OK con body `{"status":"UP"}` o similar.
```

### Caso 9 — JWT del backend (erp-backend) vía client credentials

```bash
# Para futuros service accounts (T-021 ETL, T-049 Oracle adapter)
token=$(curl -s -X POST http://localhost:8080/realms/erp/protocol/openid-connect/token \
  -d "client_id=erp-backend" \
  -d "client_secret=<SECRET_DESDE_REALM>" \
  -d "grant_type=client_credentials" | jq -r .access_token)
echo "$token" | jwt decode --json | jq .aud
# Esperado: incluye "erp-backend"
```

> El secret de `erp-backend` se genera al crear el cliente. **No se commitea**. Se guarda en `.env` (variable `KEYCLOAK_BACKEND_CLIENT_SECRET`) y se documenta en el runbook.

---

## Lo que NO se debe hacer en esta tarea

- **No configurar el realm de staging/producción.** Esos van en T-020 y T-046, con TLS, secretos en AWS Secrets Manager o equivalente, configuración hardened.
- **No tocar código de aplicación.** Si los frontends o el backend necesitan ajustes para hablar con este Keycloak, eso es T-013, T-014, T-015. Este ticket solo provee Keycloak listo.
- **No habilitar features que el MVP no usa**: User Federation (LDAP/AD), Social Identity Providers (Google, GitHub), Account Console personalizado, themes custom. Esos se evalúan después.
- **No usar JBoss/WildFly viejo.** Keycloak 25+ usa Quarkus por defecto. Si surge documentación que sugiere comandos viejos, ignorar.
- **No commitear passwords reales en realm-export.json.** Si por error queda alguno, el PR no se mergea.
- **No abrir Keycloak al puerto 80 ni 443.** Sólo 8080 internamente, expuesto al host.
- **No agregar dependencias nuevas al docker-compose** (Mailhog, Loki, etc.). Si Keycloak necesita SMTP en dev (no en este MVP), se evalúa después.

---

## Contratos y referencias

- **Contrato del agente:** [`agents/A7-devops.md`](../../agents/A7-devops.md)
- **Stack tecnológico:** [`docs/stack.md`](../../docs/stack.md) — Keycloak está listado.
- **Matriz RBAC (a completarse en T-047):** [`docs/rbac-matrix.md`](../../docs/rbac-matrix.md)
- **Docker compose de T-002:** [`docker-compose.yml`](../../docker-compose.yml) — base que se modifica.
- **Runbook dev-environment de T-002:** [`docs/runbooks/dev-environment.md`](../../docs/runbooks/dev-environment.md) — agregar referencia al nuevo runbook.
- **Documentación Keycloak:**
  - https://www.keycloak.org/getting-started/getting-started-docker
  - https://www.keycloak.org/server/containers
  - https://www.keycloak.org/server/importExport

---

## Entregables

- [ ] `docker-compose.yml` con servicio Keycloak funcional.
- [ ] `infra/local/keycloak/realm-export.json` con realm completo.
- [ ] `infra/local/keycloak/README.md`.
- [ ] `scripts/dev-keycloak-import.sh` y `scripts/dev-keycloak-export.sh` ejecutables.
- [ ] `scripts/dev-up.sh` modificado para llamar al import.
- [ ] `.env.example` con variables Keycloak documentadas.
- [ ] Script SQL para crear `keycloak_db` (idempotente).
- [ ] `docs/runbooks/keycloak-local.md` completo.
- [ ] `docs/runbooks/dev-environment.md` actualizado.
- [ ] `README.md` raíz actualizado con servicios.
- [ ] Commit: `infra(local): add keycloak with realm erp, oauth clients and dev users [A7]`
- [ ] PR con labels: `agent:A7`, `supervisor:DO`, `sprint:semana-1`, `priority:high`, `type:infra`

---

## Cómo invocar al agente en Claude Code

```bash
cd erp-project
git checkout -b feat/T-010-keycloak-docker-compose
claude
```

Prompt:

```
Ejecuta T-010 (Keycloak en docker-compose).

Actúas como agente A7. Lee en orden:
1. @CLAUDE.md
2. @agents/A7-devops.md
3. @prompts/backlog/T-010-keycloak-docker-compose.md (este ticket)
4. @docker-compose.yml (estado actual, T-002)
5. @scripts/dev-up.sh (lo extiendes)
6. @docs/runbooks/dev-environment.md (lo extiendes)
7. @docs/stack.md (Keycloak listado)

Antes de empezar, pregúntame:
1. ¿Cuál es la versión LTS más reciente de Keycloak que está estable? (yo asumo 25.0.6,
   pero confirma)
2. ¿Confirmas que los 5 roles del MVP son: admin, bodeguero, jefe-produccion,
   vendedor, gerencia? (yo creo que sí, pero quiero alinearme antes de hardcodearlos)
3. ¿Algún cliente OAuth2 adicional que ya sepas que vamos a necesitar?
   (yo solo creo erp-backend y erp-frontend; otros se agregan en sus tickets)

⚠️ No toques código de aplicación (NestJS, frontends). Solo infra y configuración
de Keycloak. Si dudas si algo es scope de este ticket, pregunta.
```

---

## Validación post-ejecución (lo llena DO)

```bash
# 1. Pre-check automático
./scripts/pre-pr-check.sh

# 2. Arranque desde cero
./scripts/dev-reset.sh
time ./scripts/dev-up.sh
# Esperado: completa en < 90s con Keycloak incluido

# 3. Keycloak ready
curl -f http://localhost:8080/health/ready
# Esperado: 200 OK

# 4. Realm existe
curl -s http://localhost:8080/realms/erp/.well-known/openid-configuration | jq .issuer
# Esperado: http://localhost:8080/realms/erp

# 5. Los 5 usuarios pueden obtener token
for user in dev-admin dev-bodega dev-produccion dev-ventas dev-gerencia; do
  status=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    http://localhost:8080/realms/erp/protocol/openid-connect/token \
    -d "client_id=erp-frontend" -d "username=$user" \
    -d "password=$KC_DEV_PASSWORD" -d "grant_type=password")
  echo "$user → HTTP $status (esperado 200)"
done

# 6. Cada usuario tiene su rol correcto
# (validación manual con admin console o con jwt decode)

# 7. Re-import es idempotente
./scripts/dev-keycloak-import.sh
./scripts/dev-keycloak-import.sh
echo "Exit code: $?"  # esperado: 0

# 8. Reset funciona
./scripts/dev-reset.sh
./scripts/dev-up.sh
# Verificar de nuevo que realm "erp" existe (debe re-importarse automáticamente)

# 9. Consumo de RAM
docker stats --no-stream | grep keycloak
# Anotar consumo (objetivo: < 600 MB en reposo)
```

- **Fecha:** _pendiente_
- **Tiempo de arranque (con Keycloak):** _pendiente_
- **RAM consumida por Keycloak en reposo:** _pendiente_
- **Casos 1-9 todos pasan:** _pendiente_
- **Realm export es idempotente:** _pendiente_
- **Resultado:** _pendiente_
- **Notas para T-013, T-014, T-015 (los que dependen de este ticket):** _pendiente_

---

## Notas para DO

**Antes de aprobar el merge:**

- Verifica visualmente con admin console que los 5 usuarios y 5 roles existen, y que cada usuario tiene su rol asignado (no más, no menos).
- Decodifica un JWT y revisa qué claims trae. El backend (T-013) va a leer esos claims; si traen información sensible que no debería viajar al frontend, alertar a S1.
- El password de los usuarios dev se documenta en el runbook con advertencia clara — esa advertencia es importante para que ningún supervisor copie esto a staging por descuido.

**Coordinación con otros supervisores:**

- **S1 (NestJS auth, T-013):** después de mergear este ticket, avisarle a S1 que ya puede arrancar T-013. Pasar URL del JWKS endpoint (`http://localhost:8080/realms/erp/protocol/openid-connect/certs`).
- **S3 (frontends, T-015):** avisar que el cliente `erp-frontend` está listo con sus redirect URIs.

**Prerrequisitos:**

- T-001 (estructura repo) ✅
- T-002 (docker-compose con PostgreSQL) ✅ — `keycloak_db` se crea en este Postgres.
- T-003 (CI/CD) ✅ — opcional, el ticket no requiere CI corriendo, pero es deseable que el smoke test del compose en CI valide Keycloak también.

**Sucesores que dependen de este ticket:**

- T-013 (auth NestJS con JWT) — necesita el JWKS endpoint y el realm.
- T-014 (RBAC en NestJS) — necesita los roles del realm.
- T-015 (login Next.js con OAuth2) — necesita el cliente `erp-frontend` con redirects.
- T-020 (staging en K8s) — replicará este Keycloak en staging con configuración endurecida.

---

**Creado:** 2026-04-28 por DO + S1 (consulta)
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
