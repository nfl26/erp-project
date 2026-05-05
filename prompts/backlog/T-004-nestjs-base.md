# T-004 · Proyecto NestJS base + Prisma init

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-004
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 5 puntos
**Prioridad:** crítica
**Rama:** `feat/T-004-nestjs-base`

---

## Contexto de negocio

Este ticket crea el esqueleto del monolito NestJS que contendrá todos los módulos del ERP durante los próximos 6 meses. Las decisiones que se toman aquí (estructura de carpetas, configuración de Prisma, ValidationPipe global, formato de errores) son difíciles de cambiar después y afectan a todos los módulos que vendrán.

Además, es el primer ticket donde **se conecta Prisma con la BD Arteo existente** mediante `prisma db pull`. El schema que genere Prisma es la base de todos los módulos posteriores.

---

## Alcance técnico

### Crear

```
services/erp-api/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   └── shared/
│       ├── prisma/
│       │   ├── prisma.module.ts
│       │   └── prisma.service.ts
│       ├── filters/
│       │   └── http-exception.filter.ts   ← formato RFC 7807
│       ├── interceptors/
│       │   └── logging.interceptor.ts     ← Pino structured logs
│       └── guards/
│           └── jwt-auth.guard.ts          ← placeholder hasta T-010 (Keycloak)
├── prisma/
│   ├── schema.prisma                      ← generado con prisma db pull
│   └── migrations/
│       └── 0_init/
│           └── migration.sql              ← generado con prisma migrate dev --name init
├── test/
│   └── app.e2e-spec.ts                    ← smoke test básico
├── package.json
├── package-lock.json
├── tsconfig.json
├── tsconfig.build.json
├── nest-cli.json
├── .eslintrc.js
├── .prettierrc
├── jest.config.ts
└── .env.example
```

### No tocar

- Módulos de negocio (bodega, ventas, producción, etc.) — vienen en tickets siguientes.
- Keycloak — viene en T-010.
- docker-compose — viene en T-002 (ya debería estar hecho).

---

## Criterios de aceptación

### Setup del proyecto

- [ ] NestJS 10.x instalado con `@nestjs/cli`.
- [ ] TypeScript 5.x configurado con strict mode activado.
- [ ] ESLint + Prettier configurados con reglas del proyecto.
- [ ] Scripts definidos en `package.json`:
  - `npm run start:dev` — arranca en modo watch
  - `npm run build` — compila a `dist/`
  - `npm run lint` — ESLint
  - `npm run typecheck` — `tsc --noEmit`
  - `npm run test` — Jest unit tests
  - `npm run test:integration` — Jest integration tests
  - `npm run test:e2e` — Playwright o Jest E2E

### Dependencias principales

- [ ] `@nestjs/core`, `@nestjs/common`, `@nestjs/platform-fastify` (Fastify, no Express).
- [ ] `@prisma/client` y `prisma` (devDependency).
- [ ] `decimal.js` — para cálculos monetarios.
- [ ] `@nestjs/event-emitter` y `eventemitter2` — para comunicación entre módulos.
- [ ] `pino` y `pino-pretty` — logging estructurado.
- [ ] `zod` — validación de schemas en runtime.
- [ ] `class-validator` y `class-transformer` — validación de DTOs.
- [ ] `@nestjs/swagger` — documentación OpenAPI.

> **Por qué Fastify y no Express:** Fastify es 2-3x más rápido en benchmarks. NestJS lo soporta nativamente. Para un ERP con múltiples endpoints concurrentes, la diferencia es significativa.

### Configuración global en `main.ts`

- [ ] **ValidationPipe global** con `whitelist: true` y `forbidNonWhitelisted: true`.
- [ ] **HttpExceptionFilter global** que formatea errores en RFC 7807.
- [ ] **Swagger** habilitado en `/api/docs` (solo en development).
- [ ] **CORS** configurado desde variable de entorno `CORS_ORIGINS`.
- [ ] **Prefix global** `/api/v1` para todos los endpoints.
- [ ] **Shutdown hooks** habilitados para Prisma.

