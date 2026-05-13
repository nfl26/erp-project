# erp-api — NestJS 10 + Fastify + Prisma

Monolito modular que contiene todos los módulos del ERP: auth, bodega, ventas, producción, notificaciones.

---

## Prerequisitos

| Herramienta | Versión mínima | Instalación |
|---|---|---|
| Node.js | 20 LTS | `winget install OpenJS.NodeJS.LTS` |
| npm | 10.x (viene con Node 20) | — |
| Docker Desktop | cualquiera reciente | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |

Verificar antes de continuar:

```powershell
node --version   # v20.x.x
npm --version    # 10.x.x
docker --version # Docker version 2x.x
```

---

## Primera ejecución (T-004)

### 1. Instalar dependencias

```powershell
cd services/erp-api
npm install
```

### 2. Configurar variables de entorno

```powershell
Copy-Item .env.example .env
```

Abrir `services/erp-api/.env` y construir `DATABASE_URL` con los valores del `.env` raíz del repo
(el mismo archivo que usa `docker-compose.yml`):

```bash
# .env raíz tiene estas variables sueltas:
#   POSTGRES_USER=erp_admin
#   POSTGRES_PASSWORD=changeme123   ← la que hayas puesto tú
#   POSTGRES_DB=erp_db
#   POSTGRES_PORT=5432
#
# Con esos valores, en services/erp-api/.env escribe:
DATABASE_URL=postgresql://erp_admin:changeme123@localhost:5432/erp_db
#                         ^user      ^password   ^host      ^port ^db
```

El resto de variables (`REDIS_URL`, `NODE_ENV`, etc.) pueden dejarse con los valores del ejemplo.

### 3. Levantar la infraestructura local

Desde la raíz del repo:

```powershell
docker compose up -d postgres redis
docker compose ps   # PostgreSQL y Redis deben aparecer como "healthy"
```

### 4. Conectar Prisma con la BD Arteo existente

```powershell
# Genera schema.prisma desde la BD real (reemplaza el placeholder)
npx prisma db pull

# Crea la migración baseline (registra el estado actual de la BD)
npx prisma migrate dev --name init

# Genera el cliente TypeScript
npx prisma generate
```

> **Importante:** `prisma db pull` necesita que PostgreSQL esté corriendo y que
> `DATABASE_URL` en `.env` apunte correctamente al contenedor.

### 5. Arrancar en modo desarrollo

```powershell
npm run start:dev
```

La API queda disponible en:

- **API:** `http://localhost:3000/api/v1`
- **Health check:** `http://localhost:3000/health`
- **Swagger:** `http://localhost:3000/api/docs`

### 6. Verificar que todo funciona

```powershell
# Health check — debe retornar status: ok
Invoke-RestMethod http://localhost:3000/health
```

Respuesta esperada:

```json
{
  "status": "ok",
  "timestamp": "2026-...",
  "services": {
    "database": "ok",
    "redis": "ok"
  }
}
```

---

## Scripts disponibles

| Comando | Qué hace |
|---|---|
| `npm run start:dev` | Arranca en modo watch (recarga en cambios) |
| `npm run build` | Compila a `dist/` (producción) |
| `npm run lint` | ESLint con autofix |
| `npm run typecheck` | TypeScript sin emitir archivos |
| `npm test` | Jest — tests unitarios |
| `npm run test:integration` | Jest — tests de integración (requiere BD real) |
| `npm run test:e2e` | Jest — smoke tests E2E con mocks |

---

## Estructura del servicio

```
src/
├── main.ts                    ← bootstrap: Fastify, pipes, filtros, Swagger
├── app.module.ts              ← raíz: ConfigModule, EventEmitter2, módulos
├── health/                    ← GET /health (público, sin autenticación)
└── shared/
    ├── prisma/                ← PrismaModule global + PrismaService
    ├── filters/               ← HttpExceptionFilter (formato RFC 7807)
    ├── interceptors/          ← LoggingInterceptor (Pino structured logs)
    └── guards/                ← JwtAuthGuard (placeholder hasta T-010 Keycloak)
prisma/
├── schema.prisma              ← fuente de verdad del schema (generado con db pull)
└── migrations/                ← historial inmutable de migraciones
```

---

## Notas de diseño

- **Fastify, no Express.** 2-3x más rápido en benchmarks. Ver `docs/stack.md`.
- **Decimal.js para todo lo monetario.** Nunca `number` o `float`. Instalado desde T-004.
- **EventEmitter2 con `wildcard: true`.** Permite escuchar `bodega.*` o `ventas.*`.
- **JWT Guard es un placeholder.** En desarrollo deja pasar todo (con warning en log). Keycloak llega en T-010.
- **Errores en formato RFC 7807.** Ver `src/shared/filters/http-exception.filter.ts`.

---

## Flujo de Prisma (resumen)

Ver detalle completo en `docs/prisma-workflow.md`.

```bash
# Cambio nace en el código:
# 1. Editar schema.prisma
npx prisma migrate dev --name descripcion_del_cambio
npx prisma generate

# Cambio llegó desde la BD:
npx prisma db pull
npx prisma migrate dev --name sync_cambio_externo
```

**Regla:** nunca `prisma db push` en staging o producción. Solo `prisma migrate deploy`.
