# internal/recetas

Submódulo de recetas de producción.

**Ticket que lo implementa:** T-026
**Responsable:** A1 (Arquitecto NestJS), supervisado por S1 + S2

## Qué va aquí

- `recetas.service.ts` — CRUD de recetas y versiones
- `recetas.repository.ts` — queries Prisma para `recetas` y `receta_lineas`
- Reglas: nunca editar una versión existente; crear versión nueva

## Invariante clave

Las recetas son versionadas e inmutables. `receta_version` es un número entero
que crece. Editar una versión existente está prohibido (ver ADR-007 y contrato A1).
