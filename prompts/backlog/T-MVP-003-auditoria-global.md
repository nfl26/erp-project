# T-MVP-003 · Auditoría global (`public.auditoria_global`)

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-MVP-003
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1 (con aprobación de TL antes de mergear — afecta arquitectura cross-módulo)
**Sprint:** Sprint 2
**Estimación:** 5 puntos
**Prioridad:** alta
**Rama:** `feat/T-MVP-003-auditoria-global`

---

## Contexto de negocio

`docs/rbac-matrix.md` declara que los siguientes eventos se auditan en `public.auditoria_global`:

- Asignación y revocación de roles.
- Creación, modificación y eliminación de usuarios.
- Intentos de acceso denegados (403) con umbral para detectar ataques.
- Cambios de tarifas (`produccion.tarifa.cambiada.v1`).
- Operaciones sensibles: cerrar O/P, aprobar cotización sobre umbral, eliminar insumos.

Esa tabla no existe hoy. Sin ella, todas esas garantías de auditoría son aspiracionales — el sistema no tiene memoria de quién hizo qué.

Este ticket crea la infraestructura: la tabla `public.auditoria_global` (en schema `public`, accesible desde todos los tenants), el `AuditoriaService` en NestJS, y el decorador `@Auditar()` que los otros módulos usan declarativamente para registrar eventos sensibles sin repetir código.

> ⚠️ **Este ticket es de Sprint 2.** Requiere que T-008 (auth) esté completo para tener `id_usuario` autenticado disponible en todos los eventos.

---

## Prerrequisitos

- [ ] **T-008 completado** — `JwtAuthGuard` disponible, `@CurrentUser()` decorator funcional.
- [ ] **T-MVP-001 completado** — patrón de eventos con `EventEmitter2` establecido.
- [ ] **T-MVP-002 completado** — evento `produccion.tarifa.cambiada.v1` existe y se puede consumir.

---

## Alcance técnico

### Nuevo en `schema.prisma`

```prisma
// En schema public — accesible desde todos los tenants
model AuditoriaGlobal {
  id            Int       @id @default(autoincrement())
  tenant_slug   String    @db.VarChar       // qué tenant generó el evento
  modulo        String    @db.VarChar(50)   // 'auth' | 'bodega' | 'produccion' | 'ventas'
  accion        String    @db.VarChar(100)  // 'usuario.creado' | 'tarifa.cambiada' | etc.
  id_usuario    Int?                        // NULL si es evento de sistema
  nombre_usuario String?  @db.VarChar(200) // denormalizado — para queries sin JOIN cross-schema
  recurso_tipo  String?   @db.VarChar(100) // 'Material' | 'Tarifa' | 'Usuario' | etc.
  recurso_id    String?   @db.VarChar(100) // ID del recurso afectado (como string para flexibilidad)
  payload       Json?                      // detalle completo del evento (antes/después si aplica)
  ip_origen     String?   @db.VarChar(45)  // IPv4 o IPv6
  resultado     String    @db.VarChar(20)  // 'ok' | 'denegado' | 'error'
  created_at    DateTime  @default(now())  @db.Timestamptz(6)

  @@index([tenant_slug, created_at])
  @@index([tenant_slug, modulo, accion])
  @@index([id_usuario, created_at])
  @@map("auditoria_global")
  @@schema("public")
}
```

> **Por qué en schema `public`:** la auditoría es cross-tenant por diseño. Los eventos de múltiples tenants viven en la misma tabla, discriminados por `tenant_slug`. Esto permite dashboards de auditoría para `super-admin` (fuera del MVP, pero la tabla lo soporta). Si la auditoría viviera en `tenant_erp`, no podría consultarse entre tenants sin cambiar el `search_path`.

### Crear en `services/erp-api/src/shared/`

```
src/shared/auditoria/
├── auditoria.module.ts           ← módulo global (@Global)
├── auditoria.service.ts          ← registrar(), queryAuditoria()
├── auditoria.interceptor.ts      ← interceptor HTTP que captura 403s automáticamente
├── decorators/
│   └── auditar.decorator.ts      ← @Auditar({ accion, recursoTipo })
├── listeners/
│   └── tarifa.listener.ts        ← consume 'produccion.tarifa.cambiada.v1'
│   └── movimiento.listener.ts    ← consume 'bodega.movimiento.registrado.v1' (solo ajustes)
└── auditoria.service.spec.ts
```

### No tocar

- Tablas de negocio en `tenant_erp`.
- Los módulos existentes (solo se les agrega el decorador `@Auditar()` en sus endpoints sensibles — eso puede ir en este ticket o en cada ticket de módulo).
- La política de RBAC de quién puede ver la auditoría (eso es T-008).