```typescript
// main.ts esperado
async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({ logger: false }),
  );

  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  }));

  app.useGlobalFilters(new HttpExceptionFilter());
  app.setGlobalPrefix('api/v1');

  if (process.env.NODE_ENV !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('ERP API')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup('api/docs', app, SwaggerModule.createDocument(app, config));
  }

  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
```

### PrismaService

- [ ] `PrismaService` extiende `PrismaClient`.
- [ ] Conecta en `onModuleInit()`.
- [ ] Desconecta gracefully en `onModuleDestroy()`.
- [ ] Exportado desde `PrismaModule` como global (`@Global()`).
- [ ] `PrismaModule` importado una sola vez en `AppModule`.

```typescript
// prisma.service.ts esperado
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
```

### Formato de errores RFC 7807

Todos los errores deben retornar este formato:

```json
{
  "type": "https://erp.arteo.cl/errors/validation-error",
  "title": "Validation Error",
  "status": 422,
  "detail": "El campo 'nombre' es requerido",
  "instance": "/api/v1/bodega/insumos",
  "timestamp": "2026-04-27T10:30:00Z",
  "traceId": "abc123"
}
```

### EventEmitter2 configurado

- [ ] `EventEmitterModule.forRoot()` importado en `AppModule`.
- [ ] Configurado con `wildcard: true` para permitir `bodega.*`.
- [ ] `maxListeners` en 20 (suficiente para todos los módulos).

### Prisma: setup desde BD existente

**Este es el paso más importante del ticket.** El agente A1 ejecuta:

```bash
# 1. Asegurarse que el docker-compose está corriendo (de T-002)
docker compose up -d postgres

# 2. Configurar DATABASE_URL
# (DO provee la URL de la BD Arteo antes de ejecutar este ticket)

# 3. Pull del schema existente
npx prisma db pull

# 4. Revisar el schema generado
# Prisma puede no detectar bien:
# - Enums con nombres no estándar
# - Relaciones implícitas (foreign keys sin nombre)
# - Columnas JSONB (las mapea como Json, que es correcto)
# Ajustar manualmente donde sea necesario

# 5. Baseline de migraciones
npx prisma migrate dev --name init

# 6. Generar cliente
npx prisma generate
```

- [ ] `prisma db pull` ejecutado exitosamente contra la BD Arteo.
- [ ] `schema.prisma` generado y revisado por S1.
- [ ] Migración inicial `0_init` creada con el DDL completo.
- [ ] `prisma generate` ejecutado sin errores.
- [ ] El cliente Prisma puede hacer una query simple sin error.

### Endpoint de health check

- [ ] `GET /health` retorna `{ status: 'ok', timestamp: '...' }`.
- [ ] **No requiere autenticación** — es el único endpoint público.
- [ ] Verifica conexión a PostgreSQL antes de responder.
- [ ] Verifica conexión a Redis antes de responder.
- [ ] Si PostgreSQL está caído: retorna 503.

```json
// GET /health — respuesta esperada (200)
{
  "status": "ok",
  "timestamp": "2026-04-27T10:30:00Z",
  "services": {
    "database": "ok",
    "redis": "ok"
  }
}
```

### Variables de entorno

- [ ] `.env.example` documenta todas las variables necesarias:

```bash
# App
NODE_ENV=development
PORT=3000
CORS_ORIGINS=http://localhost:4200,http://localhost:3001

# Database
DATABASE_URL=postgresql://erp_admin:password@localhost:5432/erp_db

# Redis
REDIS_URL=redis://localhost:6379

# Auth (placeholder hasta T-010)
JWT_SECRET=change-me-in-production
JWT_EXPIRATION=15m

# Tenant (para multi-tenancy)
DEFAULT_TENANT=demo
```

