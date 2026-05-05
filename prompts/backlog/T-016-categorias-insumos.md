# T-016 · CRUD de categorías de insumos

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-016
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1 (Supervisor backend core)
**Sprint:** Sprint 1
**Estimación:** 5 puntos
**Prioridad:** crítica
**Rama:** `feat/T-016-categorias-insumos`

---

## Contexto de negocio

El bodeguero necesita organizar los insumos en categorías (ej: "Materias primas metálicas", "Insumos químicos", "Embalajes") para facilitar búsqueda, reportes de stock crítico, y aplicar reglas diferenciadas de mínimos de stock por categoría. Hoy está en una hoja Excel llamada `insumos.xlsx`, pestaña "Categorías", con 47 categorías activas.

## Alcance técnico

- **Crear:**
  - `services/erp-api/src/modules/bodega/src/modules/categorias/categorias.module.ts`
  - `services/erp-api/src/modules/bodega/src/modules/categorias/categorias.controller.ts`
  - `services/erp-api/src/modules/bodega/src/modules/categorias/categorias.service.ts`
  - `services/erp-api/src/modules/bodega/src/modules/categorias/dto/` (create, update, filter DTOs)
  - `services/erp-api/src/modules/bodega/src/modules/categorias/events/categoria.events.ts`
  - `services/erp-api/src/modules/bodega/src/modules/categorias/categorias.service.spec.ts`
  - `services/erp-api/src/modules/bodega/prisma/migrations/<timestamp>_add_categorias/`

- **Modificar:**
  - `services/erp-api/src/modules/bodega/prisma/schema.prisma` (agregar modelo `Categoria`)
  - `services/erp-api/src/modules/bodega/src/app.module.ts` (registrar `CategoriasModule`)
  - `docs/api/bodega.yaml` (agregar endpoints)

- **No tocar:**
  - Módulo de insumos (`services/erp-api/src/modules/bodega/src/modules/insumos/`) — solo se consume por foreign key.
  - Cualquier archivo fuera de `services/erp-api/src/modules/bodega/`.

## Criterios de aceptación

- [ ] `GET /categorias` devuelve listado paginado con filtros `?search=`, `?activa=true|false`
- [ ] `GET /categorias/:id` devuelve detalle con conteo de insumos asociados
- [ ] `POST /categorias` requiere rol `admin-bodega`, valida nombre único, retorna 201 con la entidad creada
- [ ] `PATCH /categorias/:id` requiere rol `admin-bodega`, permite cambios parciales
- [ ] `DELETE /categorias/:id` requiere rol `admin-bodega`; si tiene insumos asociados retorna 409 Conflict con mensaje claro
- [ ] Todos los endpoints excepto DELETE son consultables por rol `bodeguero` (solo lectura en su caso)
- [ ] Cada mutación emite evento a EventEmitter2 (mismo formato que usaríamos en RabbitMQ cuando se extraigan microservicios): `bodega.categoria.creada.v1`, `bodega.categoria.modificada.v1`, `bodega.categoria.eliminada.v1`
- [ ] OpenAPI completo con ejemplos request/response en Swagger
- [ ] Cobertura de tests del service ≥ 90%, del controller ≥ 70%
- [ ] Logs estructurados con Pino en cada mutación (userId, categoriaId, accion)

## Contratos y referencias

- **Contrato del agente:** [agents/A1-nestjs.md](../../agents/A1-nestjs.md)
- **OpenAPI base del servicio:** [docs/api/bodega.yaml](../../docs/api/bodega.yaml)
- **Convención de eventos:** [docs/events.md](../../docs/events.md)
- **Matriz RBAC:** [docs/rbac-matrix.md](../../docs/rbac-matrix.md)

## Invariantes de dominio a preservar

1. **Nombre de categoría único (case-insensitive)** por tenant. Test explícito requerido.
2. **No se puede eliminar categoría con insumos activos asociados.** Test explícito requerido.
3. **Toda mutación genera evento en EventEmitter2 (mismo formato que usaríamos en RabbitMQ cuando se extraigan microservicios).** Test de integración que verifica la publicación.
4. **Soft-delete, no hard-delete.** Campo `deletedAt` timestamp, nunca `DELETE FROM`.

## Casos de prueba obligatorios

- **Caso 1 — Crear categoría duplicada:**
  - Input: POST con nombre ya existente (incluso con distinta capitalización).
  - Esperado: 409 Conflict con mensaje `Categoría ya existe`.

- **Caso 2 — Eliminar categoría con insumos:**
  - Setup: Categoría con 3 insumos asociados activos.
  - Input: DELETE `/categorias/:id`.
  - Esperado: 409 Conflict con mensaje `No se puede eliminar: 3 insumos asociados`.

- **Caso 3 — Eliminar categoría sin insumos:**
  - Setup: Categoría sin insumos.
  - Input: DELETE `/categorias/:id`.
  - Esperado: 204 No Content, campo `deletedAt` seteado, evento `eliminada.v1` emitido.

- **Caso 4 — Listar con filtro de búsqueda:**
  - Setup: 10 categorías, 3 contienen "metal" en el nombre.
  - Input: GET `/categorias?search=metal`.
  - Esperado: 200 con las 3 que matchean, ordenadas alfabéticamente.

- **Caso 5 — Usuario sin rol admin intenta crear:**
  - Setup: Usuario con rol `bodeguero`.
  - Input: POST `/categorias`.
  - Esperado: 403 Forbidden.

## Lo que NO se debe hacer en esta tarea

- No importar las 47 categorías del Excel. Eso lo hace el agente A5 (ETL) en ticket T-021.
- No tocar el modelo `Insumo` — la relación ya existe, solo se referencia.
- No crear endpoint bulk (`POST /categorias/bulk`). Fuera de scope.
- No agregar cache de Redis por ahora. Ticket T-025 se encarga.
- No mezclar con el módulo de productos. Productos vive en el servicio de producción (dominio de A2).

## Entregables

- [ ] Código implementado en `feat/T-016-categorias-insumos`
- [ ] Tests unitarios con cobertura ≥ 90% del service
- [ ] OpenAPI actualizado en `docs/api/bodega.yaml`
- [ ] Migración Prisma generada y probada localmente
- [ ] README del módulo actualizado en `services/erp-api/src/modules/bodega/src/modules/categorias/README.md`
- [ ] Commit con formato: `feat(bodega): add categorias crud with events [A1]`
- [ ] PR abierto con labels `agent:A1`, `supervisor:S1`, `sprint:1`, `priority:critical`

---

## Validación post-ejecución

- **Fecha de ejecución:** _pendiente_
- **Iteraciones necesarias:** _pendiente_
- **Tiempo total de supervisión humana:** _pendiente_
- **Resultado:** _pendiente_
- **Notas:** _pendiente_

---

**Creado:** 2026-04-22 por S1
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