---

## Criterios de aceptación

### 1. Tabla `auditoria_global`

- [ ] Tabla existe en schema `public`.
- [ ] Los tres índices existen.
- [ ] `tenant_slug` tiene `NOT NULL` constraint.
- [ ] `resultado` tiene `CHECK (resultado IN ('ok', 'denegado', 'error'))`.
- [ ] La tabla **no tiene UPDATE ni DELETE** — `REVOKE UPDATE, DELETE ON public.auditoria_global FROM PUBLIC`.
- [ ] `npx prisma migrate dev` aplica la migración sin errores.

### 2. `AuditoriaService`

```typescript
// Registra un evento de auditoría — fire-and-forget (no bloquea el request)
async registrar(evento: AuditoriaEventoDto): Promise<void>

// Consulta auditoría con filtros y paginación
// Solo accesible por roles admin-sistema o gerencia
async queryAuditoria(filtros: FiltroAuditoriaDto): Promise<Paginated<AuditoriaGlobal>>
```

- [ ] `registrar()` es **no bloqueante** — usa `setImmediate` o una cola interna para no agregar latencia al request principal. Si falla la escritura a la BD de auditoría, **loggea el error pero no propaga la excepción** (el request no falla por auditoría).
- [ ] `registrar()` toma el `tenant_slug` del `TenantContext` (establecido por T-007).
- [ ] `registrar()` toma el `ip_origen` del request vía `X-Forwarded-For` o `req.ip`.
- [ ] `nombre_usuario` se denormaliza en el momento del registro — no se hace JOIN para recuperarlo después.

### 3. Decorador `@Auditar()`

```typescript
// Uso en controllers:
@Post()
@Auditar({ accion: 'usuario.creado', recursoTipo: 'Usuario' })
@RequirePermiso('auth:usuario:crear')
async crearUsuario(@Body() dto: CrearUsuarioDto, @CurrentUser() user: User) {
  // El interceptor inyectado por @Auditar() registra automáticamente
  // el resultado (ok/error) y el id del recurso creado
}
```

- [ ] El decorador acepta `{ accion: string, recursoTipo: string }`.
- [ ] El interceptor asociado captura el resultado del handler (ok / error / excepción).
- [ ] Si el handler retorna un objeto con `id` o `id_*`: lo usa como `recurso_id`.
- [ ] Si el handler lanza excepción: registra `resultado: 'error'` con el mensaje en `payload`.
- [ ] `payload` incluye el body del request (con campos sensibles redactados: `password`, `password_hash`, `token`).

### 4. Interceptor de 403

`AuditoriaInterceptor` (global, registrado en `AppModule`):

- [ ] Captura automáticamente todas las respuestas 403 del sistema.
- [ ] Registra en auditoría con `accion: 'acceso.denegado'`, `resultado: 'denegado'`.
- [ ] Incluye la ruta intentada y el método HTTP en `payload`.
- [ ] **No bloquea el 403** — solo registra el intento.

### 5. Listeners de eventos

`tarifa.listener.ts`:
- [ ] Escucha `produccion.tarifa.cambiada.v1` via `@OnEvent`.
- [ ] Registra en auditoría con `modulo: 'produccion'`, `accion: 'tarifa.cambiada'`, payload con `valorAnterior`, `valorNuevo`, `motivo`.

`movimiento.listener.ts`:
- [ ] Escucha `bodega.movimiento.registrado.v1`.
- [ ] Solo registra movimientos de tipo `AJUSTE_POSITIVO` y `AJUSTE_NEGATIVO` (los ajustes son los sensibles — entradas y salidas son operación normal).
- [ ] `accion: 'stock.ajustado'` con payload del ajuste.

### 6. Tests

- [ ] `registrar()` con BD disponible: inserta la fila correctamente.
- [ ] `registrar()` con BD caída: loggea el error pero **no lanza excepción** (el proceso continúa).
- [ ] `@Auditar()` en un endpoint exitoso: registra `resultado: 'ok'` con el `recurso_id` correcto.
- [ ] `@Auditar()` en un endpoint que lanza excepción: registra `resultado: 'error'`.
- [ ] Interceptor de 403: una request sin permiso registra `resultado: 'denegado'`.
- [ ] Campos sensibles redactados: payload con `password: 'hashed'` → guardado como `password: '[REDACTED]'`.
- [ ] Cobertura ≥ 80% en `auditoria.service.ts`.

---

## Invariantes que el agente DEBE respetar