### Tests

- [ ] Test E2E smoke: `GET /health` retorna 200.
- [ ] Test unitario de `PrismaService`: conecta y desconecta correctamente.
- [ ] Test de `HttpExceptionFilter`: formatea errores en RFC 7807.
- [ ] Todos los tests pasan con `npm test`.

---

## Invariantes que el agente DEBE respetar

1. **Fastify, no Express.** Si hay algún conflicto de dependencias con Fastify, avisar a S1 antes de cambiar a Express.
2. **`schema.prisma` no se inventa.** Se genera con `prisma db pull` desde la BD real. Si la BD no está disponible, **pausar y avisar a S1**.
3. **Strict mode en TypeScript.** `"strict": true` en `tsconfig.json`. No desactivar para hacer pasar errores.
4. **Sin módulos de negocio.** Este ticket solo crea el esqueleto. Si el agente empieza a crear `BodegaModule` o `VentasModule`, se salió del scope.
5. **Decimal.js desde el inicio.** Aunque este ticket no tiene lógica monetaria, instalar `decimal.js` y agregar una nota en el README del servicio sobre cuándo usarlo.

---

## Cómo invocar al agente en Claude Code

```bash
cd tu-proyecto
git checkout -b feat/T-004-nestjs-base
claude
```

Prompt:
```
Ejecuta T-004 (proyecto NestJS base).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-004-nestjs-base.md
4. @docs/stack.md
5. @docs/prisma-workflow.md
6. @docs/adrs/ADR-010-monolito-modular.md

Antes de empezar, pregúntame:
1. ¿Está corriendo el docker-compose (T-002 completado)?
2. ¿Cuál es el DATABASE_URL de la BD Arteo?

No generes ningún módulo de negocio (bodega, ventas, etc.).
Solo el esqueleto del monolito + Prisma conectado a la BD.
```

---

## Validación post-ejecución (lo llena S1)

```bash
cd services/erp-api

# 1. Instalar dependencias
npm ci

# 2. Verificar que el schema se generó
cat prisma/schema.prisma | head -50
# Debe mostrar los modelos de la BD Arteo

# 3. Verificar estado de migraciones
npx prisma migrate status
# Debe decir: "All migrations have been applied"

# 4. Arrancar en desarrollo
npm run start:dev
# Debe arrancar sin errores en puerto 3000

# 5. Health check
curl http://localhost:3000/health
# Esperado: {"status":"ok","services":{"database":"ok","redis":"ok"}}

# 6. Swagger
# Abrir http://localhost:3000/api/docs
# Debe mostrar la documentación con el endpoint /health

# 7. Tests
npm test
# Todos deben pasar

# 8. Build
npm run build
# Debe compilar sin errores
```

- **Fecha:** _pendiente_
- **Schema generado por Prisma:** _pendiente (listar modelos principales)_
- **Health check OK:** _pendiente_
- **Tests:** _pendiente_
- **Resultado:** _pendiente_

---

## Notas para el supervisor S1

**Antes de ejecutar este ticket:**
1. Asegúrate de que T-002 (docker-compose) está completo y corriendo.
2. Ten a mano la `DATABASE_URL` de la BD Arteo. El agente la necesitará para `prisma db pull`.
3. Revisa el `schema.prisma` generado **antes de aprobar el PR**. Prisma puede malinterpretar algunas relaciones de la BD existente.

**Qué revisar en el PR:**
- El `schema.prisma` tiene los modelos correctos (tablas de Arteo reconocibles).
- Los tipos están bien mapeados (especialmente `jsonb` → `Json` y enums).
- Las relaciones (`@relation`) están correctamente definidas.
- No hay módulos de negocio en `src/modules/` (eso viene después).

---

**Creado:** 2026-04-27 por S1 + TL
**Prerrequisito:** T-002 (docker-compose) completado
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