1. **La auditoría nunca bloquea el request principal.** Si el `AuditoriaService` falla, el usuario recibe su respuesta normal. La falla se loggea con Pino pero no se propaga.
2. **Los registros de auditoría son inmutables** (REVOKE UPDATE, DELETE en BD).
3. **Campos sensibles siempre redactados** antes de guardar en `payload`. Lista mínima: `password`, `password_hash`, `token`, `refresh_token`, `secret`, `api_key`.
4. **`tenant_slug` siempre poblado.** Si por algún motivo el `TenantContext` no está disponible (ej: evento de sistema), usar el string `'system'`.
5. **No cross-schema queries.** `AuditoriaService` escribe en `public.auditoria_global` usando el `PrismaClient` con `search_path = public` — no mezcla con el schema del tenant en la misma query.

---

## Casos de prueba obligatorios

- **Caso 1 — Auditoría no bloquea:**
  - Setup: mockear `prisma.auditoriaGlobal.create` para que lance una excepción.
  - Input: request normal a cualquier endpoint con `@Auditar()`.
  - Esperado: el endpoint retorna 200/201 normalmente. El error de auditoría aparece en los logs (Pino) pero no en la respuesta.

- **Caso 2 — Redacción de campos sensibles:**
  - Input: `POST /api/v1/auth/usuarios` con body `{ nombre: 'Ana', password: 'secreta123' }`.
  - Esperado: en `auditoria_global.payload`, `password` aparece como `'[REDACTED]'`.

- **Caso 3 — Listener de tarifa:**
  - Setup: emitir evento `produccion.tarifa.cambiada.v1` via `EventEmitter2`.
  - Esperado: registro en `auditoria_global` con `accion = 'tarifa.cambiada'` y el payload correcto, dentro de los 100ms siguientes.

- **Caso 4 — 403 capturado:**
  - Setup: request a endpoint protegido sin el permiso requerido.
  - Esperado: response 403 al cliente Y registro en `auditoria_global` con `resultado = 'denegado'`.

---

## Lo que NO se debe hacer en esta tarea

- ❌ No agregar `@Auditar()` a todos los endpoints en este ticket. Solo los explícitamente sensibles listados en `rbac-matrix.md`. Los demás módulos lo agregarán en sus propios tickets.
- ❌ No crear endpoint de consulta de auditoría sin RBAC. `queryAuditoria` requiere rol `admin-sistema` o `gerencia`.
- ❌ No crear UI de auditoría. El backoffice lo hará en un ticket posterior.
- ❌ No hacer la tabla de auditoría editable. Registro append-only, inmutable.
- ❌ No bloquear el request principal si el servicio de auditoría falla.

---

## Entregables

- [ ] Tabla `public.auditoria_global` con constraints e índices.
- [ ] `AuditoriaService` con `registrar()` no bloqueante.
- [ ] Decorador `@Auditar()` e interceptor asociado.
- [ ] Interceptor global de 403.
- [ ] Listeners de eventos `tarifa.cambiada` y `stock.ajustado`.
- [ ] Tests con cobertura ≥ 80%.
- [ ] Commit: `feat(shared): add auditoria_global table + AuditoriaService [A1]`.
- [ ] PR con labels `agent:A1`, `supervisor:S1`, `sprint:2`, `priority:high`.

---

## Cómo invocar al agente

```bash
git checkout -b feat/T-MVP-003-auditoria-global
claude
```

Prompt:

```
Ejecuta T-MVP-003 (auditoría global).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md
3. @prompts/backlog/T-MVP-003-auditoria-global.md
4. @docs/rbac-matrix.md (sección Auditoría)
5. @docs/events.md
6. @services/erp-api/prisma/schema.prisma

Regla crítica: el AuditoriaService NUNCA bloquea el request principal.
Si falla la escritura a auditoría, el request sigue su curso normal.
```

---

## Validación post-ejecución (lo llena S1)

```bash
# 1. Verificar tabla en schema public
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  SELECT column_name FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'auditoria_global'
  ORDER BY ordinal_position;"

# 2. Verificar inmutabilidad
docker compose exec postgres psql -U erp_admin -d erp_db -c "
  UPDATE public.auditoria_global SET resultado = 'ok' WHERE id = 1;"
# Esperado: ERROR: permission denied

# 3. Tests
cd services/erp-api && npm test -- --testPathPattern=auditoria
```

- **Fecha:** _pendiente_
- **Tabla en schema public:** _pendiente_
- **Inmutabilidad verificada:** _pendiente_
- **AuditoriaService no bloqueante:** _pendiente_
- **Tests:** _pendiente_
- **Resultado:** _pendiente_

---

**Creado:** 2026-05-13 por TL + S1
**Prerrequisitos:** T-008, T-MVP-001, T-MVP-002 completados
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
